#!powershell

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options             = @{
        name = @{ type = "str"; default = '*'  }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name

$module.Result.exists = $false

$features = Get-WindowsFeature -Name $name

$module.Result.features = @(foreach ($feature in ($features)) {
        # These should closely reflect the options for win_feature
        @{
            name                           = $feature.Name
            display_name                   = $feature.DisplayName
            description                    = $feature.Description
            installed                      = $feature.Installed
            install_state                  = $feature.InstallState.ToString()
            feature_type                   = $feature.FeatureType
            path                           = $feature.Path
            depth                          = $feature.Depth
            depends_on                     = $feature.DependsOn
            parent                         = $feature.Parent
            server_component_descriptor    = $feature.ServerComponentDescriptor
            sub_features                   = $feature.SubFeatures
            system_service                 = $feature.SystemService
            best_practices_model_id        = $feature.BestPracticesModelId
            event_query                    = $feature.EventQuery
            post_configuration_needed      = $feature.PostConfigurationNeeded
            additional_info                = $feature.AdditionalInfo
        }
        $module.Result.exists = $true
    })

$module.ExitJson()
