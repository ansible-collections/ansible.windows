#!powershell

# Copyright: (c) 2026, Hen Yaish (hyaish@redhat.com)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -OSVersion 6.2

Set-StrictMode -Version 2

$spec = @{
    options = @{
        disk_number = @{ type = "int" }
        uniqueid = @{ type = "str" }
        path = @{ type = "str" }
    }
    mutually_exclusive = @(
        , @('disk_number', 'uniqueid', 'path')
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$disk_number = $module.Params.disk_number
$uniqueid = $module.Params.uniqueid
$path = $module.Params.path

$module.Result.disks = @()

try {
    if ($null -ne $disk_number) {
        $disks = @(Get-Disk -Number $disk_number -ErrorAction Stop)
    }
    elseif ($null -ne $uniqueid) {
        $disks = @(Get-Disk -UniqueId $uniqueid -ErrorAction Stop)
    }
    elseif ($null -ne $path) {
        $disks = @(Get-Disk -Path $path -ErrorAction Stop)
    }
    else {
        $disks = @(Get-Disk -ErrorAction Stop)
    }
}
catch {
    $module.FailJson("Failed to retrieve disk information: $($_.Exception.Message)", $_)
}

foreach ($disk in $disks) {
    $disk_info = @{
        number = $disk.Number
        friendly_name = $disk.FriendlyName
        unique_id = $disk.UniqueId
        path = $disk.Path
        partition_style = $disk.PartitionStyle.ToString()
        operational_status = $disk.OperationalStatus.ToString()
        health_status = $disk.HealthStatus.ToString()
        bus_type = $disk.BusType.ToString()
        size = $disk.Size
        allocated_size = $disk.AllocatedSize
        is_offline = $disk.IsOffline
        is_read_only = $disk.IsReadOnly
        is_system = $disk.IsSystem
        is_boot = $disk.IsBoot
        number_of_partitions = $disk.NumberOfPartitions
    }

    $module.Result.disks += $disk_info
}

$module.ExitJson()
