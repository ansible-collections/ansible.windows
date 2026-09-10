#!powershell

# Copyright: (c) 2015, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell Ansible.ModuleUtils.Backup
#AnsibleRequires -PowerShell ..module_utils.Process

$spec = @{
    options = @{
        path = @{ type = "path"; required = $true; aliases = @("dest", "destfile", "name") }
        regex = @{ type = "str"; aliases = @("regexp") }
        state = @{ type = "str"; default = "present"; choices = @("absent", "present") }
        line = @{ type = "str" }
        backrefs = @{ type = "bool"; default = $false }
        insertafter = @{ type = "str" }
        insertbefore = @{ type = "str" }
        create = @{ type = "bool"; default = $false }
        backup = @{ type = "bool"; default = $false }
        validate = @{ type = "str" }
        encoding = @{ type = "str"; default = "auto" }
        newline = @{ type = "str"; default = "windows"; choices = @("unix", "windows") }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$path = $module.Params.path
$regex = $module.Params.regex
$state = $module.Params.state
$line = $module.Params.line
$backrefs = $module.Params.backrefs
$insertafter = $module.Params.insertafter
$insertbefore = $module.Params.insertbefore
$create = $module.Params.create
$backup = $module.Params.backup
$validate = $module.Params.validate
$encoding = $module.Params.encoding
$newline = $module.Params.newline

$module.Result.msg = ""

function Write-TargetFile {
    <#
    .SYNOPSIS
    Write the supplied lines to a temporary file, optionally validate it and then commit it to the target path.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory = $true)]
        [Ansible.Basic.AnsibleModule]
        $Module,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        $OutLines,

        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        [Parameter(Mandatory = $true)]
        [String]
        $LineSep,

        [Parameter(Mandatory = $true)]
        [System.Text.Encoding]
        $Encoding,

        [String]
        $Validate
    )

    try {
        $tempPath = [System.IO.Path]::GetTempFileName()
    }
    catch {
        $Module.FailJson("Cannot create temporary file! ($($_.Exception.Message))", $_)
    }

    $joined = $OutLines -join $LineSep

    try {
        [System.IO.File]::WriteAllText($tempPath, $joined, $Encoding)

        if ($Validate) {
            if ($Validate -notlike "*%s*") {
                $Module.FailJson("validate must contain %s: $Validate")
            }

            $commandLine = $Validate.Replace("%s", $tempPath)

            try {
                $res = Start-AnsibleWindowsProcess -CommandLine $commandLine
            }
            catch {
                $Module.FailJson("failed to run validation command '$commandLine': $($_.Exception.Message)", $_)
            }

            if ($res.ExitCode -ne 0) {
                $Module.FailJson("failed to validate $commandLine with error: $($res.Stdout) $($res.Stderr)")
            }
        }

        # Commit changes to the path. Note that we have to clean up the path because Ansible wants to treat / and \
        # as interchangeable in Windows pathnames, but .NET framework internals do not support that.
        $cleanPath = $Path.Replace("/", "\")
        $checkMode = $Module.CheckMode
        try {
            Copy-Item -LiteralPath $tempPath -Destination $cleanPath -Force -WhatIf:$checkMode
        }
        catch {
            $Module.FailJson("Cannot write to: $cleanPath ($($_.Exception.Message))", $_)
        }
    }
    finally {
        # Always remove the temporary file, even in check mode, so that it is not left behind on the remote host.
        Remove-Item -LiteralPath $tempPath -Force -ErrorAction SilentlyContinue
    }

    $joined
}

