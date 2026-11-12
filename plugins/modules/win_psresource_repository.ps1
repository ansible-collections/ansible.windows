#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils.PSResourceGet

$spec = @{
    options = @{
        name = @{ type = 'str'; required = $true }
        uri = @{ type = 'str'; aliases = @('source_location') }
        state = @{ type = 'str'; default = 'present'; choices = @('absent', 'present') }
        trusted = @{ type = 'bool' }
        priority = @{ type = 'int' }
        api_version = @{
            type = 'str'
            choices = @('v2', 'v3', 'local', 'nugetServer', 'containerRegistry')
        }
        credential_info = @{
            type = 'dict'
            options = @{
                vault_name = @{ type = 'str'; required = $true }
                secret_name = @{ type = 'str'; required = $true }
            }
        }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$uri = $module.Params.uri
$state = $module.Params.state
$trusted = $module.Params.trusted
$priority = $module.Params.priority
$apiVersion = $module.Params.api_version
$credentialInfo = $module.Params.credential_info

try {
    Import-AnsiblePSResourceGet
}
catch {
    $module.FailJson($_.Exception.Message, $_)
}

if ([WildcardPattern]::ContainsWildcardCharacters($name)) {
    $module.FailJson("The repository name '$name' cannot contain wildcard characters.")
}
if ($null -ne $priority -and ($priority -lt 0 -or $priority -gt 100)) {
    $module.FailJson("priority must be between 0 and 100, got $priority.")
}

if ($state -eq 'present' -and $credentialInfo -and
    -not (Get-Module -ListAvailable -Name Microsoft.PowerShell.SecretManagement)) {
    $module.FailJson("credential_info needs the Microsoft.PowerShell.SecretManagement module to read the secret, but it is not installed.")
}

$desiredUri = $null
if ($uri) {
    if (-not [Uri]::TryCreate($uri, [UriKind]::Absolute, [ref]$desiredUri)) {
        $module.FailJson("uri '$uri' is not a valid absolute URI or path.")
    }
}

$repo = Get-PSResourceRepository -Name $name -ErrorAction SilentlyContinue
$before = if ($repo) { ConvertTo-AnsiblePSResourceRepositoryInfo -Repository $repo } else { @{} }
$after = $before.Clone()

if ($state -eq 'absent') {
    if ($repo) {
        if (-not $module.CheckMode) {
            try {
                Unregister-PSResourceRepository -Name $name -ErrorAction Stop
            }
            catch {
                $module.FailJson("Failed to unregister repository '$name': $($_.Exception.Message)", $_)
            }
        }
        $after = @{}
        $module.Result.changed = $true
    }
}
elseif (-not $repo) {
    $isPSGallery = $name -eq 'PSGallery' -and -not $uri
    if (-not $uri -and -not $isPSGallery) {
        $module.FailJson("uri is required when registering a new repository other than 'PSGallery'.")
    }

    $registerParams = @{ ErrorAction = 'Stop' }
    if ($isPSGallery) {
        $registerParams.PSGallery = $true
    }
    else {
        $registerParams.Name = $name
        $registerParams.Uri = $desiredUri
        if ($apiVersion) { $registerParams.ApiVersion = $apiVersion }
        if ($credentialInfo) {
            $registerParams.CredentialInfo = [Microsoft.PowerShell.PSResourceGet.UtilClasses.PSCredentialInfo]::new(
                $credentialInfo.vault_name, $credentialInfo.secret_name)
        }
    }
    if ($trusted) { $registerParams.Trusted = $true }
    if ($null -ne $priority) { $registerParams.Priority = $priority }

    if (-not $module.CheckMode) {
        try {
            Register-PSResourceRepository @registerParams
        }
        catch {
            $module.FailJson("Failed to register repository '$name': $($_.Exception.Message)", $_)
        }
    }

    $after = @{
        name = $name
        uri = if ($isPSGallery) { 'https://www.powershellgallery.com/api/v2' } else { $uri }
        trusted = [bool]$trusted
        priority = if ($null -ne $priority) { $priority } else { 50 }
        api_version = if ($apiVersion) { $apiVersion } else { $null }
        credential_info = if ($credentialInfo) {
            @{ vault_name = $credentialInfo.vault_name; secret_name = $credentialInfo.secret_name }
        }
        else { $null }
    }
    $module.Result.changed = $true
}
else {
    $setParams = @{}

    if ($desiredUri -and $desiredUri.AbsoluteUri -ne $repo.Uri.AbsoluteUri) {
        $setParams.Uri = $desiredUri
        $after.uri = $uri
    }
    if ($null -ne $trusted -and $trusted -ne [bool]$repo.Trusted) {
        $setParams.Trusted = $trusted
        $after.trusted = $trusted
    }
    if ($null -ne $priority -and $priority -ne $repo.Priority) {
        $setParams.Priority = $priority
        $after.priority = $priority
    }
    if ($apiVersion -and $apiVersion -ne $repo.ApiVersion.ToString()) {
        $setParams.ApiVersion = $apiVersion
        $after.api_version = $apiVersion
    }
    if ($credentialInfo) {
        $current = $repo.CredentialInfo
        if (-not $current -or
            $current.VaultName -ne $credentialInfo.vault_name -or
            $current.SecretName -ne $credentialInfo.secret_name) {
            $setParams.CredentialInfo = [Microsoft.PowerShell.PSResourceGet.UtilClasses.PSCredentialInfo]::new(
                $credentialInfo.vault_name, $credentialInfo.secret_name)
            $after.credential_info = @{
                vault_name = $credentialInfo.vault_name
                secret_name = $credentialInfo.secret_name
            }
        }
    }

    if ($setParams.Count -gt 0) {
        if (-not $module.CheckMode) {
            try {
                Set-PSResourceRepository -Name $name @setParams -ErrorAction Stop
            }
            catch {
                $module.FailJson("Failed to update repository '$name': $($_.Exception.Message)", $_)
            }
        }
        $module.Result.changed = $true
    }
}

if ($module.Result.changed -and -not $module.CheckMode -and $state -eq 'present') {
    # Report what the repository actually looks like after the change.
    $updated = Get-PSResourceRepository -Name $name -ErrorAction SilentlyContinue
    if ($updated) {
        $after = ConvertTo-AnsiblePSResourceRepositoryInfo -Repository $updated
    }
}

if ($module.DiffMode) {
    $module.Diff.before = $before
    $module.Diff.after = $after
}

$module.ExitJson()
