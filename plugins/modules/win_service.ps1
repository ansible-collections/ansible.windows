#!powershell

# Copyright: (c) 2014, Chris Hoffman <choffman@chathamfinancial.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -CSharpUtil ansible_collections.ansible.windows.plugins.module_utils.SCManager

# Need to be able to specify values larger than [Int32]::MaxValue for certain time based options.
$uint32Type = [Func[[Object], [UInt32]]]{ [UInt32]$args[0] }
$spec = @{
    options = @{
        dependencies = @{ type = 'list'; elements = 'str' }
        dependency_action = @{ type = 'str'; default = 'set'; choices = 'add', 'remove', 'set' }
        description = @{ type = 'str' }
        desktop_interact = @{ type = 'bool'; default = $false }
        display_name = @{ type = 'str' }
        error_control = @{ type = 'str'; choices = 'critical', 'ignore', 'normal', 'severe'}
        failure_actions = @{
            type = 'list'
            elements = 'dict'
            options = @{
                delay_ms = @{ aliases = ,'delay'; type = $uint32Type; default = 0 }
                type = @{ type = 'str'; choices = 'none', 'reboot', 'restart', 'run_command'; required = $true }
            }
        }
        failure_actions_on_non_crash_failure = @{ type = 'bool' }
        failure_command = @{ type = 'str' }
        failure_reboot_msg = @{ type = 'str' }
        failure_reset_period_sec = @{ aliases = ,'failure_reset_period'; type = $uint32Type }
        force_dependent_services = @{ type = 'bool'; default = $false }
        load_order_group = @{ type = 'str' }
        name = @{ type = 'str'; required = $true }
        password = @{ type = 'str'; no_log = $true }
        path = @{ type = 'str'; }
        pre_shutdown_timeout_ms = @{ aliases = ,'pre_shutdown_timeout'; type = $uint32Type }
        required_privileges = @{ type = 'list'; elements = 'str' }
        service_type = @{
            type = 'str'
            choices = 'win32_own_process', 'win32_share_process', 'user_own_process', 'user_share_process'
        }
        sid_info = @{ type = 'str'; choices = 'none', 'restricted', 'unrestricted' }
        start_mode = @{ type = 'str'; choices = 'auto', 'manual', 'disabled', 'delayed' }
        state = @{ type = 'str'; choices = 'started', 'stopped', 'restarted', 'absent', 'paused' }
        update_password = @{ type = 'str'; choices = 'always', 'on_create' }
        username = @{ type = 'str' }
    }
    required_by = @{
        password = @('username')
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$dependencies = $module.Params.dependencies
$dependencyAction = $module.Params.dependency_action
$description = $module.Params.description
$desktopInteract = $module.Params.desktop_interact
$displayName = $module.Params.display_name
$errorControl = $module.Params.error_control
$failureActions = $module.Params.failure_actions
$failureActionsOnNonCrashFailure = $module.Params.failure_actions_on_non_crash_failure
$failureCommand = $module.Params.failure_command
$failureRebootMsg = $module.Params.failure_reboot_msg
$failureResetPeriodSec = $module.Params.failure_reset_period_sec
$forceDependentServices = $module.Params.force_dependent_services
$loadOrderGroup = $module.Params.load_order_group
$name = $module.Params.name
$password = $module.Params.password
$path = $module.Params.path
$preShutdownTimeoutMs = $module.Params.pre_shutdown_timeout_ms
$requiredPrivileges = $module.Params.required_privileges
$serviceType = $module.Params.service_type
$sidInfo = $module.Params.sid_info
$startMode = $module.Params.start_mode
$state = $module.Params.state
$updatePassword = $module.Params.update_password
$username = $module.Params.username

$module.Result.exists = $false

if ($null -ne $path) {
    $path = [System.Environment]::ExpandEnvironmentVariables($path)
}

Function ConvertTo-SecurityIdentifier {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '',
        Justification='Ignore a SID conversion eror and try alternative, we do not care about the error')]
    param (
        [Parameter(Mandatory=$true)]
        [String]$Name
    )

    # First check if the account is already a SID
    try {
        New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $Name
        return
    } catch [ArgumentException] {}

    # win_service allows LocalSystem as a way of specifying SYSTEM as that is what the GUI shows. This name cannot be
    # translated so we have a manual check for it.
    if ($Name -eq 'LocalSystem') {
        [System.Security.Principal.SecurityIdentifier]'S-1-5-18'
        return
    }

    # Handle cases when referencing a local user like .\account.
    if ($Name.Contains('\')) {
        $nameSplit = $Name.Split('\', 2)
        if ($nameSplit[0] -eq '.') {
            $domain = $env:COMPUTERNAME
        } else {
            $domain = $nameSplit[0]
        }
        $username = $nameSplit[1]

        $ntAccount = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $domain, $username
    } else {
        $ntAccount = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $Name
    }

    $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
}

Function ConvertTo-ServiceFailureActionsDiff {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [Object[]]
        $FailureActions
    )

    foreach ($action in $FailureActions) {
        [Ordered]@{
            type = switch ($action.Type) {
                None { 'none' }
                Reboot { 'reboot' }
                Restart { 'restart' }
                RunCommand { 'run_command' }
            }
            delay_ms = $action.Delay
        }
    }
}

Function ConvertTo-ServiceStartModeDiff {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [Ansible.Windows.SCManager.ServiceStartType]
        $StartMode
    )

    # Convert the enum ServiceStartType to the value for a diff.
    switch ($StartMode) {
        BootStart { 'boot' }
        SystemStart { 'system' }
        AutoStart { 'auto' }
        DemandStart { 'manual' }
        Disabled { 'disabled' }
        AutoStartDelayed { 'delayed' }
    }
}

