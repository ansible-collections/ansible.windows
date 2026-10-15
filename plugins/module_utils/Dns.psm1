# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

function ConvertTo-AnsibleWindowsDnsRecordName {
    <#
    .SYNOPSIS
    Convert a relative or zone-qualified owner name to the DNS cmdlets' relative name.
    .PARAMETER Name
    The owner name, including @ for the zone apex.
    .PARAMETER Zone
    The zone containing the record.
    #>
    param([string]$Name, [string]$Zone)

    $zoneName = $Zone.TrimEnd('.')
    $recordName = $Name.TrimEnd('.')
    if ([string]::IsNullOrWhiteSpace($recordName) -or [string]::IsNullOrWhiteSpace($zoneName)) {
        throw 'DNS record name and zone must be non-empty.'
    }
    if ($recordName -eq '@' -or $recordName.Equals($zoneName, [StringComparison]::OrdinalIgnoreCase)) {
        return '@'
    }
    $suffix = ".$zoneName"
    if ($recordName.EndsWith($suffix, [StringComparison]::OrdinalIgnoreCase)) {
        return $recordName.Substring(0, $recordName.Length - $suffix.Length)
    }
    if ($Name.EndsWith('.')) {
        throw "Absolute DNS record name '$Name' is outside zone '$Zone'."
    }
    $recordName
}

function Get-AnsibleWindowsDnsRecord {
    <#
    .SYNOPSIS
    Read DNS records while preserving all errors except a missing requested record or name.
    .PARAMETER Arguments
    The DNS query parameters, including ZoneName and optional Name, RRType, ComputerName and ZoneScope.
    #>
    param([hashtable]$Arguments)

    try {
        Get-DnsServerResourceRecord @Arguments -ErrorAction Stop
    }
    catch {
        # Only missing record/name errors are empty results. Zone, access and connection errors must propagate.
        # https://learn.microsoft.com/windows/win32/debug/system-error-codes--9000-11999-
        if (($_.FullyQualifiedErrorId -match '^WIN32 (9701|9714)(,|$)') -and
            ($Arguments.ContainsKey('Name') -or $Arguments.ContainsKey('RRType'))) {
            return
        }
        throw
    }
}

function ConvertTo-AnsibleWindowsDnsRecordValue {
    <#
    .SYNOPSIS
    Normalize address and domain-name values before comparing or writing resource records.
    .PARAMETER Type
    The resource record type.
    .PARAMETER Value
    The desired values.
    #>
    param([string]$Type, [string[]]$Value)

    $values = @(foreach ($item in $Value) {
            if ($Type -in 'A', 'AAAA') {
                $address = [Net.IPAddress]::Parse($item)
                $family = [Net.Sockets.AddressFamily]::InterNetwork
                if ($Type -eq 'AAAA') { $family = [Net.Sockets.AddressFamily]::InterNetworkV6 }
                if ($address.AddressFamily -ne $family) { throw "Value '$item' is not a $Type address." }
                $address.ToString()
            }
            elseif ($Type -in 'CNAME', 'NS', 'PTR', 'SRV' -and -not $item.EndsWith('.')) { "$item." }
            else { $item }
        })
    return , $values
}

function ConvertTo-AnsibleWindowsDnsValue {
    <#
    .SYNOPSIS
    Convert DNS provider values to JSON-compatible strings, numbers, booleans and arrays.
    .PARAMETER Value
    The raw DNS record data field.
    #>
    param($Value)

    if ($null -eq $Value) { return $null }
    if ($Value -is [DateTime]) { return $Value.ToUniversalTime().ToString('o') }
    if ($Value -is [Net.IPAddress]) { return $Value.ToString() }
    if ($Value -is [array]) {
        return , @($Value | ForEach-Object { ConvertTo-AnsibleWindowsDnsValue -Value $_ })
    }
    if ($Value -is [string] -or $Value -is [ValueType]) { return $Value }
    $Value.ToString()
}

