param (
    [Parameter(Mandatory = $true)][string]$ImagePath,
    [switch]$RequireRaw
)

$Ansible.Changed = $false
$image = Get-DiskImage -ImagePath $ImagePath -ErrorAction Stop
if (-not $image.Attached -or $image.ImagePath -ne $ImagePath) {
    throw "The owned image '$ImagePath' is not attached at its expected path."
}
$disks = @($image | Get-Disk -ErrorAction Stop)
if ($disks.Count -ne 1 -or $disks[0].IsBoot -or $disks[0].IsSystem) {
    throw "Expected exactly one non-system disk for owned image '$ImagePath'."
}
$disk = $disks[0]
if ($null -eq $disk.Number -or [string]::IsNullOrWhiteSpace($disk.Path)) {
    throw "The owned image '$ImagePath' does not expose a local disk identity."
}
if ($RequireRaw -and [string]$disk.PartitionStyle -ne 'RAW') {
    throw "Refusing to initialize '$ImagePath' because its disk is not RAW."
}
$Ansible.Result = @{
    number = $disk.Number
    path = $disk.Path
    unique_id = $disk.UniqueId
    size = $disk.Size
}

