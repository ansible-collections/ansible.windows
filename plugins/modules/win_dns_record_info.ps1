#!powershell
# Copyright: (c) 2026, Ansible Project
# Copyright: (c) 2026, Hen Yaish (hyaish@redhat.com)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils.Dns

$spec = @{
    options = @{
        zone = @{ type = 'str'; required = $true }
        name = @{ type = 'str' }
        type = @{ type = 'str' }
        zone_scope = @{ type = 'str' }
        computer_name = @{ type = 'str' }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$module.Result.changed = $false
$module.Result.records = @()
$module.Result.exists = $false
$zone = $module.Params.zone.TrimEnd('.')
if ([string]::IsNullOrWhiteSpace($zone)) { $module.FailJson('zone must be non-empty.') }
$query = @{ ZoneName = $zone }
if ($null -ne $module.Params.name) {
    try { $query.Name = ConvertTo-AnsibleWindowsDnsRecordName -Name $module.Params.name -Zone $zone }
    catch { $module.FailJson("Invalid DNS record name: $($_.Exception.Message)", $_) }
    $query.Node = $true
}
if ($null -ne $module.Params.type) {
    if ([string]::IsNullOrWhiteSpace($module.Params.type)) { $module.FailJson('type must be non-empty when supplied.') }
    $query.RRType = $module.Params.type.ToUpperInvariant()
}
if ($null -ne $module.Params.computer_name) { $query.ComputerName = $module.Params.computer_name }
if ($null -ne $module.Params.zone_scope) { $query.ZoneScope = $module.Params.zone_scope }
try {
    $module.Result.records = @(Get-AnsibleWindowsDnsRecord -Arguments $query |
            ForEach-Object { ConvertTo-AnsibleWindowsDnsRecordInfo -Record $_ } |
            # Windows PowerShell 5.1 requires expressions to sort by hash table key values.
            Sort-Object -Property { $_['name'] }, { $_['type'] }, { $_['record_values'] -join "`n" })
}
catch { $module.FailJson("Error reading DNS records in zone ${zone}: $($_.Exception.Message)", $_) }
$module.Result.exists = $module.Result.records.Count -gt 0
$module.ExitJson()
