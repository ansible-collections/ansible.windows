#!powershell

# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
$spec = @{
    options = @{
        action = @{ type = 'str' ; default = "set" ; choices = @("set", "add", "remove") }
        communities = @{ type = 'list' ; elements = 'str' }
        permitted_managers = @{ type = 'list' ; elements = 'str' }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$action = $module.Params.action
$communities = $module.Params.communities
$managers = $module.Params.permitted_managers
$check_mode = $module.Checkmode

# Make sure lists are modifyable
[System.Collections.ArrayList]$managers = $managers
[System.Collections.ArrayList]$communities = $communities
[System.Collections.ArrayList]$indexes = @()


$Managers_reg_key = "HKLM:\System\CurrentControlSet\services\SNMP\Parameters\PermittedManagers"
$Communities_reg_key = "HKLM:\System\CurrentControlSet\services\SNMP\Parameters\ValidCommunities"

$module.result.permitted_managers = [System.Collections.ArrayList]@()

ForEach ($idx in (Get-Item -LiteralPath $Managers_reg_key).Property) {
    $manager = (Get-ItemProperty -LiteralPath $Managers_reg_key).$idx
    If ($idx.ToLower() -eq '(default)') {
        continue
    }

    $remove = $False
    If ($managers -Is [System.Collections.ArrayList] -And $managers.Contains($manager)) {
        If ($action -eq "remove") {
            $remove = $True
        }
        Else {
            # Remove manager from list to add since it already exists
            $managers.Remove($manager)
        }
    }
    ElseIf ($action -eq "set" -And $managers -Is [System.Collections.ArrayList]) {
        # Will remove this manager since it is not in the set list
        $remove = $True
    }

    If ($remove) {
        $module.result.changed = $True
        Remove-ItemProperty -LiteralPath $Managers_reg_key -Name $idx -WhatIf:$check_mode
    }
    Else {
        $indexes.Add([int]$idx) | Out-Null
        $module.result.permitted_managers.Add($manager) | Out-Null
    }
}

$module.result.communities = [System.Collections.ArrayList]@()

ForEach ($community in (Get-Item -LiteralPath $Communities_reg_key).Property) {
    If ($community.ToLower() -eq '(default)') {
        continue
    }

    $remove = $False
    If ($communities -Is [System.Collections.ArrayList] -And $communities.Contains($community)) {
        If ($action -eq "remove") {
            $remove = $True
        }
        Else {
            # Remove community from list to add since it already exists
            $communities.Remove($community)
        }
    }
    ElseIf ($action -eq "set" -And $communities -Is [System.Collections.ArrayList]) {
        # Will remove this community since it is not in the set list
        $remove = $True
    }

    If ($remove) {
        $module.result.changed = $True
        Remove-ItemProperty -LiteralPath $Communities_reg_key -Name $community -WhatIf:$check_mode
    }
    Else {
        $module.result.communities.Add($community) | Out-Null
    }
}

If ($action -eq "remove") {
    $module.ExitJson()
}

# Add managers that don't already exist
$next_index = 0
If ($managers -Is [System.Collections.ArrayList]) {
    ForEach ($manager in $managers) {
        While ($True) {
            $next_index = $next_index + 1
            If (-Not $indexes.Contains($next_index)) {
                $module.result.changed = $True
                New-ItemProperty -LiteralPath $Managers_reg_key -Name $next_index -Value "$manager" -WhatIf:$check_mode | Out-Null
                $module.result.permitted_managers.Add($manager) | Out-Null
                break
            }
        }
    }
}

# Add communities that don't already exist
If ($communities -Is [System.Collections.ArrayList]) {
    ForEach ($community in $communities) {
        $module.result.changed = $True
        New-ItemProperty -LiteralPath $Communities_reg_key -Name $community -PropertyType DWord -Value 4 -WhatIf:$check_mode | Out-Null
        $module.result.communities.Add($community) | Out-Null
    }
}

$module.ExitJson()

