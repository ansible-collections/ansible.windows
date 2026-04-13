# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# This module_util is for internal use only. It is not intended to be used by
# collections outside of ansible.windows.

using namespace System.Management.Automation
using namespace System.Management.Automation.Runspaces
using namespace System.Security.Principal

Function New-ScheduledTaskSession {
    <#
    .SYNOPSIS
    Creates a PSSession for a process running as a scheduled task.

    .DESCRIPTION
    Creates a PSSession that can be used to run code inside a scheduled task
    context. This context can be used to bypass issues like a network logon
    not being able to access the Windows Update API. The session will run under
    the same user with the BATCH logon type.

    The session can be used alongside the builtin cmdlets like Invoke-Command
    to run a command non-interactively. Once the session is no longer needed it
    should be cleaned up with Remove-PSSession.

    .PARAMETER PowerShellPath
    Override the PowerShell executable used, by default will use the current
    PowerShell executable.

    .PARAMETER UserName
    Runs the scheduled task as the user specified. This can be set to well
    known service accounts like 'SYSTEM', 'LocalService', or 'NetworkService'
    to run as those service accounts. It can also be set to a gMSA that ends
    with '$' in the name to run as that gMSA account. Otherwise this will
    attempt to run using S4U which only works for the current user.

    If using a gMSA, the gMSA must be configured to allow the current computer
    account the ability to retrieve its password.

    .PARAMETER Credential
    Runs the scheduled task as the user specified by the credentials. The
    process will be able to access network resources or do other tasks that
    require credentials like access DPAPI secrets. The user specified must have
    batch logon rights.

    .PARAMETER OpenTimeout
    The timeout, in seconds, to wait for the PowerShell process to be created
    by the task scheduler and also to connect to the named pipe it creates. As
    each operation are separate the total timeout could potentially be double
    the value specified here.

    .EXAMPLE
        $s = New-ScheduledTaskSession
        Invoke-Command $s { whoami /all }
        $s | Remove-PSSession

    Runs task as current user and closes the session once done.

    .EXAMPLE
        $s = New-ScheduledTaskSession -UserName SYSTEM
        Invoke-Command $s { whoami }
        $s | Remove-PSSession

    Runs task as SYSTEM.

    .NOTES
    This cmdlet requires admin permissions to create the scheduled task.
    #>
    [OutputType([System.Management.Automation.Runspaces.PSSession])]
    [CmdletBinding(DefaultParameterSetName = "UserName")]
    param (
        [Parameter()]
        [string]
        $PowerShellPath,

        [Parameter(ParameterSetName = "UserName")]
        [string]
        $UserName,

        [Parameter(ParameterSetName = "Credential")]
        [PSCredential]
        $Credential,

        [Parameter()]
        [int]
        $OpenTimeout = 30
    )

    $ErrorActionPreference = 'Stop'

    # Use a unique GUID to identify the process uniquely after we start the task.
    $powershellId = [Guid]::NewGuid().ToString()
    $taskName = "Ansible.Windows._TaskSchedulerRunner-$powershellId"

    # PowerShell 7.3 created a public way to build a PSSession but WinPS needs
    # to use reflection to build the PSSession from the Runspace object.
    $createPSSession = if ([PSSession]::Create) {
        {
            [PSSession]::Create($args[0], $taskName, $null)
        }
    }
    else {
        $remoteRunspaceType = [PSObject].Assembly.GetType('System.Management.Automation.RemoteRunspace')
        $pssessionCstr = [PSSession].GetConstructor(
            'NonPublic, Instance',
            $null,
            [type[]]@($remoteRunspaceType),
            $null)

        { $pssessionCstr.Invoke(@($args[0])) }
    }

    if (-not $PowerShellPath) {
        $executable = if ($IsCoreCLR) {
            'pwsh.exe'
        }
        else {
            'powershell.exe'
        }

        $PowerShellPath = Join-Path $PSHome $executable
    }
    # Resolve the absolute path for PowerShell for the CIM filter to work.
    if (Test-Path -LiteralPath $PowerShellPath) {
        $PowerShellPath = (Get-Item -LiteralPath $PowerShellPath).FullName
    }
    elseif ($powershellCommand = Get-Command -Name $PowerShellPath -CommandType Application -ErrorAction SilentlyContinue) {
        $PowerShellPath = $powershellCommand.Path
    }
    else {
        $exc = [ArgumentException]::new("Failed to find PowerShellPath '$PowerShellPath'")
        $err = [ErrorRecord]::new(
            $exc,
            'FailedToFindPowerShell',
            'InvalidArgument',
            $PowerShellPath)
        $PSCmdlet.ThrowTerminatingError($err)
        return
    }
    $powershellArg = "-WindowStyle Hidden -NoExit -Command '$powershellId'"

    $taskParams = @{
        Action = New-ScheduledTaskAction -Execute $PowerShellPath -Argument $powershellArg
        Force = $true
        Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
        TaskName = $taskName
        ErrorAction = 'Stop'
    }

    if ($Credential) {
        $taskParams.User = $Credential.UserName
        $taskParams.Password = $Credential.GetNetworkCredential().Password
    }
    else {
        if ($UserName) {
            $sid = ([NTAccount]$UserName).Translate([SecurityIdentifier])
        }
        else {
            $sid = [WindowsIdentity]::GetCurrent().User
        }

        # Normalise the username from the SID.
        $UserName = $sid.Translate([NTAccount]).Value
        $logonType = 'S4U'
        if ($sid.Value -in @('S-1-5-18', 'S-1-5-19', 'S-1-5-20')) {
            # SYSTEM, LocalService, NetworkService
            $logonType = 'ServiceAccount'
        }
        elseif ($UserName.EndsWith('$')) {
            # gMSA
            $logonType = 'Password'
        }

        $principal = New-ScheduledTaskPrincipal -UserId $UserName -LogonType $logonType
        $taskParams.Principal = $principal
    }

    $task = Register-ScheduledTask @taskParams
    try {
        $stopProc = $true
        $procId = 0
        $runspace = $null

        $task | Start-ScheduledTask

        # There's no API to get the running PID of a task so we use CIM to
        # enumerate the processes and find the one that matches our unique
        # command identifier.
        $wqlFilter = "ExecutablePath = '$($PowerShellPath -replace '\\', '\\')' AND CommandLine LIKE '% -WindowStyle Hidden -NoExit -Command \'$powershellId\''"
        $cimParams = @{
            ClassName = 'Win32_Process'
            Filter = $wqlFilter
            Property = 'ProcessId'
        }
        $start = Get-Date
        while (-not ($proc = Get-CimInstance @cimParams)) {
            if (((Get-Date) - $start).TotalSeconds -gt $OpenTimeout) {
                throw "Timeout waiting for PowerShell process to start"
            }
            Start-Sleep -Seconds 1
        }
        $procId = [int]$proc.ProcessId

        $typeTable = [TypeTable]::LoadDefaultTypeFiles()
        $connInfo = [NamedPipeConnectionInfo]::new($procId)
        $connInfo.OpenTimeout = $OpenTimeout * 1000
        $runspace = [RunspaceFactory]::CreateRunspace($connInfo, $host, $typeTable)
        $runspace.Open()

        $null = Register-ObjectEvent -InputObject $runspace -EventName StateChanged -MessageData $procId -Action {
            if ($EventArgs.RunspaceStateInfo.State -in @('Broken', 'Closed')) {
                Unregister-Event -SourceIdentifier $EventSubscriber.SourceIdentifier
                Stop-Process -Id $Event.MessageData -Force
            }
        }
        $stopProc = $false

        & $createPSSession $runspace
    }
    catch {
        if ($stopProc -and $procId) {
            Stop-Process -Id $procId -Force
        }
        if ($runspace) {
            $runspace.Dispose()
        }

        $err = [ErrorRecord]::new(
            $_.Exception,
            'FailedToOpenSession',
            'NotSpecified',
            $null)
        $PSCmdlet.WriteError($err)
    }
    finally {
        $task | Unregister-ScheduledTask -Confirm:$false
    }
}

Export-ModuleMember -Function New-ScheduledTaskSession
