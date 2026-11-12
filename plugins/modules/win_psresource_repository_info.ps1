#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils.PSResourceGet

$spec = @{
    options = @{
        name = @{ type = 'list'; elements = 'str'; default = @('*') }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$module.Result.repositories = @()

try {
    Import-AnsiblePSResourceGet
}
catch {
    $module.FailJson($_.Exception.Message, $_)
}

# Get all repositories and filter ourselves so a name that doesn't exist
# returns an empty list instead of an error.
try {
    $repositories = @(Get-PSResourceRepository -ErrorAction Stop)
}
catch {
    $module.FailJson("Failed to get PSResource repositories: $($_.Exception.Message)", $_)
}

$module.Result.repositories = @(
    $repositories | Where-Object {
        $repoName = $_.Name
        foreach ($pattern in $module.Params.name) {
            if ($repoName -like $pattern) {
                $true
                break
            }
        }
    } | Sort-Object -Property Name | ForEach-Object {
        ConvertTo-AnsiblePSResourceRepositoryInfo -Repository $_
    }
)

$module.ExitJson()
