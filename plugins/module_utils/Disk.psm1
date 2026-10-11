# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

$script:AnsibleWindowsDiskPropertyMaps = @{
    disk = [ordered]@{
        number = @('Number', 'int')
        size = @('Size', 'int')
        bus_type = @('BusType', 'str')
        friendly_name = @('FriendlyName', 'str')
        partition_style = @('PartitionStyle', 'str')
        partition_count = @('NumberOfPartitions', 'int')
        operational_status = @('OperationalStatus', 'str')
        sector_size = @('PhysicalSectorSize', 'int')
        read_only = @('IsReadOnly', 'bool')
        bootable = @('IsBoot', 'bool')
        system_disk = @('IsSystem', 'bool')
        clustered = @('IsClustered', 'bool')
        manufacturer = @('Manufacturer', 'str')
        model = @('Model', 'str')
        firmware_version = @('FirmwareVersion', 'str')
        location = @('Location', 'str')
        serial_number = @('SerialNumber', 'str')
        unique_id = @('UniqueId', 'str')
        guid = @('Guid', 'str')
        path = @('Path', 'str')
        allocated_size = @('AllocatedSize', 'int')
        is_offline = @('IsOffline', 'bool')
        health_status = @('HealthStatus', 'str')
        logical_sector_size = @('LogicalSectorSize', 'int')
    }
    physical_disk = [ordered]@{
        size = @('Size', 'int')
        allocated_size = @('AllocatedSize', 'int')
        device_id = @('DeviceId', 'str')
        friendly_name = @('FriendlyName', 'str')
        operational_status = @('OperationalStatus', 'list_str')
        health_status = @('HealthStatus', 'str')
        bus_type = @('BusType', 'str')
        usage_type = @('Usage', 'str')
        supported_usages = @('SupportedUsages', 'list_str')
        spindle_speed = @('SpindleSpeed', 'int')
        firmware_version = @('FirmwareVersion', 'str')
        physical_location = @('PhysicalLocation', 'str')
        manufacturer = @('Manufacturer', 'str')
        model = @('Model', 'str')
        can_pool = @('CanPool', 'bool')
        indication_enabled = @('IsIndicationEnabled', 'bool')
        partial = @('IsPartial', 'bool')
        serial_number = @('SerialNumber', 'str')
        object_id = @('ObjectId', 'str')
        unique_id = @('UniqueId', 'str')
        media_type = @('MediaType', 'str')
        cannot_pool_reason = @('CannotPoolReason', 'list_str')
    }
    virtual_disk = [ordered]@{
        size = @('Size', 'int')
        allocated_size = @('AllocatedSize', 'int')
        footprint_on_pool = @('FootprintOnPool', 'int')
        name = @('name', 'str')
        friendly_name = @('FriendlyName', 'str')
        operational_status = @('OperationalStatus', 'list_str')
        health_status = @('HealthStatus', 'str')
        provisioning_type = @('ProvisioningType', 'str')
        allocation_unit_size = @('AllocationUnitSize', 'int')
        media_type = @('MediaType', 'str')
        parity_layout = @('ParityLayout', 'int')
        access = @('Access', 'str')
        detached_reason = @('DetachedReason', 'str')
        write_cache_size = @('WriteCacheSize', 'int')
        fault_domain_awareness = @('FaultDomainAwareness', 'str')
        inter_leave = @('InterLeave', 'int')
        deduplication_enabled = @('IsDeduplicationEnabled', 'bool')
        enclosure_aware = @('IsEnclosureAware', 'bool')
        manual_attach = @('IsManualAttach', 'bool')
        snapshot = @('IsSnapshot', 'bool')
        tiered = @('IsTiered', 'bool')
        physical_sector_size = @('PhysicalSectorSize', 'int')
        logical_sector_size = @('LogicalSectorSize', 'int')
        available_copies = @('NumberOfAvailableCopies', 'int')
        columns = @('NumberOfColumns', 'int')
        groups = @('NumberOfGroups', 'int')
        physical_disk_redundancy = @('PhysicalDiskRedundancy', 'int')
        read_cache_size = @('ReadCacheSize', 'int')
        request_no_spof = @('RequestNoSinglePointOfFailure', 'bool')
        resiliency_setting_name = @('ResiliencySettingName', 'str')
        object_id = @('ObjectId', 'str')
        unique_id_format = @('UniqueIdFormat', 'str')
        unique_id = @('UniqueId', 'str')
    }
    win32_disk_drive = [ordered]@{
        availability = @('Availability', 'int')
        bytes_per_sector = @('BytesPerSector', 'int')
        capabilities = @('Capabilities', 'list_int')
        capability_descriptions = @('CapabilityDescriptions', 'list_str')
        caption = @('Caption', 'str')
        compression_method = @('CompressionMethod', 'str')
        config_manager_error_code = @('ConfigManagerErrorCode', 'int')
        config_manager_user_config = @('ConfigManagerUserConfig', 'bool')
        creation_class_name = @('CreationClassName', 'str')
        default_block_size = @('DefaultBlockSize', 'int')
        description = @('Description', 'str')
        device_id = @('DeviceID', 'str')
        error_cleared = @('ErrorCleared', 'bool')
        error_description = @('ErrorDescription', 'str')
        error_methodology = @('ErrorMethodology', 'str')
        firmware_revision = @('FirmwareRevision', 'str')
        index = @('Index', 'int')
        install_date = @('InstallDate', 'str')
        interface_type = @('InterfaceType', 'str')
        last_error_code = @('LastErrorCode', 'int')
        manufacturer = @('Manufacturer', 'str')
        max_block_size = @('MaxBlockSize', 'int')
        max_media_size = @('MaxMediaSize', 'int')
        media_loaded = @('MediaLoaded', 'bool')
        media_type = @('MediaType', 'str')
        min_block_size = @('MinBlockSize', 'int')
        model = @('Model', 'str')
        name = @('Name', 'str')
        needs_cleaning = @('NeedsCleaning', 'bool')
        number_of_media_supported = @('NumberOfMediaSupported', 'int')
        partitions = @('Partitions', 'int')
        pnp_device_id = @('PNPDeviceID', 'str')
        power_management_capabilities = @('PowerManagementCapabilities', 'list_int')
        power_management_supported = @('PowerManagementSupported', 'bool')
        scsi_bus = @('SCSIBus', 'int')
        scsi_logical_unit = @('SCSILogicalUnit', 'int')
        scsi_port = @('SCSIPort', 'int')
        scsi_target_id = @('SCSITargetId', 'int')
        sectors_per_track = @('SectorsPerTrack', 'int')
        serial_number = @('SerialNumber', 'str')
        signature = @('Signature', 'int')
        size = @('Size', 'int')
        status = @('status', 'str')
        status_info = @('StatusInfo', 'int')
        system_creation_class_name = @('SystemCreationClassName', 'str')
        system_name = @('SystemName', 'str')
        total_cylinders = @('TotalCylinders', 'int')
        total_heads = @('TotalHeads', 'int')
        total_sectors = @('TotalSectors', 'int')
        total_tracks = @('TotalTracks', 'int')
        tracks_per_cylinder = @('TracksPerCylinder', 'int')
    }
    partition = [ordered]@{
        number = @('PartitionNumber', 'int')
        size = @('Size', 'int')
        type = @('Type', 'str')
        drive_letter = @('DriveLetter', 'drive_letter')
        transition_state = @('TransitionState', 'int')
        offset = @('Offset', 'int')
        hidden = @('IsHidden', 'bool')
        shadow_copy = @('IsShadowCopy', 'bool')
        guid = @('Guid', 'str')
        access_paths = @('AccessPaths', 'list_str')
        gpt_type = @('GptType', 'str')
        no_default_driveletter = @('NoDefaultDriveLetter', 'bool')
        mbr_type = @('MbrType', 'int')
        active = @('IsActive', 'bool')
    }
    volume = [ordered]@{
        size = @('Size', 'int')
        size_remaining = @('SizeRemaining', 'int')
        type = @('FileSystem', 'str')
        label = @('FileSystemLabel', 'str')
        health_status = @('HealthStatus', 'str')
        drive_type = @('DriveType', 'str')
        object_id = @('ObjectId', 'str')
        path = @('Path', 'str')
        allocation_unit_size = @('AllocationUnitSize', 'int')
    }
}

