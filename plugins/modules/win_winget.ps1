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
        scope = @{ type = "str"; choices = @("machine", "user") }
        state = @{ type = "str"; default = "present"; choices = @("absent", "present", "latest") }
        override_args = @{ type = "str" }
        accept_source_agreements = @{ type = "bool"; default = $true }
        accept_package_agreements = @{ type = "bool"; default = $true }
        force = @{ type = "bool"; default = $false }
    }
    mutually_exclusive = @(
        , @("id", "name")
    )
    required_one_of = @(
        , @("id", "name")
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
$overrideArgs = $module.Params.override_args
$acceptSourceAgreements = $module.Params.accept_source_agreements
$acceptPackageAgreements = $module.Params.accept_package_agreements
$force = $module.Params.force

$module.Result.changed = $false
$module.Result.rc = 0
$module.Result.reboot_required = $false

Function Find-WingetPath {
    <#
    .SYNOPSIS
    Locates the winget executable path.
    When running under SYSTEM (WinRM), winget is not on PATH so we must
    resolve it from the WindowsApps directory or the DesktopAppInstaller
    package.
    #>

    # First try the standard PATH
    $wingetCmd = Get-Command -Name winget.exe -ErrorAction SilentlyContinue
    if ($wingetCmd) {
        return $wingetCmd.Source
    }

    # When running as SYSTEM we need to resolve the path manually
    # Check the WindowsApps directory for the DesktopAppInstaller package
    $windowsAppsPath = Join-Path -Path $env:ProgramFiles -ChildPath "WindowsApps"
    if (Test-Path -LiteralPath $windowsAppsPath) {
        $wingetDirs = @(
            Get-ChildItem -LiteralPath $windowsAppsPath -Directory `
                -Filter "Microsoft.DesktopAppInstaller_*" `
                -ErrorAction SilentlyContinue |
                Sort-Object Name -Descending
        )

        foreach ($dir in $wingetDirs) {
            $wingetExe = Join-Path -Path $dir.FullName -ChildPath "winget.exe"
            if (Test-Path -LiteralPath $wingetExe) {
                return $wingetExe
            }
        }
    }

    # Try the well-known alias path used in newer Windows builds
    $localAppData = [System.Environment]::GetFolderPath('LocalApplicationData')
    if ($localAppData) {
        $wingetExe = Join-Path -Path $localAppData -ChildPath "Microsoft\WindowsApps\winget.exe"
        if (Test-Path -LiteralPath $wingetExe) {
            return $wingetExe
        }
    }

    return $null
}

Function Invoke-WingetCommand {
    <#
    .SYNOPSIS
    Executes a winget command and returns the result.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [String]$WingetPath,

        [Parameter(Mandatory = $true)]
        [String[]]$Arguments,

        [Object]$Module
    )

    $pinfo = New-Object System.Diagnostics.ProcessStartInfo
    $pinfo.FileName = $WingetPath
    $pinfo.Arguments = $Arguments -join ' '
    $pinfo.RedirectStandardOutput = $true
    $pinfo.RedirectStandardError = $true
    $pinfo.UseShellExecute = $false
    $pinfo.CreateNoWindow = $true

    # Ensure UTF-8 encoding for output
    $pinfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $pinfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $pinfo

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
    Checks if a package is currently installed via winget.
    Returns package info if installed, $null if not.
    #>
    param (
        [Parameter(Mandatory = $true)]
        [String]$WingetPath,

        [String]$Id,

        [String]$Name,

        [Object]$Module
    )

    $listArgs = [System.Collections.Generic.List[String]]@("list")

    if ($Id) {
        $listArgs.Add("--id")
        $listArgs.Add($Id)
        $listArgs.Add("--exact")
    }
    elseif ($Name) {
        $listArgs.Add("--name")
        $listArgs.Add($Name)
        $listArgs.Add("--exact")
    }

    $listArgs.Add("--accept-source-agreements")
    $listArgs.Add("--disable-interactivity")

    $result = Invoke-WingetCommand -WingetPath $WingetPath -Arguments $listArgs -Module $Module

    # winget list exit code 0 means packages were found
    # exit code -1978335212 (APPINSTALLER_CLI_ERROR_NO_APPLICATIONS_FOUND) means not installed
    if ($result.ExitCode -ne 0) {
        return $null
    }

    # Parse the tabular output from winget list
    # The output format has header lines with dashes, then data rows
    $lines = $result.Stdout -split "`n" | ForEach-Object { $_.TrimEnd() } | Where-Object { $_ -ne "" }

    # Find the separator line (contains dashes)
    $separatorIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^[-\s]+$' -and $lines[$i] -match '-') {
            $separatorIndex = $i
            break
        }
    }

    if ($separatorIndex -lt 1 -or $separatorIndex -ge ($lines.Count - 1)) {
        return $null
    }

    $headerLine = $lines[$separatorIndex - 1]
    $dataLine = $lines[$separatorIndex + 1]
    $dataLen = $dataLine.Length

    # Parse column positions from the header line
    # Common columns: Name, Id, Version, Available, Source
    $idPos = $headerLine.IndexOf("Id")
    $versionPos = $headerLine.IndexOf("Version")
    $availablePos = $headerLine.IndexOf("Available")
    $sourcePos = $headerLine.IndexOf("Source")

    if ($idPos -lt 0 -or $versionPos -lt 0) {
        return $null
    }

    # Helper to safely extract a substring from a line given start and end positions
    # Returns empty string if positions are out of bounds
    $packageId = ""
    $packageVersion = ""
    $availableVersion = ""

    if ($idPos -lt $dataLen) {
        $endPos = if ($versionPos -lt $dataLen) { $versionPos } else { $dataLen }
        $length = [Math]::Min($endPos - $idPos, $dataLen - $idPos)
        if ($length -gt 0) {
            $packageId = $dataLine.Substring($idPos, $length).Trim()
        }
    }

    if ($versionPos -lt $dataLen) {
        # Determine end of version column
        $versionEnd = $dataLen
        if ($availablePos -gt 0 -and $availablePos -lt $dataLen) {
            $versionEnd = $availablePos
        }
        elseif ($sourcePos -gt 0 -and $sourcePos -lt $dataLen) {
            $versionEnd = $sourcePos
        }
        $length = [Math]::Min($versionEnd - $versionPos, $dataLen - $versionPos)
        if ($length -gt 0) {
            $packageVersion = $dataLine.Substring($versionPos, $length).Trim()
        }
    }

    if ($availablePos -gt 0 -and $availablePos -lt $dataLen) {
        $availEnd = $dataLen
        if ($sourcePos -gt 0 -and $sourcePos -gt $availablePos -and $sourcePos -lt $dataLen) {
            $availEnd = $sourcePos
        }
        $length = [Math]::Min($availEnd - $availablePos, $dataLen - $availablePos)
        if ($length -gt 0) {
            $availableVersion = $dataLine.Substring($availablePos, $length).Trim()
        }
    }

    @{
        Id = $packageId
        Version = $packageVersion
        AvailableVersion = $availableVersion
    }
}

