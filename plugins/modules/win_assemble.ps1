#!powershell

#Requires -Module Ansible.ModuleUtils.Legacy
#Requires -Module Ansible.ModuleUtils.Backup

$ErrorActionPreference = "Stop"

$params = Parse-Args $args -supports_check_mode $true

$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
$diff_mode = Get-AnsibleParam -obj $params -name "_ansible_diff" -type "bool" -default $false

$src = Get-AnsibleParam -obj $params -name "src" -type "path" -failifempty $true
$dest = Get-AnsibleParam -obj $params -name "dest" -type "path" -failifempty $true
$backup = Get-AnsibleParam -obj $params -name "backup" -type "bool" -default $false
$delimiter = Get-AnsibleParam -obj $params -name "delimiter" -type "str" -default $null
$regexp = Get-AnsibleParam -obj $params -name "regexp" -type "str" -default $null
$ignore_hidden = Get-AnsibleParam -obj $params -name "ignore_hidden" -type "bool" -default $false
$header = Get-AnsibleParam -obj $params -name "header" -type "str" -default $null
$footer = Get-AnsibleParam -obj $params -name "footer" -type "str" -default $null

# used in template/copy when dest is the path to a dir and source is a file
$original_basename = Get-AnsibleParam -obj $params -name "_original_basename" -type "str"
if ((Test-Path -LiteralPath $src -PathType Container) -and ($null -ne $original_basename)) {
    $src = Join-Path -Path $src -ChildPath $original_basename
}

$result = @{
    changed = $false
}

function Assemble-Fragments($SrcPath, $Delimiter = $null, $Regexp = $null, $IgnoreHidden = $false, $Header = $null, $Footer = $null, $Remote = $true) {
    $tmp_dest = (New-TemporaryFile).FullName
    $delimit_me = $false
    $sb = [System.Text.StringBuilder]::new()
    $add_newline = $false
    
    # If remote_src = $false and the source is a file, this was already assembled on the remote side
    if (-not $Remote -and (Test-Path -LiteralPath $SrcPath -PathType leaf)) {
        # Convert Unix LF to CRLF
        $content = (Get-Content -LiteralPath $SrcPath -Raw) -Replace "(?<!`r)`n","`r`n"
        # Use WriteAllText so the content is written as UTF-8 without BOM
        [IO.File]::WriteAllText($tmp_dest, $content)
        return $tmp_dest
    }

    if ($Header -ne $null) {
        [void]$sb.Append([Text.RegularExpressions.Regex]::Unescape($Header))
        if ($sb[$sb.Length - 1] -ne "\n") {
            [void]$sb.AppendLine()
        }
    }
    
    if ($Delimiter -ne $null) {
        # un-escape anything like newlines
        $Delimiter = [Text.RegularExpressions.Regex]::Unescape($Delimiter)
    }
    Get-ChildItem -Path $SrcPath -File -Force:(!$IgnoreHidden) | Foreach-Object {
        if ($Regexp -ne $null -and $_.Name -notmatch $Regexp) {
            return
        }
        $content = Get-Content -LiteralPath $_.FullName

        if ($add_newline) {
            [void]$sb.AppendLine()
        }
        if ($delimit_me) {
            if ($Delimiter -ne $null) {
                [void]$sb.Append($Delimiter)
                if ($sb[$sb.Length - 1] -ne "\n") {
                    [void]$sb.AppendLine()
                }
            }
        }

        # Content is split by lines to convert Unix LF to CRLF.
        [void]$sb.Append([String]::Join("\n", $content))
        if ($sb[$sb.Length - 1] -ne "\n") {
            $add_newline = $true
        } else {
            $add_newline = $false
        }
        $delimit_me = $true
    }

    if ($Footer -ne $null) {
        if ($add_newline) {
            [void]$sb.AppendLine()
        }
        [void]$sb.Append([Text.RegularExpressions.Regex]::Unescape($Footer))
    }
    # WriteAllText writes as UTF8NoBOM, regardless of how Powershell is executed.
    # Set-Content as executed under Ansible writes as ASCII by default,
    # and UTF8NoBOM isn't a valid encoding on Powershell 5.
    [IO.File]::WriteAllText($tmp_dest, $sb.ToString())
    return $tmp_dest
}

function Cleanup($Path, $Result = $null) {
    if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path
    }
}

if (-not (Test-Path -Path $src)) {
    Fail-Json $result "Source ($src) does not exist"
}

$path = Assemble-Fragments -SrcPath $src -Delimiter $delimiter -Regexp $regexp -IgnoreHidden $ignore_hidden -Header $header -Footer $footer -Remote $remote_src
$checksum = Get-FileChecksum -path $path
$copy = $true

if (Test-Path -LiteralPath $dest) {
    $target_checksum = Get-FileChecksum -path $dest
    if ($target_checksum -eq $checksum) {
        $copy = $false
    }
}

if ($copy) {
    $before_contents = $null
    $after_contents = $null

    if ($diff_mode) {
        if (Test-Path -LiteralPath $dest) {
            $before_contents = Get-Content -LiteralPath $dest -Raw | Out-String
        }
        $after_contents = Get-Content -LiteralPath $path -Raw | Out-String
    }
    if ($backup) {
        $result.backup_file = Backup-File -path $dest -WhatIf:$check_mode
    }

    Copy-Item -LiteralPath $path -Destination $dest -Force -WhatIf:$check_mode | Out-Null
    $result.changed = $true

    if ($diff_mode) {
        $result.diff = @{
            before = $before_contents
            before_header = $dest
            after = $after_contents
            after_header = $dest
        }
    }
}

$result.checksum = $checksum
$result.dest = $dest
$result.size = (Get-Item -LiteralPath $path).Length
$result.msg = "OK"

Cleanup -Path $path -Result $result

Exit-Json $result
