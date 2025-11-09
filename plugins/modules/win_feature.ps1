#!powershell

# Copyright: (c) 2014, Paul Durivage <paul.durivage@rackspace.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

using namespace Ansible.Basic

$spec = @{
    options = @{
        include_sub_features = @{ type = "bool"; default = $false }
        include_management_tools = @{ type = "bool"; default = $false }
        name = @{ type = "list"; elements = "str"; required = $true }
        source = @{ type = "str" }
        state = @{ type = "str"; choices = "present", "absent"; default = "present" }
    }
    supports_check_mode = $true
}
$module = [AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$state = $module.Params.state
$includeSubFeatures = $module.Params.include_sub_features
$includeManagementTools = $module.Params.include_management_tools
$source = $module.Params.source

$module.Result.exitcode = 'NoChangeNeeded'
$module.Result.feature_result = @()
$module.Result.reboot_required = $false
$module.Result.success = $true
$module.Result.failed = $false

if ($source) {
    if (-not (Test-Path -LiteralPath $source)) {
        $module.FailJson("Failed to find source path $source for feature install")
    }
}

if ($IsCoreCLR) {
    # ServerManager isn't natively supported in PowerShell 7 and the implicit
    # remoting session that it uses for this module doesn't serialize the
    # return results correctly. We wrap it in a WinPS job that serializes with
    # an explicit depth to avoid this problem.

    Function Install-WindowsFeature {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string]
            $Name,

            [Parameter()]
            [switch]
            $IncludeAllSubFeature,

            [Parameter()]
            [switch]
            $IncludeManagementTools,

            [Parameter()]
            [string]
            $Source,

            [Parameter()]
            [Alias('WhatIf')]
            [switch]
            $CheckMode
        )

        $serializedResult = Start-Job -PSVersion 5.1 -ScriptBlock {
            $ErrorActionPreference = 'Stop'

            Import-Module -Name ServerManager

            $installParams = @{
                Name = $args[0]
                IncludeAllSubFeature = $args[1]
                IncludeManagementTools = $args[2]
                WhatIf = $args[3]
                Restart = $false
                Confirm = $false
            }
            if ($args[4]) {
                $installParams.Source = $args[4]
            }
            $result = Install-WindowsFeature @installParams

            [System.Management.Automation.PSSerializer]::Serialize($result, 4)
        } -ArgumentList @(
            $Name,
            $IncludeAllSubFeature.IsPresent,
            $IncludeManagementTools.IsPresent,
            $CheckMode.IsPresent,
            $Source
        ) | Receive-Job -AutoRemoveJob -Wait

        [System.Management.Automation.PSSerializer]::Deserialize($serializedResult)
    }

    Function Uninstall-WindowsFeature {
        [CmdletBinding()]
        param (
            [Parameter(Mandatory)]
            [string]
            $Name,

            [Parameter()]
            [switch]
            $IncludeManagementTools,

            [Parameter()]
            [Alias('WhatIf')]
            [switch]
            $CheckMode
        )

        $serializedResult = Start-Job -PSVersion 5.1 -ScriptBlock {
            $ErrorActionPreference = 'Stop'

            Import-Module -Name ServerManager

            $uninstallParams = @{
                Name = $args[0]
                IncludeManagementTools = $args[1]
                WhatIf = $args[2]
                Restart = $false
                Confirm = $false
            }
            $result = Uninstall-WindowsFeature @uninstallParams

            [System.Management.Automation.PSSerializer]::Serialize($result, 4)
        } -ArgumentList @(
            $Name,
            $IncludeManagementTools.IsPresent,
            $CheckMode.IsPresent
        ) | Receive-Job -AutoRemoveJob -Wait

        [System.Management.Automation.PSSerializer]::Deserialize($serializedResult)
    }
}

if ($state -eq "present") {
    $installParams = @{
        Name = $name
        IncludeAllSubFeature = $includeSubFeatures
        IncludeManagementTools = $includeManagementTools
        WhatIf = $module.CheckMode
    }
    if ($source) {
        $installParams.Source = $source
    }

    $result = Install-WindowsFeature @installParams
}
else {
    $uninstallParams = @{
        Name = $name
        IncludeManagementTools = $includeManagementTools
        WhatIf = $module.CheckMode
    }

    $result = Uninstall-WindowsFeature @uninstallParams
}

$module.Result.feature_result = @(
    foreach ($entry in $result.FeatureResult) {
        $message = @(
            foreach ($msg in $entry.Message) {
                @{
                    message_type = [string]$msg.MessageType
                    error_code = $msg.ErrorCode
                    text = $msg.Text
                }
            }
        )

        @{
            id = $entry.Id
            display_name = $entry.DisplayName
            message = $message
            reboot_required = ([string]$entry.RestartNeeded -eq 'Yes')
            skip_reason = [string]$entry.SkipReason
            success = $entry.Success
        }

        $module.Result.changed = $true
    }
)

$module.Result.success = $result.Success
$module.Result.exitcode = [string]$result.ExitCode
$module.Result.reboot_required = ([string]$result.RestartNeeded -eq 'Yes')
$module.Result.failed = -not $result.Success

$module.ExitJson()
