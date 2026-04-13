#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        disable_windows_update = @{ type = "bool"; default = $false }
        log_level = @{ type = "int" }
        log_path = @{ type = "path" }
        name = @{ type = "list"; elements = "str" }
        source = @{ type = "list"; elements = "str" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$name = $module.Params.name

$commonParams = @{
    Online = $true
}
if ($module.Params.disable_windows_update) {
    $commonParams.LimitAccess = $true
}
if ($module.Params.log_level) {
    $commonParams.LogLevel = $module.Params.log_level
}
if ($module.Params.log_path) {
    $commonParams.LogPath = $module.Params.log_path
}
if ($module.Params.source) {
    $commonParams.Source = $module.Params.source
}

$module.Result.capabilities = @(
    Get-WindowsCapability @commonParams | ForEach-Object -Process {
        if ($name) {
            $hasMatched = $false
            foreach ($pattern in $name) {
                if ($_.Name -like $pattern) {
                    $hasMatched = $true
                    break
                }
            }
            if (-not $hasMatched) {
                return
            }
        }

        # Get-WindowsCapability without -Name gets capabilities with only the
        # Name and State properties set. We get the full information by calling
        # it again with the Name set. We shouldn't use -Name * in the initial
        # call since it takes a long time to retrieve the information for all
        # capabilities.
        $info = Get-WindowsCapability @commonParams -Name $_.Name

        @{
            name = $info.Name
            state = $info.State.ToString()
            display_name = $info.DisplayName
            description = $info.Description
            download_size = $info.DownloadSize
            install_size = $info.InstallSize
        }
    }
)

$module.ExitJson()