function Get-AnsibleWindowsDisk {
    <#
    .SYNOPSIS
    Enumerates local disks and applies an optional exact selector.
    .PARAMETER DiskNumber
    The operating system disk number to select.
    .PARAMETER UniqueId
    The unique disk identifier to select.
    .PARAMETER Path
    The disk device path to select.
    #>
    [CmdletBinding()]
    param (
        [Nullable[int]]$DiskNumber,
        [string]$UniqueId,
        [string]$Path
    )

    # Enumerate first so a missing selector is an empty result, not a provider lookup error.
    $disks = @(Get-Disk -ErrorAction Stop | Where-Object { $null -ne $_.Number })
    if ($null -ne $DiskNumber) {
        $disks = @($disks | Where-Object { $_.Number -eq $DiskNumber })
    }
    if ($PSBoundParameters.ContainsKey('UniqueId')) {
        $disks = @($disks | Where-Object { $_.UniqueId -eq $UniqueId })
    }
    if ($PSBoundParameters.ContainsKey('Path')) {
        $disks = @($disks | Where-Object { $_.Path -eq $Path })
    }
    $disks | Sort-Object -Property Number
}

function Test-AnsibleWindowsDiskAdministrator {
    <#
    .SYNOPSIS
    Reports whether the current token has administrator privileges for Storage queries.
    #>
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal $identity
    $principal.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}

