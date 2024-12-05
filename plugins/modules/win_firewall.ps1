#!powershell

# Copyright: (c) 2017, Michael Eaton <meaton@iforium.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$firewall_profiles = @('Domain', 'Private', 'Public')

$spec = @{
    options = @{
        profiles = @{ type = 'list' ; elements = 'str' ; choices = @("Domain", "Private", "Public") ; default = @("Domain", "Private", "Public") }
        state = @{ type = 'str' ; choices = @('disabled', 'enabled') ; required = $true }
        inbound_action = @{ type = 'str' ; choices = @('allow', 'block', 'not_configured') }
        outbound_action = @{ type = 'str' ; choices = @('allow', 'block', 'not_configured') }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$check_mode = $module.CheckMode

$profiles = $module.Params.profiles
$state = $module.Params.state
$inbound_action = $module.Params.inbound_action
$outbound_action = $module.Params.outbound_action

$module.Result.restart_required = $false
$module.Result.changed = $false
$module.Result.profiles = $profiles
$module.Result.state = $state

try {
    get-command Get-NetFirewallProfile > $null
    get-command Set-NetFirewallProfile > $null
}
catch {
    $module.FailJson("win_firewall requires Get-NetFirewallProfile and Set-NetFirewallProfile Cmdlets.", $_)
}

$FIREWALL_ENABLED = [Microsoft.PowerShell.Cmdletization.GeneratedTypes.NetSecurity.GpoBoolean]::True
$FIREWALL_DISABLED = [Microsoft.PowerShell.Cmdletization.GeneratedTypes.NetSecurity.GpoBoolean]::False

Try {

    ForEach ($profile in $firewall_profiles) {
        $current_profile = Get-NetFirewallProfile -Name $profile
        $currentstate = $current_profile.Enabled
        $current_inboundaction = $current_profile.DefaultInboundAction
        $current_outboundaction = $current_profile.DefaultOutboundAction
        $module.Result.$profile = @{
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
                $module.Result.changed = $true
                $module.Result.$profile.enabled = $true
            }
            if ($null -ne $inbound_action) {
                $inbound_action = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($inbound_action.ToLower()) -replace '_', ''
                if ($inbound_action -ne $current_inboundaction) {
                    Set-NetFirewallProfile -name $profile -DefaultInboundAction $inbound_action -WhatIf:$check_mode
                    $module.Result.changed = $true
                }
            }
            if ($null -ne $outbound_action) {
                $outbound_action = [Globalization.CultureInfo]::InvariantCulture.TextInfo.ToTitleCase($outbound_action.ToLower()) -replace '_', ''
                if ($outbound_action -ne $current_outboundaction) {
                    Set-NetFirewallProfile -name $profile -DefaultOutboundAction $outbound_action -WhatIf:$check_mode
                    $module.Result.changed = $true
                }
            }
        }
        else {

            if ($currentstate -eq $FIREWALL_ENABLED) {
                Set-NetFirewallProfile -name $profile -Enabled false -WhatIf:$check_mode
                $module.Result.changed = $true
                $module.Result.$profile.enabled = $false
            }

        }
    }
}
Catch {
    $module.FailJson("an error occurred when attempting to change firewall status for profile $profile $($_.Exception.Message)", $_)
}

$module.ExitJson()
