#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

function Get-LastBootTime {
    param([Ansible.Basic.AnsibleModule]$Module)

    try {
        $epochStart = New-Object -TypeName DateTime -ArgumentList @(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
        $lastBoot = (Get-CimInstance -ClassName Win32_OperatingSystem -Property LastBootUpTime).LastBootUpTime
        $utcBoot = $lastBoot.ToUniversalTime()

        return @{
            last_boot_time = $utcBoot.ToString("yyyy-MM-ddTHH:mm:ssZ")
            last_boot_time_epoch = (New-TimeSpan -Start $epochStart -End $utcBoot).TotalSeconds
            utc_datetime = $utcBoot
        }
    }
    catch {
        $Module.FailJson("Failed to get last boot time from CIM: $_", $_)
    }
}

function Format-ReasonCode {
    param($Value)

    # The reason code from event 1074 is returned as a string. Parse it as an integer since
    # that's what it actually represents, using Int64 rather than Int32 since the signed bit
    # (the "planned" flag, e.g. 0x80040002) makes the value negative whereas YAML
    # parses hex values as unsigned. This allows users to more easily compare the returned
    # value with a hex literal '- res.reason_code == 0x80000000'. Fall back to returning the
    # raw value unchanged if it can't be parsed so a malformed field doesn't drop the rest of
    # the reboot details.
    $reasonCode = $null
    if ([System.Management.Automation.LanguagePrimitives]::TryConvertTo($Value, [long], [ref]$reasonCode)) {
        return $reasonCode
    }
    return $Value
}

function Get-LastRebootEvent {
    param(
        [Ansible.Basic.AnsibleModule]$Module,
        [DateTime]$BootTime
    )

    try {
        $rebootEvent = Get-WinEvent -FilterHashtable @{
            LogName = 'System'
            Id = 1074
        } -MaxEvents 1 -ErrorAction SilentlyContinue

        if ($rebootEvent) {
            $eventTime = $rebootEvent.TimeCreated.ToUniversalTime()
            if ($eventTime -lt $BootTime.AddMinutes(-5)) {
                return
            }

            return @{
                process = $rebootEvent.Properties[0].Value
                reason = $rebootEvent.Properties[2].Value
                reason_code = Format-ReasonCode -Value $rebootEvent.Properties[3].Value
                type = $rebootEvent.Properties[4].Value
                comment = $rebootEvent.Properties[5].Value
                initiated_by = $rebootEvent.Properties[6].Value
                event_time = $eventTime.ToString("yyyy-MM-ddTHH:mm:ssZ")
            }
        }
    }
    catch {
        $Module.Warn("Failed to query the System event log for reboot events: $_", $_)
    }
}

function Test-ComponentBasedServicing {
    $cbsPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
    if (Test-Path -LiteralPath $cbsPath) {
        return @{
            source = 'component_based_servicing'
            description = 'Component Based Servicing has a pending reboot.'
        }
    }
}

function Test-WindowsUpdate {
    $wuPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    if (Test-Path -LiteralPath $wuPath) {
        return @{
            source = 'windows_update'
            description = 'Windows Update has installed updates that require a reboot.'
        }
    }
}

function Test-PendingFileRename {
    $params = @{
        LiteralPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
        Name = 'PendingFileRenameOperations'
        ErrorAction = 'SilentlyContinue'
    }
    $pendingRenames = (Get-ItemProperty @params)."$($params.Name)"
    if ($pendingRenames) {
        return @{
            source = 'pending_file_rename'
            description = 'There are pending file rename operations that require a reboot.'
        }
    }
}

function Test-PendingComputerRename {
    $pendingParams = @{
        LiteralPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName'
        Name = 'ComputerName'
        ErrorAction = 'SilentlyContinue'
    }
    $activeParams = @{
        LiteralPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName'
        Name = 'ComputerName'
        ErrorAction = 'SilentlyContinue'
    }
    $pendingName = (Get-ItemProperty @pendingParams)."$($pendingParams.Name)"
    $activeName = (Get-ItemProperty @activeParams)."$($activeParams.Name)"
    if ($pendingName -and $activeName -and $pendingName -ne $activeName) {
        return @{
            source = 'pending_computer_rename'
            description = "Computer name change pending from '$activeName' to '$pendingName'."
        }
    }
}

function Test-DomainJoin {
    $params = @{
        LiteralPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Netlogon'
        ErrorAction = 'SilentlyContinue'
    }
    $props = Get-ItemProperty @params
    if ($props -and ($props.PSObject.Properties.Name -contains 'JoinDomain' -or $props.PSObject.Properties.Name -contains 'AvoidSpnSet')) {
        return @{
            source = 'domain_join'
            description = 'A domain join operation is pending and requires a reboot.'
        }
    }
}

function Test-ServerManager {
    $params = @{
        LiteralPath = 'HKLM:\SOFTWARE\Microsoft\ServerManager\ServicingStorage\ServerComponentCache'
        Name = 'RestartRequired'
        ErrorAction = 'SilentlyContinue'
    }
    $restart = (Get-ItemProperty @params)."$($params.Name)"
    if ($restart) {
        return @{
            source = 'server_manager'
            description = 'Server Manager indicates a component change requires a reboot.'
        }
    }
}


$spec = @{
    options = @{}
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$bootTime = Get-LastBootTime -Module $module
$module.Result.last_reboot = @{
    time = $bootTime.last_boot_time
    time_epoch = $bootTime.last_boot_time_epoch
    details = Get-LastRebootEvent -Module $module -BootTime $bootTime.utc_datetime
}

$reasons = @(
    Test-ComponentBasedServicing
    Test-WindowsUpdate
    Test-PendingFileRename
    Test-PendingComputerRename
    Test-DomainJoin
    Test-ServerManager
)
$module.Result.reboot_required = $reasons.Count -gt 0
$module.Result.reboot_required_reasons = $reasons

$module.ExitJson()
