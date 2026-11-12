#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils.PSResourceGet

$spec = @{
    options = @{
        name = @{ type = 'list'; elements = 'str'; default = @('*') }
        version = @{ type = 'str' }
        type = @{ type = 'str'; choices = @('module', 'script') }
        scope = @{ type = 'str'; choices = @('currentuser', 'allusers') }
        path = @{ type = 'path' }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$module.Result.resources = @()

try {
    Import-AnsiblePSResourceGet
}
catch {
    $module.FailJson($_.Exception.Message, $_)
}

if ($module.Params.version) {
    $versionError = Test-AnsiblePSResourceVersion -Version $module.Params.version
    if ($versionError) {
        $module.FailJson($versionError)
    }
}

$getParams = @{
    Name = $module.Params.name
    # A name that matches nothing is not an error for an info module.
    # Invalid arguments like a malformed version still throw.
    ErrorAction = 'SilentlyContinue'
}
if ($module.Params.version) { $getParams.Version = $module.Params.version }
if ($module.Params.scope) { $getParams.Scope = $module.Params.scope }
if ($module.Params.path) { $getParams.Path = $module.Params.path }

try {
    $resources = @(Get-InstalledPSResource @getParams)
}
catch {
    $module.FailJson("Failed to get installed PSResources: $($_.Exception.Message)", $_)
}

if ($module.Params.type) {
    $resources = @($resources | Where-Object { $_.Type.ToString() -eq $module.Params.type })
}

$module.Result.resources = @(
    $resources | Sort-Object -Property Name, Version | ForEach-Object {
        ConvertTo-AnsiblePSResourceInfo -Resource $_
    }
)

$module.ExitJson()