function Get-TargetEncoding {
    <#
    .SYNOPSIS
    Determine the encoding used to read from and write to the target file.
    #>
    [CmdletBinding()]
    [OutputType([System.Text.Encoding])]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        [Parameter(Mandatory = $true)]
        [String]
        $Encoding
    )

    # The default encoding is UTF-8 without a BOM.
    $encodingObj = [System.Text.UTF8Encoding]$false

    # If an explicit encoding is specified, use that instead.
    if ($Encoding -ne "auto") {
        return [System.Text.Encoding]::GetEncoding($Encoding)
    }

    # Otherwise see if we can determine the current encoding of the target file. If the file doesn't exist yet
    # (create=true) we use the default encoding set above.
    if (-not (Test-Path -LiteralPath $Path)) {
        return $encodingObj
    }

    # Get a sorted list of encodings with preambles, longest first.
    $maxPreambleLength = 0
    $sortedList = New-Object -TypeName System.Collections.SortedList
    foreach ($encodingInfo in [System.Text.Encoding]::GetEncodings()) {
        $candidate = $encodingInfo.GetEncoding()
        $preambleLength = $candidate.GetPreamble().Length
        if ($preambleLength -gt $maxPreambleLength) {
            $maxPreambleLength = $preambleLength
        }
        if ($preambleLength -gt 0) {
            # Negate the key so that the longest preamble is checked first.
            $sortKey = ($preambleLength * 1000000 + $candidate.CodePage) * -1
            $sortedList.Add($sortKey, $candidate) > $null
        }
    }

    # Get the first N bytes from the file, where N is the max preamble length we saw.
    $bom = [byte[]]@()
    $fs = $null
    try {
        $fs = [System.IO.File]::Open(
            $Path.Replace("/", "\"),
            [System.IO.FileMode]::Open,
            [System.IO.FileAccess]::Read,
            [System.IO.FileShare]::ReadWrite)
        $buffer = New-Object -TypeName byte[] -ArgumentList $maxPreambleLength
        $read = $fs.Read($buffer, 0, $maxPreambleLength)
        if ($read -gt 0) {
            $bom = $buffer[0..($read - 1)]
        }
    }
    finally {
        if ($fs) {
            $fs.Dispose()
        }
    }

    # Iterate through the sorted encodings, looking for a full match.
    foreach ($candidate in $sortedList.GetValueList()) {
        $preamble = $candidate.GetPreamble()
        if (-not $preamble -or -not $bom -or $preamble.Length -gt $bom.Length) {
            continue
        }

        $isMatch = $true
        foreach ($idx in 0..($preamble.Length - 1)) {
            if ($preamble[$idx] -ne $bom[$idx]) {
                $isMatch = $false
                break
            }
        }
        if ($isMatch) {
            return $candidate
        }
    }

    $encodingObj
}

