# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

function Import-AnsiblePSResourceGet {
    <#
    .SYNOPSIS
    Imports the Microsoft.PowerShell.PSResourceGet module or throws if it is not available.
    #>
    [CmdletBinding()]
    param()

    $module = Import-Module -Name Microsoft.PowerShell.PSResourceGet -MinimumVersion 1.0.0 -PassThru -ErrorAction SilentlyContinue
    if (-not $module) {
        throw 'The Microsoft.PowerShell.PSResourceGet module version 1.0.0 or newer is required but was not found.'
    }
}

function ConvertTo-AnsiblePSResourceDate {
    <#
    .SYNOPSIS
    Converts a DateTime to an ISO 8601 UTC string, or $null if it is not set.
    #>
    param($Date)

    if ($null -eq $Date -or ([DateTime]$Date).Year -le 1) {
        return $null
    }
    ([DateTime]$Date).ToUniversalTime().ToString("yyyy-MM-dd'T'HH:mm:ss'Z'", [Globalization.CultureInfo]::InvariantCulture)
}

function ConvertTo-AnsiblePSResourceString {
    <#
    .SYNOPSIS
    Converts a value to a string, or $null if it is null or empty.
    #>
    param($Value)

    if ($null -eq $Value) { return $null }
    $str = $Value.ToString()
    if ([string]::IsNullOrEmpty($str)) { return $null }
    $str
}

function Get-AnsiblePSResourceVersionString {
    <#
    .SYNOPSIS
    Gets the full version of a resource including any prerelease label.
    #>
    param($Resource)

    $version = $Resource.Version.ToString()
    if ($Resource.Prerelease) {
        $version = "$version-$($Resource.Prerelease)"
    }
    $version
}

function ConvertTo-AnsiblePSResourceRepositoryInfo {
    <#
    .SYNOPSIS
    Converts a PSRepositoryInfo object to a hashtable to return from a module.
    #>
    param($Repository)

    $credentialInfo = $null
    if ($Repository.CredentialInfo) {
        $credentialInfo = @{
            vault_name = $Repository.CredentialInfo.VaultName
            secret_name = $Repository.CredentialInfo.SecretName
        }
    }

    @{
        name = $Repository.Name
        uri = if ($Repository.Uri) { $Repository.Uri.OriginalString } else { $null }
        trusted = [bool]$Repository.Trusted
        priority = [int]$Repository.Priority
        api_version = $Repository.ApiVersion.ToString()
        credential_info = $credentialInfo
    }
}

function ConvertTo-AnsiblePSResourceInfo {
    <#
    .SYNOPSIS
    Converts an installed PSResourceInfo object to a hashtable to return from a module.
    #>
    param($Resource)

    $dependencies = @(
        foreach ($dep in $Resource.Dependencies) {
            @{
                name = $dep.Name
                version_range = ConvertTo-AnsiblePSResourceString -Value $dep.VersionRange
            }
        }
    )

    @{
        name = $Resource.Name
        type = $Resource.Type.ToString()
        version = $Resource.Version.ToString()
        prerelease = ConvertTo-AnsiblePSResourceString -Value $Resource.Prerelease
        is_prerelease = [bool]$Resource.IsPrerelease
        full_version = Get-AnsiblePSResourceVersionString -Resource $Resource
        repository = ConvertTo-AnsiblePSResourceString -Value $Resource.Repository
        repository_source_location = ConvertTo-AnsiblePSResourceString -Value $Resource.RepositorySourceLocation
        installed_location = ConvertTo-AnsiblePSResourceString -Value $Resource.InstalledLocation
        installed_date = ConvertTo-AnsiblePSResourceDate -Date $Resource.InstalledDate
        published_date = ConvertTo-AnsiblePSResourceDate -Date $Resource.PublishedDate
        updated_date = ConvertTo-AnsiblePSResourceDate -Date $Resource.UpdatedDate
        author = ConvertTo-AnsiblePSResourceString -Value $Resource.Author
        company_name = ConvertTo-AnsiblePSResourceString -Value $Resource.CompanyName
        copyright = ConvertTo-AnsiblePSResourceString -Value $Resource.Copyright
        description = ConvertTo-AnsiblePSResourceString -Value $Resource.Description
        license_uri = ConvertTo-AnsiblePSResourceString -Value $Resource.LicenseUri
        project_uri = ConvertTo-AnsiblePSResourceString -Value $Resource.ProjectUri
        icon_uri = ConvertTo-AnsiblePSResourceString -Value $Resource.IconUri
        release_notes = ConvertTo-AnsiblePSResourceString -Value $Resource.ReleaseNotes
        tags = @($Resource.Tags | Where-Object { $_ } | ForEach-Object { $_.ToString() })
        dependencies = $dependencies
    }
}

Export-ModuleMember -Function Import-AnsiblePSResourceGet, ConvertTo-AnsiblePSResourceRepositoryInfo, `
    ConvertTo-AnsiblePSResourceInfo, Get-AnsiblePSResourceVersionString
