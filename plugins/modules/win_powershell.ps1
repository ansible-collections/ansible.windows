#!powershell

# Copyright: (c) 2021, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -PowerShell Ansible.ModuleUtils.AddType
#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        arguments = @{ type = 'list'; elements = 'str' }
        chdir = @{ type = 'str' }
        creates = @{ type = 'str' }
        depth = @{ type = 'int'; default = 3 }
        error_action = @{ type = 'str'; choices = 'silently_continue', 'continue', 'stop'; default = 'continue' }
        executable = @{ type = 'str' }
        input = @{ type = 'list' }
        parameters = @{ type = 'dict' }
        removes = @{ type = 'str' }
        script = @{ type = 'str'; required = $true }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$module.Result.result = @{}
$module.Result.host_out = ''
$module.Result.host_err = ''
$module.Result.output = @()
$module.Result.error = @()
$module.Result.warning = @()
$module.Result.verbose = @()
$module.Result.debug = @()
$module.Result.information = @()

Add-CSharpType -AnsibleModule $module -References @'
using System;
using System.Collections.Generic;
using System.Collections.ObjectModel;
using System.Globalization;
using System.Management.Automation;
using System.Management.Automation.Host;
using System.Security;

namespace Ansible.Windows.WinPowerShell
{
    public class Host : PSHost
    {
        private readonly PSHost PSHost;
        private readonly HostUI HostUI;

        public Host(PSHost host){
            PSHost = host;
            HostUI = new HostUI();
        }

        public override CultureInfo CurrentCulture { get { return PSHost.CurrentCulture; } }

        public override CultureInfo CurrentUICulture { get {  return PSHost.CurrentUICulture; } }

        public override Guid InstanceId { get {  return PSHost.InstanceId; } }

        public override string Name { get { return PSHost.Name; } }

        public override PSHostUserInterface UI { get {  return HostUI; } }

        public override Version Version { get {  return PSHost.Version; } }

        public override void EnterNestedPrompt()
        {
            PSHost.EnterNestedPrompt();
        }

        public override void ExitNestedPrompt()
        {
            PSHost.ExitNestedPrompt();
        }

        public override void NotifyBeginApplication()
        {
            PSHost.NotifyBeginApplication();
        }

        public override void NotifyEndApplication()
        {
            PSHost.NotifyEndApplication();
        }

        public override void SetShouldExit(int exitCode)
        {
            PSHost.SetShouldExit(exitCode);
        }
    }

    public class HostUI : PSHostUserInterface
    {
        public HostUI() {}

        public override PSHostRawUserInterface RawUI { get { return null; } }

        public override Dictionary<string, PSObject> Prompt(string caption, string message, Collection<FieldDescription> descriptions)
        {
            throw new MethodInvocationException("PowerShell is in NonInteractive mode. Read and Prompt functionality is not available.");
        }

        public override int PromptForChoice(string caption, string message, Collection<ChoiceDescription> choices, int defaultChoice)
        {
            throw new MethodInvocationException("PowerShell is in NonInteractive mode. Read and Prompt functionality is not available.");
        }

        public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName, PSCredentialTypes allowedCredentialTypes, PSCredentialUIOptions options)
        {
            throw new MethodInvocationException("PowerShell is in NonInteractive mode. Read and Prompt functionality is not available.");
        }

        public override PSCredential PromptForCredential(string caption, string message, string userName, string targetName)
        {
            throw new MethodInvocationException("PowerShell is in NonInteractive mode. Read and Prompt functionality is not available.");
        }

        public override string ReadLine()
        {
            throw new MethodInvocationException("PowerShell is in NonInteractive mode. Read and Prompt functionality is not available.");
        }

        public override SecureString ReadLineAsSecureString()
        {
            throw new MethodInvocationException("PowerShell is in NonInteractive mode. Read and Prompt functionality is not available.");
        }

        public override void Write(ConsoleColor foregroundColor, ConsoleColor backgroundColor, string value)
        {
            Console.Write(value);
        }

        public override void Write(string value)
        {
            Console.Write(value);
        }

