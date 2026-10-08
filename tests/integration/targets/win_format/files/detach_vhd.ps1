param (
    [Parameter(Mandatory = $true)]
    [string]$VhdxPath
)

$Ansible.Changed = $false
if (Test-Path -LiteralPath $VhdxPath) {
    $image = Get-DiskImage -ImagePath $VhdxPath -ErrorAction Stop
    if ($image.ImagePath -ne $VhdxPath) {
        throw "Refusing to detach an image other than the owned VHD '$VhdxPath'."
    }
    if ($image.Attached) {
        Dismount-DiskImage -ImagePath $VhdxPath -ErrorAction Stop
        $Ansible.Changed = $true
    }
    if ((Get-DiskImage -ImagePath $VhdxPath -ErrorAction Stop).Attached) {
        throw "Test VHD '$VhdxPath' is still attached."
    }
}
