#!powershell

# Copyright: (c) 2015, Matt Davis <mdavis@rolpdog.com>
# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -PowerShell Ansible.ModuleUtils.AddType
#AnsibleRequires -CSharpUtil Ansible.Basic

#AnsibleRequires -PowerShell ..module_utils.Process

$spec = @{
    options = @{
        accept_list = @{ type = 'list'; elements = 'str' }
        category_names = @{
            type = 'list'
            elements = 'str'
            default = 'CriticalUpdates', 'SecurityUpdates', 'UpdateRollups'
        }
        log_path = @{ type = 'path' }
        reject_list = @{ type = 'list'; elements = 'str' }
        server_selection = @{ type = 'str'; choices = 'default', 'managed_server', 'windows_update'; default = 'default' }
        state = @{ type = 'str'; choices = 'installed', 'searched', 'downloaded'; default = 'installed' }
        skip_optional = @{ type = 'bool'; default = $false }

        # options used by the action plugin - ignored here
        reboot = @{ type = 'bool'; default = $false }
        reboot_timeout = @{ type = 'int'; default = 1200 }
        _operation = @{ type = 'str'; choices = 'start', 'cancel', 'poll'; default = 'start' }
        _operation_options = @{ type = 'dict' }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

Function Set-CancelEvent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $CancelId,

        [Parameter(Mandatory)]
        [int]
        $TaskPid
    )

    $cancelEvent = $null
    if ([Threading.EventWaitHandle]::TryOpenExisting($CancelId, [ref]$cancelEvent)) {
        [void]$cancelEvent.Set()
        $cancelEvent.Dispose()
    }

    # We don't want to wait around forever, try out best to wait until the task has ended.
    Wait-Process -Id $TaskPid -ErrorAction SilentlyContinue -Timeout 10
}

Function Receive-ProgressOutput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]
        $PipeName,

        [Parameter()]
        [switch]
        $WaitForExit
    )

    $pipe = $reader = $null
    try {
        $pipe = New-Object -TypeName System.IO.Pipes.NamedPipeClientStream -ArgumentList @(
            '.',
            $PipeName,
            [System.IO.Pipes.PipeDirection]::InOut,
            [System.IO.Pipes.PipeOptions]'Asynchronous, WriteThrough'
        )

        # The server might be under heavy load when installing the updates
        # which delays it from creating the named pipe. Set a timeout of 5
        # minutes to account for this but don't hang in case something bad
        # happened.
        # Note: I saw a 30-60 delay on some Windows Server 2016 hosts during
        # testing (2 CPU cores).
        try {
            $pipe.Connect(300000)
        }
        catch [System.TimeoutException] {
            $module.FailJson("Timed out waiting for server pipe to be available", $_)
        }

        $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList @(
            $pipe,
            (New-Object -TypeName System.Text.UTF8Encoding)
        )

        $firstResult = $true
        while ($true) {
            # Try to read as much data as possible, wait up to 1 second for
            # server to write more data before giving up this round.
            $readTask = $reader.ReadLineAsync()
            if (-not $firstResult -and -not $readTask.AsyncWaitHandle.WaitOne(1000)) {
                break
            }

            $line = $readTask.GetAwaiter().GetResult()
            $firstResult = $WaitForExit
            $parsedResult = ConvertFrom-Json -InputObject $line
            $parsedResult

            # If the task is exit do not read anymore as the server is
            # waiting to be told it is done.
            if ($parsedResult.task -eq 'exit') {
                break
            }
        }

        # First byte signals the server to prepare for disposal.
        # Second byte is a cheap way for the server to signal it is ready for disposal
        $pipe.WriteByte(1)
        $pipe.WriteByte(1)
    }
    finally {
        if ($reader) { $reader.Dispose() }
        if ($pipe) { $pipe.Dispose() }
    }
}