function Set-TargetLine {
    <#
    .SYNOPSIS
    Implements the functionality for state=present.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Ansible.Basic.AnsibleModule]
        $Module,

        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        [String]
        $Regex,

        [String]
        $Line,

        [String]
        $InsertAfter,

        [String]
        $InsertBefore,

        [bool]
        $Create,

        [bool]
        $Backup,

        [bool]
        $Backrefs,

        [String]
        $Validate,

        [Parameter(Mandatory = $true)]
        [System.Text.Encoding]
        $Encoding,

        [Parameter(Mandatory = $true)]
        [String]
        $LineSep
    )

    # Note that we have to clean up the path because Ansible wants to treat / and \ as interchangeable in Windows
    # pathnames, but .NET framework internals do not support that.
    $cleanPath = $Path.Replace("/", "\")
    $endsWithNewline = $null

    # Check if path exists. If it does not exist, either create it if create=true was specified or fail with a
    # reasonable error message.
    if (-not (Test-Path -LiteralPath $Path)) {
        if (-not $Create) {
            $Module.FailJson("Path $Path does not exist !")
        }
        # Create a new empty file, using the specified encoding to write the correct BOM.
        [System.IO.File]::WriteAllLines($cleanPath, "", $Encoding)
        $endsWithNewline = $false
    }

    if ($InsertBefore -and $InsertAfter) {
        $Module.Warn("Both insertbefore and insertafter parameters found, ignoring `"insertafter=$InsertAfter`"")
    }

    # Read the dest file lines using the indicated encoding into a mutable ArrayList.
    $before = [System.IO.File]::ReadAllLines($cleanPath, $Encoding)
    if ($null -eq $before) {
        $lines = New-Object -TypeName System.Collections.ArrayList
    }
    else {
        $lines = [System.Collections.ArrayList]$before
        if ($null -eq $endsWithNewline) {
            $allText = [System.IO.File]::ReadAllText($cleanPath, $Encoding)
            $endsWithNewline = (($allText[-1] -eq "`n") -or ($allText[-1] -eq "`r"))
        }
    }

    if ($Module.DiffMode) {
        if ($endsWithNewline) {
            $before += ""
        }
        $Module.Diff.before = $before -join $LineSep
    }

    # Compile the regex specified, if provided.
    $mre = $null
    if ($Regex) {
        $mre = [regex]::new($Regex, [System.Text.RegularExpressions.RegexOptions]::Compiled)
    }

    # Compile the regex for insertafter or insertbefore, if provided.
    $insre = $null
    if ($InsertAfter -and $InsertAfter -ne "BOF" -and $InsertAfter -ne "EOF") {
        $insre = [regex]::new($InsertAfter, [System.Text.RegularExpressions.RegexOptions]::Compiled)
    }
    elseif ($InsertBefore -and $InsertBefore -ne "BOF") {
        $insre = [regex]::new($InsertBefore, [System.Text.RegularExpressions.RegexOptions]::Compiled)
    }

    # index[0] is the line number where the regex has been found.
    # index[1] is the line number where insertafter/insertbefore has been found.
    $index = -1, -1
    $lineno = 0

    # The most recently matched line.
    $matchedLine = ""

    # Iterate through the lines in the file looking for matches.
    foreach ($curLine in $lines) {
        if ($Regex) {
            $matchFound = $mre.Match($curLine).Success
            if ($matchFound) {
                $matchedLine = $curLine
            }
        }
        else {
            $matchFound = $Line -ceq $curLine
        }

        if ($matchFound) {
            $index[0] = $lineno
        }
        elseif ($insre -and $insre.Match($curLine).Success) {
            if ($InsertAfter) {
                $index[1] = $lineno + 1
            }
            if ($InsertBefore) {
                $index[1] = $lineno
            }
        }
        $lineno = $lineno + 1
    }

    if ($index[0] -ne -1) {
        if ($Backrefs) {
            $newLine = [regex]::Replace($matchedLine, $Regex, $Line)
        }
        else {
            $newLine = $Line
        }
        if ($lines[$index[0]] -cne $newLine) {
            $lines[$index[0]] = $newLine
            $Module.Result.changed = $true
            $Module.Result.msg = "line replaced"
        }
    }
    elseif ($Backrefs) {
        # No matches - no-op
    }
    elseif ($InsertBefore -eq "BOF" -or $InsertAfter -eq "BOF") {
        $lines.Insert(0, $Line)
        $Module.Result.changed = $true
        $Module.Result.msg = "line added"
    }
    elseif ($InsertAfter -eq "EOF" -or $index[1] -eq -1) {
        $lines.Add($Line) > $null
        $Module.Result.changed = $true
        $Module.Result.msg = "line added"
    }
    else {
        $lines.Insert($index[1], $Line)
        $Module.Result.changed = $true
        $Module.Result.msg = "line added"
    }

    # Write changes to the path if changes were made.
    if ($Module.Result.changed) {
        if ($Backup) {
            $checkMode = $Module.CheckMode
            $Module.Result.backup_file = Backup-File -path $Path -WhatIf:$checkMode
        }

        if ($endsWithNewline) {
            $lines.Add("") > $null
        }

        $writeParams = @{
            Module = $Module
            OutLines = $lines
            Path = $Path
            LineSep = $LineSep
            Encoding = $Encoding
            Validate = $Validate
        }
        $after = Write-TargetFile @writeParams

        if ($Module.DiffMode) {
            $Module.Diff.after = $after
        }
    }

    $Module.Result.encoding = $Encoding.WebName
}

function Remove-TargetLine {
    <#
    .SYNOPSIS
    Implements the functionality for state=absent.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Ansible.Basic.AnsibleModule]
        $Module,

        [Parameter(Mandatory = $true)]
        [String]
        $Path,

        [String]
        $Regex,

        [String]
        $Line,

        [bool]
        $Backup,

        [String]
        $Validate,

        [Parameter(Mandatory = $true)]
        [System.Text.Encoding]
        $Encoding,

        [Parameter(Mandatory = $true)]
        [String]
        $LineSep
    )

    # Check if path exists. If it does not exist, fail with a reasonable error message.
    if (-not (Test-Path -LiteralPath $Path)) {
        $Module.FailJson("Path $Path does not exist !")
    }

    # Read the dest file lines using the indicated encoding into a mutable ArrayList. Note that we have to clean up
    # the path because Ansible wants to treat / and \ as interchangeable in Windows pathnames, but .NET framework
    # internals do not support that.
    $cleanPath = $Path.Replace("/", "\")
    $before = [System.IO.File]::ReadAllLines($cleanPath, $Encoding)
    if ($null -eq $before) {
        $lines = New-Object -TypeName System.Collections.ArrayList
    }
    else {
        $lines = [System.Collections.ArrayList]$before
        $allText = [System.IO.File]::ReadAllText($cleanPath, $Encoding)
        if (($allText[-1] -eq "`n") -or ($allText[-1] -eq "`r")) {
            $lines.Add("") > $null
            $before += ""
        }
    }

    if ($Module.DiffMode) {
        $Module.Diff.before = $before -join $LineSep
    }

    # Compile the regex specified, if provided.
    $cre = $null
    if ($Regex) {
        $cre = [regex]::new($Regex, [System.Text.RegularExpressions.RegexOptions]::Compiled)
    }

    $found = New-Object -TypeName System.Collections.ArrayList
    $left = New-Object -TypeName System.Collections.ArrayList

    foreach ($curLine in $lines) {
        if ($Regex) {
            $matchFound = $cre.Match($curLine).Success
        }
        else {
            $matchFound = $Line -ceq $curLine
        }

        if ($matchFound) {
            $found.Add($curLine) > $null
            $Module.Result.changed = $true
        }
        else {
            $left.Add($curLine) > $null
        }
    }

    # Write changes to the path if changes were made.
    if ($Module.Result.changed) {
        if ($Backup) {
            $checkMode = $Module.CheckMode
            $Module.Result.backup_file = Backup-File -path $Path -WhatIf:$checkMode
        }

        $writeParams = @{
            Module = $Module
            OutLines = $left
            Path = $Path
            LineSep = $LineSep
            Encoding = $Encoding
            Validate = $Validate
        }
        $after = Write-TargetFile @writeParams

        if ($Module.DiffMode) {
            $Module.Diff.after = $after
        }
    }

    $Module.Result.encoding = $Encoding.WebName
    $Module.Result.found = $found.Count
    $Module.Result.msg = "$($found.Count) line(s) removed"
}

# Fail if the path is not a file.
if (Test-Path -LiteralPath $path -PathType Container) {
    $module.FailJson("Path $path is a directory")
}

# Default to the windows line separator - probably the most common.
$linesep = "`r`n"
if ($newline -eq "unix") {
    $linesep = "`n"
}

# Figure out the proper encoding to use for reading from / writing to the target file.
$encodingObj = Get-TargetEncoding -Path $path -Encoding $encoding

# Main dispatch - based on the value of 'state', perform argument validation and call the appropriate handler.
if ($state -eq "present") {
    if ($backrefs -and -not $regex) {
        $module.FailJson("regexp= is required with backrefs=true")
    }

    if (-not $line) {
        $module.FailJson("line= is required with state=present")
    }

    if (-not $insertbefore -and -not $insertafter) {
        $insertafter = "EOF"
    }

    $presentParams = @{
        Module = $module
        Path = $path
        Regex = $regex
        Line = $line
        InsertAfter = $insertafter
        InsertBefore = $insertbefore
        Create = $create
        Backup = $backup
        Backrefs = $backrefs
        Validate = $validate
        Encoding = $encodingObj
        LineSep = $linesep
    }
    Set-TargetLine @presentParams
}
else {
    if (-not $regex -and -not $line) {
        $module.FailJson("one of line= or regexp= is required with state=absent")
    }

    $absentParams = @{
        Module = $module
        Path = $path
        Regex = $regex
        Line = $line
        Backup = $backup
        Validate = $validate
        Encoding = $encodingObj
        LineSep = $linesep
    }
    Remove-TargetLine @absentParams
}

$module.ExitJson()