        public override void WriteDebugLine(string message)
        {
            Console.WriteLine(String.Format("DEBUG: {0}", message));
        }

        public override void WriteErrorLine(string value)
        {
            Console.Error.WriteLine(value);
        }

        public override void WriteLine(string value)
        {
            Console.WriteLine(value);
        }

        public override void WriteProgress(long sourceId, ProgressRecord record) {}

        public override void WriteVerboseLine(string message)
        {
            Console.WriteLine(String.Format("VERBOSE: {0}", message));
        }

        public override void WriteWarningLine(string message)
        {
            Console.WriteLine(String.Format("WARNING: {0}", message));
        }
    }
}
'@

Function Convert-OutputObject {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [AllowNull()]
        [object]
        $InputObject,

        [Parameter(Mandatory=$true)]
        [int]
        $Depth
    )

    process {
        $a = ''
        # TODO: DateTime/Type
        $_
    }
}

Function Format-Exception {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        $Exception
    )

    if (-not $Exception) {
        return $null
    }
    elseif ($Exception -is [Management.Automation.RemoteException]) {
        # When using a separate process the exceptions are a RemoteException, we want to get the info on the actual
        # exception.
        return Format-Exception -Exception $Exception.SerializedRemoteException
    }

    $type = if ($Exception -is [Exception]) {
        $Exception.GetType().FullName
    }
    else {
        # This is a RemoteException, we want to report the original non-serialized type.
        $Exception.PSTypeNames[0] -replace '^Deserialized.'
    }

    @{
        message = $Exception.Message
        type = $type
        help_link = $Exception.HelpLink
        source = $Exception.Source
        hresult = $Exception.HResult
        inner_exception = Format-Exception -Exception $Exception.InnerException
    }
}

Function Test-AnsiblePath {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [String]
        $Path
    )

    # Certain system files fail on Test-Path due to it being locked, we can still get the attributes though.
    try {
        [void][System.IO.File]::GetAttributes($Path)
        return $true
    } catch [System.IO.FileNotFoundException], [System.IO.DirectoryNotFoundException] {
        return $false
    } catch [NotSupportedException] {
        # When testing a path like Cert:\LocalMachine\My, System.IO.File will
        # not work, we just revert back to using Test-Path for this
        return Test-Path -Path $Path
    }
}

$creates = $module.Params.creates
if ($creates -and (Test-AnsiblePath -Path $creates)) {
    $module.Result.msg = "skipped, since $creates exists"
    $module.ExitJson()
}

$removes = $module.Params.removes
if ($removes -and -not (Test-AnsiblePath -Path $removes)) {
    $module.Result.msg = "skipped, since $removes does not exist"
    $module.ExitJson()
}

# Check if the script has [CmdletBinding(SupportsShouldProcess)] on it
$scriptAst = [ScriptBlock]::Create($module.Params.script).Ast
$supportsShouldProcess = $false
if ($scriptAst -is [Management.Automation.Language.ScriptBlockAst] -and $scriptAst.ParamBlock.Attributes) {
    $supportsShouldProcess = [bool]($scriptAst.ParamBlock.Attributes |
        Where-Object { $_.TypeName.Name -eq 'CmdletBinding' } |
        Select-Object -First 1 |
        ForEach-Object -Process {
            $_.NamedArguments | Where-Object {
                $_.ArgumentName -eq 'SupportsShouldProcess' -and ($_.ExpressionOmitted -or $_.Argument.ToString() -eq '$true')
            }
        })
}

if ($module.CheckMode -and -not $supportsShouldProcess) {
    $module.Result.changed = $true
    $module.Result.msg = "skipped, running in check mode"
    $module.ExitJson()
}

$runspace = $null
$process = $null
$connInfo = $null

