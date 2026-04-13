#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils._TaskSchedulerRunner

$spec = @{
    options = @{
        disable_windows_update = @{ type = "bool"; default = $false }
        log_level = @{ type = "int" }
        log_path = @{ type = "path" }
        name = @{ type = "list"; elements = "str"; required = $true }
        source = @{ type = "list"; elements = "str" }
        state = @{ type = "str"; default = "present"; choices = @("absent", "present") }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$state = $module.Params.state

$module.Result.capabilities = @()
$module.Result.reboot_required = $false
$commonParams = @{
    Online = $true
}
if ($module.Params.log_level) {
    $commonParams.LogLevel = $module.Params.log_level
}
if ($module.Params.log_path) {
    $commonParams.LogPath = $module.Params.log_path
}

$sourceParams = @{}
if ($module.Params.source) {
    $sourceParams.Source = $module.Params.source
}
if ($module.Params.disable_windows_update) {
    $sourceParams.LimitAccess = $true
}

$changedFeatures = @(
    foreach ($featureName in $name) {
        if (
            [Environment]::OSVersion.Version -lt '10.0.17764' -and
            -not [WildcardPattern]::ContainsWildcardCharacters($featureName) -and
            -not $featureName.Contains('~')
        ) {
            # Server 2019 does not support finding a capability with just the
            # name. If the provided name doesn't contain a `~` we assume it's
            # just the base name of the capability and try to find it using a
            # wildcard pattern.
            $featureName = "$featureName~*"
        }

        $feature = Get-WindowsCapability @commonParams @sourceParams -Name $featureName | ForEach-Object {
            # Get-WindowsCapability returns an object with empty Name property when the
            # feature is not found.
            if (-not $_.Name) {
                $module.FailJson("Failed to find capability '$featureName'")
            }

            $_
        }

        if ($state -eq "present" -and $feature.State -notin @('Installed', 'InstallPending')) {
            $feature.Name
        }
        elseif ($state -eq "absent" -and $feature.State -notin @('NotPresent', 'Staged', 'Removed', 'RemovePending')) {
            $feature.Name
        }
    }
)


if ($state -eq "present" -and $changedFeatures.Count -gt 0) {
    # Add-WindowsCapability uses the Windows Update API to install the
    # capabilities which fails when the user is logged in with a network logon.
    # To workaround this without requiring the caller to use become on the task
    # we create a scheduled task process running as the same user but with a
    # BATCH logon type which allows us to bypass this issue.
    $session = New-ScheduledTaskSession
    try {
        if (-not $module.CheckMode) {
            $changedFeatures | ForEach-Object {
                $name = $_

                try {
                    $res = Invoke-Command -Session $session -ScriptBlock {
                        $commonParams = $args[0]
                        $sourceParams = $args[1]
                        $name = $args[2]

                        Add-WindowsCapability @commonParams @sourceParams -Name $name
                    } -ArgumentList $commonParams, $sourceParams, $name
                }
                catch {
                    $module.FailJson("Failed to install capability '$name': $_", $_)
                }

                if ($res.RestartNeeded) {
                    $module.Result.reboot_required = $true
                }
            }
        }
    }
    finally {
        $session | Remove-PSSession
    }

    $module.Result.changed = $true
}
elseif ($state -eq "absent" -and $changedFeatures.Count -gt 0) {
    $removeParams = @{
        Online = $true
    }

    if (-not $module.CheckMode) {
        $changedFeatures | ForEach-Object {
            $name = $_
            try {
                $res = Remove-WindowsCapability @removeParams -Name $name
            }
            catch {
                $module.FailJson("Failed to remove capability '$name': $_", $_)
            }

            if ($res.RestartNeeded) {
                $module.Result.reboot_required = $true
            }
        }
    }
    $module.Result.changed = $true
}
$module.Result.capabilities = @($changedFeatures)

$module.ExitJson()
