#!powershell

# Copyright: (c) 2019, Varun Chopra (@chopraaa) <v@chopraaa.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -OSVersion 6.2
#AnsibleRequires -PowerShell ..module_utils.Volume

Set-StrictMode -Version 2

$ErrorActionPreference = "Stop"

$spec = @{
    options = @{
        drive_letter = @{ type = "str" }
        path = @{ type = "str" }
        label = @{ type = "str" }
        new_label = @{ type = "str" }
        file_system = @{ type = "str"; choices = "ntfs", "refs", "exfat", "fat32", "fat" }
        allocation_unit_size = @{ type = "int" }
        large_frs = @{ type = "bool" }
        full = @{ type = "bool"; default = $false }
        compress = @{ type = "bool" }
        integrity_streams = @{ type = "bool" }
        force = @{ type = "bool"; default = $false }
    }
    mutually_exclusive = @(
        , @('drive_letter', 'path', 'label')
    )
    required_one_of = @(
        , @('drive_letter', 'path', 'label')
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$drive_letter = $module.Params.drive_letter
$path = $module.Params.path
$label = $module.Params.label
$new_label = $module.Params.new_label
$file_system = $module.Params.file_system
$allocation_unit_size = $module.Params.allocation_unit_size
$large_frs = $module.Params.large_frs
$full_format = $module.Params.full
$compress_volume = $module.Params.compress
$integrity_streams = $module.Params.integrity_streams
$force_format = $module.Params.force

if ($null -ne $drive_letter -and $drive_letter -notmatch "^[a-zA-Z]$") {
    $module.FailJson("The parameter drive_letter should be a single character A-Z")
}
function Format-AnsibleVolume {
    param(
        $Path,
        $Label,
        $FileSystem,
        $Full,
        $UseLargeFRS,
        $Compress,
        $SetIntegrityStreams,
        $AllocationUnitSize,
        $Force
    )
    $parameters = @{
        Path = $Path
        Full = $Full
    }
    if ($null -ne $UseLargeFRS) {
        $parameters.Add("UseLargeFRS", $UseLargeFRS)
    }
    if ($null -ne $SetIntegrityStreams) {
        $parameters.Add("SetIntegrityStreams", $SetIntegrityStreams)
    }
    if ($null -ne $Compress) {
        $parameters.Add("Compress", $Compress)
    }
    if ($null -ne $Label) {
        $parameters.Add("NewFileSystemLabel", $Label)
    }
    if ($null -ne $FileSystem) {
        $parameters.Add("FileSystem", $FileSystem)
    }
    if ($null -ne $AllocationUnitSize) {
        $parameters.Add("AllocationUnitSize", $AllocationUnitSize)
    }
    if ($Force) {
        $parameters.Add("Force", $true)
    }

    Format-Volume @parameters -Confirm:$false | Out-Null
}

try {
    $volume_selector = @{}
    if ($module.Params.ContainsKey('drive_letter') -and $null -ne $drive_letter) {
        $volume_selector.DriveLetter = $drive_letter
    }
    elseif ($module.Params.ContainsKey('path') -and $null -ne $path) {
        $volume_selector.Path = $path
    }
    elseif ($module.Params.ContainsKey('label') -and $null -ne $label) {
        $volume_selector.Label = $label
    }
    else {
        $module.FailJson("Unable to locate volume: drive_letter, path and label were not specified")
    }
    $ansible_volumes = @(Get-AnsibleWinFormatVolume @volume_selector)
}
catch {
    $module.FailJson("There was an error retrieving the target volume: $($_.Exception.Message)", $_)
}

if ($ansible_volumes.Count -eq 0) {
    $module.FailJson("Unable to locate a volume matching the specified drive_letter, path or label")
}
if ($ansible_volumes.Count -gt 1) {
    $module.FailJson("The specified target matches more than one volume. Use drive_letter or path to identify a single volume")
}

$ansible_volume = $ansible_volumes[0]
$ansible_file_system = $ansible_volume.FileSystem
$ansible_volume_size = $ansible_volume.Size
$ansible_volume_label = $ansible_volume.FileSystemLabel
$volume_is_unformatted = $ansible_volume_size -eq 0 -or [string]::IsNullOrEmpty($ansible_file_system)

$target_file_system = $file_system
if ($null -eq $target_file_system) {
    $target_file_system = $ansible_file_system
}
if ($integrity_streams -eq $true -and $target_file_system -ne "refs") {
    $module.FailJson("Integrity streams can be enabled only on ReFS volumes. You specified: $($target_file_system)")
}
if ($compress_volume -eq $true) {
    if ($target_file_system -eq "ntfs") {
        if ($null -ne $allocation_unit_size -and $allocation_unit_size -gt 4096) {
            $module.FailJson("NTFS compression is not supported for allocation unit sizes above 4096")
        }
    }
    else {
        $module.FailJson("Compression can be enabled only on NTFS volumes. You specified: $($target_file_system)")
    }
}

if (
    -not $force_format -and
    -not $volume_is_unformatted -and
    $null -ne $allocation_unit_size
) {
    try {
        $ansible_volume_alu = Get-AnsibleWinFormatAllocationUnitSize -Volume $ansible_volume
    }
    catch {
        $module.FailJson("There was an error retrieving the target volume allocation unit size: $($_.Exception.Message)", $_)
    }
    if ($null -eq $ansible_volume_alu -or $ansible_volume_alu -le 0) {
        $msg = -join @(
            "Unable to verify the current allocation unit size. Specify force to format with the "
            "requested allocation_unit_size; formatting removes existing data"
        )
        $module.FailJson($msg)
    }
    if ($allocation_unit_size -ne $ansible_volume_alu) {
        $msg = -join @(
            "Force format must be specified since target allocation unit size: $($allocation_unit_size) "
            "is different from the current allocation unit size of the volume: $($ansible_volume_alu)"
        )
        $module.FailJson($msg)
    }
}

$file_system_changed = $false
if ($null -ne $file_system -and -not [string]::IsNullOrEmpty($ansible_file_system)) {
    $file_system_changed = $file_system -ne $ansible_file_system
}
$format_option_specified = $false
if ($full_format -or $null -ne $large_frs -or $null -ne $compress_volume -or $null -ne $integrity_streams) {
    $format_option_specified = $true
}
$label_changed = $null -ne $new_label -and $new_label -ne $ansible_volume_label

if ($force_format) {
    $format_volume = $true
}
elseif ($volume_is_unformatted) {
    $format_volume = $true
}
else {
    if ($file_system_changed -or $format_option_specified) {
        $module.FailJson("Force format must be specified to format non-pristine volumes")
    }
    $format_volume = $false
}

if ($format_volume) {
    if (-not $module.CheckMode) {
        $format_params = @{
            Path = $ansible_volume.Path
            Full = $full_format
            Label = $new_label
            FileSystem = $file_system
            SetIntegrityStreams = $integrity_streams
            UseLargeFRS = $large_frs
            Compress = $compress_volume
            AllocationUnitSize = $allocation_unit_size
            Force = $force_format
        }
        try {
            Format-AnsibleVolume @format_params
        }
        catch {
            $module.FailJson("Failed to format volume '$($ansible_volume.Path)' with file system '$target_file_system': $($_.Exception.Message)", $_)
        }
    }
    $module.Result.changed = $true
}
elseif ($label_changed) {
    if (-not $module.CheckMode) {
        try {
            Set-Volume -Path $ansible_volume.Path -NewFileSystemLabel $new_label -ErrorAction Stop | Out-Null
        }
        catch {
            $module.FailJson("Failed to set volume label: $($_.Exception.Message)", $_)
        }
    }
    $module.Result.changed = $true
}

$module.ExitJson()
