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

$psResourceGetName = 'Microsoft.PowerShell.PSResourceGet'

$ProgressPreference = 'SilentlyContinue'

#region Functions

function Write-CmdletWarning {
    param($Warning)

    foreach ($w in $Warning) {
        $module.Warn($w.Message)
    }
}

function Assert-CanInstallPSResourceGet {
    <#
    .SYNOPSIS
    Fails the module if PSResourceGet cannot be installed with the options given.
    #>
    param($InstallModuleCommand, $ImportError)

    if (-not $InstallModuleCommand) {
        $module.FailJson("Cannot install $psResourceGetName as Install-Module from PowerShellGet is not available.", $ImportError)
    }

    # Install-Module only understands exact versions.
    if ($version -and $version -notmatch '^\d+(\.\d+){1,3}$') {
        $module.FailJson("version must be an exact version like 1.2.3 to install $psResourceGetName, got '$version'.")
    }

    # The PowerShellGet 1.0.0.1 in Windows PowerShell 5.1 has no -AllowPrerelease.
    if ($prerelease -and -not $InstallModuleCommand.Parameters.ContainsKey('AllowPrerelease')) {
        $module.FailJson(
            "Cannot install a prerelease of $psResourceGetName as the installed PowerShellGet does not support it. " +
            "Update PowerShellGet to 1.6.0 or newer, or install a release."
        )
    }
}

function Install-PSResourceGetWithPowerShellGet {
    $installParams = @{
        Name = $psResourceGetName
        # -Force also installs the NuGet provider without prompting.
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
        # The PowerShell Gallery needs TLS 1.2, older hosts do not use it by default.
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor
        [Net.SecurityProtocolType]::Tls12
        Install-Module @installParams
    }
    catch {
        $module.FailJson("Failed to install ${psResourceGetName}: $($_.Exception.Message)", $_)
    }
    Write-CmdletWarning -Warning $cmdWarnings
}

