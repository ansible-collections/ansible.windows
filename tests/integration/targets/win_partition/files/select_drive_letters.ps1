$usedLetters = @()
foreach ($drive in Get-PSDrive -PSProvider FileSystem) {
    $usedLetters += $drive.Name.ToUpperInvariant()
}
foreach ($volume in Get-Volume) {
    if ($volume.DriveLetter) {
        $driveLetter = $volume.DriveLetter.ToString()
        $usedLetters += $driveLetter.ToUpperInvariant()
    }
}
$freeLetters = @()
foreach ($code in 90..68) {
    $letter = ([char]$code).ToString()
    if ($letter -notin $usedLetters) {
        $freeLetters += $letter
    }
}
if ($freeLetters.Count -lt 2) {
    throw 'The test requires two free drive letters.'
}
$Ansible.Changed = $false
Write-Output $freeLetters[0]
Write-Output $freeLetters[1]
