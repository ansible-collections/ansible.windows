# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# Run in a disposable child process. These mocks must also be visible to imported module utilities.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '',
    Justification = 'Isolated command mocks share an in-memory DNS server and never contact a real server.')]
param([string]$CollectionPath)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
Add-Type @'
using System;
using System.Collections;
using System.Management.Automation;
namespace Ansible.Basic {
    public class AnsibleModule {
        public static Hashtable Input;
        public static Hashtable Output;
        public static bool Check;
        public Hashtable Params;
        public Hashtable Result = new Hashtable();
        public Hashtable Diff = new Hashtable();
        public bool CheckMode;
        public static AnsibleModule Create(object args, object spec) {
            var module = new AnsibleModule();
            module.Params = (Hashtable)Input.Clone();
            module.CheckMode = Check;
            module.Result["changed"] = false;
            return module;
        }
        public void FailJson(string message) { throw new Exception(message); }
        public void FailJson(string message, object error) { throw new Exception(message + ": " + error); }
        public void ExitJson() {
            Output = (Hashtable)Result.Clone();
            Output["diff"] = Diff.Clone();
        }
    }
}
public class AuditDnsRecord {
    public string HostName;
    public string RecordType;
    public TimeSpan TimeToLive;
    public object Timestamp;
    public PSObject RecordData;
    public AuditDnsRecord(object originalObject) {
        var original = PSObject.AsPSObject(originalObject);
        HostName = LanguagePrimitives.ConvertTo<string>(original.Properties["HostName"].Value);
        RecordType = LanguagePrimitives.ConvertTo<string>(original.Properties["RecordType"].Value);
        TimeToLive = LanguagePrimitives.ConvertTo<TimeSpan>(original.Properties["TimeToLive"].Value);
        Timestamp = original.Properties["Timestamp"].Value;
        RecordData = new PSObject();
        foreach (var property in PSObject.AsPSObject(original.Properties["RecordData"].Value).Properties) {
            RecordData.Properties.Add(new PSNoteProperty(property.Name, property.Value));
        }
    }
}
'@

if (Test-Path -LiteralPath (Join-Path $CollectionPath plugins/module_utils/Dns.psm1)) {
    Import-Module (Join-Path $CollectionPath plugins/module_utils/Dns.psm1) -Force
}
$global:AuditDns = @{}
$script:Passed = 0
$script:Failures = [Collections.Generic.List[string]]::new()

