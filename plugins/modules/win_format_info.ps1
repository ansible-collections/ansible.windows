#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -OSVersion 6.2
#AnsibleRequires -PowerShell ..module_utils.Volume

Set-StrictMode -Version 2

$ErrorActionPreference = "Stop"

$spec = @{
    options = @{
        drive_letter = @{ type = "str" }
        path = @{ type = "str" }
        label = @{ type = "str" }
    }
    mutually_exclusive = @(
        , @('drive_letter', 'path', 'label')
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$drive_letter = $module.Params.drive_letter
$path = $module.Params.path
$label = $module.Params.label

if ($null -ne $drive_letter -and $drive_letter -notmatch "^[a-zA-Z]$") {
    $module.FailJson("The parameter drive_letter should be a single character A-Z")
}

try {
    $volume_selector = @{}
    if ($module.Params.ContainsKey('drive_letter') -and $null -ne $drive_letter) {
        $volume_selector.DriveLetter = $drive_letter
    }
    if ($module.Params.ContainsKey('path') -and $null -ne $path) {
        $volume_selector.Path = $path
    }
    if ($module.Params.ContainsKey('label') -and $null -ne $label) {
        $volume_selector.Label = $label
    }

    if ($volume_selector.Count -eq 0) {
        $volumes = @(Get-AnsibleWinFormatVolume -AllVolumes)
    }
    else {
        $volumes = @(Get-AnsibleWinFormatVolume @volume_selector)
    }
}
catch {
    $module.FailJson("There was an error retrieving volume information: $($_.Exception.Message)", $_)
}

$module.Result.exists = $volumes.Count -gt 0
$module.Result.volumes = @(
    foreach ($volume in $volumes) {
        try {
            $allocation_unit_size = Get-AnsibleWinFormatAllocationUnitSize -Volume $volume
        }
        catch {
            $module.FailJson("There was an error retrieving volume allocation unit size: $($_.Exception.Message)", $_)
        }

        [Ordered]@{
            allocation_unit_size = $allocation_unit_size
            drive_letter = $volume.DriveLetter
            drive_type = if ($null -ne $volume.DriveType) { $volume.DriveType.ToString() } else { $null }
            file_system = $volume.FileSystem
            file_system_label = $volume.FileSystemLabel
            health_status = if ($null -ne $volume.HealthStatus) { $volume.HealthStatus.ToString() } else { $null }
            operational_status = @($volume.OperationalStatus | Where-Object { $null -ne $_ } | ForEach-Object { $_.ToString() })
            path = $volume.Path
            size = $volume.Size
            size_remaining = $volume.SizeRemaining
        }
    }
)

$module.ExitJson()
