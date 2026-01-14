#!powershell

# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy
#AnsibleRequires -PowerShell Ansible.ModuleUtils.AddType

$ErrorActionPreference = "Stop"

$params = Parse-Args $args -supports_check_mode $true

$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -default $false
$_remote_tmp = Get-AnsibleParam $params "_ansible_remote_tmp" -type "path" -default $env:TMP

$access_time = Get-AnsibleParam -obj $params -name "access_time" -type "str"
$access_time_format = Get-AnsibleParam -obj $params -name "access_time_format" -type "str" -default "yyyy-MM-dd HH:mm:ss"
$modification_time = Get-AnsibleParam -obj $params -name "modification_time" -type "str"
$modification_time_format = Get-AnsibleParam -obj $params -name "modification_time_format" -type "str" -default "yyyy-MM-dd HH:mm:ss"
$path = Get-AnsibleParam -obj $params -name "path" -type "path" -failifempty $true -aliases "dest", "name"
$state = Get-AnsibleParam -obj $params -name "state" -type "str" -validateset "absent", "directory", "file", "touch"

# used in template/copy when dest is the path to a dir and source is a file
$original_basename = Get-AnsibleParam -obj $params -name "_original_basename" -type "str"
if ((Test-Path -LiteralPath $path -PathType Container) -and ($null -ne $original_basename)) {
    $path = Join-Path -Path $path -ChildPath $original_basename
}

$result = @{
    changed = $false
}

# Normalize the defaults for access_time and modification_time based on state
if ($state -eq "touch") {
    if ($null -eq $modification_time) {
        $modification_time = "now"
    }
    if ($null -eq $access_time) {
        $access_time = "now"
    }
}
else {
    if ($null -eq $modification_time) {
        $modification_time = "preserve"
    }
    if ($null -eq $access_time) {
        $access_time = "preserve"
    }
}

# var for Update-Timestamp function
$updateTimestamp = @{
    Path = $path
    ModificationTime = $null
    AccessTime = $null
    CheckMode = $check_mode
}

# validate correct values of mtime and atime
if ($access_time -eq "now") {
    $updateTimestamp.AccessTime = [datetime]::SpecifyKind((Get-Date), [System.DateTimeKind]::Local)
}
elseif ($access_time -ne "preserve") {
    try {
        $updateTimestamp.AccessTime = [datetime]::ParseExact($access_time, $access_time_format, $null)
        # normalize parsed timestamp as local time
        $updateTimestamp.AccessTime = [datetime]::SpecifyKind($updateTimestamp.AccessTime, [System.DateTimeKind]::Local)
    }
    catch {
        Fail-Json $result "Invalid access_time '$($access_time)'"
    }
}

if ($modification_time -eq "now") {
    $updateTimestamp.ModificationTime = [datetime]::SpecifyKind((Get-Date), [System.DateTimeKind]::Local)
}
elseif ($modification_time -ne "preserve") {
    try {
        $updateTimestamp.ModificationTime = [datetime]::ParseExact($modification_time, $modification_time_format, $null)
        # normalize parsed timestamp as local time
        $updateTimestamp.ModificationTime = [datetime]::SpecifyKind($updateTimestamp.ModificationTime, [System.DateTimeKind]::Local)
    }
    catch {
        Fail-Json $result "Invalid modification_time '$($modification_time)'"
    }
}

