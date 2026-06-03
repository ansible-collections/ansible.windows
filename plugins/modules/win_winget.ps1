#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        id = @{ type = "str" }
        name = @{ type = "str" }
        version = @{ type = "str" }
        source = @{ type = "str" }
        scope = @{ type = "str"; choices = @("user", "machine") }
        state = @{ type = "str"; default = "present"; choices = @("absent", "present", "latest") }
        allow_reboot = @{ type = "bool"; default = $false }
        architecture = @{ type = "str"; choices = @("x64", "x86", "arm64") }
        override = @{ type = "str" }
        custom = @{ type = "str" }
    }
    required_one_of = @(
        , @("id", "name")
    )
    mutually_exclusive = @(
        , @("override", "custom")
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$id = $module.Params.id
$name = $module.Params.name
$version = $module.Params.version
$source = $module.Params.source
$scope = $module.Params.scope
$state = $module.Params.state
$allowReboot = $module.Params.allow_reboot
$architecture = $module.Params.architecture
$override = $module.Params.override
$custom = $module.Params.custom

$module.Result.changed = $false
$module.Result.reboot_required = $false
$module.Result.rc = 0

Function Find-WingetPath {
    <#
    .SYNOPSIS
        Locate the winget.exe binary, handling non-interactive sessions.
    #>
    [CmdletBinding()]
    param()

    # Try PATH first
    $wingetCmd = Get-Command -Name winget.exe -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        return $wingetCmd.Source
    }

    # In non-interactive sessions (WinRM/SYSTEM), winget may not be in PATH.
    # Search known locations. Use Resolve-Path for wildcard patterns then
    # Get-Item -LiteralPath for the resolved paths.
    $literalPaths = @(
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\winget.exe"
    )
    $wildcardDirs = @(
        "$env:ProgramFiles\WindowsApps"
        "C:\Program Files\WindowsApps"
    )

    foreach ($literalPath in $literalPaths) {
        if (Test-Path -LiteralPath $literalPath) {
            return $literalPath
        }
    }

    foreach ($searchDir in $wildcardDirs) {
        if (-not (Test-Path -LiteralPath $searchDir)) {
            continue
        }
        $appDirs = [System.IO.Directory]::GetDirectories($searchDir, "Microsoft.DesktopAppInstaller_*")
        # Sort descending to get the newest version first
        $appDirs = $appDirs | Sort-Object -Descending
        foreach ($appDir in $appDirs) {
            $candidate = Join-Path -Path $appDir -ChildPath "winget.exe"
            if (Test-Path -LiteralPath $candidate) {
                return $candidate
            }
        }
    }

    return $null
}

Function Invoke-Winget {
    <#
    .SYNOPSIS
        Execute a winget command and return structured output.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]$WingetPath,

        [Parameter(Mandatory)]
        [String[]]$Arguments,

        [Object]$Module
    )

    # Build the command line
    $argList = @($Arguments)

    # Always accept source agreements and disable interactivity
    $argList += '--accept-source-agreements'
    $argList += '--disable-interactivity'

    $commandLine = "& '$WingetPath' $($argList -join ' ')"

    $module.Debug("Executing winget: $commandLine")

    $processInfo = New-Object System.Diagnostics.ProcessStartInfo
    $processInfo.FileName = $WingetPath
    $processInfo.Arguments = $argList -join ' '
    $processInfo.RedirectStandardOutput = $true
    $processInfo.RedirectStandardError = $true
    $processInfo.UseShellExecute = $false
    $processInfo.CreateNoWindow = $true
    # Force UTF-8 output
    $processInfo.EnvironmentVariables["WINGET_RUNNING_AS_SYSTEM"] = "1"
    $processInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $processInfo

    try {
        $null = $process.Start()
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $process.WaitForExit()
    }
    catch {
        $Module.FailJson("Failed to execute winget: $($_.Exception.Message)", $_)
    }

    @{
        ExitCode = $process.ExitCode
        Stdout = $stdout
        Stderr = $stderr
    }
}

