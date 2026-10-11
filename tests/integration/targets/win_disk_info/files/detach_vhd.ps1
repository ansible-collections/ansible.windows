param (
    [Parameter(Mandatory = $true)][string]$ImagePath
)

$Ansible.Changed = $false
if (Test-Path -LiteralPath $ImagePath) {
    $image = Get-DiskImage -ImagePath $ImagePath -ErrorAction Stop
    if ($image.ImagePath -ne $ImagePath) {
        throw "Refusing to detach an image other than '$ImagePath'."
    }
    if ($image.Attached) {
        $null = Dismount-DiskImage -ImagePath $ImagePath -ErrorAction Stop
        $Ansible.Changed = $true
    }
    if ((Get-DiskImage -ImagePath $ImagePath -ErrorAction Stop).Attached) {
        throw "Owned image '$ImagePath' is still attached."
    }
}
