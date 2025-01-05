#!powershell

# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        drive = @{ type = "str" }
        initial_size = @{ type = "int" ; default = 0 }
        maximum_size = @{ type = "int" ; default = 0 }
        automatic = @{ type = "bool" }
        remove_all = @{ type = "bool" ; default = $false }
        test_path = @{ type = "bool" ; default = $true }
        state = @{ type = "str" ; default = "query" ; choices = @("present", "absent", "query") }
        override = @{ type = "bool" ; default = $false }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$check_mode = $module.CheckMode

$automatic = $module.Params.automatic
$drive = $module.Params.drive
$full_path = $drive + ":\pagefile.sys"
$initial_size = $module.Params.initial_size
$maximum_size = $module.Params.maximum_size
$remove_all = $module.Params.remove_all
$state = $module.Params.state
$test_path = $module.Params.test_path
$override = $module.Params.override


$module.result.changed = $false

Function Remove-Pagefile {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        $path
    )
    Get-CIMInstance Win32_PageFileSetting | Where-Object { $_.Name -eq $path } | ForEach-Object {
        if ($PSCmdlet.ShouldProcess($Path, "remove pagefile")) {
            $_ | Remove-CIMInstance
        }
    }
}

Function Get-Pagefile($path) {
    Get-CIMInstance Win32_PageFileSetting | Where-Object { $_.Name -eq $path }
}


Function Set-RegistryWorkaround {
    param(
        [string]$full_path,
        [int]$initial_size,
        [int]$maximum_size,
        [string]$reg_path,
        [string]$exception_message,
        [switch]$check_mode
    )
    $result = @{
        succeeded = $false
    }
    try {
        Remove-Pagefile $full_path -whatif:$check_mode
    }
    catch {
        $result.msg = "Failed to remove pagefile before workaround: $($_.Exception.Message). Original exception: $exception_message"
        return $result
    }
    try {
        $pagingFilesValues = (Get-ItemProperty -LiteralPath $reg_path).PagingFiles
    }
    catch {
        $result.msg = "Failed to get pagefile settings from the registry: $($_.Exception.Message). Original exception: $exception_message"
        return $result
    }
    $pagingFilesValues += "$full_path $initial_size $maximum_size"
    try {
        Set-ItemProperty -LiteralPath $reg_path -Name "PagingFiles" -Value $pagingFilesValues
    }
    catch {
        $result.msg = "Failed to set pagefile settings in the registry: $($_.Exception.Message). Original exception: $exception_message"
        return $result
    }

    $result.succeeded = $true
    return $result
}

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"

if ($remove_all) {
    $current_page_file = Get-CIMInstance Win32_PageFileSetting
    if ($null -ne $current_page_file) {
        $current_page_file | Remove-CIMInstance -WhatIf:$check_mode > $null
        $module.result.changed = $true
    }
}

if ($null -ne $automatic) {
    # change autmoatic managed pagefile
    try {
        $computer_system = Get-CIMInstance -Class win32_computersystem
    }
    catch {
        $module.FailJson("Failed to query WMI computer system object", $_.Exception.Message )
    }
    if ($computer_system.AutomaticManagedPagefile -ne $automatic) {
        if (-not $check_mode) {
            try {
                $computer_system | Set-CimInstance -Property @{automaticmanagedpagefile = "$automatic" } > $null
            }
            catch {
                $module.FailJson("Failed to set AutomaticManagedPagefile", $_.Exception.Message )
            }
        }
        $module.result.changed = $true
    }
}

if ($state -eq "absent") {
    # Remove pagefile
    if ($null -ne (Get-Pagefile $full_path)) {
        try {
            Remove-Pagefile $full_path -whatif:$check_mode
        }
        catch {
            $module.FailJson("Failed to remove pagefile", $_.Exception.Message )
        }
        $module.result.changed = $true
    }
}

elseif ($state -eq "present") {
    # Make sure drive is accessible
    if (($test_path) -and (-not (Test-Path -LiteralPath "${drive}:"))) {
        $module.FailJson("Unable to access '${drive}:' drive")
    }
    $cur_page_file = Get-Pagefile $full_path
    # Set pagefile from scratch
    if ($null -eq $cur_page_file) {
        try {
            $pagefile = New-CIMInstance -Class Win32_PageFileSetting -Arguments @{name = $full_path; } -WhatIf:$check_mode
        }
        catch {
            $module.FailJson("Failed to create pagefile", $_.Exception.Message )
        }
        if (-not $check_mode) {
            try {
                $pagefile | Set-CimInstance -Property @{ InitialSize = $initial_size; MaximumSize = $maximum_size }
            }
            catch {
                $exception_message = $_.Exception.Message
                $result = Set-RegistryWorkaround -full_path $full_path -initial_size $initial_size
                -maximum_size $maximum_size -reg_path $regPath -exception_message $exception_message -check_mode:$check_mode
                if (-not $result.succeeded) {
                    $module.FailJson($result.msg)
                }
            }
        }
        $module.result.changed = $true
    }
    # pagefile to be changed
    else {
        if ((-not $check_mode) -and
            ( ($cur_page_file.InitialSize -ne $initial_size) -or ($cur_page_file.maximumSize -ne $maximum_size) )
        ) {
            $cur_page_file.InitialSize = $initial_size
            $cur_page_file.MaximumSize = $maximum_size
            try {
                $cur_page_file.Put() | out-null
            }
            catch {
                $exception_message = $_.Exception.Message
                $result = Set-RegistryWorkaround -full_path $full_path -initial_size $initial_size
                -maximum_size $maximum_size -reg_path $regPath -exception_message $exception_message -check_mode:$check_mode
                if (-not $result.succeeded) {
                    $module.FailJson($result.msg)
                }
            }
            $module.result.changed = $true
        }
    }
}
else {
    $module.result.pagefiles = @()
    if ($null -eq $drive) {
        try {
            $pagefiles = Get-CIMInstance Win32_PageFileSetting
        }
        catch {
            $module.FailJson("Failed to query all pagefiles", $_.Exception.Message )
        }
    }
    else {
        try {
            $pagefiles = Get-Pagefile $full_path
        }
        catch {
            $module.FailJson("Failed to query specific pagefile", $_.Exception.Message )
        }
    }
    # Get all pagefiles
    foreach ($currentPagefile in $pagefiles) {
        $currentPagefileObject = @{
            name = $currentPagefile.Name
            initial_size = $currentPagefile.InitialSize
            maximum_size = $currentPagefile.MaximumSize
            caption = $currentPagefile.Caption
            description = $currentPagefile.Description
        }
        $module.result.pagefiles += , $currentPagefileObject
    }
    # Get automatic managed pagefile state
    try {
        $module.result.automatic_managed_pagefiles = (Get-CIMInstance -Class win32_computersystem).AutomaticManagedPagefile
    }
    catch {
        $module.FailJson("Failed to query automatic managed pagefile state", $_.Exception.Message )
    }
}
$module.ExitJson()
