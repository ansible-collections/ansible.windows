#!powershell
# Copyright: (c) 2021 Sebastian Gruber ,dacoso GmbH All Rights Reserved.
# Copyright: (c) 2019, Hitachi ID Systems, Inc.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils.Dns

$spec = @{
    options = @{
        name = @{ type = "str"; required = $true }
        port = @{ type = "int" }
        priority = @{ type = "int" }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
        ttl = @{ type = "int"; default = "3600" }
        aging = @{ type = "bool"; default = $false }
        allow_update_any = @{ type = "bool"; default = $false }
        type = @{ type = "str"; choices = "A", "AAAA", "CNAME", "DHCID", "NS", "PTR", "SRV", "TXT"; required = $true }
        value = @{ type = "list"; elements = "str"; default = @() ; aliases = @( 'values' ) }
        weight = @{ type = "int" }
        zone = @{ type = "str"; required = $true }
        zone_scope = @{ type = "str" }
        computer_name = @{ type = "str" }
    }
    required_if = @(, @("type", "SRV", @("port", "priority", "weight")))
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$name = $module.Params.name
$port = $module.Params.port
$priority = $module.Params.priority
$state = $module.Params.state
$ttl = $module.Params.ttl
$aging = $module.Params.aging
$allow_update_any = $module.Params.allow_update_any
$type = $module.Params.type
$values = $module.Params.value
$weight = $module.Params.weight
$zone = $module.Params.zone
$zone_scope = $module.Params.zone_scope
$dns_computer_name = $module.Params.computer_name

try {
    $name = ConvertTo-AnsibleWindowsDnsRecordName -Name $name -Zone $zone
    $zone = $zone.TrimEnd('.')
}
catch {
    $module.FailJson("Invalid DNS record name or zone: $($_.Exception.Message)", $_)
}

$extra_args = @{}
$extra_args_new_records = @{}

if ($null -ne $dns_computer_name) {
    $extra_args.ComputerName = $dns_computer_name
}
if ($null -ne $zone_scope) {
    $extra_args.ZoneScope = $zone_scope
}
if ($aging -eq $true) {
    $extra_args_new_records.AgeRecord = $true
}
if ($allow_update_any -eq $true) {
    $extra_args_new_records.AllowUpdateAny = $true
}

if ($state -eq 'present') {
    if ($values.Count -eq 0) {
        $module.FailJson("Parameter 'values' must be non-empty when state='present'")
    }
}
else {
    if ($values.Count -ne 0) {
        $module.FailJson("Parameter 'values' must be undefined or empty when state='absent'")
    }
}

if ($type -eq 'SRV') {
    foreach ($parameter in 'port', 'priority', 'weight') {
        if ($module.Params.$parameter -lt 0 -or $module.Params.$parameter -gt 65535) {
            $module.FailJson("Parameter '$parameter' must be between 0 and 65535")
        }
    }
}

if ($ttl -lt 1 -or $ttl -gt 31557600) {
    $module.FailJson("Parameter 'ttl' must be between 1 and 31557600")
}

$ttl = New-TimeSpan -Seconds $ttl

try {
    $values = ConvertTo-AnsibleWindowsDnsRecordValue -Type $type -Value $values
}
catch {
    $module.FailJson("Invalid DNS $type record value: $($_.Exception.Message)", $_)
}
$desired_values = @($values)

$record_data_property = Get-AnsibleWindowsDnsRecordDataPropertyName -Type $type
$record_argument_name = $record_data_property
if ($type -eq 'DHCID') { $record_argument_name = 'DhcpIdentifier' }

$changes = @{
    before = ""
    after = ""
}

$query_args = @{ ZoneName = $zone; Name = $name; RRType = $type; Node = $true }
foreach ($key in $extra_args.Keys) { $query_args[$key] = $extra_args[$key] }
try {
    $records = @(Get-AnsibleWindowsDnsRecord -Arguments $query_args | Sort-Object)
}
catch {
    $module.FailJson("Error reading DNS $type resource $name in zone ${zone}: $($_.Exception.Message)", $_)
}

if ($null -ne $records) {
    # We use [Hashtable]$required_values below as a set rather than a map.
    # It provides quick lookup to test existing DNS record against. By removing
    # items as each is processed, whatever remains at the end is missing
    # content (that needs to be added).
    $required_values = @{}
    if ($type -eq 'TXT') { $required_values = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal) }
    foreach ($value in $values) {
        $required_values[$value.ToString()] = $null
    }

    foreach ($record in $records) {
        # check, if record is aging
        $record_aging_old = ($null -ne $record.Timestamp)

        $record_value = Get-AnsibleWindowsDnsRecordValue -Record $record
        if ((-Not $required_values.ContainsKey($record_value)) -Or (-Not $record_aging_old -eq $aging)) {
            try {
                $record | Remove-DnsServerResourceRecord -ZoneName $zone -Force -WhatIf:$module.CheckMode @extra_args -ErrorAction Stop
            }
            catch {
                $module.FailJson("Error removing DNS $type resource $name in zone ${zone}: $($_.Exception.Message)", $_)
            }
            $changes.before += Format-AnsibleWindowsDnsRecord -Record $record -Zone $zone -ZoneScope $zone_scope
            $module.Result.changed = $true
        }
        else {
            $needs_update = $record.TimeToLive -ne $ttl
            if ($type -eq 'SRV' -and ($record.RecordData.Port -ne $port -or
                    $record.RecordData.Priority -ne $priority -or $record.RecordData.Weight -ne $weight)) {
                $needs_update = $true
            }
            if ($needs_update) {
                $new_record = [CimInstance]::new($record)
                $new_record.TimeToLive = $ttl
                if ($type -eq 'SRV') {
                    $new_record.RecordData.Port = $port
                    $new_record.RecordData.Priority = $priority
                    $new_record.RecordData.Weight = $weight
                }
                try {
                    Set-DnsServerResourceRecord -ZoneName $zone -OldInputObject $record -NewInputObject $new_record `
                        -WhatIf:$module.CheckMode @extra_args -ErrorAction Stop
                }
                catch {
                    $module.FailJson("Error updating DNS $type resource $name in zone ${zone}: $($_.Exception.Message)", $_)
                }
                $changes.before += Format-AnsibleWindowsDnsRecord -Record $record -Zone $zone -ZoneScope $zone_scope
                $changes.after += Format-AnsibleWindowsDnsRecord -Record $new_record -Zone $zone -ZoneScope $zone_scope
                $module.Result.changed = $true
            }
            # Cross this one off the list, so we don't try adding it late
            $null = $required_values.Remove($record_value)
        }
    }
    # Whatever is left needs to be added, including when the provider returned no records.
    $values = @($required_values.Keys)
}

if ($null -ne $values -and $values.Count -gt 0) {
    foreach ($value in $values) {
        $splat_args = @{ $type = $true; $record_argument_name = $value }
        $module.Result.debug_splat_args = $splat_args
        $srv_args = @{
            DomainName = $value
            Weight = $weight
            Priority = $priority
            Port = $port
        }
        try {
            if ($type -eq 'SRV') {
                Add-DnsServerResourceRecord -SRV -Name $name -ZoneName $zone -TimeToLive $ttl @srv_args @extra_args @extra_args_new_records `
                    -WhatIf:$module.CheckMode -ErrorAction Stop
            }
            else {
                Add-DnsServerResourceRecord -Name $name -ZoneName $zone -TimeToLive $ttl @splat_args -WhatIf:$module.CheckMode `
                    @extra_args @extra_args_new_records -ErrorAction Stop
            }
        }
        catch {
            $module.FailJson("Error adding DNS $type resource $name in zone $zone with value $value", $_)
        }
        $predicted_data = @{ $record_data_property = $value }
        if ($type -eq 'SRV') { $predicted_data.Port = $port; $predicted_data.Priority = $priority; $predicted_data.Weight = $weight }
        $predicted_record = [pscustomobject]@{
            HostName = $name; RecordType = $type; TimeToLive = $ttl; RecordData = [pscustomobject]$predicted_data
        }
        $changes.after += Format-AnsibleWindowsDnsRecord -Record $predicted_record -Zone $zone -ZoneScope $zone_scope
    }
    $module.Result.changed = $true
}

if ($module.CheckMode) {
    # Simulated changes
    $module.Diff.before = $changes.before
    $module.Diff.after = $changes.after
}
else {
    # Real changes
    try {
        $records_end = @(Get-AnsibleWindowsDnsRecord -Arguments $query_args | Sort-Object)
    }
    catch {
        $module.FailJson("Error verifying DNS $type resource $name in zone ${zone}: $($_.Exception.Message)", $_)
    }
    $remaining_values = @{}
    if ($type -eq 'TXT') { $remaining_values = [Collections.Generic.Dictionary[string, object]]::new([StringComparer]::Ordinal) }
    foreach ($value in $desired_values) { $remaining_values[$value.ToString()] = $null }
    $verified = $records_end.Count -eq $remaining_values.Count
    foreach ($record in $records_end) {
        $record_value = Get-AnsibleWindowsDnsRecordValue -Record $record
        if (-not $remaining_values.ContainsKey($record_value) -or ($null -ne $record.Timestamp) -ne $aging -or
            $record.TimeToLive -ne $ttl) {
            $verified = $false
        }
        if ($type -eq 'SRV' -and ($record.RecordData.Port -ne $port -or
                $record.RecordData.Priority -ne $priority -or $record.RecordData.Weight -ne $weight)) {
            $verified = $false
        }
        $null = $remaining_values.Remove($record_value)
    }
    if (-not $verified -or $remaining_values.Count) {
        $module.FailJson("The requested DNS records did not match the values, TTL, aging, or SRV fields after the operation for $name in zone $zone. " +
            'Check the DNS server, permissions, and remote authentication.')
    }
    $module.Diff.before = @(
        $records | ForEach-Object {
            Format-AnsibleWindowsDnsRecord -Record $_ -Zone $zone -ZoneScope $zone_scope
        }
    ) -join ''
    $module.Diff.after = @(
        $records_end | ForEach-Object {
            Format-AnsibleWindowsDnsRecord -Record $_ -Zone $zone -ZoneScope $zone_scope
        }
    ) -join ''
}

$module.ExitJson()