# Used to delete symlinks as powershell cannot delete broken symlinks
Add-CSharpType -TempPath $_remote_tmp -References @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Ansible.Command {
    public class SymLinkHelper {
        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        public static extern bool DeleteFileW(string lpFileName);

        [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        public static extern bool RemoveDirectoryW(string lpPathName);

        public static void DeleteDirectory(string path) {
            if (!RemoveDirectoryW(path))
                throw new Exception(String.Format("RemoveDirectoryW({0}) failed: {1}", path, new Win32Exception(Marshal.GetLastWin32Error()).Message));
        }

        public static void DeleteFile(string path) {
            if (!DeleteFileW(path))
                throw new Exception(String.Format("DeleteFileW({0}) failed: {1}", path, new Win32Exception(Marshal.GetLastWin32Error()).Message));
        }
    }
}
'@

# Used to delete directories and files with logic on handling symbolic links
function Remove-File($file, $checkmode) {
    try {
        if ($file.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            # Bug with powershell, if you try and delete a symbolic link that is pointing
            # to an invalid path it will fail, using Win32 API to do this instead
            if ($file.PSIsContainer) {
                if (-not $checkmode) {
                    [Ansible.Command.SymLinkHelper]::DeleteDirectory($file.FullName)
                }
            }
            else {
                if (-not $checkmode) {
                    [Ansible.Command.SymLinkHelper]::DeleteFile($file.FullName)
                }
            }
        }
        elseif ($file.PSIsContainer) {
            Remove-Directory -directory $file -checkmode $checkmode
        }
        else {
            Remove-Item -LiteralPath $file.FullName -Force -WhatIf:$checkmode
        }
    }
    catch [Exception] {
        Fail-Json $result "Failed to delete $($file.FullName): $($_.Exception.Message)"
    }
}

function Remove-Directory($directory, $checkmode) {
    foreach ($file in Get-ChildItem -LiteralPath $directory.FullName) {
        Remove-File -file $file -checkmode $checkmode
    }
    Remove-Item -LiteralPath $directory.FullName -Force -Recurse -WhatIf:$checkmode
}

function Update-Timestamp {
    param (
        [string]$Path,
        [Nullable[DateTime]]$ModificationTime,
        [Nullable[DateTime]]$AccessTime,
        [bool]$CheckMode
    )
    $changed = $false
    if (Test-Path -LiteralPath $Path) {
        $file = Get-Item -LiteralPath $Path -Force
    }
    try {
        if ($ModificationTime -and $ModificationTime -ne $file.LastWriteTime) {
            if (-not $CheckMode) {
                $file.LastWriteTime = $ModificationTime
            }
            $changed = $true
        }

        if ($AccessTime -and $AccessTime -ne $file.LastAccessTime) {
            if (-not $CheckMode) {
                $file.LastAccessTime = $AccessTime
            }
            $changed = $true
        }
    }
    catch [Exception] {
        Fail-Json $result "Failed to update timestamps on $($Path): $($_.Exception.Message)"
    }
    return $changed
}

if ($state -eq "touch") {
    $newCreation = $false
    if (Test-Path -LiteralPath $path) {
        $result.changed = Update-Timestamp @updateTimestamp
    }
    else {
        Write-Output $null | Out-File -LiteralPath $path -Encoding ASCII -WhatIf:$check_mode
        $newCreation = $true
        $result.changed = $true
    }
    # Bug with powershell, if you try to update the timestamp in same filesystem operation as
    # in creation it will be unable to do so, reason we have to do it in two steps
    if ($newCreation) {
        $timestamp = Update-Timestamp @updateTimestamp
        # OR condition as Update-Timestamp may return false if no timestamps were changed
        # (default now) and we still want to report changed = true due to creation
        $result.changed = ($result.changed -or $timestamp)
    }
}

if (Test-Path -LiteralPath $path) {
    $fileinfo = Get-Item -LiteralPath $path -Force
    if ($state -eq "absent") {
        Remove-File -file $fileinfo -checkmode $check_mode
        $result.changed = $true
    }
    else {
        if ($state -eq "directory" -and -not $fileinfo.PsIsContainer) {
            Fail-Json $result "path $path is not a directory"
        }

        if ($state -eq "file" -and $fileinfo.PsIsContainer) {
            Fail-Json $result "path $path is not a file"
        }
    }

}
else {

    # If state is not supplied, test the $path to see if it looks like
    # a file or a folder and set state to file or folder
    if ($null -eq $state) {
        $basename = Split-Path -Path $path -Leaf
        if ($basename.length -gt 0) {
            $state = "file"
        }
        else {
            $state = "directory"
        }
    }

    if ($state -eq "directory") {
        $newCreation = $false
        if (-not $newCreation) {
            try {
                New-Item -Path $path -ItemType Directory -WhatIf:$check_mode | Out-Null
                $newCreation = $true
            }
            catch {
                if ($_.CategoryInfo.Category -eq "ResourceExists") {
                    $fileinfo = Get-Item -LiteralPath $_.CategoryInfo.TargetName
                    if ($state -eq "directory" -and -not $fileinfo.PsIsContainer) {
                        Fail-Json $result "path $path is not a directory"
                    }
                }
                else {
                    Fail-Json $result $_.Exception.Message
                }
            }
            $result.changed = $true
        }
        if ($newCreation) {
            # similar logic as with state: touch, need to do in two steps
            $timestamp = Update-Timestamp @updateTimestamp
            $result.changed = ($result.changed -or $timestamp)
        }
    }
    elseif ($state -eq "file") {
        Fail-Json $result "path $path will not be created"
    }

}

Exit-Json $result