if ($module.Params.executable) {
    if ($PSVersionTable.PSVersion -lt [version]'5.0') {
        $module.FailJson("executable requires PowerShell 5.0 or newer")
    }

    # TODO: Should we use -NoNewWindow so we can capture [Console]::WriteLine()?
    # Will this cause issues with random data coming back to Ansible (things bypassing redirection)?
    $processParams = @{
        FilePath = $module.Params.executable
        WindowStyle = 'Hidden'  # Really just to help with debugging locally
        PassThru = $true
    }
    if ($module.Params.arguments) {
        $processParams.ArgumentList = $module.Params.arguments
    }
    $process = Start-Process @processParams
    $connInfo = [System.Management.Automation.Runspaces.NamedPipeConnectionInfo]$process.Id

    # In case a user specified an executable that does not support the PSHost named pipe that PowerShell uses we
    # specify a timeout so the module does not hang.
    $connInfo.OpenTimeout = 5000
}

try {
    # Using a custom host allows us to capture any host UI calls through our own Console output.
    $runspaceHost = New-Object -TypeName Ansible.Windows.WinPowerShell.Host -ArgumentList $Host
    if ($connInfo) {
        $runspace = [RunspaceFactory]::CreateRunspace($runspaceHost, $connInfo)    
    }
    else {
        $runspace = [RunspaceFactory]::CreateRunspace($runspaceHost)
    }

    $runspace.Open()

    $ps = [PowerShell]::Create()
    $ps.Runspace = $runspace

    $ps.Runspace.SessionStateProxy.SetVariable('Ansible', [PSCustomObject]@{
        PSTypeName = 'Ansible.Windows.WinPowerShell.Module'
        CheckMode = $module.CheckMode
        Result = @{}
        Changed = $true
        Failed = $false
        Tmpdir = $module.Tmpdir
    })

    $eap = switch ($module.Params.error_action) {
        'stop' { 'Stop' }
        'continue' { 'Continue' }
        'silently_continue' { 'SilentlyContinue' }
    }
    $ps.Runspace.SessionStateProxy.SetVariable('ErrorActionPreference', [Management.Automation.ActionPreference]$eap)

    if ($connInfo) {
        # If we are running in a new process we need to set the various console encoding values to UTF-8 to ensure a
        # consistent encoding experience when PowerShell is running native commands and getting the output back.
        [void]$ps.AddScript(@'
$OutputEncoding = [Console]::InputEncoding = [Console]::OutputEncoding = New-Object Text.UTF8Encoding $false
'@).AddStatement()
    }

    if ($module.Params.chdir) {
        [void]$ps.AddCommand('Set-Location').AddParameter('LiteralPath', $module.Params.chdir).AddStatement()
    }

    [void]$ps.AddScript($module.Params.script)

    # We copy the existing parameter dictionary and add/modify the Confirm/WhatIf parameters if the script supports
    # processing. We do a copy to avoid modifying the original Params dictionary just for safety.
    $parameters = @{}
    if ($module.Params.parameters) {
        foreach ($kvp in $module.Params.parameters.GetEnumerator()) {
            $parameters[$kvp.Key] = $kvp.Value
        }
    }
    if ($supportsShouldProcess) {
        # We do this last to ensure we take precedence over any user inputted settings.
        $parameters.Confirm = $false  # Ensure we don't block on any confirmation prompts
        $parameters.WhatIf = $module.CheckMode
    }

    if ($parameters) {
        [void]$ps.AddParameters($parameters)
    }

    # We cannot natively call a generic function so need to resort to reflection to get the method we know is there
    # and turn it into an invocable method. We do this so we can call the overload that takes in an IList for the
    # output which means we don't loose anything from before a terminating exception was raised.
    $psOutput = [Collections.Generic.List[Object]]@()
    $invokeMethod = $ps.GetType().GetMethods('Public, Instance, InvokeMethod') | Where-Object {
        if ($_.Name -ne 'Invoke' -or $_.ReturnType -ne [void] -or -not $_.ContainsGenericParameters) {
            return $false
        }
    
        # https://docs.microsoft.com/en-us/dotnet/api/system.management.automation.powershell.invoke?view=powershellsdk-7.0.0#System_Management_Automation_PowerShell_Invoke__1_System_Collections_IEnumerable_System_Collections_Generic_IList___0__
        $parameters = $_.GetParameters()
        (
            $parameters.Count -eq 2 -and
            $parameters[0].ParameterType -eq [Collections.IEnumerable] -and
            $parameters[1].ParameterType.Namespace -eq 'System.Collections.Generic' -and
            $parameters[1].ParameterType.Name -eq 'IList`1'
        )
    }
    $invoke = $invokeMethod.MakeGenericMethod([object])

    # We redirect the current stdout and stderr so we can capture any console output.
    $origStdout = [System.Console]::Out
    $origStderr = [System.Console]::Error
    $stdoutBuffer = New-Object -TypeName System.Text.StringBuilder
    $stderrBuffer = New-Object -TypeName System.Text.StringBuilder
    $newStdout = New-Object -TypeName System.IO.StringWriter -ArgumentList $stdoutBuffer
    $newStderr = New-Object -TypeName System.IO.StringWriter -ArgumentList $stderrBuffer

    try {
        [System.Console]::SetOut($newStdout)
        [System.Console]::SetError($newStderr)

        # TODO: The input here is problematic in some scenarios, figure this out more.
        $invoke.Invoke($ps, @(@($module.Params.input), $psOutput))
    }
    catch [Management.Automation.RuntimeException] {
        # $ErrorActionPrefrence = 'Stop' and an error was raised
        # OR
        # General exception was raised in the script like 'throw "error"'.
        # We treat these as failures in the script and return them back to the user.
        $module.Result.failed = $true
        $ps.Streams.Error.Add($_.Exception.ErrorRecord)
    }
    finally {
        [System.Console]::SetOut($origStdout)
        [System.Console]::SetError($origStderr)

        $newStdout.Dispose()
        $newStderr.Dispose()
    }

    # Get the internal Ansible variable that can contain code specific information.
    $result = $ps.Runspace.SessionStateProxy.GetVariable('Ansible')

    $module.Result.host_out = $stdoutBuffer.ToString()
    $module.Result.host_err = $stderrBuffer.ToString()
    $module.Result.result = $result.Result
    $module.Result.changed = $result.Changed
    $module.Result.failed = $module.Result.failed -or $result.Failed
}
finally {
    if ($runspace) {
        $runspace.Dispose()
    }
    if ($process) {
        $process | Stop-Process -Force
    }
}

# We process the output outselves to flatten anything beyond the depth and deal with certain problemactic types with
# json serialization.
$module.Result.output = @($psOutput | Convert-OutputObject -Depth $module.Params.depth)

$module.Result.error = @($ps.Streams.Error | ForEach-Object -Process {
    $err = @{
        output = ($_ | Out-String)
        error_details = $null
        exception = Format-Exception -Exception $_.Exception
        target_object = $_.TargetObject
        category_info = @{
            category = [string]$_.CategoryInfo.Category
            category_id = [int]$_.CategoryInfo.Category
            activity = $_.CategoryInfo.Activity
            reason = $_.CategoryInfo.Reason
            target_name = $_.CategoryInfo.TargetName
            target_type = $_.CategoryInfo.TargetType
        }
        fully_qualified_error_id = $_.FullyQualifiedErrorId
        script_stack_trace = $_.ScriptStackTrace
        pipeline_iteration_info = $_.PipelineIterationInfo
    }
    if ($_.ErrorDetails) {
        $err.error_details = @{
            message = $_.ErrorDetails.Message
            recommended_action = $_.ErrorDetails.RecommendedAction
        }
    }

    $err
})

'debug', 'verbose', 'warning' | ForEach-Object -Process {
    $module.Result.$_ = @($ps.Streams.$_ | Select-Object -ExpandProperty Message)
}

# Use Select-Object as Information may not be present on earlier pwsh version (<v5).
$module.Result.information = @($ps.Streams | Select-Object -ExpandProperty Information | ForEach-Object -Process {
    @{
        message_data = $_.MessageData
        source = $_.Source
        time_generated = $_.TimeGenerated.ToUniversalTime().ToString('o')
        tags = @($_.Tags)
    }
})

$module.ExitJson()
