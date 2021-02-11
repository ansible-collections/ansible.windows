#!powershell

# Copyright: (c) 2021, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -PowerShell Ansible.ModuleUtils.AddType
#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        arguments = @{ type = 'list'; elements = 'str' }
        creates = @{ type = 'path' }
        executable = @{ type = 'str' }
        input = @{ type = 'list' }
        location = @{ type = 'str' }
        parameters = @{ type = 'dict' }
        removes = @{ type = 'path' }
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

    try {
        $attributes = [System.IO.File]::GetAttributes($Path)
    } catch [System.IO.FileNotFoundException], [System.IO.DirectoryNotFoundException] {
        return $false
    } catch [NotSupportedException] {
        # When testing a path like Cert:\LocalMachine\My, System.IO.File will
        # not work, we just revert back to using Test-Path for this
        return Test-Path -Path $Path
    }

    if ([Int32]$attributes -eq -1) {
        return $false
    } else {
        return $true
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

if ($module.CheckMode) {
    $module.Result.changed = $true
    $module.Result.msg = "skipped, running in check mode"
    $module.ExitJson()
}

$runspace = $null
$process = $null
$connInfo = $null

if ($module.Params.executable) {
    # TODO: Fail if running on powershell <5. It does not support NamedPipeConnectionInfo.
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

    # TODO: Set the location.

    # TODO: Do we actually want the script to be able to set some of these values?
    $ps.Runspace.SessionStateProxy.SetVariable('Ansible', [PSCustomObject]@{
        Result = @{}
        Changed = $true
        Failed = $false
        Tmpdir = $module.Tmpdir
    })

    [void]$ps.AddScript($module.Params.script)

    if ($module.Params.parameters) {
        [void]$ps.AddParameters($module.Params.parameters)
    }

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

        # TODO: need to test out various scenarios to see if this will ever throw an exception rather than just output
        # to the error stream.
        $module.Result.output = @($ps.Invoke($module.Params.input))
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

    # TODO: check when HadErrors is actually set and document that.
    $module.Result.failed = $result.Failed -or $ps.HadErrors
}
finally {
    if ($runspace) {
        $runspace.Dispose()
    }
    if ($process) {
        $process | Stop-Process -Force
    }
}

$module.Result.error = @($ps.Streams.Error | ForEach-Object -Process {
    # TODO: ErrorDetails
    @{
        output = ($_ | Out-String)
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
})

'debug', 'verbose', 'warning' | ForEach-Object -Process {
    $module.Result.$_ = @($ps.Streams.$_ | Select-Object -ExpandProperty Message)
}

# TODO: Will this fail on pre v5 as they don't have the Information stream.
$module.Result.information = @($ps.Streams.Information | ForEach-Object -Process {
    @{
        message_data = $_.MessageData
        source = $_.Source
        time_generated = $_.TimeGenerated.ToUniversalTime().ToString('o')
        tags = @($_.Tags)
        user = $_.User
        computer = $_.Computer
        process_id = $_.ProcessId
        native_thread_id = $_.NativeThreadId
        managed_thread_id = $_.ManagedThreadId
    }
})

$module.ExitJson()
