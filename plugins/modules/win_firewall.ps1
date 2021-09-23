#!powershell

# Copyright: (c) 2017, Michael Eaton <meaton@iforium.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

$ErrorActionPreference = "Stop"
$firewall_profiles = @('Domain', 'Private', 'Public')

$params = Parse-Args $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false

$profiles = Get-AnsibleParam -obj $params -name "profiles" -type "list" -default @("Domain", "Private", "Public")
$state = Get-AnsibleParam -obj $params -name "state" -type "str" -failifempty $true -validateset 'disabled','enabled'
$inbound_action = Get-AnsibleParam -obj $params -name "inbound_action" -type "str" -validateset 'allow','block','not_configured'
$outbound_action = Get-AnsibleParam -obj $params -name "outbound_action" -type "str" -validateset 'allow','block','not_configured'

$result = @{
    changed = $false
    profiles = $profiles
    state = $state
}

try {
    get-command Get-NetFirewallProfile > $null
    get-command Set-NetFirewallProfile > $null
}
catch {
    Fail-Json $result "win_firewall requires Get-NetFirewallProfile and Set-NetFirewallProfile Cmdlets."
}

$FIREWALL_ENABLED = [Microsoft.PowerShell.Cmdletization.GeneratedTypes.NetSecurity.GpoBoolean]::True
$FIREWALL_DISABLED = [Microsoft.PowerShell.Cmdletization.GeneratedTypes.NetSecurity.GpoBoolean]::False

Try {

    ForEach ($profile in $firewall_profiles) {
        $current_profile = Get-NetFirewallProfile -Name $profile
        $currentstate = $current_profile.Enabled
        $current_inboundaction = $current_profile.DefaultInboundAction
        $current_outboundaction = $current_profile.DefaultOutboundAction
        $result.$profile = @{
            enabled = ($currentstate -eq $FIREWALL_ENABLED)
            considered = ($profiles -contains $profile)
            currentstate = $currentstate
        }

        if ($profiles -notcontains $profile) {
            continue
        }

        if ($state -eq 'enabled') {

            if ($currentstate -eq $FIREWALL_DISABLED) {
                Set-NetFirewallProfile -name $profile -Enabled true -WhatIf:$check_mode
                $result.changed = $true
                $result.$profile.enabled = $true
            }
            if($null -ne $inbound_action) {
                $inbound_action = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($inbound_action.ToLower()) -replace '_', ''
                if ($inbound_action -ne $current_inboundaction) {
                  Set-NetFirewallProfile -name $profile -DefaultInboundAction $inbound_action -WhatIf:$check_mode
                  $result.changed = $true
                }
            }
            if($null -ne $outbound_action) {
                $outbound_action = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($outbound_action.ToLower()) -replace '_', ''
                if ($outbound_action -ne $current_outboundaction) {
                  Set-NetFirewallProfile -name $profile -DefaultOutboundAction $outbound_action -WhatIf:$check_mode
                  $result.changed = $true
                }
            }
        } else {

            if ($currentstate -eq $FIREWALL_ENABLED) {
                Set-NetFirewallProfile -name $profile -Enabled false -WhatIf:$check_mode
                $result.changed = $true
                $result.$profile.enabled = $false
            }

        }
    }
} Catch {
    Fail-Json $result "an error occurred when attempting to change firewall status for profile $profile $($_.Exception.Message)"
}

Exit-Json $result
