#!powershell

# Copyright: (c) 2015, Matt Davis <mdavis@rolpdog.com>
# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -PowerShell Ansible.ModuleUtils.AddType
#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        accept_list = @{ type = 'list'; elements = 'str'; aliases = 'whitelist' }
        category_names = @{
            type = 'list'
            elements = 'str'
            default = 'CriticalUpdates', 'SecurityUpdates', 'UpdateRollups'
        }
        log_path = @{ type = 'path' }
        reject_list = @{ type = 'list'; elements = 'str'; aliases = 'blacklist' }
        server_selection = @{ type = 'str'; choices = 'default', 'managed_server', 'windows_update'; default = 'default' }
        state = @{ type = 'str'; choices = 'installed', 'searched', 'downloaded'; default = 'installed' }
        skip_optional = @{ type = 'bool'; default = $false }

        # options used by the action plugin - ignored here
        reboot = @{ type = 'bool'; default = $false }
        reboot_timeout = @{ type = 'int'; default = 1200}
        use_scheduled_task = @{ type = 'bool'; default = $false}
        _wait = @{ type = 'bool'; default = $false }
        _output_path = @{ type = 'str' }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

# For backwards compatibility - allow the camel case names but internally use the full names
$categoryNames = $module.Params.category_names | ForEach-Object -Process {
    switch -exact ($_) {
        CriticalUpdates { 'Critical Updates' }
        DefinitionUpdates { 'Definition Updates' }
        DeveloperKits { 'Developer Kits' }
        FeaturePacks { 'Feature Packs' }
        SecurityUpdates { 'Security Updates' }
        ServicePacks { 'Service Packs' }
        UpdateRollups { 'Update Rollups' }
        default { $_ }
    }
}

Function Invoke-TaskInfo {
    <#
    .SYNOPSIS
    Bootstrap script used as the entrypoint for our ephemeral task to invoke the code written to the pipe.

    .PARAMETER PipeName
    The named pipe to read the invocation details from.

    .PARAMETER LogPath
    Write any failures to this path for reporting an error to the parent.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]
        $Id,

        [Parameter(Mandatory)]
        [String]
        $LogPath
    )

    $ErrorActionPreference = 'Stop'

    # Traps are icky but it does have the convenience of capturing all failures for us to log
    trap {
        $errInfo = $runInfo = [System.Management.Automation.PSSerializer]::Serialize($_)
        $errInfo | Out-File (Join-Path $LogPath 'error.txt')
        [System.Environment]::Exit(1)
    }

    # NamedPipeClientStream does not fail if the pipe does not exist and will hang indefinitely. In case there was a
    # problem with starting the pipe fail straight away instead of hanging. We cannot use Test-Path as that will
    # connect to the pipe which we want to reserve for our explicit .Connect() call later on. We also cannot use the
    # $Id as the filter part because old Win versions (2008/08R2) do not seem to support filtering for pipes there.
    # While we don't guarantee support for these versions I'm not ready to fully drop it when there's a simple
    # workaround.
    # Also need to enumerate the output manually to ignore illegal paths in .NET logic
    # https://github.com/ansible-collections/ansible.windows/issues/291
    $pipeEnumerator = [System.IO.Directory]::EnumerateFiles('\\.\pipe\', '*').GetEnumerator()
    try {
        while ($true) {
            try {
                $remaining = $pipeEnumerator.MoveNext()
            }
            catch {
                continue
            }

            if (-not $remaining) {
                throw "Pipe $Id does not exist"
            }

            if ($pipeEnumerator.Current -eq "\\.\pipe\$Id") {
                break
            }
        }
    }
    finally {
        $pipeEnumerator.Dispose()
    }

    $clientReader = $null
    $client = New-Object -TypeName System.IO.Pipes.NamedPipeClientStream -ArgumentList @(
        '.',
        $Id,
        [System.IO.Pipes.PipeDirection]::In,
        [System.IO.Pipes.PipeOptions]::None,
        [System.Security.Principal.TokenImpersonationLevel]::Anonymous
    )
    try {
        $client.Connect()
        $clientReader = New-Object -TypeName System.IO.StreamReader -ArgumentList $client
        $details = $clientReader.ReadToEnd()
    }
    finally {
        if ($clientReader) { $clientReader.Dispose() }
        $client.Dispose()
    }

    $rs = $null
    try {
        $eventHandle = [System.Threading.EventWaitHandle]::OpenExisting("Global\$Id")
        try {
            $runInfo = [System.Management.Automation.PSSerializer]::Deserialize($details)

            $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
            foreach ($funcInfo in $runInfo.Commands.GetEnumerator()) {
                $cmd = New-Object -TypeName System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList @(
                    $funcInfo.Key,
                    $funcInfo.Value,
                    [System.Management.Automation.ScopedItemOptions]::AllScope,
                    $null
                )
                $iss.Commands.Add($cmd)
            }

            $rs = [RunspaceFactory]::CreateRunspace($iss)
            $rs.Open()

            $ps = [PowerShell]::Create()
            $ps.Runspace = $rs
            [void]$ps.AddScript($runInfo.ScriptBlock).AddParameters($runInfo.Parameters)
            $task = $ps.BeginInvoke()

            # Signal parent that the data was received/decoded and is running.
            [void]$eventHandle.Set()
        }
        finally {
            $eventHandle.Dispose()
        }

        $ps.EndInvoke($task)
    }
    finally {
        if ($rs) { $rs.Dispose() }
    }
}

Function New-NamedPipe {
    <#
    .SYNOPSIS
    Creates a namedpipe accessible to the current user.

    .PARAMETER Name
    The pipe name to create.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingEmptyCatchBlock", "",
        Justification="We don't care about failures on dispoable, especially ones we know will occur")]
    [OutputType([System.IO.StreamWriter])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]
        $Name
    )

    $currentUser = ([Security.Principal.WindowsIdentity]::GetCurrent()).User
    $systemSid = (New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList @(
        [Security.Principal.WellKnownSidType ]::LocalSystemSid, $null))

    $pipeSec = New-Object -TypeName System.IO.Pipes.PipeSecurity
    foreach ($sid in @($currentUser, $systemSid)) {
        $pipeSec.AddAccessRule($pipeSec.AccessRuleFactory(
            $sid,
            [Int32]([System.IO.Pipes.PipeAccessRights]'ReadData,ReadAttributes,ReadExtendedAttributes,Synchronize'),
            $false,
            [System.Security.AccessControl.InheritanceFlags]::None,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Allow
        ))
    }

    # FUTURE: This won't work on pwsh as it doesn't take the PipeSecurity overload. Unfortunately the only way to do
    # that before .NET 5 (pwsh 7.2+) is to use PInvoke to call CreateNamedPipeW.
    $server = New-Object -TypeName System.IO.Pipes.NamedPipeServerStream -ArgumentList @(
        $Name,
        [System.IO.Pipes.PipeDirection]::Out,
        1,
        [System.IO.Pipes.PipeTransmissionMode]::Byte,
        [System.IO.Pipes.PipeOptions]::Asynchronous,
        0,
        0,
        $pipeSec
    )

    $sw = New-Object -TypeName System.IO.StreamWriter -ArgumentList $server

    # Calling Dispose() on the stream will throw an exception is no client has connected to the server. It still
    # closes the stream which is what we want so we just ignore the exception.
    $sw.PSObject.Members.Add((New-Object -TypeName System.Management.Automation.PSScriptMethod -ArgumentList @(
        'Dispose',
        {
            try {
                $this.PSBase.Dispose()
            }
            catch [System.InvalidOperationException] {}
        }
    )))

    $sw
}

