#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

using namespace Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = "str"; required = $true }
        state = @{ type = "str"; choices = @("present", "absent", "latest"); default = "present" }
        version = @{ type = "str" }
        provider = @{ type = "str" }
        source = @{ type = "str" }
        scope = @{ type = "str"; choices = @("currentuser", "allusers") }
        minimum_version = @{ type = "str" }
        maximum_version = @{ type = "str" }
        force = @{ type = "bool"; default = $false }
        allow_clobber = @{ type = "bool"; default = $false }
        skip_dependencies = @{ type = "bool"; default = $false }
    }
    supports_check_mode = $true
}

$module = [AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$state = $module.Params.state
$version = $module.Params.version
$provider = $module.Params.provider
$source = $module.Params.source
$scope = $module.Params.scope
$minimumVersion = $module.Params.minimum_version
$maximumVersion = $module.Params.maximum_version
$force = $module.Params.force
$allowClobber = $module.Params.allow_clobber
$skipDependencies = $module.Params.skip_dependencies

$module.Result.changed = $false
$module.Result.package_name = $name
$module.Result.rc = 0

# Validate parameter combinations
if ($state -eq "latest" -and ($version -or $minimumVersion -or $maximumVersion)) {
    $module.FailJson("Parameters 'version', 'minimum_version', and 'maximum_version' cannot be used with state=latest")
}

if ($version -and ($minimumVersion -or $maximumVersion)) {
    $module.FailJson("Parameter 'version' cannot be used with 'minimum_version' or 'maximum_version'")
}

# Helper function to check if PackageManagement module is available
Function Test-PackageManagementAvailable {
    try {
        $pkgMgmt = Get-Module -Name PackageManagement -ListAvailable -ErrorAction SilentlyContinue
        if ($pkgMgmt) {
            Import-Module PackageManagement -ErrorAction Stop
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# Helper function to get installed package
Function Get-InstalledPackage {
    param(
        [string]$Name,
        [string]$Provider
    )

    $getParams = @{
        Name = $Name
        ErrorAction = 'SilentlyContinue'
    }

    if ($Provider) {
        $getParams.ProviderName = $Provider
    }

    return Get-Package @getParams | Select-Object -First 1
}

# Helper function to find available package
Function Find-AvailablePackage {
    param(
        [string]$Name,
        [string]$Provider,
        [string]$Source,
        [string]$Version,
        [string]$MinimumVersion,
        [string]$MaximumVersion
    )

    $findParams = @{
        Name = $Name
        ErrorAction = 'SilentlyContinue'
    }

    if ($Provider) {
        $findParams.ProviderName = $Provider
    }

    if ($Source) {
        $findParams.Source = $Source
    }

    if ($Version) {
        $findParams.RequiredVersion = $Version
    }
    elseif ($MinimumVersion) {
        $findParams.MinimumVersion = $MinimumVersion
    }

    if ($MaximumVersion) {
        $findParams.MaximumVersion = $MaximumVersion
    }

    return Find-Package @findParams | Select-Object -First 1
}

# Check if PackageManagement is available
if (-not (Test-PackageManagementAvailable)) {
    $module.FailJson("PackageManagement module is not available. Ensure PowerShell 5.1+ is installed or install the PackageManagement module.")
}

# Get current package state
$currentPackage = Get-InstalledPackage -Name $name -Provider $provider

if ($currentPackage) {
    $module.Result.previous_version = $currentPackage.Version.ToString()
    $module.Result.provider = $currentPackage.ProviderName
}

# Process based on desired state
if ($state -eq "absent") {
    if ($currentPackage) {
        $uninstallParams = @{
            Name = $name
            Force = $true
            ErrorAction = 'Stop'
        }

        if ($provider) {
            $uninstallParams.ProviderName = $provider
        }

        if (-not $module.CheckMode) {
            try {
                Uninstall-Package @uninstallParams | Out-Null
                $module.Result.changed = $true
                $module.Result.msg = "Package '$name' uninstalled successfully"
            }
            catch {
                $module.FailJson("Failed to uninstall package '$name': $($_.Exception.Message)")
            }
        }
        else {
            $module.Result.changed = $true
            $module.Result.msg = "Check mode: would uninstall package '$name'"
        }
    }
    else {
        $module.Result.changed = $false
        $module.Result.msg = "Package '$name' is not installed"
    }
}
elseif ($state -eq "present" -or $state -eq "latest") {
    $needsInstall = $false
    $needsUpgrade = $false

    if (-not $currentPackage) {
        $needsInstall = $true
    }
    elseif ($state -eq "latest") {
        # Check if an upgrade is available
        $availablePackage = Find-AvailablePackage -Name $name -Provider $provider -Source $source

        if ($availablePackage -and ([Version]$availablePackage.Version -gt [Version]$currentPackage.Version)) {
            $needsUpgrade = $true
        }
    }
    elseif ($version) {
        # Check if the installed version matches the requested version
        if ($currentPackage.Version.ToString() -ne $version) {
            if (-not $force) {
                $module.FailJson("Package '$name' is installed with version $($currentPackage.Version) but version $version was requested. Use force=true to reinstall.")
            }
            $needsInstall = $true
        }
    }
    elseif ($minimumVersion) {
        # Check if installed version meets minimum requirement
        if ([Version]$currentPackage.Version -lt [Version]$minimumVersion) {
            $needsUpgrade = $true
        }
    }

    if ($needsInstall -or $needsUpgrade -or $force) {
        $installParams = @{
            Name = $name
            Force = $force
            ErrorAction = 'Stop'
        }

        if ($provider) {
            $installParams.ProviderName = $provider
        }

        if ($source) {
            $installParams.Source = $source
        }

        if ($version) {
            $installParams.RequiredVersion = $version
        }
        elseif ($minimumVersion) {
            $installParams.MinimumVersion = $minimumVersion
        }

        if ($maximumVersion) {
            $installParams.MaximumVersion = $maximumVersion
        }

        if ($scope) {
            $installParams.Scope = $scope
        }

        if ($allowClobber) {
            $installParams.AllowClobber = $true
        }

        if ($skipDependencies) {
            $installParams.SkipDependencies = $true
        }

        if (-not $module.CheckMode) {
            try {
                $result = Install-Package @installParams

                if ($result) {
                    $module.Result.changed = $true
                    $module.Result.installed_version = $result.Version.ToString()
                    $module.Result.provider = $result.ProviderName

                    if ($needsUpgrade) {
                        $module.Result.msg = "Package '$name' upgraded from $($module.Result.previous_version) to $($result.Version)"
                    }
                    else {
                        $module.Result.msg = "Package '$name' installed successfully with version $($result.Version)"
                    }
                }
            }
            catch {
                # Check if error is due to package not found
                if ($_.Exception.Message -match "No match was found") {
                    $module.FailJson("Package '$name' not found in available sources. Error: $($_.Exception.Message)")
                }
                else {
                    $module.FailJson("Failed to install package '$name': $($_.Exception.Message)")
                }
            }
        }
        else {
            $module.Result.changed = $true
            if ($needsUpgrade) {
                $module.Result.msg = "Check mode: would upgrade package '$name'"
            }
            else {
                $module.Result.msg = "Check mode: would install package '$name'"
            }
        }
    }
    else {
        $module.Result.changed = $false
        $module.Result.installed_version = $currentPackage.Version.ToString()
        $module.Result.provider = $currentPackage.ProviderName
        $module.Result.msg = "Package '$name' is already installed with the requested version ($($currentPackage.Version))"
    }
}

$module.ExitJson()
