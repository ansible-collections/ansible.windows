$Ansible.Changed = $false
$supported = $null -ne (Get-Command -Name Format-Volume -ErrorAction SilentlyContinue)
$reservedLetters = @()

if ($supported) {
    foreach ($command in 'Get-Volume', 'Get-Partition', 'Get-DiskImage', 'Dismount-DiskImage', 'diskpart.exe') {
        $null = Get-Command -Name $command -ErrorAction Stop
    }
    if ((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).DomainRole -ge 4) {
        throw 'Storage integration must not run on a domain controller.'
    }
    if (@(Get-StorageJob -ErrorAction Stop).Count -gt 0 -or @(Get-Process -Name diskpart -ErrorAction SilentlyContinue).Count -gt 0) {
        throw 'Another storage operation is active. Run the storage integration targets serially.'
    }
    # A letter may belong to an unformatted partition or mapped drive without appearing in Get-Volume.
    $reservedLetters = @(
        Get-Partition -ErrorAction Stop | Where-Object DriveLetter | ForEach-Object { [string]$_.DriveLetter }
        Get-PSDrive -PSProvider FileSystem -ErrorAction Stop | Where-Object { $_.Name -match '^[A-Za-z]$' } |
            ForEach-Object { $_.Name }
    )
    $reservedLetters = @($reservedLetters | ForEach-Object { $_.ToUpperInvariant() } | Sort-Object -Unique)
}

$Ansible.Result = @{
    supported = $supported
    reserved_letters = @($reservedLetters)
}