function Get-InstalledResource {
    param([string]$Name, [string]$Version)

    $getParams = @{
        Name = $Name
        # Not being installed is not an error here, but a malformed version still throws.
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

function Get-VersionList {
    param($Resources)

    [string[]]@(foreach ($resource in $Resources) {
            Get-AnsiblePSResourceVersionString -Resource $resource
        })
}

function Get-LatestAvailableResource {
    <#
    .SYNOPSIS
    Finds the newest version that Install-PSResource and Update-PSResource would pick.
    #>
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

    # Find-PSResource returns the newest version from every repository, but installing and
    # updating use the first repository with the resource, by priority. Only look at that
    # one, otherwise the task keeps trying to reach a version it will never install.
    $priorities = @{}
    foreach ($repo in @(Get-PSResourceRepository -ErrorAction SilentlyContinue)) {
        $priorities[$repo.Name] = [int]$repo.Priority
    }

    $defaultPriority = 50
    $preferred = $null
    $preferredPriority = 0
    foreach ($candidate in $found) {
        $priority = $defaultPriority
        if ($priorities.ContainsKey($candidate.Repository)) {
            $priority = $priorities[$candidate.Repository]
        }
        if ($null -eq $preferred -or $priority -lt $preferredPriority) {
            $preferred = $candidate.Repository
            $preferredPriority = $priority
        }
    }

    # A release is newer than a prerelease of the same version.
    $found |
        Where-Object { $_.Repository -eq $preferred } |
        Sort-Object -Property @{ Expression = { $_.Version }; Descending = $true },
        @{ Expression = { [bool]$_.IsPrerelease }; Descending = $false },
        @{ Expression = { [string]$_.Prerelease }; Descending = $true } |
        Select-Object -First 1
}

function Invoke-Install {
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
        $verb = if ($Update) { 'update' } else { 'install' }
        $module.FailJson("Failed to $verb resource '$Name': $($_.Exception.Message)", $_)
    }
    Write-CmdletWarning -Warning $cmdWarnings
}

function Invoke-Uninstall {
    param([string]$Name)

    $params = @{
        Name = $Name
        ErrorAction = 'Stop'
        WarningVariable = 'cmdWarnings'
    }
    if ($version) { $params.Version = $version }
    if ($scope) { $params.Scope = $scope }
    if ($module.Params.skip_dependency_check) { $params.SkipDependencyCheck = $true }

    try {
        Uninstall-PSResource @params
    }
    catch {
        $module.FailJson("Failed to uninstall resource '$Name': $($_.Exception.Message)", $_)
    }
    Write-CmdletWarning -Warning $cmdWarnings
}

# Each of these makes the change needed for one name and returns what it did (or would
# do in check mode): none, installed, updated, reinstalled or uninstalled.

function Invoke-AbsentState {
    param([string]$Name)

    if (@(Get-InstalledResource -Name $Name -Version $version).Count -eq 0) {
        return 'none'
    }
    if (-not $module.CheckMode) {
        Invoke-Uninstall -Name $Name
    }
    'uninstalled'
}

function Invoke-PresentState {
    param([string]$Name)

    if (@(Get-InstalledResource -Name $Name -Version $version).Count -eq 0) {
        $action = 'installed'
    }
    elseif ($module.Params.reinstall) {
        $action = 'reinstalled'
    }
    else {
        return 'none'
    }

    if (-not $module.CheckMode) {
        Invoke-Install -Name $Name -Version $version
    }
    $action
}

function Invoke-LatestState {
    param([string]$Name)

    $latest = Get-LatestAvailableResource -Name $Name -Version $version
    if (-not $latest) {
        $module.FailJson("Resource '$Name' was not found in any repository.")
    }
    $latestVersion = Get-AnsiblePSResourceVersionString -Resource $latest

    $matching = @(Get-InstalledResource -Name $Name -Version $version)
    $allInstalled = @(Get-InstalledResource -Name $Name)

    $hasLatest = @($matching | Where-Object {
            (Get-AnsiblePSResourceVersionString -Resource $_) -eq $latestVersion
        }).Count -gt 0
    if ($hasLatest) {
        return 'none'
    }

    $action = if ($allInstalled.Count -eq 0) { 'installed' } else { 'updated' }
    if ($module.CheckMode) {
        return $action
    }

    # Update-PSResource and Install-PSResource see versions that only differ by prerelease label,
    # like 3.0.0-beta1 and 3.0.0-beta2, as the same version and do nothing. Reinstalling the exact
    # version is the only way to switch between them.
    $differsByLabelOnly = @($allInstalled | Where-Object { $_.Version -eq $latest.Version }).Count -gt 0
    if ($differsByLabelOnly) {
        Invoke-Install -Name $Name -Version $latestVersion -ForceReinstall
        return $action
    }

    $before = Get-VersionList -Resources $allInstalled
    Invoke-Install -Name $Name -Version $version -Update:($action -eq 'updated')
    if ($action -eq 'updated') {
        # Update-PSResource can finish without installing anything. Only report a change
        # if a version turned up that was not there before.
        $after = Get-VersionList -Resources (Get-InstalledResource -Name $Name)
        if (@($after | Where-Object { $before -notcontains $_ }).Count -eq 0) {
            return 'none'
        }
    }
    $action
}

#endregion

foreach ($name in $names) {
    if ([WildcardPattern]::ContainsWildcardCharacters($name)) {
        $module.FailJson("The resource name '$name' cannot contain wildcard characters.")
    }
}

$credential = $null
if ($module.Params.username) {
    $securePassword = [System.Net.NetworkCredential]::new('', $module.Params.password).SecurePassword
    $credential = [PSCredential]::new($module.Params.username, $securePassword)
}

# PSResourceGet can install itself when it is asked for by name. PowerShellGet does that
# as there is no PSResourceGet to do it with yet.
if ($state -eq 'absent' -and $names -contains $psResourceGetName) {
    # Its files are in use while the module runs, removing them would leave a broken install.
    $module.FailJson("$psResourceGetName cannot be uninstalled with this module as it is in use. Use Uninstall-Module in a separate task.")
}

$installedPSResourceGet = $false
try {
    Import-AnsiblePSResourceGet
}
catch {
    $importError = $_
    if ($state -eq 'absent' -or $names -notcontains $psResourceGetName) {
        $module.FailJson(
            "$($importError.Exception.Message) Install it first, or include '$psResourceGetName' in name to install it with this module.",
            $importError
        )
    }

    $installModuleCommand = Get-Command -Name Install-Module -ErrorAction SilentlyContinue
    Assert-CanInstallPSResourceGet -InstallModuleCommand $installModuleCommand -ImportError $importError

    if ($module.CheckMode) {
        # The other names cannot be checked as there is no PSResourceGet to check them with.
        $others = @($names | Where-Object { $_ -ne $psResourceGetName })
        if ($others.Count -gt 0) {
            $module.Warn("Check mode cannot check '$($others -join "', '")' until $psResourceGetName is installed.")
        }
        $module.Result.changed = $true
        $module.Result.resources = @(@{ name = $psResourceGetName; action = 'installed'; versions = @() })
        $module.ExitJson()
    }

    Install-PSResourceGetWithPowerShellGet
    $installedPSResourceGet = $true
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

$results = foreach ($name in $names) {
    $action = switch ($state) {
        'absent' { Invoke-AbsentState -Name $name }
        'present' { Invoke-PresentState -Name $name }
        'latest' { Invoke-LatestState -Name $name }
    }

    if ($installedPSResourceGet -and $name -eq $psResourceGetName -and $action -eq 'none') {
        # It was installed above, before it could be checked here.
        $action = 'installed'
    }
    if ($action -ne 'none') {
        $module.Result.changed = $true
    }

    @{
        name = $name
        action = $action
        # In check mode nothing was changed, so this is what is installed now.
        versions = @(Get-VersionList -Resources (Get-InstalledResource -Name $name))
    }
}

$module.Result.resources = @($results)

$module.ExitJson()
