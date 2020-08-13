#!powershell

# Copyright: (c) 2018, Ripon Banik (@riponbanik)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = 'str'; required = $true }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$current_computer_name = (Get-CimInstance -Class Win32_ComputerSystem).DNSHostname

$module.Result.old_name = $current_computer_name
$module.Result.reboot_required = $false

$module.Diff.before = $current_computer_name
$module.Diff.after = $module.Params.name

if ($module.Params.name -ne $current_computer_name) {
    Try {
        Rename-Computer -NewName $module.Params.name -Force -WhatIf:$module.CheckMode
    } Catch {
        $module.FailJson("Failed to rename computer to '$($module.Params.name)': $($_.Exception.Message)", $_)
    }
    $module.Result.changed = $true
    $module.Result.reboot_required = $true
}

$module.ExitJson()
