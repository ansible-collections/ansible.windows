#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -CSharpUtil ansible_collections.ansible.windows.plugins.module_utils.CredentialManager

$spec = @{
    options = @{
        name = @{ type = "str" }
        type = @{
            type = "str"
            choices = @("domain_password", "domain_certificate", "generic_password", "generic_certificate")
        }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$type = $module.Params.type

# Map user-friendly type names to enum values
$type_map = @{
    "domain_password" = [Ansible.CredentialManager.CredentialType]::DomainPassword
    "domain_certificate" = [Ansible.CredentialManager.CredentialType]::DomainCertificate
    "generic_password" = [Ansible.CredentialManager.CredentialType]::Generic
    "generic_certificate" = [Ansible.CredentialManager.CredentialType]::GenericCertificate
}

Function ConvertTo-CredentialInfo {
    param($Credential)

    $info = @{
        name = $Credential.TargetName
        type = $Credential.Type.ToString()
        username = $Credential.UserName
        alias = $Credential.TargetAlias
        comment = $Credential.Comment
        persistence = $Credential.Persist.ToString()
        attributes = @()
    }

    foreach ($attribute in $Credential.Attributes) {
        $attr_info = @{
            name = $attribute.Keyword
            data = $null
        }
        if ($null -ne $attribute.Value -and $attribute.Value.Length -gt 0) {
            $attr_info.data = [System.Convert]::ToBase64String($attribute.Value)
        }
        $info.attributes += $attr_info
    }

    return $info
}

$module.Result.exists = $false
$module.Result.credentials = @()

if ($null -ne $name -and $null -ne $type) {
    # When both name and type are specified, use CredReadW for exact lookup
    $mapped_type = $type_map[$type]
    $credential = [Ansible.CredentialManager.Credential]::GetCredential($name, $mapped_type)

    if ($null -ne $credential) {
        $module.Result.exists = $true
        $module.Result.credentials = @(ConvertTo-CredentialInfo -Credential $credential)
    }
}
elseif ($null -ne $name -and $name -notlike '*`**') {
    # Name specified without wildcard and no type — CredEnumerateW requires
    # a wildcard in the filter, so try CredReadW across all credential types
    $all_types = @(
        [Ansible.CredentialManager.CredentialType]::Generic,
        [Ansible.CredentialManager.CredentialType]::DomainPassword,
        [Ansible.CredentialManager.CredentialType]::DomainCertificate,
        [Ansible.CredentialManager.CredentialType]::GenericCertificate
    )
    $found = [System.Collections.Generic.List[object]]::new()
    foreach ($cred_type in $all_types) {
        $credential = [Ansible.CredentialManager.Credential]::GetCredential($name, $cred_type)
        if ($null -ne $credential) {
            $found.Add((ConvertTo-CredentialInfo -Credential $credential))
        }
    }

    if ($found.Count -gt 0) {
        $module.Result.exists = $true
        [array]$module.Result.credentials = $found | Sort-Object -Property { $_.name }
    }
}
else {
    # Use CredEnumerateW — filter is either null (all) or contains a wildcard
    $filter = $name  # null filter returns all credentials
    $credentials = [Ansible.CredentialManager.Credential]::EnumerateCredentials($filter)

    # Filter by type if specified
    if ($null -ne $type) {
        $mapped_type = $type_map[$type]
        $credentials = @($credentials | Where-Object { $_.Type -eq $mapped_type })
    }

    if ($credentials.Count -gt 0) {
        $module.Result.exists = $true
        [array]$module.Result.credentials = $credentials | ForEach-Object {
            ConvertTo-CredentialInfo -Credential $_
        } | Sort-Object -Property { $_.name }
    }
}

$module.ExitJson()
