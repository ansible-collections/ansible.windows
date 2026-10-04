param($ImagePath)
$imageParams = @{
    ImagePath = $ImagePath
    ErrorAction = 'Stop'
}
$diskImage = Get-DiskImage @imageParams
Write-Output ([bool]$diskImage.Attached)
$Ansible.Changed = $false
