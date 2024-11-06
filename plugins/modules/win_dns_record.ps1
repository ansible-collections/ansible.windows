#!powershell
# Copyright: (c) 2021 Sebastian Gruber ,dacoso GmbH All Rights Reserved.
# Copyright: (c) 2019, Hitachi ID Systems, Inc.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = "str"; required = $true }
        port = @{ type = "int" }
        priority = @{ type = "int" }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
        ttl = @{ type = "int"; default = "3600" }
        aging = @{ type = "bool"; default = $false }
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
$type = $module.Params.type
$values = $module.Params.value
$weight = $module.Params.weight
$zone = $module.Params.zone
$zone_scope = $module.Params.zone_scope
$dns_computer_name = $module.Params.computer_name

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

# TODO: add warning for forest minTTL override -- see https://docs.microsoft.com/en-us/windows/desktop/ad/configuration-of-ttl-limits
if ($ttl -lt 1 -or $ttl -gt 31557600) {
    $module.FailJson("Parameter 'ttl' must be between 1 and 31557600")
}

$ttl = New-TimeSpan -Seconds $ttl

if (($type -eq 'CNAME' -or $type -eq 'NS' -or $type -eq 'PTR' -or $type -eq 'SRV') -and $null -ne $values -and $values.Count -gt 0 -and $zone[-1] -ne '.') {
    # CNAMEs and PTRs should be '.'-terminated, or record matching will fail
    $values = $values | ForEach-Object {
        if ($_ -Like "*.") { $_ } else { "$_." }
    }
}

$record_argument_name = @{
    A = "IPv4Address"
    AAAA = "IPv6Address"
    CNAME = "HostNameAlias"
    DHCID = "DhcpIdentifier"
    # MX = "MailExchange"
    NS = "NameServer"
    PTR = "PtrDomainName"
    SRV = "DomainName"
    TXT = "DescriptiveText"
}[$type]

function Get-DnsServerResourceRecordDataPropertyName {
    Switch -Exact ($type) {
        'DHCID' {
            'DhcId'
        }
        default {
            $record_argument_name
        }
    }
}

$changes = @{
    before = ""
    after = ""
}

$records = Get-DnsServerResourceRecord -ZoneName $zone -Name $name -RRType $type -Node -ErrorAction:Ignore @extra_args | Sort-Object

if ($null -ne $records) {
    # We use [Hashtable]$required_values below as a set rather than a map.
    # It provides quick lookup to test existing DNS record against. By removing
    # items as each is processed, whatever remains at the end is missing
    # content (that needs to be added).
    $required_values = @{}
    foreach ($value in $values) {
        $required_values[$value.ToString()] = $null
    }

    foreach ($record in $records) {
        # check, if record is aging
        $record_aging_old = ($null -ne $record.Timestamp)

        $record_value = $record.RecordData.$(Get-DnsServerResourceRecordDataPropertyName).ToString()
        if ((-Not $required_values.ContainsKey($record_value)) -Or (-Not $record_aging_old -eq $aging)) {
            $record | Remove-DnsServerResourceRecord -ZoneName $zone -Force -WhatIf:$module.CheckMode @extra_args
            $changes.before += "[$zone{0}] $($record.HostName) $($record.TimeToLive.TotalSeconds) IN $type $record_value`n" `
                -f ("", "/$zone_scope")[$null -ne $zone_scope]
            $module.Result.changed = $true
        }
        else {
            if ($type -eq 'SRV') {
                $record_port_old = $record.RecordData.Port.ToString()
                $record_priority_old = $record.RecordData.Priority.ToString()
                $record_weight_old = $record.RecordData.Weight.ToString()

                if ($record.TimeToLive -ne $ttl -or $port -ne $record_port_old -or $priority -ne $record_priority_old -or $weight -ne $record_weight_old) {
                    $new_record = $record.Clone()
                    $new_record.TimeToLive = $ttl
                    $new_record.RecordData.Port = $port
                    $new_record.RecordData.Priority = $priority
                    $new_record.RecordData.Weight = $weight
                    Set-DnsServerResourceRecord -ZoneName $zone -OldInputObject $record -NewInputObject $new_record -WhatIf:$module.CheckMode @extra_args

                    $changes.before += -join @(
                        "[$zone{0}] $($record.HostName) $($record.TimeToLive.TotalSeconds) IN " `
                            -f ("", "/$zone_scope")[$null -ne $zone_scope]
                        "$type $record_value $record_port_old $record_weight_old $record_priority_old`n"
                    )
                    $changes.after += "[$zone{0}] $($record.HostName) $($ttl.TotalSeconds) IN $type $record_value $port $weight $priority`n" `
                        -f ("", "/$zone_scope")[$null -ne $zone_scope]
                    $module.Result.changed = $true
                }
            }
            else {
                # This record matches one of the values; but does it match the TTL?
                if ($record.TimeToLive -ne $ttl) {
                    $new_record = $record.Clone()
                    $new_record.TimeToLive = $ttl
                    Set-DnsServerResourceRecord -ZoneName $zone -OldInputObject $record -NewInputObject $new_record -WhatIf:$module.CheckMode @extra_args
                    $changes.before += "[$zone{0}] $($record.HostName) $($record.TimeToLive.TotalSeconds) IN $type $record_value`n" `
                        -f ("", "/$zone_scope")[$null -ne $zone_scope]
                    $changes.after += "[$zone{0}] $($record.HostName) $($ttl.TotalSeconds) IN $type $record_value`n" `
                        -f ("", "/$zone_scope")[$null -ne $zone_scope]
                    $module.Result.changed = $true
                }
            }
            # Cross this one off the list, so we don't try adding it late
            $required_values.Remove($record_value)
            # Whatever is left in $required_values needs to be added
            $values = $required_values.Keys
        }
    }
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
                Add-DnsServerResourceRecord -SRV -Name $name -ZoneName $zone @srv_args @extra_args @extra_args_new_records -WhatIf:$module.CheckMode
            }
            else {
                Add-DnsServerResourceRecord -Name $name -AllowUpdateAny -ZoneName $zone -TimeToLive $ttl @splat_args -WhatIf:$module.CheckMode `
                    @extra_args @extra_args_new_records
            }
        }
        catch {
            $module.FailJson("Error adding DNS $type resource $name in zone $zone with value $value", $_)
        }
        $changes.after += "[$zone{0}] $name $($ttl.TotalSeconds) IN $type $value`n" `
            -f ("", "/$zone_scope")[$null -ne $zone_scope]
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
    $records_end = Get-DnsServerResourceRecord -ZoneName $zone -Name $name -RRType $type -Node -ErrorAction:Ignore @extra_args | Sort-Object
    $module.Diff.before = @(
        $records | ForEach-Object {
            "[$zone{0}] $($_.HostName) $($_.TimeToLive.TotalSeconds) IN $type $($_.RecordData.$(Get-DnsServerResourceRecordDataPropertyName).ToString())`n" `
                -f ("", "/$zone_scope")[$null -ne $zone_scope]
        }
    ) -join ''
    $module.Diff.after = @(
        $records_end | ForEach-Object {
            "[$zone{0}] $($_.HostName) $($_.TimeToLive.TotalSeconds) IN $type $($_.RecordData.$(Get-DnsServerResourceRecordDataPropertyName).ToString())`n" `
                -f ("", "/$zone_scope")[$null -ne $zone_scope]
        }
    ) -join ''
}

$module.ExitJson()
