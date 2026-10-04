param($ImagePath, $DiskNumber)
$diskImage = Get-DiskImage -ImagePath $ImagePath -ErrorAction Stop
if (-not $diskImage.Attached) {
    throw "Test VHD '$ImagePath' is not attached."
}

$disk = $diskImage | Get-Disk -ErrorAction Stop
if ($disk.Number -ne [int]$DiskNumber) {
    throw "Test VHD '$ImagePath' resolved to disk $($disk.Number), not disk $DiskNumber."
}

$partitions = @(
    Get-Partition -ErrorAction Stop |
        Where-Object { $_.DiskNumber -eq $disk.Number }
)
if ($partitions.Count -gt 0) {
    throw "Refusing to convert test disk $DiskNumber because it still has partitions."
}
$Ansible.Changed = $false