function ConvertTo-AnsibleWindowsDiskInfo {
    <#
    .SYNOPSIS
    Normalizes Storage and Win32 properties into documented disk information.
    .PARAMETER InputObject
    The object returned by the Storage provider.
    .PARAMETER Kind
    The property map to use for the resource.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)]
        [ValidateSet('disk', 'physical_disk', 'virtual_disk', 'win32_disk_drive', 'partition', 'volume')]
        [string]$Kind
    )

    $result = [ordered]@{}
    foreach ($entry in $script:AnsibleWindowsDiskPropertyMaps[$Kind].GetEnumerator()) {
        $property = $InputObject.PSObject.Properties[$entry.Value[0]]
        $value = if ($null -ne $property) { $property.Value } else { $null }
        $valueType = $entry.Value[1]
        if ($valueType -eq 'list_str') {
            $value = @($value | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ })
        }
        elseif ($valueType -eq 'list_int') {
            $value = @($value | Where-Object { $null -ne $_ } | ForEach-Object { [long]$_ })
        }
        elseif ($valueType -eq 'drive_letter') {
            $value = if ([string]$value -match '^[A-Za-z]$') { [string]$value } else { $null }
        }
        elseif ($null -ne $value) {
            switch ($valueType) {
                str { $value = if ($value -is [datetime]) { $value.ToString('o') } else { [string]$value } }
                int { $value = [long]$value }
                bool { $value = [bool]$value }
            }
        }
        $result[$entry.Key] = $value
    }
    $result
}