Function Get-InstalledPackage {
    <#
    .SYNOPSIS
        Check if a package is installed via winget.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]$WingetPath,

        [String]$Id,

        [String]$Name,

        [String]$Version,

        [Object]$Module
    )

    $listArgs = @('list')

    if ($Id) {
        $listArgs += '--id'
        $listArgs += $Id
        $listArgs += '--exact'
    }
    elseif ($Name) {
        $listArgs += '--name'
        $listArgs += "`"$Name`""
        $listArgs += '--exact'
    }

    $result = Invoke-Winget -WingetPath $WingetPath -Arguments $listArgs -Module $Module

    # Exit code 0 means package found, -1978335212 (APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND) means not found
    if ($result.ExitCode -ne 0) {
        return @{
            Installed = $false
            Id = if ($Id) { $Id } else { $Name }
            Version = $null
            AvailableVersion = $null
        }
    }

    # Parse the text output - winget list produces a position-based table.
    # Strip ANSI escape codes and split on newlines.
    $cleanOutput = $result.Stdout -replace '\x1b\[[0-9;]*m', ''
    $lines = $cleanOutput -split "`r?`n"

    # Winget uses \r (carriage return without newline) for spinner/progress
    # output. This causes progress text to be prepended to actual output lines.
    # Strip everything before the last \r on each line to get the clean content.
    $lines = @(
        foreach ($line in $lines) {
            $lastCR = $line.LastIndexOf("`r")
            if ($lastCR -ge 0) {
                $line.Substring($lastCR + 1)
            }
            else {
                $line
            }
        }
    )

    # Find the header line by looking for common column headers.
    # winget list output: Name  Id  Version  [Available]  Source
    # The separator is a line of dashes immediately after the header.
    $headerIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '\bName\b.*\bId\b.*\bVersion\b') {
            $headerIdx = $i
            break
        }
    }

    if ($headerIdx -lt 0 -or ($headerIdx + 2) -ge $lines.Count) {
        return @{
            Installed = $false
            Id = if ($Id) { $Id } else { $Name }
            Version = $null
            AvailableVersion = $null
        }
    }

    $headerLine = $lines[$headerIdx]

    # Determine column start positions from the header line
    $idIdx = $headerLine.IndexOf('Id')
    $versionIdx = $headerLine.IndexOf('Version')
    $availableIdx = $headerLine.IndexOf('Available')
    $sourceIdx = $headerLine.IndexOf('Source')

    # Find the first non-empty data line after the separator (headerIdx + 1 is the separator)
    $dataLine = $null
    for ($i = $headerIdx + 2; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim()) {
            $dataLine = $lines[$i]
            break
        }
    }

    if (-not $dataLine) {
        return @{
            Installed = $false
            Id = if ($Id) { $Id } else { $Name }
            Version = $null
            AvailableVersion = $null
        }
    }

    $installedVersion = $null
    $availableVersion = $null
    $packageId = if ($Id) { $Id } else { $Name }

    # Extract package ID
    if ($idIdx -ge 0 -and $idIdx -lt $dataLine.Length) {
        $idEnd = if ($versionIdx -gt $idIdx) { $versionIdx } else { $dataLine.Length }
        $detectedId = $dataLine.Substring($idIdx, [Math]::Min($idEnd - $idIdx, $dataLine.Length - $idIdx)).Trim()
        if ($detectedId) {
            $packageId = $detectedId
        }
    }

    # Extract installed version
    if ($versionIdx -ge 0 -and $versionIdx -lt $dataLine.Length) {
        # Version column ends at Available or Source column, whichever comes first
        $versionEnd = $dataLine.Length
        if ($availableIdx -gt $versionIdx) { $versionEnd = $availableIdx }
        elseif ($sourceIdx -gt $versionIdx) { $versionEnd = $sourceIdx }
        $installedVersion = $dataLine.Substring($versionIdx, [Math]::Min($versionEnd - $versionIdx, $dataLine.Length - $versionIdx)).Trim()
    }

    # Extract available version (only present when an upgrade exists)
    if ($availableIdx -ge 0 -and $availableIdx -lt $dataLine.Length) {
        $availEnd = if ($sourceIdx -gt $availableIdx) { $sourceIdx } else { $dataLine.Length }
        $rawAvail = $dataLine.Substring($availableIdx, [Math]::Min($availEnd - $availableIdx, $dataLine.Length - $availableIdx)).Trim()
        if ($rawAvail -and $rawAvail -match '^\d') {
            $availableVersion = $rawAvail
        }
    }

    @{
        Installed = $true
        Id = $packageId
        Version = if ($installedVersion) { $installedVersion } else { $null }
        AvailableVersion = if ($availableVersion) { $availableVersion } else { $null }
    }
}