Function New-AnonPipe {
    <#
    .SYNOPSIS
    Creates an anonymous pipe.

    .PARAMETER Direction
    The direction of the anonymous pipe, In creates a StreamReader and out
    creates a StreamWriter.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [System.IO.Pipes.PipeDirection]
        $Direction
    )

    $server = New-Object -TypeName System.IO.Pipes.AnonymousPipeServerStream -ArgumentList @(
        $Direction,
        [System.IO.HandleInheritability]::Inheritable
    )
    $utf8 = New-Object -TypeName System.Text.UTF8Encoding -ArgumentList $false

    if ($Direction -eq 'In') {
        New-Object -TypeName System.IO.StreamReader -ArgumentList $server, $utf8
    }
    else {
        New-Object -TypeName System.IO.StreamWriter -ArgumentList $server, $utf8
    }
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

        [Parameter()]
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
            if ($task.State -eq 4) {
                # TASK_STATE_RUNNING
                $task.Stop(0)
            }
            $taskFolder.DeleteTask($Name, 0)
        }

        $taskDefinition = $scheduler.NewTask(0)

        $taskAction = $taskDefinition.Actions.Create(0)  # TASK_ACTION_EXEC
        $taskAction.Path = $Path
        if ($Arguments) {
            $taskAction.Arguments = $Arguments
        }

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
                2, # TASK_CREATE
                $null,
                $null,
                $taskDefinition.Principal.LogonType
            )
            try {
                $runningTask = $createdTask.RunEx(
                    $null,
                    2, # TASK_RUN_IGNORE_CONSTRAINTS
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
                    if ($createdTask.LastTaskResult -eq 0x00041325) {
                        # SCHED_S_TASK_QUEUED
                        Start-Sleep -Seconds 1
                        continue
                    }

                    $taskPid = $runningTask.EnginePID

                    if ($taskPid) {
                        break
                    }

                    if ($createdTask.State -ne 4) {
                        # TASK_STATE_RUNNING
                        $errEvent = Get-WinEvent -FilterXml $taskFilter -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($errEvent) {
                            $errMessage = $errEvent.Message
                        }
                        else {
                            # If event logs are disabled for tasks we can only use the last run result for information.
                            $errMessage = "Unknown failure trying to start win_updates tasks '0x{0:X8}' - enable task event logs to see more info" -f (
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

Function Invoke-InProcess {
    <#
    .SYNOPSIS
    Invoke the scriptblock as a batch logon through the task scheduler.

    .PARAMETER Path
    The directory to store the bootstrap script and any errors it encountered.

    .PARAMETER ScriptBlock
    The scriptblock to invoke.

    .PARAMETER Parameters
    The parameters to invoke on the scriptblock.
    #>
    [OutputType([int])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [Ansible.Basic.AnsibleModule]
        $Module,

        [Parameter(Mandatory)]
        [String]
        $FunctionName,

        [Parameter(Mandatory)]
        [int]
        $FunctionLine,

        [Parameter(Mandatory)]
        [String]
        $ScriptBlock,

        [Parameter(Mandatory)]
        [Hashtable]
        $Parameters,

        [Parameter(Mandatory)]
        [ScriptBlock]
        $WaitFunction,

        [Parameter()]
        [Hashtable]
        $Commands = @{},

        [Parameter()]
        [int]
        $ParentProcessId
    )

    # FUTURE: Use NamedPipeConnectionInfo once PowerShell 5.1 is the baseline
    # to avoid the stdio smuggling mess.

    $runner = {
        param ([Parameter(Mandatory)][string]$RunInfo)

        $info = [System.Management.Automation.PSSerializer]::Deserialize($RunInfo)
        $iss = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
        foreach ($funcInfo in $info.Commands.GetEnumerator()) {
            $cmd = New-Object -TypeName System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList @(
                $funcInfo.Key,
                $funcInfo.Value,
                [System.Management.Automation.ScopedItemOptions]::AllScope,
                $null
            )
            $iss.Commands.Add($cmd)
        }

        $rs = [RunspaceFactory]::CreateRunspace($iss)
        try {
            $rs.Open()

            $ps = [PowerShell]::Create()
            $ps.Runspace = $rs
            [void]$ps.AddScript(@"
$([System.Environment]::NewLine * $($info.FunctionLine - 1))$($info.ScriptBlock)
"@).AddStatement()
            [void]$ps.AddCommand($info.FunctionName).AddParameters($info.Parameters)
            $ps.Invoke()
            foreach ($err in $ps.Streams.Error) {
                throw $err
            }
        }
        finally {
            $rs.Dispose()
        }
    }

    # Using Invoke-Expression gives us a nicer error and stack trace.
    $stubRunner = @'
try {
    chcp.com 65001 > $null
    $execWrapper = $input | Out-String
    $splitParts = $execWrapper.Split(@(\"`0`0`0`0\"), 2, [StringSplitOptions]::RemoveEmptyEntries)

    Invoke-Expression ('Function Invoke-InProcessStub { ' + $splitParts[0] + '}')
    Invoke-InProcessStub $splitParts[1]
}
catch {
    $result = @{
        message = $_.ToString()
        exception = ($_ | Out-String) + \"`r`n`r`n$($_.ScriptStackTrace)\"
    }
    $msg = \"ANSIBLE_BOOTSTRAP_ERROR: $(ConvertTo-Json $result -Compress)\"
    Write-Host $msg
    exit -1
}
'@

    $pi = $stdout = $stdin = $procWaitHandle = $null
    try {
        $stdout = New-AnonPipe -Direction In
        $stderr = New-AnonPipe -Direction In
        $stdin = New-AnonPipe -Direction Out

        # The psrp connection plugin runs in wsmprovhost, change to the builtin
        # PowerShell executable for that scenario
        $pwsh = (Get-Process -Id $pid).MainModule.FileName
        if ($pwsh -eq "$env:SystemRoot\System32\wsmprovhost.exe") {
            $pwsh = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
        }

        # We need to continuously pump the pipes to ensure the process doesn't
        # block when writing to a full pipe buffer. The async WaitOne method is
        # used so the task can response to Stop requests.
        $readScript = {
            $readTask = $args[0].ReadToEndAsync()
            while (-not $readTask.AsyncWaitHandle.WaitOne(300)) {}
            $readTask.GetAwaiter().GetResult()
        }
        $stdoutPS = [PowerShell]::Create()
        $stdoutTask = $stdoutPS.AddScript($readScript).AddArgument($stdout).BeginInvoke()
        $stderrPS = [PowerShell]::Create()
        $stderrTask = $stderrPS.AddScript($readScript).AddArgument($stderr).BeginInvoke()

        $exitWithFailureInfo = {
            param ([Parameter(Mandatory)][string]$Action)

            $rc = [Ansible.Windows.Process.ProcessUtil]::GetProcessExitCode($pi.Process)
            $stdoutStr = $stdoutPS.EndInvoke($stdoutTask)[0]
            $stderrStr = $stderrPS.EndInvoke($stderrTask)[0]

            if ($rc -eq [UInt32]::MaxValue -and $stdoutStr.StartsWith('ANSIBLE_BOOTSTRAP_ERROR: ')) {
                $info = ConvertFrom-Json -InputObject $stdoutStr.Substring(25)
                $module.Result.exception = $info.exception
                $module.FailJson("Unknown failure $Action win_updates bootstrap process: $($info.message)")
            }
            else {
                $module.Result.rc = $rc
                $module.Result.stdout = $stdoutStr
                $module.Result.stderr = $stderrStr
                $module.FailJson("Unknown failure $Action win_updates bootstrap process, see rc/stdout/stderr for more info")
            }
        }

        $si = [Ansible.Windows.Process.StartupInfo]@{
            WindowStyle = 'Hidden'  # Useful when debugging locally, doesn't really matter in normal Ansible.
            ParentProcess = $ParentProcessId
            StandardInput = $stdin.BaseStream.ClientSafePipeHandle
            StandardOutput = $stdout.BaseStream.ClientSafePipeHandle
            StandardError = $stderr.BaseStream.ClientSafePipeHandle
        }
        $pi = [Ansible.Windows.Process.ProcessUtil]::NativeCreateProcess(
            $pwsh,
            "`"$pwsh`" -NoProfile -NonInteractive -Command `$input | & { $stubRunner }",
            $null,
            $null,
            $true,
            'CreateNewConsole', # Ensures we don't mess with the current console output.
            $null,
            $null,
            $si
        )
        $procWaitHandle = New-Object -TypeName System.Threading.ManualResetEvent -ArgumentList $false
        $procSafeWaitHandle = New-Object -TypeName Microsoft.Win32.SafeHandles.SafeWaitHandle -ArgumentList @(
            $pi.Process.DangerousGetHandle(),
            $false
        )
        $procWaitHandle.SafeWaitHandle = $procSafeWaitHandle

        # Once the process has started we can dispose the local client handles
        $stdin.BaseStream.DisposeLocalCopyOfClientHandle()
        $stdout.BaseStream.DisposeLocalCopyOfClientHandle()
        $stderr.BaseStream.DisposeLocalCopyOfClientHandle()

        $runPayload = [System.Management.Automation.PSSerializer]::Serialize(@{
                Id = $eventName
                Commands = $Commands
                FunctionName = $FunctionName
                FunctionLine = $FunctionLine
                ScriptBlock = $ScriptBlock
                Parameters = $Parameters
            })

        try {
            $stdin.WriteLine("$runner`0`0`0`0$runPayload")
            $stdin.Flush()
            $stdin.Dispose()
        }
        catch [System.IO.IOException] {
            # stdin pipe has been closed, the process has ended unexpected.
            & $exitWithFailureInfo 'starting'
        }
        finally {
            $stdin = $null
        }

        # Wait for the task to signal it started the code or it failed and has ended
        $waitPS = [PowerShell]::Create()
        [void]$waitPS.AddScript($WaitFunction)
        $waitTask = $waitPS.BeginInvoke()

        $waitIdx = [System.Threading.WaitHandle]::WaitAny(@(
                $procWaitHandle, $waitTask.AsyncWaitHandle
            ))

        if ($waitIdx -eq 0) {
            & $exitWithFailureInfo 'running'
        }
        else {
            try {
                $waitPS.EndInvoke($waitTask)
            }
            catch {
                Stop-Process -Id $pi.ProcessId -Force -ErrorAction SilentlyContinue
                throw
            }

            $stdoutPS.Stop()
            $stderrPS.Stop()
        }

        $pi.ProcessId
    }
    finally {
        if ($pi) { $pi.Dispose() }
        if ($stdout) { $stdout.Dispose() }
        if ($stderr) { $stderr.Dispose() }
        if ($stdin) { $stdin.Dispose() }
        if ($procWaitHandle) { $procWaitHandle.Dispose() }
    }
}

Function Invoke-WithPipeOutput {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '',
        Justification = 'The inputs are safely validated and using it gives better stacktrace frames')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]
        $FunctionName,

        [Parameter(Mandatory)]
        [String]
        $ScriptBlock,

        [Parameter(Mandatory)]
        [int]
        $FunctionLine,

        [Parameter(Mandatory)]
        [Hashtable]
        $Parameters,

        [Parameter(Mandatory)]
        [String]
        $CancelId,

        [Parameter(Mandatory)]
        [String]
        $PipeName,

        [Parameter(Mandatory)]
        [String]
        $PipeIdentity,

        [Parameter(Mandatory)]
        [String]
        $WaitId,

        [Parameter(Mandatory)]
        [String]
        $TempPath,

        [Parameter()]
        [String]
        $LogPath,

        [Switch]
        $CheckMode
    )

    Add-CSharpType -TempPath $TempPath -References @'
using System;
using System.Collections;
using System.Collections.Concurrent;
using System.IO;
using System.IO.Pipes;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Text;
using System.Threading;
using System.Threading.Tasks;

namespace Ansible.Windows.WinUpdates
{
    public class PipeServer : IDisposable
    {
        private EventWaitHandle _cancelEvent;
        private CancellationTokenSource _cancelTokenSource = new CancellationTokenSource();
        private bool _closed = false;
        private StreamWriter _logger = null;
        private SemaphoreSlim _openLock = new SemaphoreSlim(1);
        private ManualResetEvent _waitOpenEvent = new ManualResetEvent(false);
        private NamedPipeServerStream _pipe = null;
        private string _pipeName;
        private PipeSecurity _pipeSec;
        private Task _readTask;
        private UTF8Encoding _utf8 = new UTF8Encoding();
        private RegisteredWaitHandle _registeredWaitHandle;

        public CancellationToken CancelToken
        {
            get
            {
                return _cancelTokenSource.Token;
            }
        }
        public PipeServer(string name, string clientSid, string cancelId, StreamWriter logger)
        {
            SecurityIdentifier clientId = new SecurityIdentifier(clientSid);

            EventWaitHandleSecurity eventSecurity = new EventWaitHandleSecurity();
            eventSecurity.AddAccessRule(new EventWaitHandleAccessRule(
                WindowsIdentity.GetCurrent().User,
                EventWaitHandleRights.FullControl,
                AccessControlType.Allow
            ));
            eventSecurity.AddAccessRule(new EventWaitHandleAccessRule(
                clientId,
                EventWaitHandleRights.Modify | EventWaitHandleRights.Synchronize,
                AccessControlType.Allow
            ));
#if CORECLR
            _cancelEvent = EventWaitHandleAcl.Create(
                false,
                EventResetMode.ManualReset,
                cancelId,
                out bool _,
                eventSecurity
            );
#else
            bool wasCreated;
            _cancelEvent = new EventWaitHandle(
                false,
                EventResetMode.ManualReset,
                cancelId,
                out wasCreated,
                eventSecurity
            );
#endif
            _cancelEvent.Reset();
            _registeredWaitHandle = ThreadPool.RegisterWaitForSingleObject(
                _cancelEvent, WaitCallback, null, -1, true);
            _logger = logger;
            _pipeName = name;
            _pipeSec = new PipeSecurity();
            _pipeSec.AddAccessRule(new PipeAccessRule(
                WindowsIdentity.GetCurrent().User,
                PipeAccessRights.FullControl,
                AccessControlType.Allow
            ));
            _pipeSec.AddAccessRule(new PipeAccessRule(
                clientId,
                PipeAccessRights.ReadWrite | PipeAccessRights.Synchronize,
                AccessControlType.Allow
            ));
        }

        public void WaitCallback(object state, bool timedOut)
        {
            _cancelTokenSource.Cancel();
        }

        public void WaitForConnection()
        {
            WriteLog("Starting to acquire WaitForConnection lock");
            _openLock.Wait();
            WriteLog("Acquired WaitForConnection lock");
            try
            {
                if (_pipe != null)
                {
                    WriteLog("Disposing pipe server for a new connection");
                    _pipe.Dispose();
                    _pipe = null;
                }

                WriteLog(string.Format("Creating named pipe server '{0}'", _pipeName));
#if CORECLR
                _pipe = NamedPipeServerStreamAcl.Create(
                    _pipeName,
                    PipeDirection.InOut,
                    1,
                    PipeTransmissionMode.Byte,
                    PipeOptions.Asynchronous | PipeOptions.WriteThrough,
                    0,
                    0,
                    _pipeSec,
                    inheritability: HandleInheritability.None,
                    additionalAccessRights: (PipeAccessRights)0
                );
#else
                _pipe = new NamedPipeServerStream(
                    _pipeName,
                    PipeDirection.InOut,
                    1,
                    PipeTransmissionMode.Byte,
                    PipeOptions.Asynchronous | PipeOptions.WriteThrough,
                    0,
                    0,
                    _pipeSec,
                    HandleInheritability.None
                );
#endif

                WriteLog("Waiting for client to connect to pipe");
#if CORECLR
                _pipe.WaitForConnectionAsync(CancelToken).GetAwaiter().GetResult();
#else
                // Use above when dotnet 4.6 is the minimum
                IAsyncResult waitTask = _pipe.BeginWaitForConnection(null, null);
                int waitIdx = WaitHandle.WaitAny(
                    new WaitHandle[] { waitTask.AsyncWaitHandle, CancelToken.WaitHandle });

                WriteLog(string.Format("Client connect wait idx {0}", waitIdx));
                if (waitIdx == 1)
                {
                    _pipe.Dispose();
                    throw new OperationCanceledException("Pipe WaitForConnect was cancelled", CancelToken);
                }

                _pipe.EndWaitForConnection(waitTask);
#endif
                WriteLog("Client successfully connected to pipe");

                if (_readTask == null)
                {
                    _readTask = Task.Run(() => Read());
                }

                // Signals the WriteLine is ready to go.
                _waitOpenEvent.Set();
            }
            finally
            {
                WriteLog("Starting to release WaitForConnection lock");
                _openLock.Release();
                _waitOpenEvent.Set();
                WriteLog("Released WaitForConnection lock");
            }
        }

        public void WriteLine(string line)
        {
            while (!CancelToken.IsCancellationRequested)
            {
                // Wait until the Read thread has created the pipe.
                _waitOpenEvent.WaitOne();
                if (CancelToken.IsCancellationRequested)
                {
                    throw new OperationCanceledException("Pipe WriteLine was cancelled", CancelToken);
                }

                WriteLog("Starting to acquire WriteLine lock");
                _openLock.Wait();
                WriteLog("Acquired WriteLine lock");
                try
                {
                    WriteLog(string.Format("Writing to pipe server: {0}", line));
                    byte[] data = _utf8.GetBytes(line + "\r\n");

#if CORECLR
                    _pipe.WriteAsync(data, 0, data.Length, CancelToken).GetAwaiter().GetResult();
#else
                    Task task = _pipe.WriteAsync(data, 0, data.Length);
                    int waitIdx = WaitHandle.WaitAny(
                        new WaitHandle[] { ((IAsyncResult)task).AsyncWaitHandle, CancelToken.WaitHandle });
                    if (waitIdx == 1)
                    {
                        throw new OperationCanceledException("Pipe WriteLine was cancelled", CancelToken);
                    }
                    task.GetAwaiter().GetResult();
#endif
                    WriteLog("Writing task successful");
                    break;
                }
                catch (IOException e)
                {
                    WriteLog(string.Format("Pipe failed to write: {0}({1})\r\n{2}", e.GetType().Name, e.Message, e.ToString()));
                }
                finally
                {
                    WriteLog("Starting to release WriteLine lock");
                    _openLock.Release();
                    WriteLog("Released WriteLine lock");
                }
            }
        }

        public void WriteLog(string msg)
        {
            if (_logger == null)
            {
                return;
            }

            string dateStr = DateTime.Now.ToString("u");
            string logMsg = String.Format("{0} pipe_server {1}", dateStr, msg);
            _logger.WriteLine(logMsg);
        }

        private void Read()
        {
            // The pipe needs to recreate itself as soon as the client
            // disconnects. As nothing on the client end will write, the only
            // time ReadByte() finishes is when the client or server has
            // closed their end.
            try
            {
                while (true)
                {
                    WriteLog("Starting pipe read");
                    int res = _pipe.ReadByte();
                    WriteLog(string.Format("Pipe read returned: {0}", res.ToString()));

                    // If the client sends a 1 it is signalling it is going to
                    // dispose the pipe. make sure the WriteLine thread knows
                    // to wait by unsignalling the event.
                    if (res == 1)
                    {
                        _waitOpenEvent.Reset();
                        WriteLog("Waiting for client to acknowledge closing pipe");
                        _pipe.ReadByte(); // Signal for client
                    }

                    if (_closed)
                    {
                        break;
                    }
                    WaitForConnection();
                }
            }
            catch (Exception e)
            {
                WriteLog(string.Format("Pipe reader failed with {0} {1}", e.GetType().Name, e.Message));
            }
        }

        public void Dispose()
        {
            _closed = true;
            if (_pipe != null)
            {
                _pipe.Dispose();
                _pipe = null;
            }
            if (_readTask != null)
            {
                _readTask.Wait();
                _readTask.Dispose();
                _readTask = null;
            }
            _openLock.Dispose();
            _registeredWaitHandle.Unregister(_cancelEvent);
            _cancelEvent.Dispose();
            _cancelTokenSource.Dispose();
            _waitOpenEvent.Dispose();
            GC.SuppressFinalize(this);

        }
        ~PipeServer() { Dispose(); }
    }
}
'@

    $progressScript = {
        Param($Pipe, $OutputCollection, $WaitEvent)

        $ErrorActionPreference = 'Stop'

        try {
            $Pipe.WaitForConnection()
            $WaitEvent.Set()

            # Any failures from here on out need to be communicated back over the pipe
            try {
                foreach ($toWrite in $OutputCollection.GetConsumingEnumerable()) {
                    $toWriteStr = ConvertTo-Json -InputObject $toWrite -Compress -Depth 5

                    # To avoid the exit task output from being lost, it will
                    # continously be written to the pipe until the cancel
                    # signal has been received by the action plugin.
                    do {
                        $pipe.WriteLine($toWriteStr)
                    }
                    while ($toWrite.task -eq 'exit')
                }
            }
            catch [System.OperationCanceledException] {
                $Pipe.WriteLog("Cancellation requested, shutting down output consumer")
                return
            }
            catch {
                # Forces the update task to fail when it next tries to send output back
                $OutputCollection.CompleteAdding()

                $Pipe.WriteLog("Failure during pipe writeline task`n$_`n$($_.ScriptStackTrace)`n$($_.Exception | Select-Object * | Out-String)`n")

                $toWriteStr = ConvertTo-Json -Compress -InputObject @{
                    task = 'exit'
                    result = @{
                        changed = $false
                        failed = $true
                        exception = @{
                            message = "Failed during pipe writeline task: $($_.ToString())"
                            exception = ($_ | Out-String) + "`r`n`r`n$($_.ScriptStackTrace)"
                        }
                        reboot_required = $false
                    }
                }
                $Pipe.WriteLine($toWriteStr)
            }
        }
        catch {
            $Pipe.WriteLog("Failure during pipe processing task`n$_`n$($_.ScriptStackTrace)")
            throw "Failure during pipe processing task: $_"
        }
    }

    $outputCollection = $progressPS = $progressTask = $waitEvent = $logger = $null
    if ($LogPath -and -not $CheckMode) {
        $logFS = [System.IO.File]::Open($LogPath, 'Append', 'Write', 'Read')
        $logger = New-Object -TypeName System.IO.StreamWriter -ArgumentList @(
            $logFS,
            (New-Object -TypeName System.Text.UTF8Encoding)
        )
        $logger.AutoFlush = $true
    }
    $pipe = New-Object -TypeName Ansible.Windows.WinUpdates.PipeServer -ArgumentList @(
        $PipeName,
        $PipeIdentity,
        $CancelId
        $logger
    )
    try {
        $waitEvent = [System.Threading.EventWaitHandle]::OpenExisting($WaitId)
        $outputCollection = New-Object -TypeName 'System.Collections.Concurrent.BlockingCollection[System.Collections.IDictionary]'

        $progressPS = [PowerShell]::Create()
        $null = $progressPS.AddScript($progressScript)
        $null = $progressPS.AddParameters(@{
                Pipe = $pipe
                OutputCollection = $outputCollection
                WaitEvent = $waitEvent
            })
        $progressTask = $progressPS.BeginInvoke()
        while (-not $waitEvent.WaitOne(300)) {
            if ($progressTask.IsCompleted) {
                $tempTask = $progressTask
                $progressTask = $null
                $progressPS.EndInvoke($tempTask)
            }
        }

        # # Use iex to preserve the function names in the error stack trace
        Invoke-Expression @"
$([System.Environment]::NewLine * $($FunctionLine - 1))$ScriptBlock

$FunctionName @Parameters -CancelToken `$pipe.CancelToken -OutputCollection `$outputCollection -Logger `$logger
"@
    }
    catch {
        $pipe.WriteLog("Failure during Invoke-WithPipeOutput: $_`n$($_.ScriptStackTrace)")
        throw
    }
    finally {
        if ($outputCollection -and -not $outputCollection.IsAddingCompleted) {
            $outputCollection.CompleteAdding()
        }
        if ($progressPS) {
            if ($progressTask) {
                $progressPS.EndInvoke($progressTask)
            }
            $progressPS.Dispose()
        }
        if ($waitEvent) { $waitEvent.Dispose() }
        if ($outputCollection) {
            $outputCollection.Dispose()
        }
        $pipe.Dispose()
        if ($logger) { $logger.Dispose() }
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
        $TempPath,

        [Parameter(Mandatory)]
        [System.Threading.CancellationToken]
        $CancelToken,

        [Parameter(Mandatory)]
        [System.Collections.Concurrent.BlockingCollection[System.Collections.IDictionary]]
        $OutputCollection,

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
        [System.IO.StreamWriter]
        $Logger,

        [Switch]
        $CheckMode,

        [Switch]
        $LocalDebugger
    )

    Add-CSharpType -TempPath $TempPath -References @'
using System;
using System.Collections;
using System.Collections.Concurrent;
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

    public enum UpdateExceptionContext : int
    {
        General = 1,
        WindowsDriver = 2,
        WindowsInstaller = 3,
        SearchIncomplete = 4,
    }

    public class NativeMethods
    {
        [DllImport("Kernel32.dll")]
        public static extern UInt32 SetThreadExecutionState(
            UInt32 esFlags);
    }

    public class API
    {
        public Dictionary<int, string> IndexMap = new Dictionary<int, string>();

        private BlockingCollection<IDictionary> OutputCollection;
        private StreamWriter Logger = null;
        private bool LocalDebugging;

        public API(BlockingCollection<IDictionary> outputCollection, StreamWriter logger, bool localDebugging)
        {
            OutputCollection = outputCollection;
            Logger = logger;
            LocalDebugging = localDebugging;
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
            Hashtable progress = new Hashtable()
            {
                { "task", task },
                { "result", result },
            };
            OutputCollection.Add(progress);
        }

        public void WriteLog(string msg)
        {
            string dateStr = DateTime.Now.ToString("u");
            string logMsg = String.Format("{0} update_task {1}", dateStr, msg);

            if (Logger != null)
            {
                Logger.WriteLine(logMsg);
            }

            if (LocalDebugging)
            {
                Console.WriteLine(logMsg);
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
                    WriteLog(String.Format("{0} RequestAbort", method));
                    try
                    {
                        job.GetType().InvokeMember(
                            "RequestAbort",
                            BindingFlags.InvokeMethod,
                            null,
                            job,
                            new object[] {}
                        );
                    }
                    catch (TargetInvocationException e)
                    {
                        Exception exp = e;
                        if (e.InnerException is COMException)
                            exp = e.InnerException;

                        WriteLog(String.Format("{0} RequestAbort failed: {1}", method, exp.Message));
                    }
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
            Justification = "False positive, the syntax is valid and works")]
        [CmdletBinding()]
        param (
            [Parameter(Mandatory, Position = 0)]
            [String]
            $Action,

            [Parameter(Mandatory, Position = 1)]
            [System.Threading.Tasks.Task]
            $Task
        )

        try {
            # Tells the host not to go to sleep every minute, this
            # passes in the flags ES_CONTINUOUS | ES_SYSTEM_REQUIRED.
            # https://github.com/ansible-collections/ansible.windows/issues/310
            while (-not $Task.AsyncWaitHandle.WaitOne(60000)) {
                [void][Ansible.Windows.WinUpdates.NativeMethods]::SetThreadExecutionState([UInt32]"0x80000001")
            }

            $Task.GetAwaiter().GetResult()
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

            $progressObj = @{CurrentUpdateId = $updateId }
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

    # Makes sure an exception is captured and logged
    trap {
        if (-not $exitResult) {
            $exitResult = @{
                changed = $false
                reboot_required = $false
            }
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
            $api.WriteLog("Exception encountered:`r`n$($_ | Out-String)`r`nExiting...")
        }
        $OutputCollection.Add(@{
                task = 'exit'
                result = $exitResult
            })
        # We don't want to raise the error but we do want to exit the function
        return
    }

    $exitResult = @{
        changed = $false
        failed = $false
        reboot_required = $false
        action = $null  # Current action, used for exception information if set
        exception = $null  # Exception info in case of a failure @{message, exception, hresult}
    }

    $api = New-Object -TypeName Ansible.Windows.WinUpdates.API -ArgumentList @(
        $OutputCollection,
        $Logger,
        $LocalDebugger
    )
    $api.WriteProgress('started', @{})

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
    $searchResult = Invoke-AsyncMethod 'Searching for updates' $api.SearchAsync($searcher, $query, $CancelToken)
    $resCode = [Ansible.Windows.WinUpdates.OperationResultCode]$searchResult.ResultCode

    # If the search suceeded but had errors, continue on and try to log the warnings if any.
    # https://github.com/ansible-collections/ansible.windows/issues/366
    if ($resCode -eq 'SuceededWithErrors') {
        $api.WriteLog("Searcher returned success but with $($searchResult.Warnings.Count) warnings")
        for ($i = 0; $i -lt $searchResult.Warnings.Count; $i++) {
            $warning = $searchResult.Warnings.Item($i)

            $warningContext = [Ansible.Windows.WinUpdates.UpdateExceptionContext]$warning.Context
            $api.WriteLog(("Search warning {0} - Context {1} - HResult 0x{2:X8} - Message: {3}" -f
                    $i, $warningContext, $warning.HResult, $warning.Message))
        }
    }
    elseif ($resCode -ne 'Succeeded') {
        # Probably due to a cancelation request
        throw "Failed to search for updates ($resCode $([int]$resCode))"
    }
    $api.WriteLog("Found $($searchResult.Updates.Count) updates")

    $api.WriteLog("Filtering found updates based on input search criteria")
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
            $filteredUpdates.Add(@{id = $updateInfo.id; reasons = $filteredReasons })
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
        $api.WriteLog("No updates pending: exiting...")
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
        $downloadResult = Invoke-AsyncMethod 'Downloading updates' $api.DownloadAsync($dl, ${function:Receive-CallbackProgress}, $CancelToken)
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

    $installResult = Invoke-AsyncMethod 'Installing updates' $api.InstallAsync($installer, ${function:Receive-CallbackProgress}, $CancelToken)
    $exitResult.changed = $true

    # https://www.microsoft.com/en-us/wdsi/defenderupdates
    $defenderExe = [System.IO.Path]::Combine($env:ProgramFiles, 'Windows Defender', 'MpCmdRun.exe')
    $runDefenderCommand = {
        $defenderArgs = $args
        $api.WriteLog("Running defender command $defenderExe $($defenderArgs -join " ")")
        $stdoutLines = $null
        $stderrLines = . { &$defenderExe @defenderArgs | Set-Variable stdoutLines } 2>&1 | ForEach-Object ToString

        $stdout = @($stdoutLines) -join "`n"
        $stderr = @($stderrLines) -join "`n"
        $api.WriteLog("Defender command result - RC: $LASTEXITCODE`nSTDOUT:`n$stdout`nSTDERR:`n$stderr")

        $LASTEXITCODE
    }

    $failed = $false
    $progressResult = [System.Collections.Generic.List[Object]]@()
    for ($i = 0; $i -lt $updateCollection.Count; $i++) {
        $update = $updateCollection.Item($i)
        $res = $installResult.GetUpdateResult($i)
        $updateId = $update.Identity.UpdateId
        $updateKBs = @($Update.KBArticleIDs | ForEach-Object { "$_" })
        $resultCode = [Ansible.Windows.WinUpdates.OperationResultCode]$res.ResultCode
        $hresult = $res.HResult
        $rebootRequired = $res.RebootRequired

        $api.WriteLog("Install result for $updateId - ResultCode: $resultCode, HResult: $hresult, RebootRequired: $rebootRequired")

        # KB2267602 is a massive pain. Sometimes it may not install properly
        # until a new definition has been released by Microsoft. Unfortunately
        # after the first attempt which fails subsequent attempts will look
        # like they've suceeded but have not in reality. This attempts to
        # recover from that bad state to ensure it stays failed rather than the
        # false positive causing an infinite loop. The MpCmdRun command can be
        # used to install the update outside of WUA which seems to work when
        # WUA does not.
        if (
            $resultCode -ne 'Succeeded' -and
            '2267602' -in $updateKBs -and
            (Test-Path -LiteralPath $defenderExe)
        ) {
            $null = & $runDefenderCommand '-RemoveDefinitions' '-DynamicSignatures'
            $rc = & $runDefenderCommand '-SignatureUpdate'

            if ($rc -eq 0) {
                # If it was successful, override the WUA result.
                $resultCode = [Ansible.Windows.WinUpdates.OperationResultCode]::Succeeded
                $hresult = 0
            }
        }

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

if ($module.Params._operation -eq 'cancel') {
    # Cancels the background update process
    $options = $module.Params._operation_options
    Set-CancelEvent -CancelId $options.cancel_id -TaskPid $options.task_pid

    $module.ExitJson()
}
elseif ($module.Params._operation -eq 'poll') {
    $module.Result.output = @(Receive-ProgressOutput -PipeName $module.Params._operation_options.pipe_name)
    $module.ExitJson()
}

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

<#
Most of the Windows Update Agent API will not run under a remote token which is typically what a WinRM process is.
We can use a scheduled task to change the logon to a batch/service logon allowing us to bypass that restriction if
it is needed (not running under become). The other benefit of a scheduled task is that it is not tied to the lifetime
of the WinRM process. This allows it to outlive any network drops. In the case of async we need to tie the lifetime of
this process to the scheduled task, in other situations we poll the status in a separate process.
#>
try {
    $null = (New-Object -ComObject Microsoft.Update.SystemInfo).RebootRequired
    # If we get here WUA will work with the current rights and we don't need
    # to spawn as a scheduled task.
    $spawnWithScheduledTask = $false
}
catch {
    $spawnWithScheduledTask = $true
}

$taskId = [Guid]::NewGuid().Guid
$pipeName = "Ansible.Windows.WinUpdates-$taskId"
$cancelId = "Global\Ansible.Windows.WinUpdates-$taskId"
$waitId = "Global\Ansible.Windows.WinUpdates-$taskId-Started"

$startupWait = {
    $ErrorActionPreference = 'Stop'

    $pipe = $reader = $waitEvent = $null
    try {
        $pipe = New-Object -TypeName System.IO.Pipes.NamedPipeClientStream -ArgumentList @(
            '.',
            'PIPE_NAME',
            [System.IO.Pipes.PipeDirection]::In,
            [System.IO.Pipes.PipeOptions]::Asynchronous
        )

        # Use ConnectAsync once .NET 4.6 is the minimum to simplify code
        # We need to use short timeouts so this can response to stop requests
        while ($true) {
            try {
                $pipe.Connect(1000)
            }
            catch [System.TimeoutException] {
                continue
            }
            break
        }

        # Wait until this event is set, used to ensure the named pipe server is
        # actually ready to start sending the data
        $waitEvent = [System.Threading.EventWaitHandle]::OpenExisting('WAIT_ID')
        while (-not $waitEvent.WaitOne(300)) {}

        # Now wait until the first line was added, this signals the win_updates
        # task is ready to run and report on its progress
        $reader = New-Object -TypeName System.IO.StreamReader -ArgumentList @(
            $pipe,
            (New-Object -TypeName System.Text.UTF8Encoding)
        )

        $readTask = $reader.ReadLineAsync()
        while (-not $readTask.AsyncWaitHandle.WaitOne(300)) {}
        $rawResult = $readTask.GetAwaiter().GetResult()

        $result = $null
        if ($rawResult) {
            $result = ConvertFrom-Json -InputObject $rawResult
        }
        if ($result.task -ne 'started') {
            throw "Expecting task started from remote pipe but got '$rawResult'"
        }
    }
    finally {
        if ($waitEvent) { $waitEvent.Dispose() }
        if ($reader) { $reader.Dispose() }
        if ($pipe) { $pipe.Dispose() }
    }
} -replace 'PIPE_NAME', $pipeName -replace 'WAIT_ID', $waitId

# The scheduled task might need to fallback to run as SYSTEM so grant that SID rights to tmpdir
$systemSid = (New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList @(
        [Security.Principal.WellKnownSidType ]::LocalSystemSid, $null))
$outputDirAcl = Get-Acl -LiteralPath $module.Tmpdir
$systemAce = $outputDirAcl.AccessRuleFactory(
    $systemSid,
    [System.Security.AccessControl.FileSystemRights]'Modify,Read,ExecuteFile,Synchronize',
    $false,
    [System.Security.AccessControl.InheritanceFlags]'ContainerInherit, ObjectInherit',
    [System.Security.AccessControl.PropagationFlags]::None,
    [System.Security.AccessControl.AccessControlType]::Allow
)
$outputDirAcl.AddAccessRule($systemAce)
Set-Acl -LiteralPath $module.Tmpdir -AclObject $outputDirAcl

$updateParameters = @{
    Category = $categoryNames
    Accept = @(if ($module.Params.accept_list) { $module.Params.accept_list })
    Reject = @(if ($module.Params.reject_list) { $module.Params.reject_list })
    ServerSelection = $module.Params.server_selection
    State = $module.Params.state
    SkipOptional = $module.Params.skip_optional
    TempPath = $module.Tmpdir
    CheckMode = $module.CheckMode
}
$wait = [bool]$module.Params._operation_options.wait

$invokeSplat = @{
    Module = $module
    Commands = @{
        'Add-CSharpType' = ${function:Add-CSharpType}
    }
    FunctionName = 'Invoke-WithPipeOutput'
    ScriptBlock = ${function:Invoke-WithPipeOutput}.StartPosition.Content
    FunctionLine = ${function:Invoke-WithPipeOutput}.StartPosition.StartLine
    Parameters = @{
        FunctionName = 'Install-WindowsUpdate'
        ScriptBlock = ${function:Install-WindowsUpdate}.StartPosition.Content
        FunctionLine = ${function:Install-WindowsUpdate}.StartPosition.StartLine
        Parameters = $updateParameters
        PipeName = $pipeName
        PipeIdentity = ([System.Security.Principal.WindowsIdentity]::GetCurrent().User.Value)
        CancelId = $cancelId
        TempPath = $module.Tmpdir
        LogPath = $module.Params.log_path
        WaitId = $waitId
        CheckMode = $module.CheckMode
    }
    WaitFunction = [ScriptBlock]::Create($startupWait)
}

# We use an event to be notified when the pipe is up and running. This is
# needed so our $startupWait task can only try and connect to the pipe when it
# is ready. Failure to do so might have it connect but then fail before the
# task is ready to actually receive the started result.
$waitEvent = New-Object -TypeName System.Threading.EventWaitHandle -ArgumentList @(
    $false,
    [System.Threading.EventResetMode]::ManualReset,
    $waitId
)
try {
    # If debugging locally change this to $true
    if ($false) {
        $wait = $true
        $updateParameters.LocalDebugger = $true

        $params = $invokeSplat.Parameters
        $null = &$invokeSplat.ScriptBlock @params
    }
    else {
        # The parent pid can be anything, use cmd as it's quicker to start over
        # PowerShell.
        $cmdPath = "$env:SystemRoot\System32\cmd.exe"

        $parentPid = $null
        try {
            if ($spawnWithScheduledTask) {
                $parentPid = Start-EphemeralTask -Name "ansible-$($Module.ModuleName)" -Path $cmdPath
            }
            else {
                # The WMI Win32_Process.Create method will spawn a process that
                # lives outside of any job and thus will outlive this process.
                $wmiRes = Invoke-CimMethod -ClassName Win32_Process -Name Create -Arguments @{ CommandLine = $cmdPath }
                if ($wmiRes.ReturnValue -ne 0) {
                    $msg = ([System.ComponentModel.Win32Exception][int]$wmiRes.ReturnValue).Message
                    throw "WMI Win32_Process.Create failed: {0} (0x{1:X8})" -f ($msg, $wmiRes.ReturnValue)
                }
                $parentPid = $wmiRes.ProcessId
            }

            $taskPid = Invoke-InProcess @invokeSplat -ParentProcessId $parentPid
        }
        catch {
            $bootstrapMethod = if ($spawnWithScheduledTask) {
                'Task Scheduler'
            }
            else {
                'Ansible Become'
            }
            $Module.FailJson("Failed to start new win_updates task with $($bootstrapMethod): $($_.Exception.Message)", $_)
        }
        finally {
            if ($parentPid) {
                Stop-Process -Id $parentPid -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
finally {
    $waitEvent.Dispose()
}

if ($wait) {
    # Format the output for legacy async behaviour
    $module.Result.reboot_required = $false
    $module.Result.rebooted = $false
    $module.Result.changed = $false
    $module.Result.found_update_count = 0
    $module.Result.failed_update_count = 0
    $module.Result.installed_update_count = 0
    $module.Result.updates = @{}
    $module.Result.filtered_updates = @{}

    $updates = @{}

    try {
        Receive-ProgressOutput -PipeName $pipeName -WaitForExit | ForEach-Object {
            $task = $_.task
            $result = $_.result

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
    }
    finally {
        Set-CancelEvent -CancelId $cancelId -TaskPid $taskPid
    }

    foreach ($updateKvp in $updates.GetEnumerator()) {
        $info = $updateKvp.Value

        if ($info.Contains('filtered_reasons')) {
            $module.Result.filtered_updates[$info.id] = $info
            continue
        }

        $module.Result.found_update_count += 1
        if ($info.Contains('failure_hresult_code')) {
            $module.Result.failed_update_count += 1
        }
        elseif ($info.installed) {
            $module.Result.installed_update_count += 1
        }
        $module.Result.updates[$info.id] = $info
    }
}
else {
    $module.Result.cancel_options = @{
        cancel_id = $cancelId
        task_pid = $taskPid
    }
    $module.Result.poll_options = @{
        pipe_name = $pipeName
    }
}

$module.ExitJson()
