param($DiskNumber)
$disk = Get-Disk -Number $DiskNumber -ErrorAction Stop
if ($disk.PartitionStyle -ne 'GPT') {
    throw "Expected GPT partition style, found '$($disk.PartitionStyle)'."
}
$Ansible.Changed = $false
