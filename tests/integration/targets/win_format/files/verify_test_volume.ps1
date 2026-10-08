param (
    [Parameter(Mandatory = $true)]
    [string]$VhdxPath,
    [Parameter(Mandatory = $true)]
    [char]$DriveLetter
)

$Ansible.Changed = $false
$image = Get-DiskImage -ImagePath $VhdxPath -ErrorAction Stop
if (-not $image.Attached -or $image.ImagePath -ne $VhdxPath) {
    throw "The owned VHD '$VhdxPath' is not attached at its expected path."
}
$disks = @($image | Get-Disk -ErrorAction Stop)
$partitions = @(Get-Partition -DriveLetter $DriveLetter -ErrorAction Stop)
if ($disks.Count -ne 1 -or $partitions.Count -ne 1) {
    throw "Expected one disk and one partition for the owned test VHD '$VhdxPath'."
}
$disk = $disks[0]
$partition = $partitions[0]
if ($disk.IsBoot -or $disk.IsSystem -or $partition.DiskNumber -ne $disk.Number) {
    throw "Refusing to test drive '$DriveLetter' because it is not a non-system partition on '$VhdxPath'."
}
$volumes = @($partition | Get-Volume -ErrorAction Stop)
if ($volumes.Count -ne 1 -or $volumes[0].DriveLetter -ne $DriveLetter) {
    throw "The owned partition does not expose the expected test volume '$DriveLetter'."
}

$Ansible.Result = @{
    disk_number = $disk.Number
    partition_number = $partition.PartitionNumber
    path = $volumes[0].Path
}
