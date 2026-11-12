#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils.PSResourceGet

$spec = @{
    options = @{
        name = @{ type = 'list'; elements = 'str'; required = $true }
        state = @{ type = 'str'; default = 'present'; choices = @('absent', 'latest', 'present') }
        version = @{ type = 'str' }
        prerelease = @{ type = 'bool'; default = $false }
        repository = @{ type = 'str' }
        scope = @{ type = 'str'; choices = @('currentuser', 'allusers') }
        trust_repository = @{ type = 'bool'; default = $false }
        reinstall = @{ type = 'bool'; default = $false }
        accept_license = @{ type = 'bool'; default = $false }
        no_clobber = @{ type = 'bool'; default = $false }
        skip_dependency_check = @{ type = 'bool'; default = $false }
        authenticode_check = @{ type = 'bool'; default = $false }
        username = @{ type = 'str' }
        password = @{ type = 'str'; no_log = $true }
    }
    required_together = @(
        , @('username', 'password')
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$module.Result.resources = @()

$names = $module.Params.name
$state = $module.Params.state
$version = $module.Params.version
$prerelease = $module.Params.prerelease
$repository = $module.Params.repository
$scope = $module.Params.scope

# Hide the progress bars, they only add noise to the module output.
$ProgressPreference = 'SilentlyContinue'

try {
    Import-AnsiblePSResourceGet
}
catch {
    $module.FailJson($_.Exception.Message, $_)
}

foreach ($name in $names) {
    if ([WildcardPattern]::ContainsWildcardCharacters($name)) {
        $module.FailJson("The resource name '$name' cannot contain wildcard characters.")
    }
}

$credential = $null
if ($module.Params.username) {
    $securePassword = [System.Net.NetworkCredential]::new('', $module.Params.password).SecurePassword
    $credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $module.Params.username, $securePassword
}

Function Write-CmdletWarning {
    param($Warning)
    foreach ($w in $Warning) {
        $module.Warn($w.Message)
    }
}

Function Get-InstalledResource {
    param([string]$Name, [string]$Version)

    $getParams = @{
        Name = $Name
        # A resource that isn't installed is not an error, a malformed version still throws.
        ErrorAction = 'SilentlyContinue'
    }
    if ($Version) { $getParams.Version = $Version }
    if ($scope) { $getParams.Scope = $scope }

    try {
        @(Get-InstalledPSResource @getParams)
    }
    catch {
        $module.FailJson("Failed to get installed resource '$Name': $($_.Exception.Message)", $_)
    }
}

Function Get-LatestAvailableResource {
    param([string]$Name, [string]$Version)

    $findParams = @{
        Name = $Name
        Prerelease = $prerelease
        ErrorAction = 'Stop'
    }
    if ($Version) { $findParams.Version = $Version }
    if ($repository) { $findParams.Repository = $repository }
    if ($credential) { $findParams.Credential = $credential }

    try {
        $found = @(Find-PSResource @findParams)
    }
    catch {
        $module.FailJson("Failed to find resource '$Name' in a repository: $($_.Exception.Message)", $_)
    }

    # Find-PSResource returns every matching version when a version range is set.
    # Releases sort ahead of prereleases of the same version.
    $found |
        Sort-Object -Property @{ Expression = { $_.Version }; Descending = $true },
        @{ Expression = { [bool]$_.IsPrerelease }; Descending = $false },
        @{ Expression = { [string]$_.Prerelease }; Descending = $true } |
        Select-Object -First 1
}

Function Get-VersionList {
    param($Resources)
    , @(foreach ($resource in $Resources) { Get-AnsiblePSResourceVersionString -Resource $resource })
}

Function Invoke-Install {
    param([string]$Name, [string]$Version, [switch]$Update)

    $params = @{
        Name = $Name
        Prerelease = $prerelease
        ErrorAction = 'Stop'
        WarningVariable = 'cmdWarnings'
    }
    if ($Version) { $params.Version = $Version }
    if ($scope) { $params.Scope = $scope }
    if ($repository) { $params.Repository = $repository }
    if ($credential) { $params.Credential = $credential }
    if ($module.Params.trust_repository) { $params.TrustRepository = $true }
    if ($module.Params.accept_license) { $params.AcceptLicense = $true }
    if ($module.Params.skip_dependency_check) { $params.SkipDependencyCheck = $true }
    if ($module.Params.authenticode_check) { $params.AuthenticodeCheck = $true }

    try {
        if ($Update) {
            Update-PSResource @params -Quiet
        }
        else {
            if ($module.Params.reinstall) { $params.Reinstall = $true }
            if ($module.Params.no_clobber) { $params.NoClobber = $true }
            Install-PSResource @params -Quiet
        }
    }
    catch {
        $action = if ($Update) { 'update' } else { 'install' }
        $module.FailJson("Failed to $action resource '$Name': $($_.Exception.Message)", $_)
    }
    Write-CmdletWarning -Warning $cmdWarnings
}

$results = [System.Collections.Generic.List[Object]]::new()

foreach ($name in $names) {
    $action = 'none'
    $installed = @(Get-InstalledResource -Name $name -Version $version)

    if ($state -eq 'absent') {
        if ($installed.Count -gt 0) {
            $action = 'uninstalled'
            if (-not $module.CheckMode) {
                $uninstallParams = @{
                    Name = $name
                    ErrorAction = 'Stop'
                    WarningVariable = 'cmdWarnings'
                }
                if ($version) { $uninstallParams.Version = $version }
                if ($scope) { $uninstallParams.Scope = $scope }
                if ($module.Params.skip_dependency_check) { $uninstallParams.SkipDependencyCheck = $true }
                try {
                    Uninstall-PSResource @uninstallParams
                }
                catch {
                    $module.FailJson("Failed to uninstall resource '$name': $($_.Exception.Message)", $_)
                }
                Write-CmdletWarning -Warning $cmdWarnings
            }
        }
    }
    elseif ($state -eq 'present') {
        if ($installed.Count -eq 0) {
            $action = 'installed'
        }
        elseif ($module.Params.reinstall) {
            $action = 'reinstalled'
        }

        if ($action -ne 'none' -and -not $module.CheckMode) {
            Invoke-Install -Name $name -Version $version
        }
    }
    else {
        # latest, work out the newest version that is available and see if it is installed.
        $latest = Get-LatestAvailableResource -Name $name -Version $version
        if (-not $latest) {
            $module.FailJson("Resource '$name' was not found in any repository.")
        }

        $latestVersion = Get-AnsiblePSResourceVersionString -Resource $latest
        $hasLatest = @(
            $installed | Where-Object { (Get-AnsiblePSResourceVersionString -Resource $_) -eq $latestVersion }
        ).Count -gt 0
        $anyInstalled = (Get-InstalledResource -Name $name).Count -gt 0

        if (-not $anyInstalled) {
            $action = 'installed'
        }
        elseif (-not $hasLatest) {
            $action = 'updated'
        }

        if ($action -ne 'none' -and -not $module.CheckMode) {
            Invoke-Install -Name $name -Version $version -Update:($action -eq 'updated')
        }
    }

    if ($action -ne 'none') {
        $module.Result.changed = $true
    }

    # In check mode this is the current state as nothing was changed.
    $after = Get-InstalledResource -Name $name

    $results.Add(@{
            name = $name
            action = $action
            versions = (Get-VersionList -Resources $after)
        })
}

$module.Result.resources = @($results)

$module.ExitJson()
