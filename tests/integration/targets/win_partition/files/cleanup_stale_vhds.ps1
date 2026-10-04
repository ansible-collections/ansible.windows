# Only recover exact test images that have been untouched for at least a day.
# Recently modified VHDs may belong to another active integration run.
$staleBeforeUtc = [DateTime]::UtcNow.AddDays(-1)
$testVhdNames = @('AnsiblePart.vhdx', 'AnsibleWinPartitionTest.vhdx')
$tempDirParams = @{
    LiteralPath = $env:TEMP
    Directory = $true
    ErrorAction = 'Stop'
}
$tempDirectories = @(Get-ChildItem @tempDirParams)
$testDirectories = @(
    $tempDirectories | Where-Object { $_.Name -like 'ansible.*.test' }
)

foreach ($directory in $testDirectories) {
    $childItemParams = @{
        LiteralPath = $directory.FullName
        File = $true
        ErrorAction = 'SilentlyContinue'
    }
    $testVhds = @(
        Get-ChildItem @childItemParams |
            Where-Object {
                $_.Name -in $testVhdNames -and
                $_.LastWriteTimeUtc -lt $staleBeforeUtc
            }
    )
    foreach ($vhd in $testVhds) {
        $imageParams = @{
            ImagePath = $vhd.FullName
            ErrorAction = 'Stop'
        }
        $diskImage = Get-DiskImage @imageParams
        if ($diskImage -and $diskImage.Attached) {
            $disk = $diskImage | Get-Disk -ErrorAction Stop
            $partitions = @(
                Get-Partition -ErrorAction Stop |
                    Where-Object { $_.DiskNumber -eq $disk.Number }
            )
            foreach ($partition in $partitions) {
                $removeParams = @{
                    InputObject = $partition
                    Confirm = $false
                    ErrorAction = 'Stop'
                }
                Remove-Partition @removeParams | Out-Null
            }

            $dismountParams = @{
                ImagePath = $vhd.FullName
                ErrorAction = 'Stop'
            }
            Dismount-DiskImage @dismountParams | Out-Null
        }

        $diskImage = Get-DiskImage @imageParams
        if ($diskImage -and $diskImage.Attached) {
            throw "Unable to detach stale test VHD '$($vhd.FullName)'."
        }

        $removeFileParams = @{
            LiteralPath = $vhd.FullName
            Force = $true
            ErrorAction = 'Stop'
        }
        Remove-Item @removeFileParams
        if (Test-Path -LiteralPath $vhd.FullName) {
            throw "Unable to remove stale test VHD '$($vhd.FullName)'."
        }
    }
}
$Ansible.Changed = $false
