#!powershell

# Copyright: (c) 2017, Marc Tschapek <marc.tschapek@itelligence.de>
# Copyright: (c) 2026, Hen Yaish (@Yaish25491)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils.Disk
#AnsibleRequires -OSVersion 10.0

Set-StrictMode -Version 2

$spec = @{
    options = @{
        disk_number = @{ type = 'int' }
        unique_id = @{ type = 'str' }
        path = @{ type = 'str' }
        filter = @{
            type = 'list'
            elements = 'str'
            choices = 'physical_disk', 'virtual_disk', 'win32_disk_drive', 'partitions', 'volumes'
            default = 'physical_disk', 'virtual_disk', 'win32_disk_drive', 'partitions', 'volumes'
        }
    }
    mutually_exclusive = @(, @('disk_number', 'unique_id', 'path'))
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

if ($null -ne $module.Params.disk_number -and $module.Params.disk_number -lt 0) {
    $module.FailJson('disk_number must be greater than or equal to 0')
}
foreach ($name in 'unique_id', 'path') {
    if ($null -ne $module.Params[$name] -and [string]::IsNullOrWhiteSpace($module.Params[$name])) {
        $module.FailJson("$name must not be empty or whitespace")
    }
}

if (-not (Test-AnsibleWindowsDiskAdministrator)) {
    $module.FailJson('This module requires an elevated administrator account')
}

$selector = @{}
if ($null -ne $module.Params.disk_number) { $selector.DiskNumber = $module.Params.disk_number }
if ($null -ne $module.Params.unique_id) { $selector.UniqueId = $module.Params.unique_id }
if ($null -ne $module.Params.path) { $selector.Path = $module.Params.path }

$module.Result.changed = $false
try {
    $module.Result.disks = @(Get-AnsibleWindowsDiskInformation -Selector $selector -Filter $module.Params.filter)
}
catch {
    $module.FailJson($_.Exception.Message, $_)
}
$module.Result.exists = $module.Result.disks.Count -gt 0
$module.ExitJson()