Function ConvertTo-ServiceStateDiff {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [Ansible.Windows.SCManager.ServiceStatus]
        $State
    )

    # Converts the enum ServiceStatus to the value for a diff.
    switch ($State) {
        Stopped { 'stopped' }
        StartPending { 'start_pending' }
        StopPending { 'stop_pending' }
        Running { 'started' }
        ContinuePending { 'continue_pending' }
        PausePending { 'pause_pending' }
        Paused { 'paused' }
    }
}

Function ConvertTo-ServiceTypeDiff {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [Ansible.Windows.SCManager.ServiceType]
        $ServiceType
    )

    # Converts the enum ServiceType to the valud for a diff.
    $ServiceType = [uint32]$ServiceType -band -bnot [uint32][Ansible.Windows.SCManager.ServiceType]::InteractiveProcess
    $ServiceType = $ServiceType -band -bnot [uint32][Ansible.Windows.SCManager.ServiceType]::UserServiceInstance
    switch ($ServiceType.ToString()) {
        KernelDriver { 'kernel_driver' }
        FileSystemDriver { 'file_system_driver' }
        Adapter { 'adapter' }
        RecognizerDriver { 'recognizer_driver' }
        Win32OwnProcess { 'win32_own_process' }
        Win32ShareProcess { 'win32_share_process' }
        UserOwnprocess { 'user_own_process' }
        UserShareProcess { 'user_share_process' }
        PkgService { 'pkg_service' }
    }
}

Function Get-ServiceDiff {
    [CmdletBinding()]
    param (
        [Ansible.Windows.SCManager.Service]
        $Service
    )

    if (-not $Service) {
        ""
    } else {
        $diff = @{
            dependencies = $Service.DependentOn
            description = $Service.Description
            desktop_interact = $Service.ServiceType.HasFlag(
                [Ansible.Windows.SCManager.ServiceType]::InteractiveProcess)
            display_name = $Service.DisplayName
            error_control = $Service.ErrorControl.ToString().ToLowerInvariant()
            failure_actions = @(ConvertTo-ServiceFailureActionsDiff -FailureActions $Service.FailureActions.Actions)
            failure_actions_on_non_crash_failure = $Service.FailureActionsOnNonCrashFailures
            failure_command = $Service.FailureActions.Command
            failure_reboot_msg = $Service.FailureActions.RebootMsg
            failure_reset_period_sec = $Service.FailureActions.ResetPeriod
            load_order_group = $Service.LoadOrderGroup
            name = $Service.ServiceName
            path = $Service.Path
            pre_shutdown_timeout_ms = $Service.PreShutdownTimeout
            required_privileges = $Service.RequiredPrivileges
            service_type = ConvertTo-ServiceTypeDiff -ServiceType $Service.ServiceType
            sid_info = $Service.ServiceSidInfo.ToString().ToLowerInvariant()
            start_mode = ConvertTo-ServiceStartModeDiff -StartMode $Service.StartType
            state = ConvertTo-ServiceStateDiff -State $Service.State
        }

        # Only set the username/password diff if we have the proper type.
        if ( -not (
            $Service.ServiceType.HasFlag([Ansible.Windows.SCManager.ServiceType]::KernelDriver) -or
            $service.ServiceType.HasFlag([Ansible.Windows.SCManager.ServiceType]::FileSystemDriver)
        )) {
            $diff.username = $Service.Account.Value
            $diff.password = 'REDACTED'
        }

        $diff
    }
}

