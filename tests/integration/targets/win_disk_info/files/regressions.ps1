# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# Shared state must be visible to mocks called from the imported utility module.
# This script runs only in a disposable child process, never in the Ansible module host.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '',
    Justification = 'Cross-module command mocks share state within an isolated test process.')]
param([string]$CollectionPath)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2
Add-Type @'
using System;
using System.Collections;
namespace Ansible.Basic {
    public class AnsibleModule {
        public static Hashtable Input;
        public static Hashtable Output;
        public static bool Check;
        public Hashtable Params;
        public Hashtable Result = new Hashtable();
        public bool CheckMode;
        public static AnsibleModule Create(object args, object spec) {
            var m = new AnsibleModule();
            m.Params = (Hashtable)Input.Clone(); m.CheckMode = Check;
            return m;
        }
        public void FailJson(string message) { throw new Exception(message); }
        public void FailJson(string message, object error) { throw new Exception(message); }
        public void ExitJson() { Output = Result; }
    }
}
'@
# Run in a clean child process: the controller's real Ansible.Basic type must stay untouched.
$diskUtility = Import-Module (Join-Path $CollectionPath plugins/module_utils/Disk.psm1) -Force -PassThru
$global:AuditPropertyMaps = & $diskUtility { $script:AnsibleWindowsDiskPropertyMaps }
# Any unexpected mutator is a test failure, including in check mode.
foreach ($command in 'Initialize-Disk', 'Clear-Disk', 'Set-Disk', 'New-Partition', 'Remove-Partition',
    'Set-Partition', 'Resize-Partition', 'Format-Volume', 'Set-Volume', 'Mount-DiskImage', 'Dismount-DiskImage') {
    Set-Item -LiteralPath "Function:global:$command" -Value { throw "Unexpected storage mutation: $($MyInvocation.MyCommand.Name)" }
}
function New-AuditObject($kind, $values) {
    $props = [ordered]@{}
    foreach ($field in $global:AuditPropertyMaps[$kind].Values) { $props[$field[0]] = $null }
    foreach ($key in $values.Keys) { $props[$key] = $values[$key] }
    [pscustomobject]$props
}
function Reset-AuditData {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
        Justification = 'Global mock state is read by commands and assertions outside this reset function.')]
    param()

    $global:AuditFailure = ''
    $global:AuditCalls = [Collections.Generic.List[string]]::new()
    $global:AuditDisks = @(
        New-AuditObject disk @{ Number = 3; Size = 512; Path = 'disk3'; UniqueId = 'space'; SerialNumber = 'space-serial'; PartitionStyle = 'GPT' }
        New-AuditObject disk @{ Number = 1; Size = 256; Path = 'disk1'; UniqueId = 'id1'; SerialNumber = 'serial1'; PartitionStyle = 'MBR' }
        New-AuditObject disk @{
            Number = 0
            Size = 256
            Path = 'disk0'
            UniqueId = 'id0'
            SerialNumber = 'serial0'
            PartitionStyle = 'GPT'
            OperationalStatus = 'Online'
        }
        New-AuditObject disk @{ Number = 2; Size = 256; Path = 'disk2'; UniqueId = 'id2'; SerialNumber = 'serial2'; PartitionStyle = 'RAW' }
        New-AuditObject disk @{ Number = $null; Size = 256; Path = 'remote'; UniqueId = 'remote'; PartitionStyle = 'GPT' }
    )
    $global:AuditPhysical = @(
        New-AuditObject physical_disk @{
            DeviceId = 'different-id-0'
            UniqueId = 'id0'
            SerialNumber = 'serial0'
            Size = 256
            CanPool = $false
            OperationalStatus = @('OK')
            SupportedUsages = @('AutoSelect', 'Journal')
            CannotPoolReason = @('In Use')
        }
        New-AuditObject physical_disk @{
            DeviceId = 'different-id-1'
            UniqueId = 'id1'
            SerialNumber = 'serial1'
            Size = 256
            CanPool = $true
            OperationalStatus = @('OK')
            SupportedUsages = @()
        }
    )
    $global:AuditVirtual = @(New-AuditObject virtual_disk @{
            UniqueId = 'space'
            FriendlyName = 'Owned space'
            Size = 512
            ResiliencySettingName = 'Simple'
            OperationalStatus = @('OK')
            MockNumbers = @(3)
        })
    $global:AuditPartitions = @(
        New-AuditObject partition @{
            DiskNumber = 0
            PartitionNumber = 1
            Size = 100
            DriveLetter = [char]'C'
            AccessPaths = @('volume0')
            GptType = 'gpt-type'
            NoDefaultDriveLetter = $false
        }
        New-AuditObject partition @{ DiskNumber = 1; PartitionNumber = 1; Size = 100; DriveLetter = [char]0; AccessPaths = @(); MbrType = 7; IsActive = $false }
    )
    $global:AuditVolumes = @(New-AuditObject volume @{
            ObjectId = 'volume-id0'
            Path = 'volume0'
            FileSystem = 'NTFS'
            FileSystemLabel = ''
            Size = 100
            SizeRemaining = 80
            AllocationUnitSize = 4096
            HealthStatus = 'Healthy'
            DriveType = 'Fixed'
        })
    $global:AuditAssociatedVolumes = @($global:AuditVolumes)
    $global:AuditWin32 = @(
        New-AuditObject win32_disk_drive @{
            Index = 0
            SerialNumber = 'duplicate'
            Size = '256'
            Capabilities = @(3, 4)
            CapabilityDescriptions = @('Random Access', 'Supports Writing')
        }
        New-AuditObject win32_disk_drive @{ Index = 1; SerialNumber = 'duplicate'; Size = '256' }
    )
}
function Invoke-AuditQuery([string]$stage) {
    $global:AuditCalls.Add($stage)
    if ($global:AuditFailure -eq $stage) { throw "simulated provider failure: $stage" }
}
function global:Get-Disk {
    [CmdletBinding()]param([Parameter(ValueFromPipeline = $true)]$InputObject)
    process { Invoke-AuditQuery disks; $global:AuditDisks }
}
function global:Get-PhysicalDisk {
    [CmdletBinding()]param($VirtualDisk)
    if ($PSBoundParameters.ContainsKey('VirtualDisk')) { Invoke-AuditQuery physical_associations }
    else { Invoke-AuditQuery physical }
    $global:AuditPhysical
}
function global:Get-VirtualDisk { [CmdletBinding()]param() Invoke-AuditQuery virtual; $global:AuditVirtual }
function global:Get-Partition { [CmdletBinding()]param() Invoke-AuditQuery partitions; $global:AuditPartitions }
function global:Get-Volume { [CmdletBinding()]param() Invoke-AuditQuery volumes; $global:AuditVolumes }
function global:Get-CimInstance { [CmdletBinding()]param($ClassName) Invoke-AuditQuery win32; $global:AuditWin32 }
function global:Get-CimAssociatedInstance {
    [CmdletBinding()]param($InputObject, $Association, $ResultClassName)
    if ($Association -eq 'MSFT_VirtualDiskToDisk') {
        Invoke-AuditQuery virtual_associations
        $global:AuditDisks | Where-Object { $_.Number -in $InputObject.MockNumbers }
    }
    elseif ($Association -eq 'MSFT_PartitionToVolume') {
        Invoke-AuditQuery volume_associations
        if ($InputObject.DiskNumber -eq 0) { $global:AuditAssociatedVolumes }
    }
    else { throw "Unexpected association $Association" }
}
function global:Test-AnsibleWindowsDiskAdministrator { $global:AuditIsAdmin }
function Invoke-AuditModule([hashtable]$Params = @{}, [switch]$CheckMode) {
    $defaults = @{
        disk_number = $null
        unique_id = $null
        path = $null
        filter = @('physical_disk', 'virtual_disk', 'win32_disk_drive', 'partitions', 'volumes')
    }
    foreach ($key in $Params.Keys) { $defaults[$key] = $Params[$key] }
    [Ansible.Basic.AnsibleModule]::Input = $defaults
    [Ansible.Basic.AnsibleModule]::Check = [bool]$CheckMode
    [Ansible.Basic.AnsibleModule]::Output = $null
    & (Join-Path $CollectionPath plugins/modules/win_disk_info.ps1)
    [Ansible.Basic.AnsibleModule]::Output
}
function Assert-Audit([bool]$Condition, [string]$Message) { if (-not $Condition) { throw $Message } }
$global:AuditIsAdmin = $true
$script:Count = 0
function Test-Audit([string]$Name, [scriptblock]$Body) {
    Reset-AuditData
    & $Body
    $script:Count++
    Write-Output "PASS $Name"
}
Test-Audit 'sorted local disk list, info interface and changed false' {
    $r = Invoke-AuditModule
    Assert-Audit (($r.disks.number -join ',') -eq '0,1,2,3') 'local ordering'
    Assert-Audit ($r.exists -and -not $r.changed -and -not $r.ContainsKey('ansible_facts')) 'info interface'
}
foreach ($case in @(@{ disk_number = 0 }, @{ unique_id = 'id0' }, @{ path = 'disk0' })) {
    Test-Audit "selector $($case.Keys)" {
        $r = Invoke-AuditModule $case
        Assert-Audit ($r.disks.Count -eq 1 -and $r.disks[0].number -eq 0) 'wrong selection'
    }
}
foreach ($case in @(@{ disk_number = 99 }, @{ unique_id = 'missing' }, @{ path = 'missing' })) {
    Test-Audit "no match $($case.Keys)" {
        $r = Invoke-AuditModule $case
        Assert-Audit (-not $r.exists -and $r.disks.Count -eq 0 -and -not $r.changed) 'no-match result'
        Assert-Audit ($global:AuditCalls.Count -eq 1) 'queried optional providers for empty selection'
    }
}
Test-Audit 'empty inventory' {
    $global:AuditDisks = @()
    $r = Invoke-AuditModule
    Assert-Audit (-not $r.exists -and $r.disks.Count -eq 0) 'empty inventory'
}
Test-Audit 'mixed partition styles and no-letter normalization' {
    $r = Invoke-AuditModule @{ filter = @('partitions') }
    Assert-Audit ($r.disks[0].partitions[0].Contains('gpt_type') -and -not $r.disks[0].partitions[0].Contains('mbr_type')) 'GPT fields'
    Assert-Audit ($r.disks[1].partitions[0].mbr_type -eq 7 -and -not $r.disks[1].partitions[0].Contains('gpt_type')) 'MBR fields'
    Assert-Audit ($null -eq $r.disks[1].partitions[0].drive_letter) 'char zero was not null'
    Assert-Audit ($r.disks[2].partitions.Count -eq 0) 'RAW partitions'
}
Test-Audit 'independent virtual-only filter uses disk associations' {
    $r = Invoke-AuditModule @{ filter = @('virtual_disk') }
    Assert-Audit ($r.disks[3].virtual_disk.unique_id -eq 'space') 'virtual disk missing'
    Assert-Audit (-not $r.disks[3].Contains('physical_disk') -and 'physical' -notin $global:AuditCalls) 'physical filter dependency'
}
Test-Audit 'physical identity does not depend on DeviceId equaling disk number' {
    $r = Invoke-AuditModule @{ disk_number = 0; filter = @('physical_disk') }
    Assert-Audit ($r.disks[0].physical_disk.device_id -eq 'different-id-0') 'wrong physical identity'
}
Test-Audit 'serial fallback trims whitespace and requires size' {
    $global:AuditPhysical[0].UniqueId = 'different'
    $global:AuditPhysical[0].SerialNumber = ' serial0 '
    $r = Invoke-AuditModule @{ disk_number = 0; filter = @('physical_disk') }
    Assert-Audit ($r.disks[0].physical_disks.Count -eq 1) 'serial fallback'
}
Test-Audit 'Storage Spaces backing disks remain separate objects' {
    $r = Invoke-AuditModule @{ disk_number = 3; filter = @('physical_disk') }
    Assert-Audit ($r.disks[0].physical_disks.Count -eq 2 -and $null -eq $r.disks[0].physical_disk) 'multi-device cardinality'
}
Test-Audit 'Win32 mapping uses index despite duplicate serial numbers' {
    $r = Invoke-AuditModule @{ filter = @('win32_disk_drive') }
    Assert-Audit ($r.disks[0].win32_disk_drive.index -eq 0 -and $r.disks[1].win32_disk_drive.index -eq 1) 'Win32 index'
}
Test-Audit 'volume filter implies partitions and preserves absent associations' {
    $r = Invoke-AuditModule @{ filter = @('volumes') }
    Assert-Audit ($r.disks[0].partitions[0].volumes[0].allocation_unit_size -eq 4096) 'volume data'
    Assert-Audit ($r.disks[1].partitions[0].volumes.Count -eq 0) 'absent volume association'
}
Test-Audit 'nullable properties and list cardinality' {
    $r = Invoke-AuditModule
    Assert-Audit ($null -eq $r.disks[0].manufacturer) 'missing optional property'
    Assert-Audit ($r.disks[0].physical_disk.operational_status -is [array]) 'single status lost list shape'
    Assert-Audit ($r.disks[1].physical_disk.supported_usages -is [array]) 'empty usages lost list shape'
    Assert-Audit ($r.disks[0].win32_disk_drive.size -is [long]) 'Win32 string size not numeric'
    Assert-Audit ($r.disks[3].virtual_disk.resiliency_setting_name -is [string]) 'resiliency type'
}
Test-Audit 'query caching' {
    $null = Invoke-AuditModule
    foreach ($stage in 'disks', 'physical', 'virtual', 'win32', 'partitions', 'volumes') {
        Assert-Audit (@($global:AuditCalls | Where-Object { $_ -eq $stage }).Count -eq 1) "repeated $stage inventory"
    }
}
Test-Audit 'empty filter avoids optional queries' {
    $r = Invoke-AuditModule @{ filter = @() }
    Assert-Audit ($global:AuditCalls.Count -eq 1 -and -not $r.disks[0].Contains('partitions')) 'empty filter'
}
Test-Audit 'check mode returns same complete state without mutation' {
    $a = Invoke-AuditModule | ConvertTo-Json -Depth 15 -Compress
    $b = Invoke-AuditModule -CheckMode | ConvertTo-Json -Depth 15 -Compress
    Assert-Audit ($a -eq $b) 'check-mode payload differs'
}
Test-Audit 'missing selection in check mode' {
    $r = Invoke-AuditModule @{ path = 'missing' } -CheckMode
    Assert-Audit (-not $r.exists -and -not $r.changed -and $r.disks.Count -eq 0) 'missing check mode'
}
foreach ($case in @(@{ disk_number = -1 }, @{ unique_id = '' }, @{ path = ' ' })) {
    Test-Audit "invalid selector $($case.Keys)" {
        $failed = $false
        try { $null = Invoke-AuditModule $case } catch { $failed = $true }
        Assert-Audit ($failed -and $global:AuditCalls.Count -eq 0) 'invalid input reached provider'
    }
}
foreach ($stage in 'disks', 'physical', 'virtual', 'win32', 'partitions', 'volumes', 'virtual_associations', 'volume_associations', 'physical_associations') {
    Test-Audit "provider error $stage" {
        $global:AuditFailure = $stage
        $failed = $false
        try { $null = Invoke-AuditModule } catch { $failed = $_.Exception.Message -like "*simulated provider failure: $stage*" }
        Assert-Audit $failed 'provider error was hidden'
    }
}
Test-Audit 'ambiguous physical identity fails' {
    $global:AuditPhysical += $global:AuditPhysical[0]
    $failed = $false
    try {
        $null = Invoke-AuditModule @{
            disk_number = 0
            filter = @('physical_disk')
        }
    }
    catch { $failed = $_.Exception.Message -like '*identity is ambiguous*' }
    Assert-Audit $failed 'ambiguous physical identity accepted'
}
Test-Audit 'multiple virtual associations fail' {
    $global:AuditVirtual += $global:AuditVirtual[0]
    $failed = $false
    try { $null = Invoke-AuditModule @{ filter = @('virtual_disk') } } catch { $failed = $_.Exception.Message -like '*More than one virtual disk*' }
    Assert-Audit $failed 'ambiguous virtual association accepted'
}
Test-Audit 'missing enumerated volume fails instead of inventing data' {
    # Keep the association visible while simulating an inconsistent provider enumeration.
    $global:AuditVolumes = @()
    $failed = $false
    try {
        $null = Invoke-AuditModule @{
            disk_number = 0
            filter = @('volumes')
        }
    }
    catch { $failed = $_.Exception.Message -like '*Expected one enumerated volume*' }
    Assert-Audit $failed 'inconsistent provider accepted'
}
Test-Audit 'volume identity distinguishes duplicated cluster paths' {
    $global:AuditVolumes += New-AuditObject volume @{ ObjectId = 'remote-volume'; Path = 'volume0'; Size = 999 }
    $r = Invoke-AuditModule @{ disk_number = 0; filter = @('volumes') }
    Assert-Audit ($r.disks[0].partitions[0].volumes.Count -eq 1 -and $r.disks[0].partitions[0].volumes[0].size -eq 100) 'wrong volume identity'
}
Test-Audit 'volume path fallback when provider omits object ID' {
    $global:AuditVolumes[0].ObjectId = $null
    $r = Invoke-AuditModule @{ disk_number = 0; filter = @('volumes') }
    Assert-Audit ($r.disks[0].partitions[0].volumes[0].path -eq 'volume0') 'volume path fallback'
}
Test-Audit 'duplicate Win32 index fails' {
    $global:AuditWin32 += $global:AuditWin32[0]
    $failed = $false
    try { $null = Invoke-AuditModule @{ disk_number = 0; filter = @('win32_disk_drive') } }
    catch { $failed = $_.Exception.Message -like '*More than one Win32 disk drive*' }
    Assert-Audit $failed 'ambiguous Win32 association accepted'
}
Test-Audit 'administrator requirement' {
    $global:AuditIsAdmin = $false
    $failed = $false
    try { $null = Invoke-AuditModule } catch { $failed = $_.Exception.Message -like '*administrator account*' }
    Assert-Audit ($failed -and $global:AuditCalls.Count -eq 0) 'unelevated query allowed'
}

