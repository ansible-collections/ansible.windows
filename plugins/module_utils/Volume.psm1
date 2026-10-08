# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

Function Get-AnsibleWinFormatVolume {
    <#
    .SYNOPSIS
    Gets the volume or volumes that match a drive letter, path, or file system label.

    .PARAMETER DriveLetter
    The drive letter to use when selecting a volume.

    .PARAMETER Path
    The volume path to use when selecting a volume.

    .PARAMETER Label
    The file system label to use when selecting volumes.

    .PARAMETER AllVolumes
    Return all volumes when no selector is provided.
    #>
    [CmdletBinding()]
    param (
        [String]
        $DriveLetter,

        [String]
        $Path,

        [String]
        $Label,

        [Switch]
        $AllVolumes
    )

    if ($PSBoundParameters.ContainsKey('DriveLetter')) {
        # In a Windows failover cluster, filter out volumes from remote nodes. Only local volumes have a disk number.
        $partitions = @(
            Get-Partition -ErrorAction Stop | Where-Object {
                $_.DriveLetter -eq $DriveLetter -and $null -ne $_.DiskNumber
            }
        )
        if ($partitions.Count -eq 0) {
            return
        }

        @(
            foreach ($partition in $partitions) {
                Get-Volume -Partition $partition -ErrorAction Stop
            }
        )
    }
    elseif ($PSBoundParameters.ContainsKey('Path')) {
        # Filter explicitly so missing selectors return no volumes rather than a cmdlet lookup error.
        @(Get-Volume -ErrorAction Stop | Where-Object { $_.Path -eq $Path })
    }
    elseif ($PSBoundParameters.ContainsKey('Label')) {
        @(Get-Volume -ErrorAction Stop | Where-Object { $_.FileSystemLabel -eq $Label })
    }
    elseif ($AllVolumes) {
        @(Get-Volume -ErrorAction Stop)
    }
    else {
        throw "A drive letter, path, label, or AllVolumes selector is required"
    }
}

Function Get-AnsibleWinFormatAllocationUnitSize {
    <#
    .SYNOPSIS
    Gets the allocation unit size for a volume.

    .PARAMETER Volume
    The volume to query.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        $Volume
    )

    if ([string]::IsNullOrEmpty($Volume.Path)) {
        return
    }

    $deviceId = $Volume.Path.Replace('\', '\\')
    $cimVolume = Get-CimInstance -ClassName Win32_Volume -Filter "DeviceId = '$deviceId'" -Property BlockSize -ErrorAction Stop |
        Select-Object -First 1

    if ($null -ne $cimVolume) {
        $cimVolume.BlockSize
    }
}

Export-ModuleMember -Function Get-AnsibleWinFormatVolume, Get-AnsibleWinFormatAllocationUnitSize