Function Get-ServiceFromName {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $Name
    )

    # Get-Service -Name * doesn't work if the name has a wildcard char like '[]'. Use Where-Object to achieve the same
    # result just in a slightly more expensive way.
    $service = Get-Service | Where-Object { $_.ServiceName -eq $Name -or $_.DisplayName -eq $Name }

    # https://github.com/ansible-collections/ansible.windows/issues/115
    # Get-Service without a name will not output driver services whereas -Name does. Fallback to checking with -Name
    # if we couldn't find a match from above.
    if ($service) {
        return $service
    }
    Get-Service -Name $Name -ErrorAction SilentlyContinue
}

Function Set-ServiceAccount {
    [CmdletBinding()]
    param (
        [String]
        $Username,

        [String]
        $Password,

        [Switch]
        $UpdatePassword,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.username = $Username
    $Module.Diff.after.password = 'REDACTED'
    if ($null -ne $Service -and $Service.Account) {
        $desiredSid = $null
        if ($Username) {
            $desiredSid = ConvertTo-SecurityIdentifier -Name $Username
            $Module.Diff.after.username = $desiredSid.Translate([System.Security.Principal.NTAccount]).Value
        }
        $actualSid = ConvertTo-SecurityIdentifier -Name $Service.Account.Value

        if ($null -eq $desiredSid) {
            $Module.Diff.after.username = $Service.Account.Value
        } elseif (-not $desiredSid.Equals($actualSid)) {
            # We need to remove the desktop interact flag if we are changing from SYSTEM to another account
            $systemSid = ConvertTo-SecurityIdentifier -Name 'LocalSystem'
            if (-not $desiredSid.Equals($systemSid)) {
                Set-ServiceType -DesktopInteract $false -Username $username -Module $Module -Service $Service
            }

            if (-not $Module.CheckMode) {
                $Service.Account = $desiredSid
            }
            $UpdatePassword = $true  # Always set the password if changing the account.

            $Module.Result.changed = $true
        }

        # We cannot compare the password, so always change it based on the update_password module option.
        if ($UpdatePassword -and $Password) {
            $Module.Diff.after.password = 'CHANGED REDACTED'

            if (-not $Module.CheckMode -and $Service) {
                $Service.Password = $Password
            }
            $Module.Result.changed = $true
        }
    }
}

Function Set-ServiceDependencies {
    [CmdletBinding()]
    param (
        [String[]]
        $Dependencies,

        [String]
        $DependencyAction,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.dependencies = $Dependencies
    if ($null -ne $Service) {
        $Module.Diff.after.dependencies = $Service.DependentOn

        if ($null -ne $Dependencies) {
            $existingDependencies = [String[]]$Service.DependentOn
            [String[]]$addedDependents = @()
            [String[]]$removedDependents = @()

            if ($DependencyAction -eq 'add') {
                $addedDependents = [Linq.Enumerable]::Except($Dependencies, $existingDependencies)
            } elseif ($DependencyAction -eq 'remove') {
                $removedDependents = [Linq.Enumerable]::Intersect($Dependencies, $existingDependencies)
            } else {
                $addedDependents = [Linq.Enumerable]::Except($Dependencies, $existingDependencies)
                $removedDependents = [Linq.Enumerable]::Except($existingDependencies, $Dependencies)
            }

            if ($addedDependents -or $removedDependents) {
                $newDependents = $Service.DependentOn
                foreach ($toRemove in $removedDependents) {
                    $null = $newDependents.Remove($toRemove)
                }
                foreach ($toAdd in $addedDependents) {
                    $newDependents.Add($toAdd)
                }
                $Module.Diff.after.dependencies = $newDependents

                if (-not $Module.CheckMode) {
                    $Service.DependentOn = $newDependents
                }
                $Module.Result.changed = $true
            }
        }
    }
}

Function Set-ServiceDescription {
    [CmdletBinding()]
    param (
        # [String] - Cannot set so we can pass $null in (empty string is delete while $null is preserve).
        $Description,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.description = $Description
    if ($null -ne $Service) {
        if ($null -eq $Description) {
            $Module.Diff.after.description = $Service.Description
        } else {
            if (-not $Description) {
                $Description = $null
            }

            if ($Description -cne $Service.Description) {
                if (-not $Module.CheckMode) {
                    $Service.Description = $Description
                }
                $Module.Result.changed = $true
            }
        }
    }
}

Function Set-ServiceDisplayName {
    [CmdletBinding()]
    param (
        [String]
        $DisplayName,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.display_name = $DisplayName
    if ($null -ne $Service) {
        if (-not $DisplayName) {
            $Module.Diff.after.display_name = $Service.DisplayName
        } elseif ($DisplayName -cne $Service.DisplayName) {
            if (-not $Module.CheckMode) {
                $Service.DisplayName = $DisplayName
            }
            $Module.Result.changed = $true
        }
    }
}

Function Set-ServiceErrorControl {
    [CmdletBinding()]
    param (
        [String]
        $ErrorControl,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.error_control = $ErrorControl
    if ($null -ne $Service) {
        if (-not $ErrorControl) {
            $Module.Diff.after.error_control = $Service.ErrorControl.ToString().ToLowerInvariant()
        } elseif ([Ansible.Windows.SCManager.ErrorControl]$ErrorControl -ne $Service.ErrorControl) {
            if (-not $Module.CheckMode) {
                $Service.ErrorControl = $ErrorControl
            }
            $Module.Result.changed = $true
        }
    }
}

Function Set-ServiceFailureActions {
    [CmdletBinding()]
    param (
        [Object[]]
        $Actions,

        # [Bool] - Allow passing in $null
        $ActionOnNonCrashFailure,

        # [String]
        $Command,

        # [String]
        $RebootMsg,

        # [UInt32]
        $ResetPeriod,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.failure_actions = $Actions
    $Module.Diff.after.failure_actions_on_non_crash_failure = $ActionOnCrashFailure
    $Module.Diff.after.failure_command = $Command
    $Module.Diff.after.failure_reboot_msg = $RebootMsg
    $Module.Diff.after.failure_reset_period_sec = $ResetPeriod

    if ($null -ne $Service) {
        if ($null -eq $ActionOnNonCrashFailure) {
            $Module.Diff.after.failure_actions_on_non_crash_failure = $Service.FailureActionsOnNonCrashFailures
        } elseif ($ActionOnNonCrashFailure -ne $Service.FailureActionsOnNonCrashFailures) {
            if (-not $Module.CheckMode) {
                $Service.FailureActionsOnNonCrashFailures = $ActionOnNonCrashFailure
            }
            $Module.Result.changed = $true
        }

        $newFailures = New-Object -TypeName Ansible.Windows.SCManager.FailureActions
        $changed = $false

        if ($null -eq $Actions) {
            $diff = @(ConvertTo-ServiceFailureActionsDiff -FailureActions $Service.FailureActions.Actions)
            $Module.Diff.after.failure_actions = $diff
        } else {
            $newActions = [System.Collections.Generic.List[Ansible.Windows.SCManager.Action]]@()
            foreach ($action in $Actions) {
                $newActions.Add([Ansible.Windows.SCManager.Action]@{
                    Type = switch ($action.type) {
                        none { 'None' }
                        reboot { 'Reboot' }
                        restart { 'Restart' }
                        run_command { 'RunCommand' }
                    }
                    Delay = $action.delay_ms
                })
            }

            $changed = $newActions.Count -ne $Service.FailureActions.Actions.Count
            if (-not $changed) {
                for ($i = 0; $i -lt $newActions.Count; $i++) {
                    $existing = $Service.FailureActions.Actions[$i]
                    $new = $newActions[$i]

                    if ($new.Type -ne $existing.Type -or $new.Delay -ne $existing.Delay) {
                        $changed = $true
                        break
                    }
                }
            }

            if ($changed) {
                $newFailures.Actions = $newActions
            }
        }

        if ($null -eq $Command) {
            $Module.Diff.after.failure_command = $Service.FailureActions.Command
        } else {
            if (-not $Command) {  # Empty string resets the value but we still want idempotency.
                $Command = $null
            }

            if ($Command -cne $Service.FailureActions.Command) {
                $newFailures.Command = $Command
                $changed = $true
            }
        }

        if ($null -eq $RebootMsg) {
            $Module.Diff.after.failure_reboot_msg = $Service.FailureActions.RebootMsg
        } else {
            if (-not $RebootMsg) {  # See Command
                $RebootMsg = $null
            }

            if ($RebootMsg -cne $Service.FailureActions.RebootMsg) {
                $newFailures.RebootMsg = $RebootMsg
                $changed = $true
            }
        }

        if ($null -eq $ResetPeriod) {
            $Module.Diff.after.failure_reset_period_sec = $Service.FailureActions.ResetPeriod
        } elseif ($ResetPeriod -ne $Service.FailureActions.ResetPeriod) {
            $newFailures.ResetPeriod = $ResetPeriod
            $changed = $true
        }

        if ($changed) {
            if (-not $Module.CheckMode) {
                $Service.FailureActions = $newFailures
            }
            $Module.Result.changed = $true
        }
    }
}

Function Set-ServiceLoadOrderGroup {
    [CmdletBinding()]
    param (
        # [String] - Cannot set so we can pass $null in (empty string is delete while $null is preserve).
        $LoadOrderGroup,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.load_order_group = $LoadOrderGroup
    if ($null -ne $Service) {
        if ($null -eq $LoadOrderGroup) {
            $Module.Diff.after.load_order_group = $Service.LoadOrderGroup
        } else {
            if ($LoadOrderGroup -cne $Service.LoadOrderGroup) {
                if (-not $Module.CheckMode) {
                    $Service.LoadOrderGroup = $LoadOrderGroup
                }
                $Module.Result.changed = $true
            }
        }
    }
}

Function Set-ServicePath {
    [CmdletBinding()]
    param (
        [String]
        [AllowNull()]
        $Path,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.path = $Path
    if ($null -ne $Service) {
        if (-not $Path) {
            $Module.Diff.after.path = $Service.Path
        } elseif ($Path -cne $Service.Path) {
            if (-not $Module.CheckMode) {
                $Service.Path = $Path
            }
            $Module.Result.changed = $true
        }
    }
}

Function Set-ServicePreShutdownTimeoutMs {
    [CmdletBinding()]
    param (
        # [UInt32] - Need to be able to pass $Null in
        $PreShutdownTimeoutMs,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.pre_shutdown_timeout_ms = $PreShutdownTimeoutMs
    if ($null -ne $Service) {
        if ($null -eq $PreShutdownTimeoutMs) {
            $Module.Diff.after.pre_shutdown_timeout_ms = $Service.PreShutdownTimeout
        } elseif ($PreShutdownTimeoutMs -ne $Service.PreShutdownTimeout) {
            if (-not $Module.CheckMode) {
                $Service.PreShutdownTimeout = $PreShutdownTimeoutMs
            }
            $Module.Result.changed = $true
        }
    }
}

Function Set-ServiceRequiredPrivileges {
    [CmdletBinding()]
    param (
        [String[]]
        $RequiredPrivileges,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.required_privileges = $RequiredPrivileges
    if ($null -ne $Service) {
        if ($null -eq $RequiredPrivileges) {
            $Module.Diff.after.required_privileges = $Service.RequiredPrivileges
        } else {
            $existingPrivis = $Service.RequiredPrivileges.ToArray()
            $extraPrivs = [String[]][Linq.Enumerable]::Except($RequiredPrivileges, $existingPrivis)
            $missingPrivs = [String[]][Linq.Enumerable]::Except($existingPrivis, $RequiredPrivileges)

            if ($extraPrivs -or $missingPrivs) {
                if (-not $Module.CheckMode) {
                    $Service.RequiredPrivileges = $RequiredPrivileges
                }
                $Module.Result.changed = $true
            }
        }
    }
}

Function Set-ServiceSidInfo {
    [CmdletBinding()]
    param (
        [String]
        $SidInfo,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.sid_info = $SidInfo
    if ($null -ne $Service) {
        if (-not $SidInfo) {
            $Module.Diff.after.sid_info = $Service.ServiceSidInfo.ToString().ToLowerInvariant()
        } elseif ([Ansible.Windows.SCManager.ServiceSidInfo]$SidInfo -ne $Service.ServiceSidInfo) {
            if (-not $Module.CheckMode) {
                $Service.ServiceSidInfo = $SidInfo
            }
            $Module.Result.changed = $true
        }
    }
}

Function Set-ServiceStartMode {
    [CmdletBinding()]
    param (
        [String]
        $StartMode,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.start_mode = $StartMode
    if ($null -ne $Service) {
        if (-not $StartMode) {
            $Module.Diff.after.start_mode = ConvertTo-ServiceStartModeDiff -StartMode $Service.StartType
        } else {
            $stateMap = @{
                auto = [Ansible.Windows.SCManager.ServiceStartType]::AutoStart
                delayed = [Ansible.Windows.SCManager.ServiceStartType]::AutoStartDelayed
                disabled = [Ansible.Windows.SCManager.ServiceStartType]::Disabled
                manual = [Ansible.Windows.SCManager.ServiceStartType]::DemandStart
            }

            foreach ($kvp in $stateMap.GetEnumerator()) {
                if ($StartMode -ne $kvp.Key) {
                    continue
                }

                if ($Service.StartType -ne $kvp.Value) {
                    if (-not $Module.CheckMode) {
                        $Service.StartType = $kvp.Value
                    }

                    $Module.Result.changed = $true
                }
            }
        }
    }
}

Function Set-ServiceState {
    [CmdletBinding()]
    param (
        [String]
        $State,

        [Switch]
        $ForceDependentServices,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.state = $State
    if ($null -ne $Service) {
        $stateEnum = [Ansible.Windows.SCManager.ServiceStatus]

        # Due to *-Service cmdlets in win ps struggling with wildcard chars like [ we need to pipe in an actual service
        # object to the state changing cmdlets.
        $winService = Get-ServiceFromName -Name $Service.ServiceName

        if (-not $State) {
            $Module.Diff.after.state = ConvertTo-ServiceStateDiff -State $Service.State

        } elseif ($State -eq 'started' -and $Service.State -ne $stateEnum::Running) {
            if ($Service.State -eq $stateEnum::Paused) {
                try {
                    $winService | Resume-Service -WhatIf:$Module.CheckMode
                } catch {
                    $msg = "failed to start service from paused state $($Service.ServiceName): $($_.Exception.Message)"
                    $Module.FailJson($msg, $_)
                }
            } else {
                $winService | Start-Service -WhatIf:$Module.CheckMode
            }
            $Module.Result.changed = $true

        } elseif ($State -eq 'stopped' -and $Service.State -ne $stateEnum::Stopped) {
            $winService | Stop-Service -Force:$ForceDependentServices.IsPresent -WhatIf:$Module.CheckMode
            $Module.Result.changed = $true

        } elseif ($State -eq 'restarted') {
            $winService | Restart-Service -Force:$ForceDependentServices.IsPresent -WhatIf:$Module.CheckMode
            $Module.Result.changed = $true

        } elseif ($State -eq 'paused' -and $Service.State -ne $stateEnum::Paused) {
            if (-not $Service.ControlsAccepted.HasFlag([Ansible.Windows.SCManager.ControlsAccepted]::PauseContinue)) {
                $Module.FailJson("failed to pause service $($Service.ServiceName): The service does not support pausing")
            }

            try {
                $winService | Suspend-Service -WhatIf:$Module.CheckMode
            } catch {
                $Module.FailJson("failed to pause service $($Service.ServiceName): $($_.Exception.Message)", $_)
            }
            $Module.Result.changed = $true
        }
    }
}

Function Set-ServiceType {
    [CmdletBinding()]
    param (
        [String]
        $ServiceType,

        [Boolean]
        $DesktopInteract,

        [String]
        $Username,

        [Ansible.Basic.AnsibleModule]
        $Module,

        [Ansible.Windows.SCManager.Service]
        $Service
    )

    $Module.Diff.after.desktop_interact = $DesktopInteract
    $Module.Diff.after.service_type = $ServiceType
    if ($null -ne $Service) {
        [Ansible.Windows.SCManager.ServiceType]$desiredType = switch($ServiceType) {
            kernel_driver { [Ansible.Windows.SCManager.ServiceType]::KernelDriver }
            file_system_driver { [Ansible.Windows.SCManager.ServiceType]::FileSystemDriver }
            adapter { [Ansible.Windows.SCManager.ServiceType]::Adapter }
            recognizer_driver { [Ansible.Windows.SCManager.ServiceType]::RecognizerDriver }
            win32_own_process { [Ansible.Windows.SCManager.ServiceType]::Win32OwnProcess }
            win32_share_process { [Ansible.Windows.SCManager.ServiceType]::Win32ShareProcess }
            user_own_process { [Ansible.Windows.SCManager.ServiceType]::UserOwnprocess }
            user_share_process { [Ansible.Windows.SCManager.ServiceType]::UserShareProcess }
            default { $Service.ServiceType }
        }
        $Module.Diff.after.service_type = ConvertTo-ServiceTypeDiff -ServiceType $desiredType

        $interactive = [uint32][Ansible.Windows.SCManager.ServiceType]::InteractiveProcess
        if ($DesktopInteract) {
            if ($Username) {
                $actualAccount = ConvertTo-SecurityIdentifier -Name $Username
            } else {
                $actualAccount = $Service.Account.Translate([System.Security.Principal.SecurityIdentifier])
            }
            $systemSid = ConvertTo-SecurityIdentifier -Name 'LocalSystem'

            if (-not $actualAccount.Equals($systemSid)) {
                $Module.FailJson("Can only set 'desktop_interact' to true when 'username' equals 'SYSTEM'")
            }

            $desiredType = [uint32]$desiredType -bor $interactive
        } else {
            $desiredType = [uint32]$desiredType -band -bnot $interactive
        }

        if ($desiredType -ne $Service.ServiceType) {
            if (-not $Module.CheckMode) {
                $Service.ServiceType = $desiredType
            }
            $Module.Result.changed = $true
        }
    }
}

# We don't need the full gauntlet of service rights for this module. Only request the ones that are needed in case
# we come across a more restricted service.
# https://github.com/ansible-collections/ansible.windows/issues/118
$rights = [Ansible.Windows.SCManager.ServiceRights]'QueryConfig, QueryStatus, EnumerateDependents'

if ($failureActions) {
    # If setting an SC_ACTION_RESTART failure action the handle needs to be opened with start rights.
    $rights = $rights -bor [Ansible.Windows.SCManager.ServiceRights]::Start
}

if ($state -eq 'absent') {
    $rights = $rights -bor [Ansible.Windows.SCManager.ServiceRights]::Delete
}
else {
    $rights = $rights -bor [Ansible.Windows.SCManager.ServiceRights]::ChangeConfig
}

$service = Get-ServiceFromName -Name $name | ForEach-Object {
    New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList @(
        $_.ServiceName, $rights
    )
}
$module.Diff.before = Get-ServiceDiff -Service $service

if ($state -eq 'absent') {
    if ($service) {
        $winService = Get-ServiceFromName -Name $service.ServiceName
        $winService | Stop-Service -Force:$forceDependentServices -WhatIf:$module.CheckMode
        if (-not $module.CheckMode) {
            $service.Delete()
        }

        $module.Result.changed = $true
    }

    $module.Diff.after = ""
} else {
    # win_service can be used as a way to get info from an existing service by not setting any of these parameters.
    # This should be deprecated in the future in favour of win_service_info to simplify this module.
    $detectChanges = (
        $null -ne $service -or
        $null -ne $description -or
        $null -ne $displayName -or
        $null -ne $dependencies -or
        $dependencyAction -ne 'set' -or
        $desktopInteract -eq $true -or
        $null -ne $errorControl -or
        $null -ne $failureActions -or
        $null -ne $failureActionsOnNonCrashFailure -or
        $null -ne $failureCommand -or
        $null -ne $failureRebootMsg -or
        $null -ne $failureResetPeriodSec -or
        $null -ne $loadOrderGroup -or
        $null -ne $path -or
        $null -ne $preShutdownTimeoutMs -or
        $null -ne $requiredPrivileges -or
        $null -ne $serviceType -or
        $null -ne $sidInfo -or
        $null -ne $startMode -or
        $null -ne $state -or
        $null -ne $username -or
        $null -ne $password
    )

    if ($detectChanges) {
        $updatePassword = switch ($updatePassword) {
            always { $true }
            on_create { $false }
            default {
                # TODO: add deprecation warning for a change to always as the default.
                $false
            }
        }

        if (-not $service) {
            $updatePassword = $true

            if ($null -ne $path) {
                $null = New-Service -Name $name -BinaryPathName $path -WhatIf:$module.CheckMode
                if (-not $module.CheckMode) {
                    $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $name
                }
                $module.Result.changed = $true
            } else {
                $module.FailJson("Service '$name' is not installed, need to set 'path' to create a new service")
            }
        }

        # Each component is set in the Set-Service* cmdlets below
        $module.Diff.after = @{
            name = if ($service) { $service.ServiceName } else { $name }
        }

        $common = @{Service = $service; Module = $module}

        # The ServiceStartName for these types of services aren't the account it runs on so running this will fail
        # to convert it to an account. While this could be configured in the future for now we just ignore the values.
        if ( -not (
            $service.ServiceType.HasFlag([Ansible.Windows.SCManager.ServiceType]::KernelDriver) -or
            $service.ServiceType.HasFlag([Ansible.Windows.SCManager.ServiceType]::FileSystemDriver)
        )) {
            Set-ServiceAccount -Username $username -Password $password -UpdatePassword:$updatePassword @common
        }

        Set-ServiceDependencies -Dependencies $dependencies -DependencyAction $dependencyAction @common
        Set-ServiceDescription -Description $description @common
        Set-ServiceDisplayName -DisplayName $displayName @common
        Set-ServiceErrorControl -ErrorControl $errorControl @common

        $failureParams = @{
            Actions = $failureActions
            ActionOnNonCrashFailure = $failureActionsOnNonCrashFailure
            Command = $failureCommand
            RebootMsg = $failureRebootMsg
            ResetPeriod = $failureResetPeriodSec
        }
        Set-ServiceFailureActions @failureParams @common

        Set-ServiceLoadOrderGroup -LoadOrderGroup $loadOrderGroup @common
        Set-ServicePath -Path $path @common
        Set-ServicePreShutdownTimeoutMs -PreShutdownTimeoutMs $preShutdownTimeoutMs @common
        Set-ServiceRequiredPrivileges -RequiredPrivileges $requiredPrivileges @common
        Set-ServiceSidInfo -SidInfo $sidInfo @common
        Set-ServiceStartMode -StartMode $startMode @common
        Set-ServiceType -ServiceType $serviceType -DesktopInteract $desktopInteract -Username $username @common

        # This should always be set last in case one of the config options above changes
        Set-ServiceState -State $state -ForceDependentServices:$forceDependentServices @common
    } else {
        # TODO: deprecate this scenario as state != 'absent' should require one of the params in $detectChanges.
        $module.Diff.after = $module.Diff.before
    }
}

# The after diff already contains the pre-formatted return information. This should be deprecated with no new
# fields returned as this is just a backwards compatibility nightmare.
if ($module.Diff.after) {
    $after = $module.Diff.after

    $module.Result.exists = $true

    $module.Result.dependencies = $after.dependencies
    $module.Result.description = $after.description
    $module.Result.desktop_interact = $after.desktop_interact
    $module.Result.display_name = $after.display_name
    $module.Result.name = $after.name
    $module.Result.path = $after.path
    $module.Result.start_mode = $after.start_mode

    # Backwards compat, win_service used to just return the raw StartName value of the service and not a normalised
    # name that the diff has. The only case this matters if the username is SYSTEM which we correct to LocalSystem.
    $module.Result.username = $after.username
    if ($after.username) {
        $userSid = ConvertTo-SecurityIdentifier -Name $after.username
        $systemSid = ConvertTo-SecurityIdentifier -Name 'LocalSystem'
        if ($userSid.Equals($systemSid)) {
            $module.Result.username = 'LocalSystem'
        }
    }

    # Backwards compat, returned state was just a lowercase state of (Get-Service).State, whereas the diff matches
    # the output of win_service_info, i.e. 'continue_pending' becomes 'continuepending'. Also started needs to become
    # running to match the original value here.
    $module.Result.state = $after.state.Replace('_', '')
    if ($module.Result.state -in @('restarted', 'started')) {
        $module.Result.state = 'running'
    }

    # This isn't something we return in the diff as we cannot set this value.
    $module.Result.can_pause_and_continue = $null
    $module.Result.depended_by = @()
    if ($service) {
        $service.Refresh()  # Always ensure we are working with the latest info available.
        $module.Result.depended_by = $service.DependedBy
        $module.Result.can_pause_and_continue = $service.ControlsAccepted.HasFlag(
            [Ansible.Windows.SCManager.ControlsAccepted]::PauseContinue
        )
    }
}

$module.ExitJson()