Function Install-WingetPackage {
    <#
    .SYNOPSIS
        Install a package using winget.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]$WingetPath,

        [String]$Id,

        [String]$Name,

        [String]$Version,

        [String]$Source,

        [String]$Scope,

        [String]$Architecture,

        [String]$Override,

        [String]$Custom,

        [Bool]$AllowReboot,

        [Object]$Module
    )

    $installArgs = @('install')

    if ($Id) {
        $installArgs += '--id'
        $installArgs += $Id
        $installArgs += '--exact'
    }
    elseif ($Name) {
        $installArgs += '--name'
        $installArgs += "`"$Name`""
        $installArgs += '--exact'
    }

    if ($Version) {
        $installArgs += '--version'
        $installArgs += $Version
    }

    if ($Source) {
        $installArgs += '--source'
        $installArgs += $Source
    }

    if ($Scope) {
        $installArgs += '--scope'
        $installArgs += $Scope
    }

    if ($Architecture) {
        $installArgs += '--architecture'
        $installArgs += $Architecture
    }

    if ($Override) {
        $installArgs += '--override'
        $installArgs += "`"$Override`""
    }

    if ($Custom) {
        $installArgs += '--custom'
        $installArgs += "`"$Custom`""
    }

    if ($AllowReboot) {
        $installArgs += '--allow-reboot'
    }

    $installArgs += '--accept-package-agreements'
    $installArgs += '--silent'
    # Prevent winget from attempting an upgrade when the package is already installed
    $installArgs += '--no-upgrade'

    $result = Invoke-Winget -WingetPath $WingetPath -Arguments $installArgs -Module $Module

    $Module.Result.rc = $result.ExitCode
    $Module.Result.stdout = $result.Stdout
    $Module.Result.stderr = $result.Stderr

    # winget exit codes:
    # 0 = success
    # -1978335189 (0x8A15002B) = APPINSTALLER_CLI_ERROR_INSTALL_REBOOT_REQUIRED_TO_FINISH
    # -1978335188 (0x8A15002C) = APPINSTALLER_CLI_ERROR_INSTALL_REBOOT_REQUIRED_FOR_INSTALL
    # -1978335185 (0x8A15002F) = APPINSTALLER_CLI_ERROR_INSTALL_REBOOT_INITIATED_BY_INSTALLER
    $rebootCodes = @(-1978335189, -1978335188, -1978335185)

    if ($result.ExitCode -in $rebootCodes) {
        $Module.Result.reboot_required = $true
        return
    }

    if ($result.ExitCode -ne 0) {
        $Module.FailJson("Failed to install package: winget exited with code $($result.ExitCode). stdout: $($result.Stdout). stderr: $($result.Stderr)")
    }
}

Function Update-WingetPackage {
    <#
    .SYNOPSIS
        Upgrade a package using winget.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]$WingetPath,

        [String]$Id,

        [String]$Name,

        [String]$Version,

        [String]$Source,

        [String]$Scope,

        [String]$Architecture,

        [String]$Override,

        [String]$Custom,

        [Bool]$AllowReboot,

        [Object]$Module
    )

    $upgradeArgs = @('upgrade')

    if ($Id) {
        $upgradeArgs += '--id'
        $upgradeArgs += $Id
        $upgradeArgs += '--exact'
    }
    elseif ($Name) {
        $upgradeArgs += '--name'
        $upgradeArgs += "`"$Name`""
        $upgradeArgs += '--exact'
    }

    if ($Version) {
        $upgradeArgs += '--version'
        $upgradeArgs += $Version
    }

    if ($Source) {
        $upgradeArgs += '--source'
        $upgradeArgs += $Source
    }

    if ($Scope) {
        $upgradeArgs += '--scope'
        $upgradeArgs += $Scope
    }

    if ($Architecture) {
        $upgradeArgs += '--architecture'
        $upgradeArgs += $Architecture
    }

    if ($Override) {
        $upgradeArgs += '--override'
        $upgradeArgs += "`"$Override`""
    }

    if ($Custom) {
        $upgradeArgs += '--custom'
        $upgradeArgs += "`"$Custom`""
    }

    $upgradeArgs += '--accept-package-agreements'
    $upgradeArgs += '--silent'

    $result = Invoke-Winget -WingetPath $WingetPath -Arguments $upgradeArgs -Module $Module

    $Module.Result.rc = $result.ExitCode
    $Module.Result.stdout = $result.Stdout
    $Module.Result.stderr = $result.Stderr

    $rebootCodes = @(-1978335189, -1978335188, -1978335185)

    if ($result.ExitCode -in $rebootCodes) {
        $Module.Result.reboot_required = $true
        return
    }

    if ($result.ExitCode -ne 0) {
        $Module.FailJson("Failed to upgrade package: winget exited with code $($result.ExitCode). stdout: $($result.Stdout). stderr: $($result.Stderr)")
    }
}