function Get-AnsibleWindowsDiskInformation {
    <#
    .SYNOPSIS
    Retrieves disks and requested related information without changing storage state.
    .PARAMETER Selector
    Optional disk number, unique identifier, or path selector.
    .PARAMETER Filter
    Additional information categories to include.
    #>
    [CmdletBinding()]
    param (
        [hashtable]$Selector = @{},
        [string[]]$Filter
    )

    $stage = 'disks'
    try {
        $disks = @(Get-AnsibleWindowsDisk @Selector)
        if ($disks.Count -eq 0) {
            return
        }
        $physicalDisks = @()
        $win32Disks = @()
        $partitions = @()
        $volumes = @()
        $virtualDisksByNumber = @{}
        if ('physical_disk' -in $Filter) {
            $stage = 'physical disks'
            $physicalDisks = @(Get-PhysicalDisk -ErrorAction Stop)
        }
        if ('win32_disk_drive' -in $Filter) {
            $stage = 'Win32 disk drives'
            $win32Disks = @(Get-CimInstance -ClassName Win32_DiskDrive -ErrorAction Stop)
        }
        if ('partitions' -in $Filter -or 'volumes' -in $Filter) {
            $stage = 'partitions'
            $partitions = @(Get-Partition -ErrorAction Stop)
        }
        if ('volumes' -in $Filter) {
            $stage = 'volumes'
            $volumes = @(Get-Volume -ErrorAction Stop)
        }
        if ('virtual_disk' -in $Filter -or 'physical_disk' -in $Filter) {
            $stage = 'virtual disks'
            $virtualDisks = @(Get-VirtualDisk -ErrorAction Stop)
            foreach ($virtualDisk in $virtualDisks) {
                $stage = "disk associations for virtual disk '$($virtualDisk.FriendlyName)'"
                $associationParams = @{
                    InputObject = $virtualDisk
                    Association = 'MSFT_VirtualDiskToDisk'
                    ResultClassName = 'MSFT_Disk'
                    ErrorAction = 'Stop'
                }
                $associatedDisks = @(Get-CimAssociatedInstance @associationParams)
                foreach ($associatedDisk in $associatedDisks) {
                    if ($null -eq $associatedDisk.Number) {
                        continue
                    }
                    $number = [string]$associatedDisk.Number
                    if ($virtualDisksByNumber.ContainsKey($number)) {
                        throw "More than one virtual disk is associated with local disk $number"
                    }
                    $virtualDisksByNumber[$number] = $virtualDisk
                }
            }
        }

        foreach ($disk in $disks) {
            $stage = "properties of disk $($disk.Number)"
            $diskInfo = ConvertTo-AnsibleWindowsDiskInfo -InputObject $disk -Kind disk
            $virtualDisk = $virtualDisksByNumber[[string]$disk.Number]
            if ('virtual_disk' -in $Filter) {
                $diskInfo.virtual_disk = if ($null -ne $virtualDisk) {
                    ConvertTo-AnsibleWindowsDiskInfo -InputObject $virtualDisk -Kind virtual_disk
                }
                else { $null }
            }
            if ('physical_disk' -in $Filter) {
                $stage = "physical disk associations for disk $($disk.Number)"
                if ($null -ne $virtualDisk) {
                    $relatedPhysicalDisks = @(Get-PhysicalDisk -VirtualDisk $virtualDisk -ErrorAction Stop)
                }
                else {
                    # DeviceId is a provider identifier, not necessarily the OS disk number.
                    $relatedPhysicalDisks = @($physicalDisks | Where-Object {
                            -not [string]::IsNullOrWhiteSpace($disk.UniqueId) -and $_.UniqueId -eq $disk.UniqueId
                        })
                    if ($relatedPhysicalDisks.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($disk.SerialNumber)) {
                        $relatedPhysicalDisks = @($physicalDisks | Where-Object {
                                -not [string]::IsNullOrWhiteSpace($_.SerialNumber) -and
                                $_.SerialNumber.Trim() -eq $disk.SerialNumber.Trim() -and $_.Size -eq $disk.Size
                            })
                    }
                    if ($relatedPhysicalDisks.Count -gt 1) {
                        throw "Physical disk identity is ambiguous for disk $($disk.Number)"
                    }
                }
                $diskInfo.physical_disks = @(
                    $relatedPhysicalDisks | Sort-Object -Property DeviceId | ForEach-Object {
                        $info = ConvertTo-AnsibleWindowsDiskInfo -InputObject $_ -Kind physical_disk
                        if ($_.CanPool) {
                            $info.Remove('cannot_pool_reason')
                        }
                        $info
                    }
                )
                $diskInfo.physical_disk = if ($diskInfo.physical_disks.Count -eq 1) { $diskInfo.physical_disks[0] } else { $null }
            }
            if ('win32_disk_drive' -in $Filter) {
                $stage = "Win32 association for disk $($disk.Number)"
                $win32Disk = @($win32Disks | Where-Object { $_.Index -eq $disk.Number })
                if ($win32Disk.Count -gt 1) {
                    throw "More than one Win32 disk drive matches disk $($disk.Number)"
                }
                $diskInfo.win32_disk_drive = if ($win32Disk.Count -eq 1) {
                    ConvertTo-AnsibleWindowsDiskInfo -InputObject $win32Disk[0] -Kind win32_disk_drive
                }
                else { $null }
            }
            if ('partitions' -in $Filter -or 'volumes' -in $Filter) {
                $stage = "partitions of disk $($disk.Number)"
                $diskPartitions = @($partitions | Where-Object { $_.DiskNumber -eq $disk.Number } | Sort-Object -Property PartitionNumber)
                $diskInfo.partitions = @(
                    foreach ($partition in $diskPartitions) {
                        $partitionInfo = ConvertTo-AnsibleWindowsDiskInfo -InputObject $partition -Kind partition
                        if ([string]$disk.PartitionStyle -eq 'GPT') {
                            $partitionInfo.Remove('mbr_type')
                            $partitionInfo.Remove('active')
                        }
                        elseif ([string]$disk.PartitionStyle -eq 'MBR') {
                            $partitionInfo.Remove('gpt_type')
                            $partitionInfo.Remove('no_default_driveletter')
                        }
                        else {
                            foreach ($field in 'gpt_type', 'no_default_driveletter', 'mbr_type', 'active') {
                                $partitionInfo.Remove($field)
                            }
                        }
                        if ('volumes' -in $Filter) {
                            $stage = "volumes of disk $($disk.Number), partition $($partition.PartitionNumber)"
                            # An association query returns [] for reserved/unformatted partitions without a volume.
                            # Reuse the enumerated cmdlet objects so Storage's enum adapters remain available.
                            $associationParams = @{
                                InputObject = $partition
                                Association = 'MSFT_PartitionToVolume'
                                ResultClassName = 'MSFT_Volume'
                                ErrorAction = 'Stop'
                            }
                            $associatedVolumes = @(Get-CimAssociatedInstance @associationParams)
                            $partitionInfo.volumes = @(
                                foreach ($associatedVolume in ($associatedVolumes | Sort-Object -Property Path)) {
                                    $volume = @($volumes | Where-Object {
                                            if (-not [string]::IsNullOrWhiteSpace($associatedVolume.ObjectId)) {
                                                $_.ObjectId -eq $associatedVolume.ObjectId
                                            }
                                            else {
                                                $_.Path -eq $associatedVolume.Path
                                            }
                                        })
                                    if ($volume.Count -ne 1) {
                                        throw "Expected one enumerated volume for '$($associatedVolume.Path)', found $($volume.Count)"
                                    }
                                    ConvertTo-AnsibleWindowsDiskInfo -InputObject $volume[0] -Kind volume
                                }
                            )
                        }
                        $partitionInfo
                    }
                )
            }
            $diskInfo
        }
    }
    catch {
        throw "Failed to retrieve ${stage}: $($_.Exception.Message)"
    }
}

Export-ModuleMember -Function Get-AnsibleWindowsDisk, Test-AnsibleWindowsDiskAdministrator, ConvertTo-AnsibleWindowsDiskInfo, Get-AnsibleWindowsDiskInformation
