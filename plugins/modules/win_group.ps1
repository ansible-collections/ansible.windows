#!powershell

# Copyright: (c) 2014, Chris Hoffman <choffman@chathamfinancial.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        description = @{
            type = 'str'
        }
        name = @{
            type = 'str'
            required = $true
        }
        state = @{
            type = 'str'
            default = 'present'
            choices = 'absent', 'present'
        }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$state = $module.Params.state
$description = $module.Params.description

$module.Diff.before = $null
$module.Diff.after = $null

$adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
$group = $adsi.Children | Where-Object { $_.SchemaClassName -eq 'group' -and $_.Name -eq $name }
if ($group) {
    $module.Diff.before = @{
        name = $name
        # ADSI returns a collection for values even if they are single valued,
        # this ensures it's a single value in the diff output
        description = $group.Description | Select-Object -First 1
    }
}

if ($state -eq "present") {
    if (-not $group) {
        if (-not $module.CheckMode) {
            $group = $adsi.Create("Group", $name)
            $group.SetInfo()
        }

        $module.Result.changed = $true
    }

    # If in check mode and the group was created we skip the extra checks
    if ($group) {
        $existingDescription = $group.Description | Select-Object -First 1

        if ($null -ne $description) {
            if ($existingDescription -ne $description) {
                if (-not $module.CheckMode) {
                    $group.Description = $description
                    $group.SetInfo()
                }
                $module.Result.changed = $true
            }
        }
        else {
            # For diff output
            $description = $existingDescription
        }
    }

    $module.Diff.after = @{
        name = $name
        description = $description
    }
}
elseif ($state -eq "absent" -and $group) {
    if (-not $module.CheckMode) {
        $adsi.delete("Group", $group.Name.Value)
    }
    $module.Result.changed = $true
}

$module.ExitJson()
