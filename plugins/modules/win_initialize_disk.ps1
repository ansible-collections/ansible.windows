#!powershell

# Copyright: (c) 2019, Brant Evans (bevans@redhat.com)
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
        style = @{ type = "str"; choices = "gpt", "mbr"; default = "gpt" }
        online = @{ type = "bool"; default = $true }
        force = @{ type = "bool"; default = $false }
    }
    mutually_exclusive = @(
        , @('disk_number', 'uniqueid', 'path')
    )
    required_one_of = @(
        , @('disk_number', 'uniqueid', 'path')
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$disk_number = $module.Params.disk_number
$uniqueid = $module.Params.uniqueid
$path = $module.Params.path
$partition_style = $module.Params.style
$bring_online = $module.Params.online
$force_init = $module.Params.force

function Get-AnsibleDisk {
    param(
        $DiskNumber,
        $UniqueId,
        $Path
    )

    try {
        if ($null -ne $DiskNumber) {
            return Get-Disk -Number $DiskNumber -ErrorAction Stop
        }
        elseif ($null -ne $UniqueId) {
            return Get-Disk -UniqueId $UniqueId -ErrorAction Stop
        }
        elseif ($null -ne $Path) {
            return Get-Disk -Path $Path -ErrorAction Stop
        }
    }
    catch {
        $module.FailJson("There was an error retrieving the disk: $($_.Exception.Message)", $_)
    }

    $module.FailJson("Unable to retrieve disk: disk_number, id, or path was not specified")
}

function Initialize-AnsibleDisk {
    param(
        $AnsibleDisk,
        $PartitionStyle
    )

    if ($AnsibleDisk.IsReadOnly) {
        $module.FailJson("Unable to initialize disk as it is read-only")
    }

    $parameters = @{
        Number = $AnsibleDisk.Number
        PartitionStyle = $PartitionStyle
    }

    if ((-Not $module.CheckMode) -And -Not ("Offline" -eq $AnsibleDisk.OperationalStatus)) {
        Initialize-Disk @parameters -Confirm:$false
    }

    $module.Result.changed = $true
}

function Clear-AnsibleDisk {
    param(
        $AnsibleDisk
    )

    $parameters = @{
        Number = $AnsibleDisk.Number
    }

    if (-Not $module.CheckMode) {
        Clear-Disk @parameters -RemoveData -RemoveOEM -Confirm:$false
    }
}

function Set-AnsibleDiskOnline {
    param(
        $AnsibleDisk,
        $BringOnline
    )

    if ($BringOnline -And -Not $module.CheckMode) {
        if ($AnsibleDisk.IsOffline) {
            Set-Disk -Number $AnsibleDisk.Number -IsOffline:$false
        }

        if ($AnsibleDisk.IsReadOnly) {
            Set-Disk -Number $AnsibleDisk.Number -IsReadOnly:$false
        }
    }
}

$ansible_disk = Get-AnsibleDisk -DiskNumber $disk_number -UniqueId $uniqueid -Path $path
$ansible_part_style = $ansible_disk.PartitionStyle.ToString()

if (("RAW" -eq $ansible_part_style) -Or ("Offline" -eq $ansible_disk.OperationalStatus)) {
    Set-AnsibleDiskOnline -AnsibleDisk $ansible_disk -BringOnline $bring_online
    Initialize-AnsibleDisk -AnsibleDisk $ansible_disk -PartitionStyle $partition_style
}
else {
    if (($ansible_part_style -ne $partition_style.ToUpper()) -And -Not $force_init) {
        $msg = -join @(
            "Force initialization must be specified since the target partition style: $($partition_style.ToLower()) "
            "is different from the current partition style: $($ansible_part_style.ToLower())"
        )
        $module.FailJson($msg)
    }
    elseif ($force_init) {
        Set-AnsibleDiskOnline -AnsibleDisk $ansible_disk -BringOnline $bring_online
        Clear-AnsibleDisk -AnsibleDisk $ansible_disk
        if ($bring_online) {
            Initialize-AnsibleDisk -AnsibleDisk $ansible_disk -PartitionStyle $partition_style
        }
    }
}

$module.ExitJson()