function Reset-AuditFixture {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '',
        Justification = 'Global mock state is read by commands and assertions outside this reset function.')]
    param()

    $global:Ansible = [pscustomobject]@{ Changed = $false; Result = $null }
    $global:AuditFixturePath = 'owned.vhdx'
    $global:AuditFixtureImage = [pscustomobject]@{ ImagePath = $global:AuditFixturePath; Attached = $true }
    $global:AuditFixtureExists = $true
    $global:AuditDetachCount = 0
    $global:AuditDetachFailure = $false
    $global:AuditStuckAttachment = $false
    $global:AuditDisks = @(New-AuditObject disk @{
            Number = 1
            Path = 'disk1'
            UniqueId = 'id1'
            Size = 256
            IsBoot = $false
            IsSystem = $false
            PartitionStyle = 'RAW'
        })
}
function global:Test-Path { [CmdletBinding()]param($LiteralPath) $global:AuditFixtureExists }
function global:Get-DiskImage { [CmdletBinding()]param($ImagePath) $global:AuditFixtureImage }
function global:Dismount-DiskImage {
    [CmdletBinding()]param($ImagePath)
    $global:AuditDetachCount++
    if ($global:AuditDetachFailure) { throw 'simulated detach failure' }
    if (-not $global:AuditStuckAttachment) { $global:AuditFixtureImage.Attached = $false }
}
Test-Audit 'owned RAW image identity' {
    Reset-AuditFixture
    & (Join-Path $PSScriptRoot verify_owned_disk.ps1) -ImagePath $global:AuditFixturePath -RequireRaw
    Assert-Audit ($global:Ansible.Result.number -eq 1 -and $global:Ansible.Result.path -eq 'disk1') 'owned identity'
    Assert-Audit (-not $global:Ansible.Changed) 'identity verification changed storage'
}
foreach ($unsafe in 'foreign path', 'detached', 'boot', 'system', 'multiple disks', 'no local number', 'no path', 'initialized') {
    Test-Audit "reject unsafe fixture: $unsafe" {
        Reset-AuditFixture
        switch ($unsafe) {
            'foreign path' { $global:AuditFixtureImage.ImagePath = 'foreign.vhdx' }
            detached { $global:AuditFixtureImage.Attached = $false }
            boot { $global:AuditDisks[0].IsBoot = $true }
            system { $global:AuditDisks[0].IsSystem = $true }
            'multiple disks' { $global:AuditDisks += $global:AuditDisks[0] }
            'no local number' { $global:AuditDisks[0].Number = $null }
            'no path' { $global:AuditDisks[0].Path = '' }
            initialized { $global:AuditDisks[0].PartitionStyle = 'GPT' }
        }
        $failed = $false
        try { & (Join-Path $PSScriptRoot verify_owned_disk.ps1) -ImagePath $global:AuditFixturePath -RequireRaw }
        catch { $failed = $true }
        Assert-Audit ($failed -and -not $global:Ansible.Changed) 'unsafe fixture accepted'
    }
}
Test-Audit 'detach verifies removal of the attachment' {
    Reset-AuditFixture
    & (Join-Path $PSScriptRoot detach_vhd.ps1) -ImagePath $global:AuditFixturePath
    Assert-Audit ($global:AuditDetachCount -eq 1 -and $global:Ansible.Changed -and -not $global:AuditFixtureImage.Attached) 'detach failed'
    & (Join-Path $PSScriptRoot detach_vhd.ps1) -ImagePath $global:AuditFixturePath
    Assert-Audit ($global:AuditDetachCount -eq 1 -and -not $global:Ansible.Changed) 'repeated detach changed storage'
}
Test-Audit 'missing image cleanup is unchanged' {
    Reset-AuditFixture
    $global:AuditFixtureExists = $false
    & (Join-Path $PSScriptRoot detach_vhd.ps1) -ImagePath $global:AuditFixturePath
    Assert-Audit ($global:AuditDetachCount -eq 0 -and -not $global:Ansible.Changed) 'missing image detached'
}
Test-Audit 'cleanup refuses a foreign image' {
    Reset-AuditFixture
    $global:AuditFixtureImage.ImagePath = 'foreign.vhdx'
    $failed = $false
    try { & (Join-Path $PSScriptRoot detach_vhd.ps1) -ImagePath $global:AuditFixturePath }
    catch { $failed = $true }
    Assert-Audit ($failed -and $global:AuditDetachCount -eq 0) 'foreign image detached'
}
Test-Audit 'failed detach is visible and another image can still be cleaned' {
    Reset-AuditFixture
    $global:AuditDetachFailure = $true
    $failed = $false
    try { & (Join-Path $PSScriptRoot detach_vhd.ps1) -ImagePath $global:AuditFixturePath }
    catch { $failed = $_.Exception.Message -like '*simulated detach failure*' }
    Assert-Audit $failed 'detach failure hidden'
    Reset-AuditFixture
    & (Join-Path $PSScriptRoot detach_vhd.ps1) -ImagePath $global:AuditFixturePath
    Assert-Audit ($global:AuditDetachCount -eq 1 -and -not $global:AuditFixtureImage.Attached) 'next cleanup failed'
}
Test-Audit 'cleanup reports an image that remains attached' {
    Reset-AuditFixture
    $global:AuditStuckAttachment = $true
    $failed = $false
    try { & (Join-Path $PSScriptRoot detach_vhd.ps1) -ImagePath $global:AuditFixturePath }
    catch { $failed = $_.Exception.Message -like '*still attached*' }
    Assert-Audit $failed 'stuck attachment hidden'
}
Write-Output "$script:Count regression cases passed against the actual scripts with mocked platform boundaries."

