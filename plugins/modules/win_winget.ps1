#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

using namespace Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = "str"; required = $true; aliases = @("id") }
        state = @{ type = "str"; choices = @("present", "absent", "latest"); default = "present" }
        version = @{ type = "str" }
        source = @{ type = "str" }
        scope = @{ type = "str"; choices = @("user", "machine") }
        architecture = @{ type = "str"; choices = @("x86", "x64", "arm", "arm64") }
        override_arguments = @{ type = "str" }
        accept_package_agreements = @{ type = "bool"; default = $true }
    }
    supports_check_mode = $true
}

$module = [AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$state = $module.Params.state
$version = $module.Params.version
$source = $module.Params.source
$scope = $module.Params.scope
$architecture = $module.Params.architecture
$overrideArguments = $module.Params.override_arguments
$acceptAgreements = $module.Params.accept_package_agreements

$module.Result.changed = $false
$module.Result.package_id = $name
$module.Result.rc = 0

# Validate parameters
if ($state -eq "latest" -and $version) {
    $module.FailJson("Parameter 'version' cannot be used with state=latest")
}

# Helper function to check if winget is available
Function Test-WingetAvailable {
    try {
        $wingetPath = (Get-Command winget -ErrorAction SilentlyContinue).Source
        if ($wingetPath) {
            return $true
        }
        return $false
    }
    catch {
        return $false
    }
}

# Helper function to execute winget commands
Function Invoke-Winget {
    param(
        [string[]]$Arguments,
        [switch]$CheckMode
    )

    if ($CheckMode) {
        return @{
            rc = 0
            stdout = "Check mode: would execute winget $($Arguments -join ' ')"
            stderr = ""
        }
    }

    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = "winget.exe"
    $startInfo.Arguments = $Arguments -join " "
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true

    $process = New-Object System.Diagnostics.Process
    $process.StartInfo = $startInfo

    $stdout = New-Object System.Text.StringBuilder
    $stderr = New-Object System.Text.StringBuilder

    $stdoutEvent = Register-ObjectEvent -InputObject $process -EventName OutputDataReceived -Action {
        if ($EventArgs.Data) {
            $Event.MessageData.AppendLine($EventArgs.Data)
        }
    } -MessageData $stdout

    $stderrEvent = Register-ObjectEvent -InputObject $process -EventName ErrorDataReceived -Action {
        if ($EventArgs.Data) {
            $Event.MessageData.AppendLine($EventArgs.Data)
        }
    } -MessageData $stderr

    try {
        [void]$process.Start()
        $process.BeginOutputReadLine()
        $process.BeginErrorReadLine()
        $process.WaitForExit()

        return @{
            rc = $process.ExitCode
            stdout = $stdout.ToString()
            stderr = $stderr.ToString()
        }
    }
    finally {
        Unregister-Event -SourceIdentifier $stdoutEvent.Name -ErrorAction SilentlyContinue
        Unregister-Event -SourceIdentifier $stderrEvent.Name -ErrorAction SilentlyContinue
        $process.Dispose()
    }
}

# Helper function to get installed package information
Function Get-WingetPackage {
    param([string]$PackageId)

    $args = @("list", "--id", $PackageId, "--exact", "--disable-interactivity")
    $result = Invoke-Winget -Arguments $args

    if ($result.rc -eq 0 -and $result.stdout -match $PackageId) {
        # Parse the output to extract version
        $lines = $result.stdout -split "`n"
        foreach ($line in $lines) {
            if ($line -match $PackageId) {
                # Winget list output format: Name   Id   Version   Available
                # Extract version using regex
                if ($line -match '\s+([\d\.]+)\s*') {
                    return @{
                        installed = $true
                        version = $matches[1]
                        output = $result.stdout
                    }
                }
            }
        }
        return @{
            installed = $true
            version = "unknown"
            output = $result.stdout
        }
    }

    return @{
        installed = $false
        version = $null
        output = $result.stdout
    }
}

# Check if winget is available
if (-not (Test-WingetAvailable)) {
    $module.FailJson("Winget is not available on this system. Install the App Installer package from Microsoft Store or download from GitHub (https://github.com/microsoft/winget-cli/releases)")
}

# Get current package state
$currentPackage = Get-WingetPackage -PackageId $name

if ($currentPackage.installed) {
    $module.Result.previous_version = $currentPackage.version
}

# Process based on desired state
if ($state -eq "absent") {
    if ($currentPackage.installed) {
        $uninstallArgs = @("uninstall", "--id", $name, "--exact", "--disable-interactivity")

        if ($acceptAgreements) {
            $uninstallArgs += "--accept-source-agreements"
        }

        $result = Invoke-Winget -Arguments $uninstallArgs -CheckMode:$module.CheckMode

        $module.Result.rc = $result.rc
        $module.Result.stdout = $result.stdout
        $module.Result.stderr = $result.stderr

        if ($result.rc -eq 0) {
            $module.Result.changed = $true
        }
        elseif ($result.rc -eq -1978335189) {
            # Package not found (already uninstalled)
            $module.Result.changed = $false
        }
        else {
            $module.FailJson("Failed to uninstall package '$name'. RC: $($result.rc). Error: $($result.stderr)")
        }
    }
    else {
        $module.Result.changed = $false
        $module.Result.stdout = "Package '$name' is not installed"
    }
}
elseif ($state -eq "present" -or $state -eq "latest") {
    $needsInstall = $false
    $needsUpgrade = $false

    if (-not $currentPackage.installed) {
        $needsInstall = $true
    }
    elseif ($state -eq "latest") {
        # Check if an upgrade is available
        $needsUpgrade = $true  # Winget will determine if upgrade is needed
    }
    elseif ($version -and $currentPackage.version -ne $version) {
        $needsInstall = $true  # Reinstall to get specific version
    }

    if ($needsInstall -or $needsUpgrade) {
        if ($needsInstall) {
            $installArgs = @("install", "--id", $name, "--exact", "--disable-interactivity")

            if ($version) {
                $installArgs += @("--version", $version)
            }
        }
        else {
            $installArgs = @("upgrade", "--id", $name, "--exact", "--disable-interactivity")
        }

        if ($source) {
            $installArgs += @("--source", $source)
        }

        if ($scope) {
            $installArgs += @("--scope", $scope)
        }

        if ($architecture) {
            $installArgs += @("--architecture", $architecture)
        }

        if ($overrideArguments) {
            $installArgs += @("--override", $overrideArguments)
        }

        if ($acceptAgreements) {
            $installArgs += @("--accept-package-agreements", "--accept-source-agreements")
        }

        $result = Invoke-Winget -Arguments $installArgs -CheckMode:$module.CheckMode

        $module.Result.rc = $result.rc
        $module.Result.stdout = $result.stdout
        $module.Result.stderr = $result.stderr

        if ($result.rc -eq 0) {
            $module.Result.changed = $true

            # Get installed version after installation
            if (-not $module.CheckMode) {
                $updatedPackage = Get-WingetPackage -PackageId $name
                if ($updatedPackage.installed) {
                    $module.Result.installed_version = $updatedPackage.version
                }
            }
        }
        elseif ($result.rc -eq -1978335189) {
            # Package not found in sources
            $module.FailJson("Package '$name' not found in winget sources. Error: $($result.stderr)")
        }
        elseif ($result.rc -eq -1978335212 -and $state -eq "latest") {
            # No available upgrade found
            $module.Result.changed = $false
            $module.Result.installed_version = $currentPackage.version
            $module.Result.stdout = "Package '$name' is already at the latest version"
        }
        else {
            $module.FailJson("Failed to install/upgrade package '$name'. RC: $($result.rc). Error: $($result.stderr)")
        }
    }
    else {
        $module.Result.changed = $false
        $module.Result.installed_version = $currentPackage.version
        $module.Result.stdout = "Package '$name' is already installed with the requested version"
    }
}

$module.ExitJson()