function Get-AnsibleWindowsDnsRecordDataPropertyName {
    <#
    .SYNOPSIS
    Get the provider field containing a resource record's primary value.
    .PARAMETER Type
    The resource record type.
    #>
    param([string]$Type)

    @{
        A = 'IPv4Address'; AAAA = 'IPv6Address'; CNAME = 'HostNameAlias'; DHCID = 'DhcId'; NS = 'NameServer'
        PTR = 'PtrDomainName'; SRV = 'DomainName'; TXT = 'DescriptiveText'; MX = 'MailExchange'
    }[$Type]
}

function Get-AnsibleWindowsDnsRecordValue {
    <#
    .SYNOPSIS
    Get the primary record value, joining TXT segments into their logical value.
    .PARAMETER Record
    The provider resource record.
    #>
    param($Record)

    $property = Get-AnsibleWindowsDnsRecordDataPropertyName -Type $Record.RecordType
    if ($property -and $null -ne $Record.RecordData.$property) {
        if ($Record.RecordType -eq 'TXT') { return @($Record.RecordData.$property) -join '' }
        $Record.RecordData.$property.ToString()
    }
}

function Format-AnsibleWindowsDnsRecord {
    <#
    .SYNOPSIS
    Format an actual or predicted record consistently for diff output.
    .PARAMETER Record
    The provider resource record or a predicted record with equivalent properties.
    .PARAMETER Zone
    The zone containing the record.
    .PARAMETER ZoneScope
    The optional zone scope containing the record.
    #>
    param($Record, [string]$Zone, [string]$ZoneScope)

    $scope = ''
    if ($ZoneScope) { $scope = "/$ZoneScope" }
    $value = Get-AnsibleWindowsDnsRecordValue -Record $Record
    if ($Record.RecordType -eq 'SRV') {
        $value += " $($Record.RecordData.Port) $($Record.RecordData.Weight) $($Record.RecordData.Priority)"
    }
    "[$Zone$scope] $($Record.HostName) $($Record.TimeToLive.TotalSeconds) IN $($Record.RecordType) $value`n"
}

function ConvertTo-AnsibleWindowsDnsRecordInfo {
    <#
    .SYNOPSIS
    Convert DNS resource record objects to stable information-module results.
    .PARAMETER Record
    The provider resource record.
    #>
    param($Record)

    $names = @{
        IPv4Address = 'ipv4_address'; IPv6Address = 'ipv6_address'; HostNameAlias = 'host_name_alias'
        DhcId = 'dhc_id'; NameServer = 'name_server'; PtrDomainName = 'ptr_domain_name'; DomainName = 'domain_name'
        DescriptiveText = 'descriptive_text'; Port = 'port'; Priority = 'priority'; Weight = 'weight'
        MailExchange = 'mail_exchange'; Preference = 'preference'
    }
    $data = @{}
    $properties = $Record.RecordData.PSObject.Properties
    if ($Record.RecordData.PSObject.Properties['CimInstanceProperties']) {
        $properties = $Record.RecordData.CimInstanceProperties
    }
    foreach ($property in $properties) {
        $key = $names[$property.Name]
        if (-not $key) { $key = $property.Name.ToLowerInvariant() }
        $data[$key] = ConvertTo-AnsibleWindowsDnsValue -Value $property.Value
    }
    $type = $Record.RecordType.ToString().ToUpperInvariant()
    $values = @()
    $value = Get-AnsibleWindowsDnsRecordValue -Record $Record
    if ($null -ne $value) { $values = @($value) }
    @{
        name = $Record.HostName
        type = $type
        ttl = [long]$Record.TimeToLive.TotalSeconds
        aging = $null -ne $Record.Timestamp
        timestamp = ConvertTo-AnsibleWindowsDnsValue -Value $Record.Timestamp
        record_values = $values
        data = $data
    }
}

Export-ModuleMember -Function ConvertTo-AnsibleWindowsDnsRecordName, Get-AnsibleWindowsDnsRecord, `
    ConvertTo-AnsibleWindowsDnsRecordValue, ConvertTo-AnsibleWindowsDnsRecordInfo, `
    Get-AnsibleWindowsDnsRecordDataPropertyName, Get-AnsibleWindowsDnsRecordValue, Format-AnsibleWindowsDnsRecord