# Find winget
$wingetPath = Find-WingetPath
if (-not $wingetPath) {
    $module.FailJson("winget.exe was not found on this system. Ensure Windows Package Manager is installed.")
}

# Get current installed state
$installedPackage = Get-InstalledPackage -WingetPath $wingetPath -Id $id -Name $name -Module $module
$isInstalled = $null -ne $installedPackage

# Build the package identifier for result output
$packageIdentifier = if ($id) { $id } else { $name }

switch ($state) {
    "present" {
        if ($isInstalled) {
            # If a specific version is requested and it differs from installed, we need to act
            if ($version -and $installedPackage.Version -ne $version) {
                if (-not $module.CheckMode) {
                    $installArgs = [System.Collections.Generic.List[String]]@("install")

                    if ($id) {
                        $installArgs.Add("--id")
                        $installArgs.Add($id)
                        $installArgs.Add("--exact")
                    }
                    else {
                        $installArgs.Add("--name")
                        $installArgs.Add("`"$name`"")
                        $installArgs.Add("--exact")
                    }

                    $installArgs.Add("--version")
                    $installArgs.Add($version)
                    $installArgs.Add("--silent")
                    $installArgs.Add("--disable-interactivity")

                    if ($acceptSourceAgreements) { $installArgs.Add("--accept-source-agreements") }
                    if ($acceptPackageAgreements) { $installArgs.Add("--accept-package-agreements") }
                    if ($source) { $installArgs.Add("--source"); $installArgs.Add($source) }
                    if ($scope) { $installArgs.Add("--scope"); $installArgs.Add($scope) }
                    if ($overrideArgs) { $installArgs.Add("--override"); $installArgs.Add("`"$overrideArgs`"") }
                    if ($force) { $installArgs.Add("--force") }

                    $result = Invoke-WingetCommand -WingetPath $wingetPath -Arguments $installArgs -Module $module
                    $module.Result.rc = $result.ExitCode

                    if ($result.ExitCode -notin @(0, 0x8A15002B)) {
                        # 0x8A15002B = reboot required
                        $module.Result.stdout = $result.Stdout
                        $module.Result.stderr = $result.Stderr
                        $module.FailJson("Failed to install package '$packageIdentifier' version '$version': winget returned exit code $($result.ExitCode)")
                    }

                    if ($result.ExitCode -eq 0x8A15002B) {
                        $module.Result.reboot_required = $true
                    }
                }

                $module.Result.changed = $true
                $module.Result.previous_version = $installedPackage.Version
                $module.Result.installed_version = $version
                $module.Result.package_id = if ($id) { $id } elseif ($installedPackage.Id) { $installedPackage.Id } else { $name }
            }
            elseif ($force) {
                # Force reinstall
                if (-not $module.CheckMode) {
                    $installArgs = [System.Collections.Generic.List[String]]@("install")

                    if ($id) {
                        $installArgs.Add("--id")
                        $installArgs.Add($id)
                        $installArgs.Add("--exact")
                    }
                    else {
                        $installArgs.Add("--name")
                        $installArgs.Add("`"$name`"")
                        $installArgs.Add("--exact")
                    }

                    $installArgs.Add("--silent")
                    $installArgs.Add("--force")
                    $installArgs.Add("--disable-interactivity")

                    if ($acceptSourceAgreements) { $installArgs.Add("--accept-source-agreements") }
                    if ($acceptPackageAgreements) { $installArgs.Add("--accept-package-agreements") }
                    if ($source) { $installArgs.Add("--source"); $installArgs.Add($source) }
                    if ($scope) { $installArgs.Add("--scope"); $installArgs.Add($scope) }
                    if ($version) { $installArgs.Add("--version"); $installArgs.Add($version) }
                    if ($overrideArgs) { $installArgs.Add("--override"); $installArgs.Add("`"$overrideArgs`"") }

                    $result = Invoke-WingetCommand -WingetPath $wingetPath -Arguments $installArgs -Module $module
                    $module.Result.rc = $result.ExitCode

                    if ($result.ExitCode -notin @(0, 0x8A15002B)) {
                        $module.Result.stdout = $result.Stdout
                        $module.Result.stderr = $result.Stderr
                        $module.FailJson("Failed to reinstall package '$packageIdentifier': winget returned exit code $($result.ExitCode)")
                    }

                    if ($result.ExitCode -eq 0x8A15002B) {
                        $module.Result.reboot_required = $true
                    }
                }

                $module.Result.changed = $true
                $module.Result.installed_version = if ($version) { $version } else { $installedPackage.Version }
                $module.Result.package_id = if ($id) { $id } elseif ($installedPackage.Id) { $installedPackage.Id } else { $name }
            }
            else {
                # Already installed at correct version, no change needed
                $module.Result.installed_version = $installedPackage.Version
                $module.Result.package_id = if ($id) { $id } elseif ($installedPackage.Id) { $installedPackage.Id } else { $name }
            }
        }
        else {
            # Not installed, need to install
            if (-not $module.CheckMode) {
                $installArgs = [System.Collections.Generic.List[String]]@("install")

                if ($id) {
                    $installArgs.Add("--id")
                    $installArgs.Add($id)
                    $installArgs.Add("--exact")
                }
                else {
                    $installArgs.Add("--name")
                    $installArgs.Add("`"$name`"")
                    $installArgs.Add("--exact")
                }

                $installArgs.Add("--silent")
                $installArgs.Add("--disable-interactivity")

                if ($acceptSourceAgreements) { $installArgs.Add("--accept-source-agreements") }
                if ($acceptPackageAgreements) { $installArgs.Add("--accept-package-agreements") }
                if ($source) { $installArgs.Add("--source"); $installArgs.Add($source) }
                if ($scope) { $installArgs.Add("--scope"); $installArgs.Add($scope) }
                if ($version) { $installArgs.Add("--version"); $installArgs.Add($version) }
                if ($overrideArgs) { $installArgs.Add("--override"); $installArgs.Add("`"$overrideArgs`"") }
                if ($force) { $installArgs.Add("--force") }

                $result = Invoke-WingetCommand -WingetPath $wingetPath -Arguments $installArgs -Module $module
                $module.Result.rc = $result.ExitCode

                if ($result.ExitCode -notin @(0, 0x8A15002B)) {
                    $module.Result.stdout = $result.Stdout
                    $module.Result.stderr = $result.Stderr
                    $module.FailJson("Failed to install package '$packageIdentifier': winget returned exit code $($result.ExitCode)")
                }

                if ($result.ExitCode -eq 0x8A15002B) {
                    $module.Result.reboot_required = $true
                }

                # Verify installation by re-querying
                $postInstall = Get-InstalledPackage -WingetPath $wingetPath -Id $id -Name $name -Module $module
                if ($postInstall) {
                    $module.Result.installed_version = $postInstall.Version
                    $module.Result.package_id = if ($id) { $id } elseif ($postInstall.Id) { $postInstall.Id } else { $name }
                }
                else {
                    $module.Result.installed_version = if ($version) { $version } else { "unknown" }
                    $module.Result.package_id = $packageIdentifier
                }
            }
            else {
                $module.Result.installed_version = if ($version) { $version } else { "latest" }
                $module.Result.package_id = $packageIdentifier
            }

            $module.Result.changed = $true
        }
    }

    "absent" {
        if ($isInstalled) {
            if (-not $module.CheckMode) {
                $uninstallArgs = [System.Collections.Generic.List[String]]@("uninstall")

                if ($id) {
                    $uninstallArgs.Add("--id")
                    $uninstallArgs.Add($id)
                    $uninstallArgs.Add("--exact")
                }
                else {
                    $uninstallArgs.Add("--name")
                    $uninstallArgs.Add("`"$name`"")
                    $uninstallArgs.Add("--exact")
                }

                $uninstallArgs.Add("--silent")
                $uninstallArgs.Add("--disable-interactivity")

                if ($acceptSourceAgreements) { $uninstallArgs.Add("--accept-source-agreements") }
                if ($source) { $uninstallArgs.Add("--source"); $uninstallArgs.Add($source) }
                if ($version) { $uninstallArgs.Add("--version"); $uninstallArgs.Add($version) }
                if ($force) { $uninstallArgs.Add("--force") }

                $result = Invoke-WingetCommand -WingetPath $wingetPath -Arguments $uninstallArgs -Module $module
                $module.Result.rc = $result.ExitCode

                if ($result.ExitCode -notin @(0, 0x8A15002B)) {
                    $module.Result.stdout = $result.Stdout
                    $module.Result.stderr = $result.Stderr
                    $module.FailJson("Failed to uninstall package '$packageIdentifier': winget returned exit code $($result.ExitCode)")
                }

                if ($result.ExitCode -eq 0x8A15002B) {
                    $module.Result.reboot_required = $true
                }
            }

            $module.Result.changed = $true
            $module.Result.previous_version = $installedPackage.Version
            $module.Result.package_id = if ($id) { $id } elseif ($installedPackage.Id) { $installedPackage.Id } else { $name }
        }
        # else: not installed, nothing to do
    }

    "latest" {
        if ($isInstalled) {
            # Check if an upgrade is available
            $hasUpgrade = $false
            if ($installedPackage.AvailableVersion -and $installedPackage.AvailableVersion -ne "") {
                $hasUpgrade = $true
            }

            if ($hasUpgrade) {
                if (-not $module.CheckMode) {
                    $upgradeArgs = [System.Collections.Generic.List[String]]@("upgrade")

                    if ($id) {
                        $upgradeArgs.Add("--id")
                        $upgradeArgs.Add($id)
                        $upgradeArgs.Add("--exact")
                    }
                    else {
                        $upgradeArgs.Add("--name")
                        $upgradeArgs.Add("`"$name`"")
                        $upgradeArgs.Add("--exact")
                    }

                    $upgradeArgs.Add("--silent")
                    $upgradeArgs.Add("--disable-interactivity")

                    if ($acceptSourceAgreements) { $upgradeArgs.Add("--accept-source-agreements") }
                    if ($acceptPackageAgreements) { $upgradeArgs.Add("--accept-package-agreements") }
                    if ($source) { $upgradeArgs.Add("--source"); $upgradeArgs.Add($source) }
                    if ($scope) { $upgradeArgs.Add("--scope"); $upgradeArgs.Add($scope) }
                    if ($overrideArgs) { $upgradeArgs.Add("--override"); $upgradeArgs.Add("`"$overrideArgs`"") }
                    if ($force) { $upgradeArgs.Add("--force") }

                    $result = Invoke-WingetCommand -WingetPath $wingetPath -Arguments $upgradeArgs -Module $module
                    $module.Result.rc = $result.ExitCode

                    if ($result.ExitCode -notin @(0, 0x8A15002B)) {
                        $module.Result.stdout = $result.Stdout
                        $module.Result.stderr = $result.Stderr
                        $module.FailJson("Failed to upgrade package '$packageIdentifier': winget returned exit code $($result.ExitCode)")
                    }

                    if ($result.ExitCode -eq 0x8A15002B) {
                        $module.Result.reboot_required = $true
                    }

                    # Re-query to get new version
                    $postUpgrade = Get-InstalledPackage -WingetPath $wingetPath -Id $id -Name $name -Module $module
                    if ($postUpgrade) {
                        $module.Result.installed_version = $postUpgrade.Version
                    }
                    else {
                        $module.Result.installed_version = $installedPackage.AvailableVersion
                    }
                }
                else {
                    $module.Result.installed_version = $installedPackage.AvailableVersion
                }

                $module.Result.changed = $true
                $module.Result.previous_version = $installedPackage.Version
                $module.Result.package_id = if ($id) { $id } elseif ($installedPackage.Id) { $installedPackage.Id } else { $name }
            }
            else {
                # Already at latest version
                $module.Result.installed_version = $installedPackage.Version
                $module.Result.package_id = if ($id) { $id } elseif ($installedPackage.Id) { $installedPackage.Id } else { $name }
            }
        }
        else {
            # Not installed, install latest
            if (-not $module.CheckMode) {
                $installArgs = [System.Collections.Generic.List[String]]@("install")

                if ($id) {
                    $installArgs.Add("--id")
                    $installArgs.Add($id)
                    $installArgs.Add("--exact")
                }
                else {
                    $installArgs.Add("--name")
                    $installArgs.Add("`"$name`"")
                    $installArgs.Add("--exact")
                }

                $installArgs.Add("--silent")
                $installArgs.Add("--disable-interactivity")

                if ($acceptSourceAgreements) { $installArgs.Add("--accept-source-agreements") }
                if ($acceptPackageAgreements) { $installArgs.Add("--accept-package-agreements") }
                if ($source) { $installArgs.Add("--source"); $installArgs.Add($source) }
                if ($scope) { $installArgs.Add("--scope"); $installArgs.Add($scope) }
                if ($overrideArgs) { $installArgs.Add("--override"); $installArgs.Add("`"$overrideArgs`"") }
                if ($force) { $installArgs.Add("--force") }

                $result = Invoke-WingetCommand -WingetPath $wingetPath -Arguments $installArgs -Module $module
                $module.Result.rc = $result.ExitCode

                if ($result.ExitCode -notin @(0, 0x8A15002B)) {
                    $module.Result.stdout = $result.Stdout
                    $module.Result.stderr = $result.Stderr
                    $module.FailJson("Failed to install package '$packageIdentifier': winget returned exit code $($result.ExitCode)")
                }

                if ($result.ExitCode -eq 0x8A15002B) {
                    $module.Result.reboot_required = $true
                }

                # Re-query to get installed version
                $postInstall = Get-InstalledPackage -WingetPath $wingetPath -Id $id -Name $name -Module $module
                if ($postInstall) {
                    $module.Result.installed_version = $postInstall.Version
                    $module.Result.package_id = if ($id) { $id } elseif ($postInstall.Id) { $postInstall.Id } else { $name }
                }
                else {
                    $module.Result.installed_version = "unknown"
                    $module.Result.package_id = $packageIdentifier
                }
            }
            else {
                $module.Result.installed_version = "latest"
                $module.Result.package_id = $packageIdentifier
            }

            $module.Result.changed = $true
        }
    }
}

$module.ExitJson()
