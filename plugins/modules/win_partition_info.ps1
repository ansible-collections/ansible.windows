#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -OSVersion 6.2

Set-StrictMode -Version 2

$ErrorActionPreference = "Stop"

$spec = @{
    options = @{
        disk_number = @{ type = "int" }
        partition_number = @{ type = "int" }
        drive_letter = @{ type = "str" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$disk_number = $module.Params.disk_number
$partition_number = $module.Params.partition_number
$drive_letter = $module.Params.drive_letter

if ($null -ne $disk_number -and $disk_number -lt 0) {
    $module.FailJson("disk_number must be greater than or equal to 0")
}
if ($null -ne $partition_number -and $partition_number -lt 1) {
    $module.FailJson("partition_number must be greater than or equal to 1")
}
if ($null -ne $drive_letter) {
    if ($drive_letter -notmatch '^[a-zA-Z]$') {
        $module.FailJson("drive_letter must be a single letter from A to Z")
    }
    if ($null -ne $disk_number -or $null -ne $partition_number) {
        $module.FailJson("drive_letter cannot be specified with disk_number or partition_number")
    }
}

try {
    # Query once without filters so a no-match query is distinguishable from a
    # Storage provider error. Apply filters locally to keep no-result queries
    # successful while allowing unexpected cmdlet errors to reach the caller.
    $partitions = @(Get-Partition -ErrorAction Stop)
}
catch {
    $module.FailJson("Failed to retrieve partition information: $($_.Exception.Message)", $_)
}

if ($null -ne $disk_number) {
    $partitions = @($partitions | Where-Object { $_.DiskNumber -eq $disk_number })
}
if ($null -ne $partition_number) {
    $partitions = @($partitions | Where-Object { $_.PartitionNumber -eq $partition_number })
}
if ($null -ne $drive_letter) {
    $partitions = @($partitions | Where-Object { $_.DriveLetter -eq $drive_letter })
}

$module.Result.exists = $partitions.Count -gt 0
$module.Result.partitions = @(
    foreach ($partition in $partitions) {
        $partitionDriveLetter = $null
        if ($null -ne $partition.DriveLetter) {
            $partitionDriveLetter = $partition.DriveLetter.ToString()
        }

        $accessPaths = @()
        if ($null -ne $partition.AccessPaths) {
            $accessPaths = @($partition.AccessPaths)
        }

        [ordered]@{
            access_paths = $accessPaths
            disk_number = $partition.DiskNumber
            drive_letter = $partitionDriveLetter
            gpt_type = $partition.GptType
            guid = $partition.Guid
            is_active = $partition.IsActive
            is_boot = $partition.IsBoot
            is_hidden = $partition.IsHidden
            is_offline = $partition.IsOffline
            is_read_only = $partition.IsReadOnly
            is_shadow_copy = $partition.IsShadowCopy
            is_system = $partition.IsSystem
            mbr_type = $partition.MbrType
            no_default_drive_letter = $partition.NoDefaultDriveLetter
            offset = $partition.Offset
            operational_status = $partition.OperationalStatus
            partition_number = $partition.PartitionNumber
            size = $partition.Size
            transition_state = $partition.TransitionState
            type = $partition.Type
        }
    }
)

$module.ExitJson()