Function Start-EphemeralTask {
    <#
    .SYNOPSIS
    Creates and starts the process as a scheduled task immediately.

    .PARAMETER Name
    The name of the task to create.

    .PARAMETER Path
    The executable path to invoke.

    .PARAMETER Arguments
    The arguments to run the task with.
    #>
    [OutputType([Int32])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [String]
        $Name,

        [Parameter(Mandatory)]
        [String]
        $Path,

        [Parameter(Mandatory)]
        [String]
        $Arguments
    )

    $errMessage = $null
    $scheduler = New-Object -ComObject Schedule.Service
    try {
        $scheduler.Connect()
        $taskFolder = $scheduler.GetFolder('\')

        # Stop and delete the task if it is already running
        $task = $null
        $folderTasks = $taskFolder.GetTasks(1)  # TASK_ENUM_HIDDEN
        for ($i = 1; $i -le $folderTasks.Count; $i++) {
            if ($folderTasks.Item($i).Name -eq $Name) {
                $task = $folderTasks.Item($i)
                break
            }
        }
        if ($task) {
            if ($task.State -eq 4) {  # TASK_STATE_RUNNING
                $task.Stop(0)
            }
            $taskFolder.DeleteTask($Name, 0)
        }

        $taskDefinition = $scheduler.NewTask(0)

        $taskAction = $taskDefinition.Actions.Create(0)  # TASK_ACTION_EXEC
        $taskAction.Path = $Path
        $taskAction.Arguments = $Arguments

        $taskDefinition.Settings.AllowDemandStart = $true
        $taskDefinition.Settings.AllowHardTerminate = $true
        $taskDefinition.Settings.DisallowStartIfOnBatteries = $false
        $taskDefinition.Settings.Enabled = $true
        $taskDefinition.Settings.StopIfGoingOnBatteries = $false

        # Try the current user first but fallback to SYSTEM in case the user isn't allowed to do batch logons.
        $userSids = @(
            [Security.Principal.WindowsIdentity]::GetCurrent().User
            (New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList @(
                [Security.Principal.WellKnownSidType ]::LocalSystemSid, $null))
        )
        foreach ($sid in $userSids) {
            # While S4U is designed for normal user accounts it is accepted for well known service accounts
            $taskDefinition.Principal.UserId = $sid.Value
            $taskDefinition.Principal.LogonType = 2  # TASK_LOGON_S4U
            $taskDefinition.Principal.RunLevel = 1  # TASK_RUNLEVEL_HIGHEST

            $registerDate = Get-Date
            $createdTask = $taskFolder.RegisterTaskDefinition(
                $Name,
                $taskDefinition,
                2,  # TASK_CREATE
                $null,
                $null,
                $taskDefinition.Principal.LogonType
            )
            try {
                $runningTask = $createdTask.RunEx(
                    $null,
                    2,  # TASK_RUN_IGNORE_CONSTRAINTS
                    0,
                    ""
                )

                # Gets the task logs if there is a failure and has been logged after the register datetime.
                $taskFilter = @"
<QueryList>
    <Query Id="0" Path="Microsoft-Windows-TaskScheduler/Operational">
        <Select Path="Microsoft-Windows-TaskScheduler/Operational">
            *[
                EventData/Data[@Name='TaskName']='\$Name'
            and
                System[(Level=2)]
            and
                System[TimeCreated[@SystemTime&gt;='$($registerDate.ToUniversalTime().ToString("o"))']]
            ]
        </Select>
    </Query>
</QueryList>
"@
                # There is a chance EnginePID isn't yet defined (task hasn't fully started). We want to wait until that prop
                # is populated before returning the value and continuing on.
                $taskPid = 0
                $errMessage = $null
                while ($true) {
                    # The task might still be initialising, wait until it is no longer queued
                    if ($createdTask.LastTaskResult -eq 0x00041325) {  # SCHED_S_TASK_QUEUED
                        Start-Sleep -Seconds 1
                        continue
                    }

                    $taskPid = $runningTask.EnginePID

                    if ($taskPid) {
                        break
                    }

                    if ($createdTask.State -ne 4) {  # TASK_STATE_RUNNING
                        $errEvent = Get-WinEvent -FilterXml $taskFilter -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($errEvent) {
                            $errMessage = $errEvent.Message
                        }
                        else {
                            # If event logs are disabled for tasks we can only use the last run result for information.
                            $errMessage = "Unknown failure trying to start win_updates tasks '0x{0:X8}'- enable task event logs to see more info" -f (
                                $createdTask.LastTaskResult
                            )
                        }

                        break
                    }
                    Start-Sleep -Seconds 1
                }

                if ($taskPid) {
                    $taskPid
                    break
                }
            }
            finally {
                # The task will continue to run even after it is deleted
                $taskFolder.DeleteTask($Name, 0)
            }
        }

        if ($errMessage) {
            throw "Failed to start task: $errMessage"
        }
    }
    finally {
        [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($scheduler)
    }
}

Function Invoke-AsBatchLogon {
    <#
    .SYNOPSIS
    Invoke the scriptblock as a batch logon through the task scheduler.

    .PARAMETER Path
    The directory to store the bootstrap script and any errors it encountered.

    .PARAMETER ScriptBlock
    The scriptblock to invoke.

    .PARAMETER Parameters
    The parameters to invoke on the scriptblock.

    .PARAMETER Wait
    Wait for the scriptblock to finish instead of it running in the background.
    #>
    [OutputType([int])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Ansible.Basic.AnsibleModule]
        $Module,

        [Parameter(Mandatory)]
        [ScriptBlock]
        $ScriptBlock,

        [Parameter(Mandatory)]
        [Hashtable]
        $Parameters,

        [Parameter()]
        [Hashtable]
        $Commands = @{},

        [Switch]
        $Wait
    )

    $errPath = Join-Path $Module.Tmpdir 'error.txt'
    if (Test-Path -LiteralPath $errPath) {
        Remove-Item -LiteralPath $errpath -Force
    }

    $eventHandle = $server = $null
    try {
        $pipeName = "ansible-$($Module.ModuleName)-$([Guid]::NewGuid().Guid)"
        $server = New-NamedPipe -Name $pipeName
        $waitConnect = $server.BaseStream.BeginWaitForConnection($null, $null)

        $eventHandle = New-Object -TypeName System.Threading.EventWaitHandle -ArgumentList @(
            $false,
            [System.Threading.EventResetMode]::ManualReset,
            "Global\$pipeName"
        )
        [void]$eventHandle.Reset()

        $scriptPath = Join-Path $Module.Tmpdir 'task.ps1'
        Set-Content -LiteralPath $scriptPath -Value ${function:Invoke-TaskInfo}

        $pwsh = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        $arguments = '-ExecutionPolicy ByPass -NoProfile -NonInteractive -File "{0}" -Id "{1}" -LogPath "{2}"' -f (
            $scriptPath, $pipeName, $module.TmpDir
        )
        $taskPid = Start-EphemeralTask -Name "ansible-$($Module.ModuleName)" -Path $pwsh -Arguments $arguments

        # Wait for the task to connect to our pipe or for the process to end (failed and should be reported)
        $waitProcPS = [PowerShell]::Create()
        [void]$waitProcPS.AddCommand('Wait-Process').AddParameters(@{Id=$taskPid; ErrorAction='SilentlyContinue'})
        $waitProcTask = $waitProcPS.BeginInvoke()

        $waitIdx = [System.Threading.WaitHandle]::WaitAny(@(
            $waitProcTask.AsyncWaitHandle, $waitConnect.AsyncWaitHandle
        ))
        if ($waitIdx -eq 0) {
            throw "Task failed to connect to pipe"
        }

        $server.BaseStream.EndWaitForConnection($waitConnect)
        $runInfo = [System.Management.Automation.PSSerializer]::Serialize(@{
            Commands = $Commands
            ScriptBlock = $ScriptBlock.ToString()
            Parameters = $Parameters
        })
        $server.WriteLine($runInfo)
        $server.BaseStream.WaitForPipeDrain()
        # Close the named pipe so the client knows it's reached the end
        $server.Dispose()

        # Wait for confirmation the task has received the data and has started the task or failed (proc has ended)
        $waitIdx = [System.Threading.WaitHandle]::WaitAny(@(
            $waitProcTask.AsyncWaitHandle, $eventHandle
        ))

        if ($waitIdx -eq 0) {
            throw "Task failed to invoke script"
        }

        if ($Wait) {
            [void]$waitProcPS.EndInvoke($waitProcTask)
        }
        else {
            $waitProcPS.Stop()
        }

        $taskPid
    }
    catch {
        if (Test-Path -LiteralPath $errPath) {
            $rawError = Get-Content -LiteralPath $errPath -Raw
            $errDetails = [System.Management.Automation.PSSerializer]::Deserialize($rawError)

            # Because the ErrorRecord is a deserialized object we need to manually build the exception msg.
            $catInfo = '{0}: ({1}:{2}) [{3}], {4}' -f (
                [System.Management.Automation.ErrorCategory]$errDetails.ErrorCategory_Category,
                $errDetails.ErrorCategory_TargetName,
                $errDetails.ErrorCategory_TargetType,
                $errDetails.ErrorCategory_Activity,
                $errDetails.ErrorCategory_Reason
            )
            $exceptionString = "{0}`r`n{1}" -f ($errDetails.ToString(), $errDetails.InvocationInfo.PositionMessage)
            $exceptionString += "`r`n    + CategoryInfo          : {0}" -f $catInfo
            $exceptionString += "`r`n    + FullyQualifiedErrorId : {0}" -f $errDetails.FullyQualifiedErrorId
            $exceptionString += "`r`n`r`nScriptStackTrace:`r`n{0}" -f $errDetails.ErrorDetails_ScriptStackTrace

            $Module.Result.exception = $exceptionString
            $Module.FailJson("Failure in task bootstrap script ($($_.Exception.Message)): $($errDetails.ToString())")
        }
        else {
            $Module.FailJson("Failed to invoke batch script: $($_.Exception.Message)", $_)
        }
    }
    finally {
        if ($eventHandle) { $eventHandle.Dispose() }
        if ($server) { $server.Dispose() }
    }
}

Function Install-WindowsUpdate {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String[]]
        $Category,

        [Parameter(Mandatory)]
        [String]
        $ServerSelection,

        [Parameter(Mandatory)]
        [String]
        $State,

        [Parameter(Mandatory)]
        [String]
        $OutputPath,

        [Parameter(Mandatory)]
        [String]
        $CancelId,

        [Parameter()]
        [AllowEmptyCollection()]
        [String[]]
        $Accept = @(),

        [Parameter()]
        [Switch]
        $SkipOptional,

        [Parameter()]
        [AllowEmptyCollection()]
        [String[]]
        $Reject = @(),

        [Parameter()]
        [String]
        $LogPath,

        [Switch]
        $CheckMode,

        [Switch]
        $LocalDebugger
    )

    $ErrorActionPreference = 'Stop'

    $exitResult = @{
        changed = $false
        failed = $false
        reboot_required = $false
        action = $null  # Current action, used for exception information if set
        exception = $null  # Exception info in case of a failure @{message, exception, hresult}
    }

    $tmpDir = Split-Path -Path $outputPath -Parent
    Add-CSharpType -TempPath $tmpDir -References @'