Function Uninstall-WingetPackage {
    <#
    .SYNOPSIS
        Uninstall a package using winget.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [String]$WingetPath,

        [String]$Id,

        [String]$Name,

        [Object]$Module
    )

    $uninstallArgs = @('uninstall')

    if ($Id) {
        $uninstallArgs += '--id'
        $uninstallArgs += $Id
        $uninstallArgs += '--exact'
    }
    elseif ($Name) {
        $uninstallArgs += '--name'
        $uninstallArgs += "`"$Name`""
        $uninstallArgs += '--exact'
    }

    $uninstallArgs += '--silent'

    $result = Invoke-Winget -WingetPath $WingetPath -Arguments $uninstallArgs -Module $Module

    $Module.Result.rc = $result.ExitCode
    $Module.Result.stdout = $result.Stdout
    $Module.Result.stderr = $result.Stderr

    $rebootCodes = @(-1978335189, -1978335188, -1978335185)

    if ($result.ExitCode -in $rebootCodes) {
        $Module.Result.reboot_required = $true
        return
    }

    if ($result.ExitCode -ne 0) {
        $Module.FailJson("Failed to uninstall package: winget exited with code $($result.ExitCode). stdout: $($result.Stdout). stderr: $($result.Stderr)")
    }
}

# Main logic

# Find winget
$wingetPath = Find-WingetPath
if (-not $wingetPath) {
    $module.FailJson("winget.exe was not found on the target host. Ensure Windows Package Manager is installed.")
}

# Validate winget is functional - use direct process call since --version
# does not accept the extra flags that Invoke-Winget appends
$versionProcessInfo = New-Object System.Diagnostics.ProcessStartInfo
$versionProcessInfo.FileName = $wingetPath
$versionProcessInfo.Arguments = '--version'
$versionProcessInfo.RedirectStandardOutput = $true
$versionProcessInfo.RedirectStandardError = $true
$versionProcessInfo.UseShellExecute = $false
$versionProcessInfo.CreateNoWindow = $true
$versionProcess = New-Object System.Diagnostics.Process
$versionProcess.StartInfo = $versionProcessInfo
try {
    $null = $versionProcess.Start()
    $versionStdout = $versionProcess.StandardOutput.ReadToEnd()
    $null = $versionProcess.StandardError.ReadToEnd()
    $versionProcess.WaitForExit()
    if ($versionProcess.ExitCode -ne 0) {
        $module.FailJson("winget is not functional: exit code $($versionProcess.ExitCode)")
    }
}
catch {
    $module.FailJson("winget is not functional: $($_.Exception.Message)", $_)
}
$module.Debug("winget version: $($versionStdout.Trim())")

# Get current package state
$packageState = Get-InstalledPackage -WingetPath $wingetPath -Id $id -Name $name -Version $version -Module $module

$module.Result.package = @{
    id = $packageState.Id
    version = $packageState.Version
    available_version = $packageState.AvailableVersion
}

$changed = $false

switch ($state) {
    'present' {
        if (-not $packageState.Installed) {
            $changed = $true
            if (-not $module.CheckMode) {
                Install-WingetPackage -WingetPath $wingetPath -Id $id -Name $name `
                    -Version $version -Source $source -Scope $scope `
                    -Architecture $architecture -Override $override -Custom $custom `
                    -AllowReboot $allowReboot -Module $module
            }
        }
        elseif ($version -and $packageState.Version -ne $version) {
            # Specific version requested but different version installed
            $changed = $true
            if (-not $module.CheckMode) {
                Install-WingetPackage -WingetPath $wingetPath -Id $id -Name $name `
                    -Version $version -Source $source -Scope $scope `
                    -Architecture $architecture -Override $override -Custom $custom `
                    -AllowReboot $allowReboot -Module $module
            }
        }
    }

    'absent' {
        if ($packageState.Installed) {
            $changed = $true
            if (-not $module.CheckMode) {
                Uninstall-WingetPackage -WingetPath $wingetPath -Id $id -Name $name -Module $module
            }
        }
    }

    'latest' {
        if (-not $packageState.Installed) {
            # Not installed at all, install it
            $changed = $true
            if (-not $module.CheckMode) {
                Install-WingetPackage -WingetPath $wingetPath -Id $id -Name $name `
                    -Version $version -Source $source -Scope $scope `
                    -Architecture $architecture -Override $override -Custom $custom `
                    -AllowReboot $allowReboot -Module $module
            }
        }
        elseif ($packageState.AvailableVersion) {
            # Installed but an upgrade is available
            $changed = $true
            if (-not $module.CheckMode) {
                Update-WingetPackage -WingetPath $wingetPath -Id $id -Name $name `
                    -Version $version -Source $source -Scope $scope `
                    -Architecture $architecture -Override $override -Custom $custom `
                    -AllowReboot $allowReboot -Module $module
            }
        }
    }
}

# If we made changes and not in check mode, refresh the package state
if ($changed -and -not $module.CheckMode) {
    $newState = Get-InstalledPackage -WingetPath $wingetPath -Id $id -Name $name -Module $module
    $module.Result.package = @{
        id = $newState.Id
        version = $newState.Version
        available_version = $newState.AvailableVersion
    }
}

$module.Result.changed = $changed

$module.ExitJson()
