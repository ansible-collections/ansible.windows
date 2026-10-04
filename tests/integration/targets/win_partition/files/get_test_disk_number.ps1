param($ImagePath)
$imageParams = @{
    ImagePath = $ImagePath
    ErrorAction = 'Stop'
}
$diskImage = Get-DiskImage @imageParams
$disk = $diskImage | Get-Disk -ErrorAction Stop
if ($null -eq $disk) {
    throw "Unable to find the disk for test VHD '$ImagePath'."
}
$disk.Number