using System;
using System.Collections;
using System.Collections.Generic;
using System.IO;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Management.Automation;
using System.Management.Automation.Runspaces;
using System.Threading;
using System.Threading.Tasks;

namespace Ansible.Windows.WinUpdates
{
    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("77254866-9F5B-4C8E-B9E2-C77A8530D64B")]
    public interface IDownloadCompletedCallback
    {
        void Invoke(IDownloadJob job, IDownloadCompletedCallbackArgs callbackArgs);
    }

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    [Guid("C574DE85-7358-43F6-AAE8-8697E62D8BA7")]
    public interface IDownloadJob {}

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    [Guid("FA565B23-498C-47A0-979D-E7D5B1813360")]
    public interface IDownloadCompletedCallbackArgs {}

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("8C3F1CDD-6173-4591-AEBD-A56A53CA77C1")]
    public interface IDownloadProgressChangedCallback
    {
        void Invoke(IDownloadJob job, IDownloadProgressChangedCallbackArgs callbackArgs);
    }

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    [Guid("324FF2C6-4981-4B04-9412-57481745AB24")]
    public interface IDownloadProgressChangedCallbackArgs {}

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    [Guid("DAA4FDD0-4727-4DBE-A1E7-745DCA317144")]
    public interface IDownloadResult {}

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("45F4F6F3-D602-4F98-9A8A-3EFA152AD2D3")]
    public interface IInstallationCompletedCallback
    {
        void Invoke(IInstallationJob job, IInstallationCompletedCallbackArgs callbackArgs);
    }

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    [Guid("5C209F0B-BAD5-432A-9556-4699BED2638A")]
    public interface IInstallationJob {}

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    [Guid("250E2106-8EFB-4705-9653-EF13C581B6A1")]
    public interface IInstallationCompletedCallbackArgs {}

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("E01402D5-F8DA-43BA-A012-38894BD048F1")]
    public interface IInstallationProgressChangedCallback
    {
        void Invoke(IInstallationJob job, IInstallationProgressChangedCallbackArgs callbackArgs);
    }

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    [Guid("E4F14E1E-689D-4218-A0B9-BC189C484A01")]
    public interface IInstallationProgressChangedCallbackArgs {}

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    [Guid("A43C56D6-7451-48D4-AF96-B6CD2D0D9B7A")]
    public interface IInstallationResult {}

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    [Guid("88AEE058-D4B0-4725-A2F1-814A67AE964C")]
    public interface ISearchCompletedCallback
    {
        void Invoke(ISearchJob job, ISearchCompletedCallbackArgs callbackArgs);
    }

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    [Guid("7366EA16-7A1A-4EA2-B042-973D3E9CD99B")]
    public interface ISearchJob {}

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    [Guid("A700A634-2850-4C47-938A-9E4B6E5AF9A6")]
    public interface ISearchCompletedCallbackArgs {}

    [ComImport()]
    [InterfaceType(ComInterfaceType.InterfaceIsIDispatch)]
    [Guid("D40CFF62-E08C-4498-941A-01E25F0FD33C")]
    public interface ISearchResult {}

    public enum OperationResultCode : int
    {
        NotStarted = 0,
        InProgress = 1,
        Succeeded = 2,
        SuceededWithErrors = 3,
        Failed = 4,
        Aborted = 5,
    }

    public class API
    {
        public Dictionary<int, string> IndexMap = new Dictionary<int, string>();

        private Mutex LogMutex = new Mutex();
        private Mutex OutputMutex = new Mutex();
        private string OutputPath;
        private string LogPath;
        private bool CheckMode;
        private bool LocalDebugging;

        public API(string outputPath, string logPath, bool checkMode, bool localDebugging)
        {
            OutputPath = outputPath;
            LogPath = logPath;
            CheckMode = checkMode;
            LocalDebugging = localDebugging;
        }

        public static Task WaitHandleToTask(WaitHandle waitHandle)
        {
            TaskCompletionSource<object> tcs = new TaskCompletionSource<object>();

            ThreadPool.RegisterWaitForSingleObject(
                waitHandle,
                (o, timeout) => { tcs.SetResult(null); },
                null,
                Timeout.InfiniteTimeSpan,
                true
            );

            return tcs.Task;
        }

        public Task<IDownloadResult> DownloadAsync(object downloader, ScriptBlock progress,
            CancellationToken cancelToken)
        {
            BuildOnCompleted onCompleted = action => new DownloadCompletedCallback(action);
            return InvokeAsync<IDownloadResult>(downloader, "Download", onCompleted,
                new DownloadProgressChangedCallback(progress, this), cancelToken);
        }

        public Task<IInstallationResult> InstallAsync(object installer, ScriptBlock progress,
            CancellationToken cancelToken)
        {
            BuildOnCompleted onCompleted = action => new InstallationCompletedCallback(action);
            return InvokeAsync<IInstallationResult>(installer, "Install", onCompleted,
                new InstallationProgressChangedCallback(progress, this), cancelToken);
        }

        public Task<ISearchResult> SearchAsync(object searcher, string criteria, CancellationToken cancelToken)
        {
            BuildOnCompleted onCompleted = action => new SearchCompletedCallback(action);
            return InvokeAsync<ISearchResult>(searcher, "Search", onCompleted, criteria, cancelToken);
        }

        public void InvokePowerShell(ScriptBlock scriptblock, object job, object callbackArgs, string id)
        {
            try
            {
                using (Runspace rs = RunspaceFactory.CreateRunspace())
                using (PowerShell pipeline = PowerShell.Create())
                {
                    rs.Open();
                    pipeline.Runspace = rs;
                    pipeline.AddScript(scriptblock.ToString());
                    pipeline.AddParameter("Api", this);
                    pipeline.AddParameter("Job", job);
                    pipeline.AddParameter("CallbackArgs", callbackArgs);
                    pipeline.Invoke();
                }
            }
            catch (Exception e)
            {
                WriteLog(String.Format("{0} failed to invoke powershell script: {1}", id, e.Message));
                throw;
            }
        }

        public void WriteProgress(string task, IDictionary result)
        {
            Dictionary<string, object> progress = new Dictionary<string, object>()
            {
                { "task", task },
                { "result", result },
            };

            using (Runspace rs = RunspaceFactory.CreateRunspace())
            using (PowerShell pipeline = PowerShell.Create())
            {
                rs.Open();
                pipeline.Runspace = rs;
                pipeline.AddCommand("ConvertTo-Json");
                pipeline.AddParameter("InputObject", progress);
                pipeline.AddParameter("Compress", true);
                pipeline.AddParameter("Depth", 5);
                string msg = pipeline.Invoke<string>()[0];

                AppendFile(msg, OutputPath, OutputMutex);
            }
        }

        public void WriteLog(string msg)
        {
            string dateStr = DateTime.Now.ToString("u");
            string logMsg = String.Format("{0} {1}", dateStr, msg);

            if (!String.IsNullOrWhiteSpace(LogPath) && !CheckMode)
                AppendFile(logMsg, LogPath, LogMutex);

            if (LocalDebugging)
            {
                LogMutex.WaitOne();
                try
                {
                    Console.WriteLine(logMsg);
                }
                finally
                {
                    LogMutex.ReleaseMutex();
                }
            }
        }

        private void AppendFile(string msg, string path, Mutex mut)
        {
            mut.WaitOne();
            try
            {
                using (FileStream fs = new FileStream(path, FileMode.Append, FileAccess.Write, FileShare.Read))
                using (StreamWriter sw = new StreamWriter(fs))
                    sw.WriteLine(msg);
            }
            finally
            {
                mut.ReleaseMutex();
            }
        }

        private delegate object BuildOnCompleted(Action<object, object> action);

        private Task<T>InvokeAsync<T>(object com, string method, BuildOnCompleted buildOnCompleted, object onProgress,
            CancellationToken cancelToken)
            where T : class
        {
            TaskCompletionSource<T> task = new TaskCompletionSource<T>();
            object job = null;
            CancellationTokenRegistration? reg = null;

            object onCompleted = buildOnCompleted((_job, callbackArgs) =>
            {
                try
                {
                    T res = com.GetType().InvokeMember(
                        String.Format("End{0}", method),
                        BindingFlags.InvokeMethod,
                        null,
                        com,
                        new object[] { _job }
                    ) as T;
                    task.TrySetResult(res);
                }
                catch (TargetInvocationException e)
                {
                    Exception exp = e;
                    if (e.InnerException is COMException)
                        exp = e.InnerException;

                    task.TrySetException(exp);
                    WriteLog(String.Format("{0} on completed callback failed: {1}", method, exp.Message));
                }
                finally
                {
                    job = null;
                    if (reg != null)
                        ((CancellationTokenRegistration)reg).Dispose();
                }
            });

            job = com.GetType().InvokeMember(
                String.Format("Begin{0}", method),
                BindingFlags.InvokeMethod,
                null,
                com,
                new object[] { onProgress, onCompleted, method }
            );
            reg = cancelToken.Register(() =>
            {
                //task.TrySetCanceled(cancelToken);
                if (job != null)
                {
                    job.GetType().InvokeMember(
                        "RequestAbort",
                        BindingFlags.InvokeMethod,
                        null,
                        job,
                        new object[] {}
                    );
                }
            });

            return task.Task;
        }
    }

    public class DownloadCompletedCallback : IDownloadCompletedCallback
    {
        private Action<IDownloadJob, IDownloadCompletedCallbackArgs> Action;

        public DownloadCompletedCallback(Action<IDownloadJob, IDownloadCompletedCallbackArgs> action)
        {
            this.Action = action;
        }

        public void Invoke(IDownloadJob job, IDownloadCompletedCallbackArgs callbackArgs)
        {
            Action.Invoke(job, callbackArgs);
        }
    }

    public class DownloadProgressChangedCallback : IDownloadProgressChangedCallback
    {
        private ScriptBlock Action;
        private API Api;

        public DownloadProgressChangedCallback(ScriptBlock action, API api)
        {
            this.Action = action;
            this.Api = api;
        }

        public void Invoke(IDownloadJob job, IDownloadProgressChangedCallbackArgs callbackArgs)
        {
            Api.InvokePowerShell(Action, job, callbackArgs, "Download");
        }
    }

    public class InstallationCompletedCallback : IInstallationCompletedCallback
    {
        private Action<IInstallationJob, IInstallationCompletedCallbackArgs> Action;

        public InstallationCompletedCallback(Action<IInstallationJob, IInstallationCompletedCallbackArgs> action)
        {
            this.Action = action;
        }

        public void Invoke(IInstallationJob job, IInstallationCompletedCallbackArgs callbackArgs)
        {
            Action.Invoke(job, callbackArgs);
        }
    }

    public class InstallationProgressChangedCallback : IInstallationProgressChangedCallback
    {
        private ScriptBlock Action;
        private API Api;

        public InstallationProgressChangedCallback(ScriptBlock action, API api)
        {
            this.Action = action;
            this.Api = api;
        }

        public void Invoke(IInstallationJob job, IInstallationProgressChangedCallbackArgs callbackArgs)
        {
            Api.InvokePowerShell(Action, job, callbackArgs, "Install");
        }
    }

    public class SearchCompletedCallback : ISearchCompletedCallback
    {
        private Action<ISearchJob, ISearchCompletedCallbackArgs> Action;

        public SearchCompletedCallback(Action<ISearchJob, ISearchCompletedCallbackArgs> action)
        {
            this.Action = action;
        }

        public void Invoke(ISearchJob job, ISearchCompletedCallbackArgs callbackArgs)
        {
            Action.Invoke(job, callbackArgs);
        }
    }
}
'@

    Function Invoke-AsyncMethod {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSPossibleIncorrectUsageOfAssignmentOperator", "",
            Justification="False positive, the syntax is valid and works")]
        [CmdletBinding()]
        param (
            [Parameter(Mandatory, Position=0)]
            [String]
            $Action,

            [Parameter(Mandatory, Position=1)]
            [ScriptBlock]
            $ScriptBlock
        )

        try {
            $cancelToken = New-Object -TypeName System.Threading.CancellationTokenSource
            $task = &$ScriptBlock $cancelToken.Token

            $waitIdx = [System.Threading.Tasks.Task]::WaitAny(@(
                $cancelTask, $task
            ))
            if ($waitIdx -eq 0) {
                if (-not $task.IsCompleted) {
                    # Sends the COM RequestAbort signal to the job
                    $cancelToken.Cancel()
                }
            }

            [void]$task.Wait()
            $task.Result
        }
        catch {
            $exitResult.action = $Action

            # The COMException could be deeply nested, try and throw that if it exists
            $exp = $_.Exception
            do {
                if ($exp -is [System.Runtime.InteropServices.COMException]) {
                    throw $exp
                }
            } while ($exp = $exp.InnerException)

            throw  # Otherwise throw the original
        }
    }

    Function Receive-CallbackProgress {
        [CmdletBinding()]
        param ($Api, $Job, $CallbackArgs)

        # This runs in a brand new Runspace and doesn't have access to any of vars in our normal process.
        try {
            $taskType = $Job.AsyncState.ToLower()
            $progress = $CallbackArgs.Progress
            $updateIdx = $progress.CurrentUpdateIndex
            $updateId = $Api.IndexMap[$updateIdx]

            $progressObj = @{CurrentUpdateId = $updateId}
            foreach ($prop in $progress.PSObject.Properties) {
                $progressObj[$prop.Name] = $prop.Value
            }

            $res = $CallbackArgs.Progress.GetUpdateResult($updateIdx)
            $resObj = @{}
            foreach ($prop in $res.PSObject.Properties) {
                $resObj[$prop.Name] = $prop.Value
            }

            $finalRes = @{
                task = $taskType
                result = @{
                    progress = $progressObj
                    result = $resObj
                }
            }
            $Api.WriteLog("Received $taskType progress update:`r`n$($finalRes | ConvertTo-Json)")
            $Api.WriteProgress($taskType, $finalRes.result)
        }
        catch {
            $Api.WriteLog("Progress $taskType callback failed: $($_ | Out-String)`r`n$($_.ScriptStackTrace)")
            throw
        }
    }

    Function Test-InList {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [String[]]
            $InputObject,

            [Parameter(Mandatory)]
            [AllowEmptyCollection()]
            [String[]]
            $Match
        )

        if ($Match.Count -eq 0) {
            return $true
        }

        $isMatch = $false
        :outer foreach ($entry in $InputObject) {
            foreach ($matchEntry in $Match) {
                if ($entry -imatch $matchEntry) {
                    $isMatch = $true
                    break :outer
                }
            }

        }

        $isMatch
    }

    Function Format-UpdateInfo {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [object]
            $Update
        )

        # https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-uamg/9ed3c4f7-30fc-4b7b-97e1-308b5159822c
        $impact = switch ($Update.InstallationBehavior.Impact) {
            0 { 'Normal' }
            1 { 'Minor' }
            2 { 'RequiresExclusiveHandling' }
            default { "Unknown $($Update.InstallationBehavior.Impact)" }
        }

        # https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-uamg/eee24bbd-0be7-4a81-bed5-bff1fbb1832b
        $rebootBehavior = switch ($Update.InstallationBehavior.RebootBehavior) {
            0 { 'NeverReboots' }
            1 { 'AlwaysRequiresReboot' }
            2 { 'CanRequestReboot' }
            default { "Unknown $($Update.InstallationBehavior.RebootBehavior)" }
        }

        # https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-uamg/a4ec1231-6523-4196-8497-7b63ecc35b61
        $updateType = switch ($Update.Type) {
            1 { 'Software' }
            2 { 'Driver' }
            default { "Unknown $($Update.Type)" }
        }

        # https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-uamg/d4dc5648-a8a9-436d-9fdd-c90730bf64b0
        $deploymentAction = switch ($Update.DeploymentAction) {
            0 { 'None' }
            1 { 'Installation' }
            2 { 'Uninstallation' }
            3 { 'Detection' }
            default { "Unknown $($Update.DeploymentAction)" }
        }

        # https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-uamg/012a7226-c23d-4905-b630-9a6506032aa9
        $autoSelection = switch ($Update.AutoSelection) {
            0 { 'LetWindowsUpdateDecide' }
            1 { 'AutoSelectIfDownloaded' }
            2 { 'NeverAutoSelect' }
            3 { 'AlwaysAutoSelect' }
            default { "Unknown $($Update.AutoSelection)" }
        }

        # https://docs.microsoft.com/en-us/openspecs/windows_protocols/ms-uamg/02e59b57-4d4e-4060-ab69-8207a10271aa
        $autoDownload = switch ($Update.AutoDownload) {
            0 { 'LetWindowsUpdateDecide' }
            1 { 'NeverAutoDownload' }
            2 { 'AlwaysAutoDownload' }
            default { "Unknown $($Update.AutoDownload)" }
        }

        [Ordered]@{
            # User friendly info / Identifiers
            id = $Update.Identity.UpdateID
            title = $Update.Title
            description = $Update.Description
            kb = @($Update.KBArticleIDs | ForEach-Object { "KB$_" })

            # Search filter critera
            type = $updateType
            deployment_action = $deploymentAction
            auto_select_on_websites = $Update.AutoSelectOnWebSites
            browse_only = $Update.BrowseOnly
            revision_number = $Update.Identity.RevisionNumber
            categories = @($Update.Categories | ForEach-Object { $_.Name })
            is_installed = $Update.IsInstalled
            is_hidden = $Update.IsHidden
            is_present = $Update.IsPresent
            reboot_required = $Update.RebootRequired

            # Extra info
            impact = $impact
            reboot_behaviour = $rebootBehavior
            is_beta = $Update.IsBeta
            is_downloaded = $Update.IsDownloaded
            is_mandatory = $Update.IsMandatory
            is_uninstallable = $Update.IsUninstallable
            auto_selection = $autoSelection
            auto_download = $autoDownload
        }
    }

    # Make sure the output file exists before running
    [IO.File]::Create($OutputPath).Dispose()
    $cancelEvent = New-Object -TypeName System.Threading.EventWaitHandle -ArgumentList @(
        $false,
        [System.Threading.EventResetMode]::ManualReset,
        $CancelId
    )
    [void]$cancelEvent.Reset()
    $cancelTask = [Ansible.Windows.WinUpdates.API]::WaitHandleToTask($cancelEvent)
    $api = New-Object -TypeName Ansible.Windows.WinUpdates.API -ArgumentList $OutputPath, $LogPath, $CheckMode, $LocalDebugger

    # Make sure each exception is captured and logged to the file
    trap {
        if (-not $exitResult) {
            $exitResult = @{}
        }
        $exitResult.failed = $true
        $exitResult.exception = @{
            message = $_.ToString()
            exception = ($_ | Out-String) + "`r`n`r`n$($_.ScriptStackTrace)"
        }
        if ($exitResult.action) {
            $exitResult.exception.message = $exitResult.action + ": " + $exitResult.exception.message
            $exitResult.Remove('action')
        }

        if ($_.Exception -is [Runtime.InteropServices.COMException]) {
            # COMExceptions don't contain any info in the error message, we make sure we return the HResult for the
            # action plugin to properly decode
            $exitResult.exception.hresult = $_.Exception.HResult
        }

        if ($api) {
            $api.WriteProgress('exit', $exitResult)
            $api.WriteLog("Exception encountered:`r`n$(ConvertTo-Json $exitResult)`r`nExiting...")
        }
        else {
            # May happen if a failure occurs before $api is defined, probably due to edits during development
            $exit = @{
                task = 'exit'
                result = $exitResult
            }
            Set-Content -LiteralPath $OutputPath -Value (ConvertTo-Json $exit -Compress)
        }
    }

    $rebootRequired = (New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired
    $exitResult.reboot_required = $rebootRequired
    $api.WriteLog("Reboot requirement check: $rebootRequired")

    $api.WriteLog("Creating Windows Update session...")
    $session = New-Object -ComObject Microsoft.Update.Session

    $api.WriteLog("Create Windows Update searcher...")
    $searcher = $session.CreateUpdateSearcher()

    $api.WriteLog("Setting the Windows Update Agent source catalog...")
    $serverSelectionValue = switch ($ServerSelection) {
        "default" { 0 }
        "managed_server" { 1 }
        "windows_update" { 2 }
    }
    $searcher.ServerSelection = $serverSelectionValue
    $api.WriteLog("Search source set to '$($ServerSelection)' (ServerSelection = $($serverSelectionValue))")

    $query = 'IsInstalled = 0'
    $api.WriteLog("Searching for updates to install with query '$query'")
    $searchResult = Invoke-AsyncMethod 'Searching for updates' { $api.SearchAsync($searcher, $query, $args[0]) }
    $resCode = [Ansible.Windows.WinUpdates.OperationResultCode]$searchResult.ResultCode
    if ($resCode -ne 'Succeeded') {
        # Probably due to a cancelation request
        throw "Failed to search for updates ($resCode $([int]$resCode))"
    }
    $api.WriteLog("Found $($searchResult.Updates.Count) updates")

    $api.WriteLog("Filtering found updated based on input search criteria")
    $updateCollection = New-Object -ComObject Microsoft.Update.UpdateColl

    $allUpdates = [System.Collections.Generic.List[Hashtable]]@()
    $filteredUpdates = [System.Collections.Generic.List[Hashtable]]@()
    foreach ($update in $searchResult.Updates) {
        $updateInfo = Format-UpdateInfo -Update $update
        $api.WriteLog("Process filtering rules for`r`n$(ConvertTo-Json $updateInfo)")
        $allUpdates.Add($updateInfo)

        $categoryMatch = $Category.Length -eq 0
        foreach ($matchCat in $Category) {
            if ($matchCat -eq '*' -or $updateInfo.categories -ieq $matchCat) {
                $categoryMatch = $true
                break
            }
        }
        $matchList = ($updateInfo.title + $updateInfo.kb)

        $filteredReasons = [System.Collections.Generic.List[String]]@()
        if (-not (Test-InList -InputObject $matchList -Match $Accept)) {
            $filteredReasons.Add('accept_list')
        }
        if ($Reject.Count -gt 0 -and (Test-InList -InputObject $matchList -Match $Reject)) {
            $filteredReasons.Add('reject_list')
        }
        if ($updateInfo.is_hidden) {
            $filteredReasons.Add('hidden')
        }
        if (-not $categoryMatch) {
            $filteredReasons.Add('category_names')
        }

        if ($SkipOptional) {
            If ($updateInfo.browse_only) {
                $filteredReasons.Add('skip_optional')
            }
        }

        $updateId = "$($updateInfo.id) - $($updateInfo.title)"
        if ($filteredReasons) {
            $api.WriteLog("Skipping update $updateId due to $($filteredReasons -join ", ")")
            $filteredUpdates.Add(@{id=$updateInfo.id; reasons=$filteredReasons})
        }
        else {
            if (-not $update.EulaAccepted) {
                $api.WriteLog("Accepting EULA for $updateId")
                $update.AcceptEula()
            }

            $api.WriteLog("Adding update $updateId")
            $updateCollection.Add($update) > $null
        }
    }
    # Allows the action plugin to map update ids to human readable update info
    $api.WriteProgress('search_result', @{
        updates = $allUpdates
        filtered = $filteredUpdates
    })

    $exit = $false
    if ($CheckMode) {
        $api.WriteLog("Check mode: exiting...")
        $exit = $true
    }
    elseif ($State -eq 'searched') {
        $api.WriteLog("Search mode: exiting...")
        $exit = $true
    }
    elseif ($updateCollection.Count -eq 0) {
        $api.WriteLog("No updated pending: exiting...")
        $exit = $true
    }
    if ($exit) {
        $exitResult.changed = $updateCollection.Count -gt 0 -and $State -ne 'searched'
        $api.WriteProgress('exit', $exitResult)
        return
    }

    if ($rebootRequired) {
        throw "A reboot is required before more updates can be installed"
    }

    $downloadCollection = New-Object -ComObject Microsoft.Update.UpdateColl
    $api.IndexMap.Clear()
    foreach ($update in $updateCollection) {
        if ($update.IsDownloaded) {
            $api.WriteLog("Update $($update.Identity.UpdateId) already downloaded, skipping...")
            continue
        }

        $api.WriteLog("Update $($update.Identity.UpdateId) not downloaded")
        $api.IndexMap[$downloadCollection.Count] = $update.Identity.UpdateId
        $downloadCollection.Add($update) > $null
    }

    if ($downloadCollection.Count -gt 0) {
        $api.WriteLog("Downloading updates...")
        $dl = $session.CreateUpdateDownloader()
        $dl.Updates = $downloadCollection
        $downloadResult = Invoke-AsyncMethod 'Downloading updates' { $api.DownloadAsync($dl, ${function:Receive-CallbackProgress}, $args[0]) }
        $exitResult.changed = $true

        # FUTURE: configurable download retry
        $failed = $false
        $progressResult = [System.Collections.Generic.List[Object]]@()
        for ($i = 0; $i -lt $downloadCollection.Count; $i++) {
            $update = $downloadCollection.Item($i)
            $res = $downloadResult.GetUpdateResult($i)
            $updateId = $update.Identity.UpdateId
            $resultCode = [Ansible.Windows.WinUpdates.OperationResultCode]$res.ResultCode
            $hresult = $res.HResult

            $api.WriteLog("Download result for $updateId - ResultCode: $resultCode, HResult: $hresult")
            $progressResult.Add(@{
                id = $updateId
                result_code = [int]$resultCode
                hresult = $hresult
            })
            if ($resultCode -ne 'Succeeded') {
                $failed = $true
            }
        }
        $api.WriteProgress('download_result', @{
            info = $progressResult
        })
        if ($failed) {
            # More details are in the downloaded list
            throw "Failed to download all updates - see updates for more information"
        }
    }
    else {
        $api.WriteLog("All updates selected have been downloaded...")
    }

    if ($State -eq 'downloaded') {
        $api.WriteLog("Download mode: exiting...")
        $api.WriteProgress('exit', $exitResult)
        return
    }

    $api.WriteLog("Installing updates...")
    $installer = $session.CreateUpdateInstaller()
    $installer.AllowSourcePrompts = $false
    $installer.ClientApplicationID = "ansible.windows.win_updates"
    $installer.Updates = $updateCollection

    $api.IndexMap.Clear()
    for ($i = 0; $i -lt $installer.Updates.Count; $i++) {
        $api.IndexMap[$i] = $installer.Updates.Item($i).Identity.UpdateId
    }

    $installResult = Invoke-AsyncMethod 'Installing updates' { $api.InstallAsync($installer, ${function:Receive-CallbackProgress}, $args[0]) }
    $exitResult.changed = $true

    $failed = $false
    $progressResult = [System.Collections.Generic.List[Object]]@()
    for ($i = 0; $i -lt $updateCollection.Count; $i++) {
        $update = $updateCollection.Item($i)
        $res = $installResult.GetUpdateResult($i)
        $updateId = $update.Identity.UpdateId
        $resultCode = [Ansible.Windows.WinUpdates.OperationResultCode]$res.ResultCode
        $hresult = $res.HResult
        $rebootRequired = $res.RebootRequired

        $api.WriteLog("Install result for $updateId - ResultCode: $resultCode, HResult: $hresult, RebootRequired: $rebootRequired")
        $progressResult.Add(@{
            id = $updateId
            result_code = [int]$resultCode
            hresult = $hresult
            reboot_required = $rebootRequired
        })
        if ($resultCode -ne 'Succeeded') {
            $failed = $true
        }
        if ($rebootRequired) {
            $exitResult.reboot_required = $true
        }
    }
    $api.WriteProgress('install_result', @{
        info = $progressResult
    })

    if ($failed) {
        # More details are in the installed list
        throw "Failed to install all updates - see updates for more information"
    }

    $exitResult.reboot_required = (New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired
    $api.WriteLog("Post-install reboot requirement $($exitResult.reboot_required)")

    $api.WriteProgress('exit', $exitResult)
}

<#
Most of the Windows Update Agent API will not run under a remote token which is typically what a WinRM process is.
We can use a scheduled task to change the logon to a batch/service logon allowing us to bypass that restriction. The
other benefit of a scheduled task is that it is not tied to the lifetime of the WinRM process. This allows it to
outlive any network drops. In the case of async we need to tie the lifetime of this process to the scheduled task, in
other situations we poll the status in a separate process.
#>
$outputPathDir = $module.Params._output_path
if (-not $outputPathDir) {
    # Running async means this won't be set, just use the module tmpdir.
    $outputPathDir = $module.Tmpdir
}

# The scheduled task might need to fallback to run as SYSTEM so grant that SID rights to OutputDir
$systemSid = (New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList @(
        [Security.Principal.WellKnownSidType ]::LocalSystemSid, $null))
$outputDirAcl = Get-Acl -LiteralPath $outputPathDir
$systemAce = $outputDirAcl.AccessRuleFactory(
    $systemSid,
    [System.Security.AccessControl.FileSystemRights]'Modify,Read,ExecuteFile,Synchronize',
    $false,
    [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
    [System.Security.AccessControl.PropagationFlags]::None,
    [System.Security.AccessControl.AccessControlType]::Allow
)
$outputDirAcl.AddAccessRule($systemAce)
Set-Acl -LiteralPath $outputPathDir -AclObject $outputDirAcl

$outputPath = [IO.Path]::GetFullpath((Join-Path $outputPathDir 'output.txt'))
$cancelId = "Global\Ansible.Windows.WinUpdates-$([Guid]::NewGuid().Guid)"

$invokeSplat = @{
    Module = $module
    Commands = @{
        'Add-CSharpType' = ${function:Add-CSharpType}
    }
    ScriptBlock = ${function:Install-WindowsUpdate}
    Parameters = @{
        Category = $categoryNames
        Accept = @(if ($module.Params.accept_list) { $module.Params.accept_list })
        Reject = @(if ($module.Params.reject_list) { $module.Params.reject_list })
        ServerSelection = $module.Params.server_selection
        State = $module.Params.state
        SkipOptional = $module.Params.skip_optional
        CancelId = $cancelId
        OutputPath = $outputPath
        LogPath = $module.Params.log_path
        CheckMode = $module.CheckMode
    }
    Wait = $module.Params._wait
}

# In case of a reboot the tmpdir will be shared and we need to start from scratch again.
Remove-Item -LiteralPath $outputPath -ErrorAction SilentlyContinue -Force

$eventId = 'Ansible.Windows.WinUpdatesWatcher'
$fsWatcher = [System.IO.FileSystemWatcher]@{
    Path = Split-Path -Path $outputPath -Parent
    Filter = Split-Path -Path $outputPath -Leaf
}
try {
    Register-ObjectEvent -InputObject $fsWatcher -EventName Created -SourceIdentifier $eventId

    # If debugging locally change this to $true
    if ($false) {
        $invokeSplat.Wait = $true
        $params = $invokeSplat.Parameters
        $null = Install-WindowsUpdate @params -LocalDebugger
    }
    else {
        $taskPid = Invoke-AsBatchLogon @invokeSplat
    }

    # Make sure the output file exists before continuing (task has started)
    $null = Wait-Event -SourceIdentifier $eventId
}
finally {
    $fsWatcher.EnableRaisingEvents = $false
    $fsWatcher.Dispose()
    Remove-Event -SourceIdentifier $eventId -ErrorAction SilentlyContinue
    Unregister-Event -SourceIdentifier $eventId -ErrorAction SilentlyContinue
}

if ($invokeSplat.Wait) {
    # Format the output for legacy async behaviour
    $module.Result.reboot_required = $false
    $module.Result.changed = $false
    $module.Result.found_update_count = 0
    $module.Result.failed_update_count = 0
    $module.Result.installed_update_count = 0
    $module.Result.updates = [System.Collections.Generic.List[Hashtable]]@()
    $module.Result.filtered_updates = [System.Collections.Generic.List[Hashtable]]@()

    $updates = @{}
    Get-Content -LiteralPath $outputPath | ForEach-Object -Process {
        $progress = ConvertFrom-Json -InputObject $_
        $task = $progress.task
        $result = $progress.result

        if ($task -eq 'search_result') {
            $filterMap = @{}
            foreach ($filteredUpdate in $result.filtered) {
                $filterMap[$filteredUpdate.id] = $filteredUpdate.reasons
            }

            foreach ($updateInfo in $result.updates) {
                $resultInfo = @{
                    categories = @($updateInfo.categories)
                    id = $updateInfo.id
                    installed = $false
                    downloaded = $false
                    kb = @($updateInfo.kb | ForEach-Object {
                        if ($_.StartsWith("KB")) {
                            $_.Substring(2)
                        }
                        else {
                            $_
                        }
                    })
                    title = $updateInfo.title
                }

                if ($updateInfo.id -in $filterMap.Keys) {
                    $reasons = @($filterMap[$updateInfo.id])

                    # This value is deprecated in favour of the full list and should be removed in 2023-06-01. We also
                    # need to rename the whitelist/blacklist reasons for backwards compatibility.
                    $depReason = $reasons[0]
                    if ($depReason -eq 'accept_list') { $depReason = 'whitelist' }
                    if ($depReason -eq 'reject_list') { $depReason = 'blacklist' }

                    $resultInfo.filtered_reasons = $reasons
                    $resultInfo.filtered_reason = $depReason
                }

                $updates[$updateInfo.id] = $resultInfo
            }
        }
        elseif ($task -in @('download_result', 'install_result')) {
            foreach ($resultInfo in $result.info) {
                $updateInfo = $updates[$resultInfo.id]
                if ($resultInfo.result_code -ne 2) {
                    $updateInfo.failure_hresult_code = $resultInfo.hresult
                }
                else {
                    $taskType = if ($task -eq 'download_result') { 'downloaded' } else { 'installed' }
                    $updateInfo[$taskType] = $true
                }
            }
        }
        elseif ($task -eq 'exit') {
            $module.Result.changed = $result.changed
            $module.Result.reboot_required = $result.reboot_required
            $module.Result.failed = $result.failed

            if ($result.exception) {
                $module.Result.msg = $result.exception.message
                $module.Result.exception = $result.exception.exception
                if ($result.exception.hresult) {
                    $module.Result.hresult = $result.exception.hresult
                }
            }
        }
    }

    foreach ($updateKvp in $updates.GetEnumerator()) {
        $id = $updateKvp.Key
        $info = $updateKvp.Value

        if ($info.Contains('filtered_reasons')) {
            $module.Result.filtered_updates.Add($info)
            continue
        }

        $module.Result.found_update_count += 1
        if ($info.Contains('failure_hresult_code')) {
            $module.Result.failed_update_count += 1
        }
        elseif ($info.installed) {
            $module.Result.installed_update_count += 1
        }
        $module.Result.updates.Add($info)
    }
}
else {
    $module.Result.output_path = $outputPath
    $module.Result.task_pid = $taskPid
    $module.Result.cancel_id = $cancelId
}

$module.ExitJson()
