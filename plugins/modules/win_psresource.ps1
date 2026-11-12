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

# PSResourceGet can install itself when it is asked for by name. It is installed
# through PowerShellGet v2 as PSResourceGet is not there to do it.
$psResourceGetName = 'Microsoft.PowerShell.PSResourceGet'
$bootstrapped = $false

if ($state -eq 'absent' -and $names -contains $psResourceGetName) {
    # Its files are in use as the module is loaded, so removing them would leave a broken install.
    $module.FailJson("$psResourceGetName cannot be uninstalled with this module as it is in use. Use Uninstall-Module in a separate task.")
}

try {
    Import-AnsiblePSResourceGet
}
catch {
    $importError = $_
    if ($state -eq 'absent' -or $names -notcontains $psResourceGetName) {
        $module.FailJson("$($importError.Exception.Message) Install it first, or include '$psResourceGetName' in name to install it with this module.", $importError)
    }

    $installModule = Get-Command -Name Install-Module -ErrorAction SilentlyContinue
    if (-not $installModule) {
        $module.FailJson("Cannot install $psResourceGetName as the Install-Module command from PowerShellGet is not available.", $importError)
    }
    if ($version -and $version -notmatch '^\d+(\.\d+){1,3}$') {
        $module.FailJson("version must be an exact version like 1.2.3 to install $psResourceGetName, got '$version'.")
    }

    $bootstrapped = $true
    if ($module.CheckMode) {
        # Nothing else can be checked as the module needed for that is not installed.
        $others = @($names | Where-Object { $_ -ne $psResourceGetName })
        if ($others.Count -gt 0) {
            $module.Warn("Check mode cannot check '$($others -join "', '")' until $psResourceGetName is installed.")
        }
        $module.Result.changed = $true
        $module.Result.resources = @(@{ name = $psResourceGetName; action = 'installed'; versions = @() })
        $module.ExitJson()
    }

    $installParams = @{
        Name = $psResourceGetName
        # Also installs the NuGet package provider without prompting if it is needed.
        Force = $true
        AllowClobber = $true
        ErrorAction = 'Stop'
        WarningVariable = 'cmdWarnings'
    }
    if ($version) { $installParams.RequiredVersion = $version }
    if ($prerelease) { $installParams.AllowPrerelease = $true }
    if ($repository) { $installParams.Repository = $repository }
    if ($scope) { $installParams.Scope = $scope }
    if ($credential) { $installParams.Credential = $credential }

    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        Install-Module @installParams
    }
    catch {
        $module.FailJson("Failed to install ${psResourceGetName}: $($_.Exception.Message)", $_)
    }
    foreach ($w in $cmdWarnings) { $module.Warn($w.Message) }
    $module.Result.changed = $true

    try {
        Import-AnsiblePSResourceGet
    }
    catch {
        $module.FailJson("Installed $psResourceGetName but could not load it: $($_.Exception.Message)", $_)
    }
}

if ($version) {
    $versionError = Test-AnsiblePSResourceVersion -Version $version
    if ($versionError) {
        $module.FailJson($versionError)
    }
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

    if ($found.Count -eq 0) {
        return
    }

    # Find-PSResource returns the newest version from every repository, but installing
    # and updating use the first repository that has the resource by priority. Only
    # consider the repository they would use or the task never settles on a version.
    $priorities = @{}
    foreach ($repo in @(Get-PSResourceRepository -ErrorAction SilentlyContinue)) {
        $priorities[$repo.Name] = [int]$repo.Priority
    }
    $chosenRepo = $null
    $chosenPriority = 0
    foreach ($candidate in $found) {
        $priority = if ($priorities.ContainsKey($candidate.Repository)) { $priorities[$candidate.Repository] } else { 50 }
        if ($null -eq $chosenRepo -or $priority -lt $chosenPriority) {
            $chosenRepo = $candidate.Repository
            $chosenPriority = $priority
        }
    }

    # Releases sort ahead of prereleases of the same version.
    $found |
        Where-Object { $_.Repository -eq $chosenRepo } |
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
    param([string]$Name, [string]$Version, [switch]$Update, [switch]$ForceReinstall)

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
            if ($module.Params.reinstall -or $ForceReinstall) { $params.Reinstall = $true }
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
        $allInstalled = @(Get-InstalledResource -Name $name)
        $anyInstalled = $allInstalled.Count -gt 0

        # Update-PSResource and Install-PSResource treat versions that only differ by prerelease
        # label, like 3.0.0-beta1 and 3.0.0-beta2, as the same so they do nothing. Reinstalling
        # the exact version is the only way to switch between them.
        $labelOnly = -not $hasLatest -and @($allInstalled | Where-Object { $_.Version -eq $latest.Version }).Count -gt 0

        if (-not $anyInstalled) {
            $action = 'installed'
        }
        elseif (-not $hasLatest) {
            $action = 'updated'
        }

        if ($action -ne 'none' -and -not $module.CheckMode) {
            if ($labelOnly) {
                Invoke-Install -Name $name -Version $latestVersion -ForceReinstall
            }
            else {
                $versionsBefore = Get-VersionList -Resources $allInstalled
                Invoke-Install -Name $name -Version $version -Update:($action -eq 'updated')
                if ($action -eq 'updated') {
                    # Only report a change if the update installed a version that was not there before.
                    $versionsAfter = Get-VersionList -Resources (Get-InstalledResource -Name $name)
                    if (@($versionsAfter | Where-Object { $versionsBefore -notcontains $_ }).Count -eq 0) {
                        $action = 'none'
                    }
                }
            }
        }
    }

    if ($bootstrapped -and $name -eq $psResourceGetName -and $action -eq 'none') {
        # Installed above, before the checks here could see that it was missing.
        $action = 'installed'
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
