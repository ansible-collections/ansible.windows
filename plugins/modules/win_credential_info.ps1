#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -CSharpUtil ..module_utils._CredentialManager

using namespace ansible_collections.ansible.windows.plugins.module_utils._CredentialManager

$spec = @{
    options = @{
        name = @{ type = "str" }
        type = @{
            type = "str"
            choices = @("domain_certificate", "domain_password", "generic_certificate", "generic_password")
        }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$type = $module.Params.type

$type_map = @{
    "domain_password" = [CredentialType]::DomainPassword
    "domain_certificate" = [CredentialType]::DomainCertificate
    "generic_password" = [CredentialType]::Generic
    "generic_certificate" = [CredentialType]::GenericCertificate
}

Function ConvertTo-CredentialOutput {
    param($InputObject)

    $info = @{
        name = $InputObject.TargetName
        type = $InputObject.Type.ToString()
        username = $InputObject.UserName
        alias = $InputObject.TargetAlias
        comment = $InputObject.Comment
        persistence = $InputObject.Persist.ToString()
        attributes = @()
    }

    foreach ($attribute in $InputObject.Attributes) {
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

if ($null -ne $name -and $null -ne $type -and $name -notlike '*`**') {
    # Exact name + type: use CredReadW for single lookup
    $mapped_type = $type_map[$type]
    $credential = [Credential]::GetCredential($name, $mapped_type)

    if ($null -ne $credential) {
        $module.Result.exists = $true
        $module.Result.credentials = @(ConvertTo-CredentialOutput -InputObject $credential)
    }
}
elseif ($null -ne $name -and $name -notlike '*`**') {
    # Name without wildcard - CredEnumerateW requires a wildcard in the filter,
    # so try CredReadW across all credential types
    $all_types = @(
        [CredentialType]::Generic,
        [CredentialType]::DomainPassword,
        [CredentialType]::DomainCertificate,
        [CredentialType]::GenericCertificate
    )
    $found = [System.Collections.Generic.List[object]]::new()
    foreach ($cred_type in $all_types) {
        $credential = [Credential]::GetCredential($name, $cred_type)
        if ($null -ne $credential) {
            $found.Add((ConvertTo-CredentialOutput -InputObject $credential))
        }
    }

    if ($found.Count -gt 0) {
        $module.Result.exists = $true
        [array]$module.Result.credentials = $found | Sort-Object -Property { $_.name }
    }
}
else {
    # Use CredEnumerateW - filter is either null (all) or contains a wildcard
    $filter = $name
    $credentials = [Credential]::EnumerateCredentials($filter)

    if ($null -ne $type) {
        $mapped_type = $type_map[$type]
        $credentials = @($credentials | Where-Object { $_.Type -eq $mapped_type })
    }

    if ($credentials.Count -gt 0) {
        $module.Result.exists = $true
        [array]$module.Result.credentials = $credentials | ForEach-Object {
            ConvertTo-CredentialOutput -InputObject $_
        } | Sort-Object -Property { $_.name }
    }
}

$module.ExitJson()
