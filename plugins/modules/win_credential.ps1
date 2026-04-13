#!powershell

# Copyright: (c) 2018, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -CSharpUtil ansible_collections.ansible.windows.plugins.module_utils.CredentialManager

$spec = @{
    options = @{
        alias = @{ type = "str" }
        attributes = @{
            type = "list"
            elements = "dict"
            options = @{
                name = @{ type = "str"; required = $true }
                data = @{ type = "str" }
                data_format = @{ type = "str"; default = "text"; choices = @("base64", "text") }
            }
        }
        comment = @{ type = "str" }
        name = @{ type = "str"; required = $true }
        persistence = @{ type = "str"; default = "local"; choices = @("enterprise", "local") }
        secret = @{ type = "str"; no_log = $true }
        secret_format = @{ type = "str"; default = "text"; choices = @("base64", "text") }
        state = @{ type = "str"; default = "present"; choices = @("absent", "present") }
        type = @{
            type = "str"
            required = $true
            choices = @("domain_password", "domain_certificate", "generic_password", "generic_certificate")
        }
        update_secret = @{ type = "str"; default = "always"; choices = @("always", "on_create") }
        username = @{ type = "str" }
    }
    required_if = @(
        , @("state", "present", @("username"))
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$alias = $module.Params.alias
$attributes = $module.Params.attributes
$comment = $module.Params.comment
$name = $module.Params.name
$persistence = $module.Params.persistence
$secret = $module.Params.secret
$secret_format = $module.Params.secret_format
$state = $module.Params.state
$type = $module.Params.type
$update_secret = $module.Params.update_secret
$username = $module.Params.username

$module.Diff.before = ""
$module.Diff.after = ""

Function ConvertTo-CredentialAttribute {
    param($Attributes)

    $converted_attributes = [System.Collections.Generic.List`1[Ansible.CredentialManager.CredentialAttribute]]@()
    foreach ($attribute in $Attributes) {
        $new_attribute = New-Object -TypeName Ansible.CredentialManager.CredentialAttribute
        $new_attribute.Keyword = $attribute.name

        if ($null -ne $attribute.data) {
            if ($attribute.data_format -eq "base64") {
                $new_attribute.Value = [System.Convert]::FromBase64String($attribute.data)
            }
            else {
                $new_attribute.Value = [System.Text.Encoding]::UTF8.GetBytes($attribute.data)
            }
        }
        $converted_attributes.Add($new_attribute) > $null
    }

    return , $converted_attributes
}

Function Get-DiffInfo {
    param($AnsibleCredential)

    $diff = @{
        alias = $AnsibleCredential.TargetAlias
        attributes = [System.Collections.ArrayList]@()
        comment = $AnsibleCredential.Comment
        name = $AnsibleCredential.TargetName
        persistence = $AnsibleCredential.Persist.ToString()
        type = $AnsibleCredential.Type.ToString()
        username = $AnsibleCredential.UserName
    }

    foreach ($attribute in $AnsibleCredential.Attributes) {
        $attribute_info = @{
            name = $attribute.Keyword
            data = $null
        }
        if ($null -ne $attribute.Value) {
            $attribute_info.data = [System.Convert]::ToBase64String($attribute.Value)
        }
        $diff.attributes.Add($attribute_info) > $null
    }

    return , $diff
}

# If the username is a certificate thumbprint, verify it's a valid cert in the CurrentUser/Personal store
if ($null -ne $username -and $type -in @("domain_certificate", "generic_certificate")) {
    # Ensure the thumbprint is upper case with no spaces or hyphens
    $username = $username.ToUpperInvariant().Replace(" ", "").Replace("-", "")

    $certificate = Get-Item -LiteralPath Cert:\CurrentUser\My\$username -ErrorAction SilentlyContinue
    if ($null -eq $certificate) {
        $module.FailJson("Failed to find certificate with the thumbprint $username in the CurrentUser\My store")
    }
}

# Convert the input secret to a byte array
if ($null -ne $secret) {
    if ($secret_format -eq "base64") {
        $secret = [System.Convert]::FromBase64String($secret)
    }
    else {
        $secret = [System.Text.Encoding]::Unicode.GetBytes($secret)
    }
}

$persistence = switch ($persistence) {
    "local" { [Ansible.CredentialManager.CredentialPersist]::LocalMachine }
    "enterprise" { [Ansible.CredentialManager.CredentialPersist]::Enterprise }
}

$type = switch ($type) {
    "domain_password" { [Ansible.CredentialManager.CredentialType]::DomainPassword }
    "domain_certificate" { [Ansible.CredentialManager.CredentialType]::DomainCertificate }
    "generic_password" { [Ansible.CredentialManager.CredentialType]::Generic }
    "generic_certificate" { [Ansible.CredentialManager.CredentialType]::GenericCertificate }
}

$existing_credential = [Ansible.CredentialManager.Credential]::GetCredential($name, $type)
if ($null -ne $existing_credential) {
    $module.Diff.before = Get-DiffInfo -AnsibleCredential $existing_credential
}

if ($state -eq "absent") {
    if ($null -ne $existing_credential) {
        if (-not $module.CheckMode) {
            $existing_credential.Delete()
        }
        $module.Result.changed = $true
    }
}
else {
    if ($null -eq $existing_credential) {
        $new_credential = New-Object -TypeName Ansible.CredentialManager.Credential
        $new_credential.Type = $type
        $new_credential.TargetName = $name
        $new_credential.Comment = if ($comment) { $comment } else { [NullString]::Value }
        $new_credential.Secret = $secret
        $new_credential.Persist = $persistence
        $new_credential.TargetAlias = if ($alias) { $alias } else { [NullString]::Value }
        $new_credential.UserName = $username

        if ($null -ne $attributes) {
            $new_credential.Attributes = ConvertTo-CredentialAttribute -Attributes $attributes
        }

        if (-not $module.CheckMode) {
            $new_credential.Write($false)
        }
        $module.Result.changed = $true
    }
    else {
        $changed = $false
        $preserve_blob = $false

        # make sure we do case comparison for the comment
        if ($existing_credential.Comment -cne $comment) {
            $existing_credential.Comment = $comment
            $changed = $true
        }

        if ($existing_credential.Persist -ne $persistence) {
            $existing_credential.Persist = $persistence
            $changed = $true
        }

        if ($existing_credential.TargetAlias -ne $alias) {
            $existing_credential.TargetAlias = $alias
            $changed = $true
        }

        if ($existing_credential.UserName -ne $username) {
            $existing_credential.UserName = $username
            $changed = $true
        }

        if ($null -ne $attributes) {
            $attribute_changed = $false

            $new_attributes = ConvertTo-CredentialAttribute -Attributes $attributes
            if ($new_attributes.Count -ne $existing_credential.Attributes.Count) {
                $attribute_changed = $true
            }
            else {
                for ($i = 0; $i -lt $new_attributes.Count; $i++) {
                    $new_keyword = $new_attributes[$i].Keyword
                    $new_value = $new_attributes[$i].Value
                    if ($null -eq $new_value) {
                        $new_value = ""
                    }
                    else {
                        $new_value = [System.Convert]::ToBase64String($new_value)
                    }

                    $existing_keyword = $existing_credential.Attributes[$i].Keyword
                    $existing_value = $existing_credential.Attributes[$i].Value
                    if ($null -eq $existing_value) {
                        $existing_value = ""
                    }
                    else {
                        $existing_value = [System.Convert]::ToBase64String($existing_value)
                    }

                    if (($new_keyword -cne $existing_keyword) -or ($new_value -ne $existing_value)) {
                        $attribute_changed = $true
                        break
                    }
                }
            }

            if ($attribute_changed) {
                $existing_credential.Attributes = $new_attributes
                $changed = $true
            }
        }

        if ($null -eq $secret) {
            # If we haven't explicitly set a secret, tell Windows to preserve the existing blob
            $preserve_blob = $true
            $existing_credential.Secret = $null
        }
        elseif ($update_secret -eq "always") {
            # We should only set the password if we can't read the existing one or it doesn't match our secret
            if ($existing_credential.Secret.Length -eq 0) {
                # We cannot read the secret so don't know if its the configured secret
                $existing_credential.Secret = $secret
                $changed = $true
            }
            else {
                # We can read the secret so compare with our input
                $input_secret_b64 = [System.Convert]::ToBase64String($secret)
                $actual_secret_b64 = [System.Convert]::ToBase64String($existing_credential.Secret)
                if ($input_secret_b64 -ne $actual_secret_b64) {
                    $existing_credential.Secret = $secret
                    $changed = $true
                }
            }
        }

        if ($changed -and -not $module.CheckMode) {
            $existing_credential.Write($preserve_blob)
        }
        $module.Result.changed = $changed
    }

    if ($module.CheckMode) {
        # We cannot reliably get the credential in check mode, set it based on the input
        $module.Diff.after = @{
            alias = $alias
            attributes = $attributes
            comment = $comment
            name = $name
            persistence = $persistence.ToString()
            type = $type.ToString()
            username = $username
        }
    }
    else {
        # Get a new copy of the credential and use that to set the after diff
        $new_credential = [Ansible.CredentialManager.Credential]::GetCredential($name, $type)
        $module.Diff.after = Get-DiffInfo -AnsibleCredential $new_credential
    }
}

$module.ExitJson()