function Reset-AuditDnsState {
    $global:AuditDns.Clear()
    $global:AuditDns.Records = @{}
    $global:AuditDns.Calls = [Collections.Generic.List[object]]::new()
    $global:AuditDns.Failure = ''
    $global:AuditDns.ErrorId = 'WIN32 5'
    $global:AuditDns.NoWrite = $false
    $global:AuditDns.DomainRole = 5
}
function Assert-AuditCondition([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Invoke-AuditDnsCall([string]$Operation, [string]$Server, [string]$Zone, [string]$Scope) {
    $global:AuditDns.Calls.Add(@{ operation = $Operation; server = $Server; zone = $Zone; scope = $Scope })
    if ($global:AuditDns.Failure -eq $Operation) {
        Write-Error 'simulated DNS access denied' -ErrorId $global:AuditDns.ErrorId -Category PermissionDenied
    }
}
function Get-AuditDnsKey([string]$Server, [string]$Zone, [string]$Scope, [string]$Name, [string]$Type) {
    "$Server|$Zone|$Scope|$Name|$Type"
}
function global:Get-DnsServerResourceRecord {
    [CmdletBinding()]
    param($ZoneName, $Name, $RRType, [switch]$Node, $ComputerName = 'localhost', $ZoneScope = '')
    Invoke-AuditDnsCall -Operation get -Server $ComputerName -Zone $ZoneName -Scope $ZoneScope
    $records = @(foreach ($key in $global:AuditDns.Records.Keys) {
            $parts = $key.Split('|')
            if ($parts[0] -eq $ComputerName -and $parts[1] -eq $ZoneName -and $parts[2] -eq $ZoneScope -and
                (-not $PSBoundParameters.ContainsKey('Name') -or $parts[3] -eq $Name) -and
                (-not $PSBoundParameters.ContainsKey('RRType') -or $parts[4] -eq $RRType)) {
                $global:AuditDns.Records[$key]
            }
        })
    if (-not $records.Count -and $PSBoundParameters.ContainsKey('Name')) {
        Write-Error 'DNS name does not exist' -ErrorId 'WIN32 9714' -Category ObjectNotFound
    }
    # Return records in descending order so a hash table's incidental iteration order cannot hide missing info sorting.
    $records | Sort-Object -Property HostName, RecordType, @{ Expression = { $_.RecordData | ConvertTo-Json -Compress } } -Descending
}
function global:Add-DnsServerResourceRecord {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param($ZoneName, $Name, $ComputerName = 'localhost', $ZoneScope = '', [TimeSpan]$TimeToLive = '01:00:00',
        [switch]$A, [switch]$AAAA, [switch]$CNAME, [switch]$NS, [switch]$PTR, [switch]$SRV, [switch]$TXT, [switch]$DHCID,
        $IPv4Address, $IPv6Address, $HostNameAlias, $NameServer, $PtrDomainName, $DomainName, $DescriptiveText, $DhcpIdentifier,
        [UInt16]$Weight, [UInt16]$Priority, [UInt16]$Port, [switch]$AgeRecord, [switch]$AllowUpdateAny)
    Invoke-AuditDnsCall -Operation add -Server $ComputerName -Zone $ZoneName -Scope $ZoneScope
    if ($global:AuditDns.NoWrite -or -not $PSCmdlet.ShouldProcess($ZoneName, $MyInvocation.MyCommand.Name)) { return }
    $properties = @{
        A = 'IPv4Address'; AAAA = 'IPv6Address'; CNAME = 'HostNameAlias'; NS = 'NameServer'; PTR = 'PtrDomainName'
        SRV = 'DomainName'; TXT = 'DescriptiveText'; DHCID = 'DhcpIdentifier'
    }
    $type = @($properties.Keys | Where-Object { $PSBoundParameters.ContainsKey($_) })[0]
    $property = $properties[$type]
    $value = $PSBoundParameters[$property]
    if ($type -in 'A', 'AAAA') { $value = [Net.IPAddress]::Parse($value) }
    if ($type -eq 'DHCID') { $property = 'DhcId' }
    $data = @{ $property = $value }
    if ($type -eq 'SRV') { $data.Weight = $Weight; $data.Priority = $Priority; $data.Port = $Port }
    $record = [pscustomobject]@{
        HostName = $Name
        RecordType = $type
        TimeToLive = $TimeToLive
        Timestamp = $(if ($AgeRecord) { [DateTime]::UtcNow } else { $null })
        RecordData = [pscustomobject]$data
        AllowUpdateAny = $AllowUpdateAny.IsPresent
    }
    $key = Get-AuditDnsKey -Server $ComputerName -Zone $ZoneName -Scope $ZoneScope -Name $Name -Type $type
    $global:AuditDns.Records[$key] = @($global:AuditDns.Records[$key]) + @($record) | Where-Object { $null -ne $_ }
}
function global:Remove-DnsServerResourceRecord {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param([Parameter(ValueFromPipeline = $true)]$InputObject, $ZoneName, $ComputerName = 'localhost', $ZoneScope = '',
        [switch]$Force)
    process {
        Invoke-AuditDnsCall -Operation remove -Server $ComputerName -Zone $ZoneName -Scope $ZoneScope
        if ($global:AuditDns.NoWrite -or -not $PSCmdlet.ShouldProcess($ZoneName, $MyInvocation.MyCommand.Name)) { return }
        $key = Get-AuditDnsKey -Server $ComputerName -Zone $ZoneName -Scope $ZoneScope `
            -Name $InputObject.HostName -Type $InputObject.RecordType
        $global:AuditDns.Records[$key] = @($global:AuditDns.Records[$key] | Where-Object { $_ -ne $InputObject })
    }
}
function global:Set-DnsServerResourceRecord {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param($OldInputObject, $NewInputObject, $ZoneName, $ComputerName = 'localhost', $ZoneScope = '')
    Invoke-AuditDnsCall -Operation set -Server $ComputerName -Zone $ZoneName -Scope $ZoneScope
    if ($global:AuditDns.NoWrite -or -not $PSCmdlet.ShouldProcess($ZoneName, $MyInvocation.MyCommand.Name)) { return }
    $key = Get-AuditDnsKey -Server $ComputerName -Zone $ZoneName -Scope $ZoneScope `
        -Name $OldInputObject.HostName -Type $OldInputObject.RecordType
    $global:AuditDns.Records[$key] = @($global:AuditDns.Records[$key] | Where-Object { $_ -ne $OldInputObject }) + @($NewInputObject)
}
function Invoke-AuditDnsModule([hashtable]$Overrides = @{}, [switch]$Check) {
    $parameters = @{
        name = 'host'; zone = 'example.test'; type = 'A'; value = @('192.0.2.1'); ttl = 3600; aging = $false
        allow_update_any = $false; state = 'present'; port = $null; weight = $null; priority = $null
        zone_scope = 'isolated'; computer_name = 'dns.example.test'
    }
    foreach ($key in $Overrides.Keys) { $parameters[$key] = $Overrides[$key] }
    [Ansible.Basic.AnsibleModule]::Input = $parameters
    [Ansible.Basic.AnsibleModule]::Check = $Check.IsPresent
    [Ansible.Basic.AnsibleModule]::Output = $null
    # Substitute only the native CIM copy constructor: CIM instances cannot be constructed on this controller.
    # Native integration exercises the original constructor; all control flow here is the production source.
    $source = Get-Content -LiteralPath (Join-Path $CollectionPath plugins/modules/win_dns_record.ps1) -Raw
    & ([scriptblock]::Create($source.Replace('[CimInstance]::new', '[AuditDnsRecord]::new')))
    [Ansible.Basic.AnsibleModule]::Output
}
function Invoke-AuditDnsInfo([hashtable]$Overrides = @{}, [switch]$Check) {
    $parameters = @{ zone = 'example.test'; name = $null; type = $null; zone_scope = 'isolated'; computer_name = 'dns.example.test' }
    foreach ($key in $Overrides.Keys) { $parameters[$key] = $Overrides[$key] }
    [Ansible.Basic.AnsibleModule]::Input = $parameters
    [Ansible.Basic.AnsibleModule]::Check = $Check.IsPresent
    [Ansible.Basic.AnsibleModule]::Output = $null
    & (Join-Path $CollectionPath plugins/modules/win_dns_record_info.ps1)
    [Ansible.Basic.AnsibleModule]::Output
}
function Test-AuditCase([string]$CaseName, [scriptblock]$Body) {
    Reset-AuditDnsState
    try {
        & $Body
        $script:Passed++
        Write-Output "PASS $CaseName"
    }
    catch {
        $script:Failures.Add("${CaseName}: $($_.Exception.Message)")
        Write-Output "FAIL ${CaseName}: $($_.Exception.Message)"
    }
}

Test-AuditCase 'remote create, repeat, update, delete and repeat delete' {
    $r = Invoke-AuditDnsModule
    Assert-AuditCondition $r.changed 'create did not change'
    $r = Invoke-AuditDnsModule
    Assert-AuditCondition (-not $r.changed) 'repeat create changed'
    $r = Invoke-AuditDnsModule @{ value = @('192.0.2.2') }
    Assert-AuditCondition $r.changed 'update did not change'
    $r = Invoke-AuditDnsModule @{ state = 'absent'; value = @() }
    Assert-AuditCondition $r.changed 'delete did not change'
    $r = Invoke-AuditDnsModule @{ state = 'absent'; value = @() }
    Assert-AuditCondition (-not $r.changed) 'repeat delete changed'
    $wrongCalls = @($global:AuditDns.Calls | Where-Object { $_.server -ne 'dns.example.test' -or $_.scope -ne 'isolated' })
    Assert-AuditCondition ($wrongCalls.Count -eq 0) 'wrong server or scope'
}
foreach ($name in 'host.example.test', 'HOST.EXAMPLE.TEST.') {
    Test-AuditCase "zone-qualified owner $name" {
        $r = Invoke-AuditDnsModule @{ name = $name }
        $key = Get-AuditDnsKey -Server 'dns.example.test' -Zone 'example.test' -Scope 'isolated' -Name 'host' -Type 'A'
        Assert-AuditCondition ($r.changed -and $global:AuditDns.Records.ContainsKey($key)) 'record was created under the wrong owner name'
        $r = Invoke-AuditDnsModule @{ name = 'host' }
        Assert-AuditCondition (-not $r.changed) 'relative and absolute owners are not equivalent'
    }
}
Test-AuditCase 'SRV creation retains a non-default TTL' {
    $r = Invoke-AuditDnsModule @{ type = 'SRV'; value = @('target.example.test'); port = 443; weight = 2; priority = 3; ttl = 7200 }
    $key = Get-AuditDnsKey -Server 'dns.example.test' -Zone 'example.test' -Scope 'isolated' -Name 'host' -Type 'SRV'
    Assert-AuditCondition ($global:AuditDns.Records[$key][0].TimeToLive.TotalSeconds -eq 7200) 'SRV creation omitted TTL'
    $r = Invoke-AuditDnsModule @{ type = 'SRV'; value = @('target.example.test'); port = 443; weight = 2; priority = 3; ttl = 7200 }
    Assert-AuditCondition (-not $r.changed) 'SRV repeat changed'
}
Test-AuditCase 'provider read denial cannot become successful absence' {
    $global:AuditDns.Failure = 'get'
    $failed = $false
    try { $null = Invoke-AuditDnsModule @{ state = 'absent'; value = @() } }
    catch { $failed = $_.Exception.Message -like '*simulated DNS access denied*' }
    Assert-AuditCondition $failed 'query denial was reported as absence'
    Assert-AuditCondition (@($global:AuditDns.Calls | Where-Object { $_.operation -ne 'get' }).Count -eq 0) 'mutated after a query denial'
}
Test-AuditCase 'successful command without a write cannot report successful creation' {
    $global:AuditDns.NoWrite = $true
    $failed = $false
    try { $null = Invoke-AuditDnsModule }
    catch { $failed = $_.Exception.Message -like '*requested DNS records*' }
    Assert-AuditCondition $failed 'missing record was reported as a successful change'
}
Test-AuditCase 'check-mode create does not write or demand a postcondition' {
    $r = Invoke-AuditDnsModule -Check
    Assert-AuditCondition ($r.changed -and $global:AuditDns.Records.Count -eq 0) 'check mode wrote a record'
}

foreach ($kind in 'A', 'AAAA', 'CNAME', 'NS', 'PTR', 'SRV', 'TXT', 'DHCID') {
    Test-AuditCase "$kind remote record and typed information" {
        $parameters = @{ type = $kind; value = @('target.example.test') }
        switch ($kind) {
            A { $parameters.value = @('192.0.2.1') }
            AAAA { $parameters.value = @('2001:db8::1') }
            SRV { $parameters.port = 443; $parameters.priority = 3; $parameters.weight = 2 }
            TXT { $parameters.value = @('Literal TXT text') }
            DHCID { $parameters.value = @('AQEB') }
        }
        $r = Invoke-AuditDnsModule $parameters
        Assert-AuditCondition $r.changed 'create did not change'
        $info = Invoke-AuditDnsInfo @{ name = 'host'; type = $kind }
        Assert-AuditCondition ($info.exists -and $info.records.Count -eq 1 -and -not $info.changed) 'information cardinality'
        Assert-AuditCondition ($info.records[0].type -eq $kind -and $info.records[0].ttl -eq 3600) 'information type or TTL'
        Assert-AuditCondition ($null -eq $info.records[0].timestamp -and -not $info.records[0].aging) 'static timestamp'
        $r = Invoke-AuditDnsModule $parameters
        Assert-AuditCondition (-not $r.changed) 'repeat changed'
        $r = Invoke-AuditDnsModule @{ type = $kind; state = 'absent'; value = @(); port = 443; priority = 3; weight = 2 }
        Assert-AuditCondition $r.changed 'delete did not change'
        $info = Invoke-AuditDnsInfo @{ name = 'host'; type = $kind }
        Assert-AuditCondition (-not $info.exists -and $info.records.Count -eq 0 -and -not $info.changed) 'missing information'
    }
}
Test-AuditCase 'expanded IPv6 address uses canonical comparisons' {
    $r = Invoke-AuditDnsModule @{ type = 'AAAA'; value = @('2001:0db8:0000:0000:0000:0000:0000:0001') }
    Assert-AuditCondition $r.changed 'IPv6 creation'
    $r = Invoke-AuditDnsModule @{ type = 'AAAA'; value = @('2001:db8::1') }
    Assert-AuditCondition (-not $r.changed) 'equivalent address changed'
    $info = Invoke-AuditDnsInfo @{ type = 'AAAA' }
    Assert-AuditCondition ($info.records[0].data.ipv6_address -eq '2001:db8::1') 'address was not serialized'
}
Test-AuditCase 'TXT comparisons preserve case and join provider segments' {
    $null = Invoke-AuditDnsModule @{ type = 'TXT'; value = @('Upper') }
    $r = Invoke-AuditDnsModule @{ type = 'TXT'; value = @('upper') }
    Assert-AuditCondition $r.changed 'TXT case change ignored'
    $info = Invoke-AuditDnsInfo @{ type = 'TXT' }
    Assert-AuditCondition ($info.records[0].record_values[0] -ceq 'upper') 'wrong literal text'
    $record = @($global:AuditDns.Records.Values)[0][0]
    $record.RecordData.DescriptiveText = @('up', 'per')
    $r = Invoke-AuditDnsModule @{ type = 'TXT'; value = @('upper') }
    $info = Invoke-AuditDnsInfo @{ type = 'TXT' }
    Assert-AuditCondition (-not $r.changed -and $info.records[0].record_values[0] -ceq 'upper' -and
        $r.diff.after -like '*IN TXT upper*') 'segmented TXT value did not converge'
}
foreach ($literal in 'Count', 'Keys', 'Values') {
    Test-AuditCase "TXT value $literal cannot shadow dictionary members" {
        $parameters = @{ type = 'TXT'; value = @($literal) }
        $r = Invoke-AuditDnsModule $parameters -Check
        $info = Invoke-AuditDnsInfo @{ type = 'TXT' }
        Assert-AuditCondition ($r.changed -and -not $info.exists -and
            $r.diff.after.Contains("IN TXT $literal`n")) 'check-mode creation lost the literal or wrote a record'
        $r = Invoke-AuditDnsModule $parameters
        $info = Invoke-AuditDnsInfo @{ type = 'TXT' }
        Assert-AuditCondition ($r.changed -and $info.records.Count -eq 1 -and
            $info.records[0].record_values[0] -ceq $literal) 'creation lost the literal TXT value'
        $r = Invoke-AuditDnsModule $parameters
        Assert-AuditCondition (-not $r.changed) 'repeat creation changed'
        $r = Invoke-AuditDnsModule $parameters -Check
        Assert-AuditCondition (-not $r.changed) 'check-mode repeat creation changed'

        $parameters.value = @($literal.ToLowerInvariant())
        $r = Invoke-AuditDnsModule $parameters -Check
        $info = Invoke-AuditDnsInfo @{ type = 'TXT' }
        Assert-AuditCondition ($r.changed -and $info.records[0].record_values[0] -ceq $literal) 'check-mode update wrote a record'
        $r = Invoke-AuditDnsModule $parameters
        $info = Invoke-AuditDnsInfo @{ type = 'TXT' }
        Assert-AuditCondition ($r.changed -and $info.records.Count -eq 1 -and
            $info.records[0].record_values[0] -ceq $parameters.value[0]) 'case-sensitive update lost the TXT value'
        $r = Invoke-AuditDnsModule $parameters
        Assert-AuditCondition (-not $r.changed) 'repeat update changed'

        $parameters.state = 'absent'
        $parameters.value = @()
        $r = Invoke-AuditDnsModule $parameters -Check
        $info = Invoke-AuditDnsInfo @{ type = 'TXT' }
        Assert-AuditCondition ($r.changed -and $info.exists) 'check-mode delete removed the record'
        $r = Invoke-AuditDnsModule $parameters
        $info = Invoke-AuditDnsInfo @{ type = 'TXT' }
        Assert-AuditCondition ($r.changed -and -not $info.exists) 'delete retained the record'
        $r = Invoke-AuditDnsModule $parameters
        Assert-AuditCondition (-not $r.changed) 'repeat delete changed'
    }
}
Test-AuditCase 'empty read-only inventory and check mode' {
    $info = Invoke-AuditDnsInfo -Check
    Assert-AuditCondition (-not $info.changed -and -not $info.exists -and $info.records.Count -eq 0) 'empty inventory'
    Assert-AuditCondition (@($global:AuditDns.Calls | Where-Object { $_.operation -ne 'get' }).Count -eq 0) 'info mutated'
}
Test-AuditCase 'information lists sorts and filters independently' {
    $null = Invoke-AuditDnsModule @{ name = 'z'; value = @('192.0.2.2') }
    $null = Invoke-AuditDnsModule @{ name = 'a' }
    $null = Invoke-AuditDnsModule @{ name = 'a'; type = 'TXT'; value = @('text') }
    $info = Invoke-AuditDnsInfo
    Assert-AuditCondition (($info.records.name -join ',') -eq 'a,a,z') 'unstable owner ordering'
    $info = Invoke-AuditDnsInfo @{ name = 'a.example.test.' }
    Assert-AuditCondition ($info.records.Count -eq 2) 'owner lookup lost a type'
    $info = Invoke-AuditDnsInfo @{ type = 'TXT' }
    Assert-AuditCondition ($info.records.Count -eq 1 -and $info.records[0].record_values[0] -eq 'text') 'type filter'
    $info = Invoke-AuditDnsInfo @{ type = 'AAAA' }
    Assert-AuditCondition (-not $info.exists -and $info.records.Count -eq 0) 'missing type'
}
Test-AuditCase 'information orders owners types and values independently of provider order' {
    $null = Invoke-AuditDnsModule @{ name = 'z'; value = @('192.0.2.3') }
    $null = Invoke-AuditDnsModule @{ name = 'a'; type = 'TXT'; value = @('text') }
    $null = Invoke-AuditDnsModule @{ name = 'a'; value = @('192.0.2.2', '192.0.2.1') }
    $writesBefore = @($global:AuditDns.Calls | Where-Object { $_.operation -ne 'get' }).Count
    $info = Invoke-AuditDnsInfo
    $order = @($info.records | ForEach-Object { '{0}|{1}|{2}' -f $_.name, $_.type, ($_.record_values -join ',') })
    $expected = @('a|A|192.0.2.1', 'a|A|192.0.2.2', 'a|TXT|text', 'z|A|192.0.2.3')
    Assert-AuditCondition (($order -join "`n") -ceq ($expected -join "`n")) "wrong info order: $($order -join '; ')"
    $repeat = Invoke-AuditDnsInfo -Check
    $repeatOrder = @($repeat.records | ForEach-Object { '{0}|{1}|{2}' -f $_.name, $_.type, ($_.record_values -join ',') })
    Assert-AuditCondition (($repeatOrder -join "`n") -ceq ($expected -join "`n")) 'check-mode ordering differs'
    Assert-AuditCondition (@($global:AuditDns.Calls | Where-Object { $_.operation -ne 'get' }).Count -eq $writesBefore) 'info mutated records'
}
foreach ($owner in '@', 'example.test', 'example.test.') {
    Test-AuditCase "zone apex owner $owner" {
        $null = Invoke-AuditDnsModule @{ name = $owner }
        $info = Invoke-AuditDnsInfo @{ name = '@' }
        Assert-AuditCondition ($info.records.Count -eq 1 -and $info.records[0].name -eq '@') 'wrong apex'
    }
}
foreach ($operation in 'add', 'set', 'remove') {
    Test-AuditCase "remote $operation failure is visible" {
        if ($operation -ne 'add') { $null = Invoke-AuditDnsModule }
        $global:AuditDns.Failure = $operation
        $parameters = @{}
        if ($operation -eq 'set') { $parameters.ttl = 7200 }
        if ($operation -eq 'remove') { $parameters.state = 'absent'; $parameters.value = @() }
        $failed = $false
        try { $null = Invoke-AuditDnsModule $parameters }
        catch {
            $failed = $_.Exception.Message -like '*simulated DNS access denied*'
            if (-not $failed) { throw }
        }
        Assert-AuditCondition $failed 'mutation error was hidden'
    }
}
foreach ($operation in 'update', 'delete') {
    Test-AuditCase "$operation check mode leaves records unchanged" {
        $null = Invoke-AuditDnsModule
        $before = Invoke-AuditDnsInfo
        $parameters = @{ value = @('192.0.2.2') }
        if ($operation -eq 'delete') { $parameters.state = 'absent'; $parameters.value = @() }
        $r = Invoke-AuditDnsModule $parameters -Check
        $after = Invoke-AuditDnsInfo
        Assert-AuditCondition ($r.changed -and ($before.records | ConvertTo-Json -Depth 8) -eq
            ($after.records | ConvertTo-Json -Depth 8)) 'check mode mutated records'
    }
}
Test-AuditCase 'no-op deletion fails verification' {
    $null = Invoke-AuditDnsModule
    $global:AuditDns.NoWrite = $true
    $failed = $false
    try { $null = Invoke-AuditDnsModule @{ state = 'absent'; value = @() } }
    catch { $failed = $_.Exception.Message -like '*requested DNS records*' }
    Assert-AuditCondition $failed 'undeleted record reported success'
}
foreach ($query in @(@{ name = '' }, @{ zone = ' ' }, @{ name = 'outside.invalid.' }, @{ type = '' })) {
    Test-AuditCase "invalid information query $($query.Keys)" {
        $failed = $false
        try { $null = Invoke-AuditDnsInfo $query } catch { $failed = $true }
        Assert-AuditCondition ($failed -and $global:AuditDns.Calls.Count -eq 0) 'invalid query reached provider'
    }
}
foreach ($code in 'WIN32 5', 'WIN32 9601', 'WIN32 1722') {
    Test-AuditCase "information propagates provider error $code" {
        $global:AuditDns.ErrorId = $code
        $global:AuditDns.Failure = 'get'
        $failed = $false
        try { $null = Invoke-AuditDnsInfo @{ name = 'host' } } catch { $failed = $true }
        Assert-AuditCondition $failed 'provider failure became empty success'
    }
}
Test-AuditCase 'information check mode equals a normal read and performs no mutations' {
    $null = Invoke-AuditDnsModule
    $global:AuditDns.Calls.Clear()
    $normal = Invoke-AuditDnsInfo @{ name = 'host' }
    $check = Invoke-AuditDnsInfo @{ name = 'host.example.test.' } -Check
    Assert-AuditCondition (($normal.records | ConvertTo-Json -Depth 8) -eq ($check.records | ConvertTo-Json -Depth 8)) 'check-mode data'
    Assert-AuditCondition (-not $check.changed -and -not $check.ContainsKey('ansible_facts')) 'info interface'
    Assert-AuditCondition (@($global:AuditDns.Calls | Where-Object { $_.operation -ne 'get' }).Count -eq 0) 'info mutated'
}

foreach ($kind in 'A', 'NS', 'TXT') {
    Test-AuditCase "$kind multiple values converge without losing or duplicating records" {
        $parameters = @{ type = $kind; value = @('first.example.test', 'second.example.test') }
        if ($kind -eq 'A') { $parameters.value = @('192.0.2.1', '192.0.2.2') }
        if ($kind -eq 'TXT') { $parameters.value = @('Upper', 'upper') }
        $null = Invoke-AuditDnsModule $parameters
        $info = Invoke-AuditDnsInfo
        Assert-AuditCondition ($info.records.Count -eq 2) 'multiple values lost'
        $r = Invoke-AuditDnsModule $parameters
        Assert-AuditCondition (-not $r.changed) 'multiple-value repeat changed'
        $parameters.value = @($parameters.value[1])
        $r = Invoke-AuditDnsModule $parameters
        $info = Invoke-AuditDnsInfo
        Assert-AuditCondition ($r.changed -and $info.records.Count -eq 1) 'unwanted value remained'
    }
}
Test-AuditCase 'aging transitions expose serializable timestamps and converge' {
    $null = Invoke-AuditDnsModule @{ aging = $true }
    $info = Invoke-AuditDnsInfo
    Assert-AuditCondition ($info.records[0].aging -and $info.records[0].timestamp -is [string]) 'dynamic timestamp'
    $r = Invoke-AuditDnsModule @{ aging = $true }
    Assert-AuditCondition (-not $r.changed) 'aging repeat changed'
    $r = Invoke-AuditDnsModule
    $info = Invoke-AuditDnsInfo
    Assert-AuditCondition ($r.changed -and -not $info.records[0].aging -and $null -eq $info.records[0].timestamp) 'static timestamp'
}
Test-AuditCase 'information preserves provider fields for types the action module does not manage' {
    $key = Get-AuditDnsKey -Server 'dns.example.test' -Zone 'example.test' -Scope 'isolated' -Name '@' -Type 'SOA'
    $global:AuditDns.Records[$key] = @([pscustomobject]@{
            HostName = '@'; RecordType = 'SOA'; TimeToLive = [TimeSpan]::FromHours(1); Timestamp = $null
            RecordData = [pscustomobject]@{ SerialNumber = [uint32]7; PrimaryServer = 'dns.example.test.' }
        })
    $info = Invoke-AuditDnsInfo
    Assert-AuditCondition ($info.records[0].type -eq 'SOA' -and $info.records[0].record_values.Count -eq 0 -and
        $info.records[0].data.serialnumber -eq 7 -and $info.records[0].data.primaryserver -eq 'dns.example.test.') 'SOA fields'
}
Test-AuditCase 'duplicate requested values are written once' {
    $r = Invoke-AuditDnsModule @{ value = @('192.0.2.1', '192.0.2.1') }
    $info = Invoke-AuditDnsInfo
    Assert-AuditCondition ($r.changed -and $info.records.Count -eq 1) 'duplicate values created duplicate records'
    $r = Invoke-AuditDnsModule @{ value = @('192.0.2.1', '192.0.2.1') }
    Assert-AuditCondition (-not $r.changed) 'duplicate values caused a repeat change'
}
Test-AuditCase 'TTL update copies the original record and reports correct diff' {
    $null = Invoke-AuditDnsModule
    $r = Invoke-AuditDnsModule @{ ttl = 7200 }
    $info = Invoke-AuditDnsInfo
    Assert-AuditCondition ($r.changed -and $info.records[0].ttl -eq 7200) 'TTL update failed'
    Assert-AuditCondition ($r.diff.before -like '*3600 IN A*' -and $r.diff.after -like '*7200 IN A*') 'original record was mutated'
    $r = Invoke-AuditDnsModule @{ ttl = 7200 }
    Assert-AuditCondition (-not $r.changed) 'TTL repeat changed'
}
Test-AuditCase 'SRV updates retain typed port priority weight and TTL' {
    $parameters = @{ type = 'SRV'; value = @('target.example.test'); port = 443; priority = 3; weight = 2 }
    $null = Invoke-AuditDnsModule $parameters
    $parameters.port = 8443; $parameters.priority = 5; $parameters.weight = 4; $parameters.ttl = 7200
    $r = Invoke-AuditDnsModule $parameters
    $info = Invoke-AuditDnsInfo
    $record = $info.records[0]
    Assert-AuditCondition ($r.changed -and $record.data.port -eq 8443 -and $record.data.priority -eq 5 -and
        $record.data.weight -eq 4 -and $record.ttl -eq 7200) 'SRV fields were not updated'
    $r = Invoke-AuditDnsModule $parameters
    Assert-AuditCondition (-not $r.changed) 'SRV update repeat changed'
}

foreach ($field in 'port', 'priority', 'weight') {
    foreach ($invalid in -1, 65536) {
        Test-AuditCase "invalid SRV $field=$invalid preserves existing state before any provider call" {
            $parameters = @{ type = 'SRV'; value = @('old.example.test'); port = 443; priority = 3; weight = 2 }
            $null = Invoke-AuditDnsModule $parameters
            $before = (Invoke-AuditDnsInfo).records | ConvertTo-Json -Depth 8
            $parameters[$field] = $invalid
            foreach ($state in 'present', 'absent') {
                $parameters.state = $state
                $parameters.value = @()
                if ($state -eq 'present') { $parameters.value = @('new.example.test') }
                foreach ($check in $true, $false) {
                    $global:AuditDns.Calls.Clear()
                    $failed = $false
                    try { $null = Invoke-AuditDnsModule $parameters -Check:$check }
                    catch { $failed = $_.Exception.Message -like "*Parameter '$field' must be between 0 and 65535*" }
                    Assert-AuditCondition ($failed -and $global:AuditDns.Calls.Count -eq 0) 'invalid input reached the provider'
                    $after = (Invoke-AuditDnsInfo).records | ConvertTo-Json -Depth 8
                    Assert-AuditCondition ($before -eq $after) 'invalid input changed an existing record'
                }
            }
        }
    }
}
foreach ($boundary in 0, 65535) {
    Test-AuditCase "SRV fields accept the UInt16 boundary $boundary" {
        $parameters = @{ type = 'SRV'; value = @('target.example.test'); port = $boundary; priority = $boundary; weight = $boundary }
        $r = Invoke-AuditDnsModule $parameters
        $record = (Invoke-AuditDnsInfo).records[0]
        Assert-AuditCondition ($r.changed -and $record.data.port -eq $boundary -and
            $record.data.priority -eq $boundary -and $record.data.weight -eq $boundary) 'valid SRV boundary was rejected'
        $r = Invoke-AuditDnsModule $parameters
        Assert-AuditCondition (-not $r.changed) 'boundary repeat changed'
    }
}
foreach ($kind in 'A', 'SRV') {
    Test-AuditCase "$kind TTL-only no-op update fails verification and can recover" {
        $parameters = @{ type = $kind }
        if ($kind -eq 'SRV') {
            $parameters.value = @('target.example.test'); $parameters.port = 443; $parameters.priority = 3; $parameters.weight = 2
        }
        $null = Invoke-AuditDnsModule $parameters
        $parameters.ttl = 7200
        $global:AuditDns.NoWrite = $true
        $r = Invoke-AuditDnsModule $parameters -Check
        Assert-AuditCondition $r.changed 'TTL check mode did not predict a change'
        foreach ($attempt in 1..2) {
            $failed = $false
            try { $null = Invoke-AuditDnsModule $parameters }
            catch { $failed = $_.Exception.Message -like '*requested DNS records*' }
            Assert-AuditCondition $failed "TTL-only no-op update $attempt reported success"
            $record = (Invoke-AuditDnsInfo).records[0]
            Assert-AuditCondition ($record.ttl -eq 3600) 'provider unexpectedly wrote the TTL'
        }
        $global:AuditDns.NoWrite = $false
        $r = Invoke-AuditDnsModule $parameters
        Assert-AuditCondition ($r.changed -and (Invoke-AuditDnsInfo).records[0].ttl -eq 7200) 'TTL update did not recover'
        $r = Invoke-AuditDnsModule $parameters
        Assert-AuditCondition (-not $r.changed) 'TTL recovery repeat changed'
    }
}
Test-AuditCase 'SRV diffs include every field consistently across normal and check mode' {
    $parameters = @{ type = 'SRV'; value = @('target.example.test'); port = 443; priority = 3; weight = 2 }
    $expected = "[example.test/isolated] host 3600 IN SRV target.example.test. 443 2 3`n"
    $check = Invoke-AuditDnsModule $parameters -Check
    $r = Invoke-AuditDnsModule $parameters
    Assert-AuditCondition ($check.diff.after -eq $expected -and $r.diff.after -eq $expected -and
        $check.diff.before -eq '' -and $r.diff.before -eq '') 'SRV creation diff omitted fields'
    foreach ($field in 'port', 'priority', 'weight') {
        $before = $expected
        $parameters[$field]++
        $expected = "[example.test/isolated] host 3600 IN SRV target.example.test. $($parameters.port) $($parameters.weight) $($parameters.priority)`n"
        $check = Invoke-AuditDnsModule $parameters -Check
        $r = Invoke-AuditDnsModule $parameters
        Assert-AuditCondition ($check.diff.before -eq $before -and $r.diff.before -eq $before -and
            $check.diff.after -eq $expected -and $r.diff.after -eq $expected) "SRV $field update diff omitted the change"
        $repeat = Invoke-AuditDnsModule $parameters
        Assert-AuditCondition (-not $repeat.changed) "SRV $field repeat changed"
    }
    $parameters.state = 'absent'; $parameters.value = @()
    $check = Invoke-AuditDnsModule $parameters -Check
    $r = Invoke-AuditDnsModule $parameters
    Assert-AuditCondition ($check.diff.before -eq $expected -and $r.diff.before -eq $expected -and
        $check.diff.after -eq '' -and $r.diff.after -eq '') 'SRV deletion diff omitted fields'
}
Test-AuditCase 'allow_update_any controls creation without rewriting existing permissions' {
    foreach ($allow in $false, $true) {
        Reset-AuditDnsState
        $null = Invoke-AuditDnsModule @{ allow_update_any = $allow }
        $record = @($global:AuditDns.Records.Values)[0][0]
        Assert-AuditCondition ($record.AllowUpdateAny -eq $allow) 'creation permissions were not forwarded'
        $global:AuditDns.Calls.Clear()
        $check = Invoke-AuditDnsModule @{ allow_update_any = (-not $allow) } -Check
        $r = Invoke-AuditDnsModule @{ allow_update_any = (-not $allow) }
        Assert-AuditCondition (-not $check.changed -and -not $r.changed -and $record.AllowUpdateAny -eq $allow) 'existing permissions changed'
        Assert-AuditCondition (@($global:AuditDns.Calls | Where-Object { $_.operation -ne 'get' }).Count -eq 0) 'permission toggle invoked a mutation'
    }
}

# Exercise fixture safety against owned temporary files and a simulated zone list.
function global:Get-DnsServerZone {
    [CmdletBinding()]
    param([string]$ComputerName)
    $global:AuditDns.ZoneServer = $ComputerName
    if ($global:AuditDns.ContainsKey('ZoneReadFailure')) { throw 'simulated zone read denial' }
    foreach ($zone in $global:AuditDns.Zones) { [pscustomobject]@{ ZoneName = $zone } }
}
function global:Get-CimInstance {
    [CmdletBinding()]
    param($ClassName)
    if ($ClassName -ne 'Win32_ComputerSystem') { throw "Unexpected fixture query: $ClassName" }
    [pscustomobject]@{ DomainRole = $global:AuditDns.DomainRole }
}
$fixtureDirectory = $PSScriptRoot
function Invoke-AuditFixturePrecheck([hashtable]$Parameters) {
    $initialSystemRoot = $env:SystemRoot
    $initialComputerName = $env:COMPUTERNAME
    try {
        # The controller harness also runs on non-Windows hosts.
        if (-not $env:SystemRoot) { $env:SystemRoot = [IO.Path]::GetTempPath() }
        if (-not $env:COMPUTERNAME) { $env:COMPUTERNAME = [Environment]::MachineName }
        & (Join-Path $fixtureDirectory prechecks.ps1) @Parameters
    }
    finally {
        $env:SystemRoot = $initialSystemRoot
        $env:COMPUTERNAME = $initialComputerName
    }
}
foreach ($remote in $false, $true) {
    Test-AuditCase "execution-host preflight verifies DNS tools and server access remote=$remote" {
        $global:AuditDns.Zones = @()
        $Ansible = @{ Changed = $true; Result = @{} }
        $server = [Environment]::MachineName
        if ($remote) { $server += '-dns' }
        & (Join-Path $fixtureDirectory check_execution_host.ps1) -ComputerName $server -RequireRemoteHost $remote
        Assert-AuditCondition (-not $Ansible.Changed -and $Ansible.Result.remote -eq $remote -and
            $global:AuditDns.ZoneServer -eq $server) 'preflight did not query the selected server without mutation'
    }
}
Test-AuditCase 'execution-host preflight rejects an alias for the same machine' {
    $Ansible = @{ Changed = $true; Result = @{} }
    $failed = $false
    try {
        & (Join-Path $fixtureDirectory check_execution_host.ps1) -ComputerName ([Environment]::MachineName) -RequireRemoteHost $true
    }
    catch { $failed = $_.Exception.Message -like '*distinct Windows host*' }
    Assert-AuditCondition ($failed -and -not $Ansible.Changed -and -not $global:AuditDns.ContainsKey('ZoneServer')) 'same-host alias reached DNS'
}
Test-AuditCase 'execution-host preflight reports missing DNS tools before querying a server' {
    function Get-Command {
        [CmdletBinding()]
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '',
            Justification = 'This test-scoped command mock injects a missing dependency inside a disposable regression process.')]
        param($Name)
        throw "simulated missing DNS tools: $Name"
    }
    $Ansible = @{ Changed = $true; Result = @{} }
    $failed = $false
    $server = 'dns.example.test'
    try { & (Join-Path $fixtureDirectory check_execution_host.ps1) -ComputerName $server }
    catch { $failed = $_.Exception.Message -like '*requires the DnsServer PowerShell tools*' }
    Assert-AuditCondition ($failed -and -not $Ansible.Changed -and -not $global:AuditDns.ContainsKey('ZoneServer')) 'missing tools reached DNS'
}
Test-AuditCase 'execution-host preflight preserves remote authentication errors' {
    $global:AuditDns.ZoneReadFailure = $true
    $Ansible = @{ Changed = $true; Result = @{} }
    $failed = $false
    $server = 'dns.example.test'
    try { & (Join-Path $fixtureDirectory check_execution_host.ps1) -ComputerName $server -RequireRemoteHost $true }
    catch { $failed = $_.Exception.Message -like '*remote authentication*simulated zone read denial*' }
    Assert-AuditCondition ($failed -and -not $Ansible.Changed -and $global:AuditDns.ZoneServer -eq $server) 'authentication error was hidden'
}
Test-AuditCase 'fixture precheck rejects a domain controller before preparing resources' {
    $Ansible = @{ Changed = $true; Result = @{} }
    $failed = $false
    try { & (Join-Path $fixtureDirectory prechecks.ps1) }
    catch { $failed = $_.Exception.Message -like '*win_dns_record_allow_domain_controller=true*' }
    Assert-AuditCondition ($failed -and -not $Ansible.Changed -and $Ansible.Result.Count -eq 0) 'domain controller was accepted'
}
foreach ($role in 4, 5) {
    Test-AuditCase "fixture precheck rejects DNS feature management on an opted-in DC role=$role" {
        $global:AuditDns.DomainRole = $role
        $Ansible = @{ Changed = $true; Result = @{} }
        $failed = $false
        try { Invoke-AuditFixturePrecheck @{ AllowDomainController = $true } }
        catch { $failed = $_.Exception.Message -like '*win_dns_record_manage_dns_feature=false*' }
        Assert-AuditCondition ($failed -and -not $Ansible.Changed -and $Ansible.Result.Count -eq 0) 'DC feature management was accepted'
    }
    Test-AuditCase "fixture precheck permits an opted-in preconfigured test DC role=$role" {
        $global:AuditDns.DomainRole = $role
        $Ansible = @{ Changed = $true; Result = @{} }
        Invoke-AuditFixturePrecheck @{ AllowDomainController = $true; ManageDnsFeature = $false }
        Assert-AuditCondition (-not $Ansible.Changed -and $Ansible.Result.zone -match '^win-dns-[0-9a-f]{32}\.test$' -and
            $Ansible.Result.reverse_zone -like '*.198.in-addr.arpa' -and
            $global:AuditDns.Calls.Count -eq 0) 'DC precheck prepared invalid fixtures or queried DNS'
    }
}
Test-AuditCase 'fixture precheck permits a member server with default feature management' {
    $global:AuditDns.DomainRole = 3
    $Ansible = @{ Changed = $true; Result = @{} }
    Invoke-AuditFixturePrecheck @{}
    Assert-AuditCondition (-not $Ansible.Changed -and $Ansible.Result.zone -match '^win-dns-[0-9a-f]{32}\.test$') 'member server was rejected'
}
foreach ($guard in 'reserve_zones', 'verify_cleanup') {
    foreach ($residue in 'none', 'zone', 'file') {
        Test-AuditCase "$guard detects $residue fixture residue" {
            $Ansible = @{ Changed = $true }
            $global:AuditDns.Zones = @()
            if ($residue -eq 'zone') { $global:AuditDns.Zones = @('owned.test') }
            $directory = Join-Path ([IO.Path]::GetTempPath()) ([Guid]::NewGuid().ToString('N'))
            $null = [IO.Directory]::CreateDirectory($directory)
            try {
                if ($residue -eq 'file') { [IO.File]::WriteAllText((Join-Path $directory owned.test.dns), 'fixture') }
                $failed = $false
                try { & (Join-Path $fixtureDirectory "$guard.ps1") -ZoneNames @('owned.test') -DnsDirectory $directory }
                catch { $failed = $true }
                Assert-AuditCondition ($failed -eq ($residue -ne 'none') -and -not $Ansible.Changed) 'fixture guard result'
            }
            finally { [IO.Directory]::Delete($directory, $true) }
        }
    }
}

Write-Output "$script:Passed regression cases passed; $($script:Failures.Count) failed."
if ($script:Failures.Count) { throw ($script:Failures -join "`n") }
