$Ansible.Changed = $false
foreach ($command in 'Get-Disk', 'Get-Partition', 'Get-Volume', 'Get-PhysicalDisk', 'Get-VirtualDisk',
    'Get-CimAssociatedInstance', 'Get-DiskImage', 'Dismount-DiskImage', 'diskpart.exe') {
    $null = Get-Command -Name $command -ErrorAction Stop
}
if ((Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop).DomainRole -ge 4) {
    throw 'Disk integration fixtures must not be created on a domain controller.'
}
if (@(Get-StorageJob -ErrorAction Stop).Count -gt 0 -or @(Get-Process -Name diskpart -ErrorAction SilentlyContinue).Count -gt 0) {
    throw 'Another storage operation is active. Run storage integration targets serially.'
}

