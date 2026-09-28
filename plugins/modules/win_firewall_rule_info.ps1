#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = 'str' }
        group = @{ type = 'str' }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$group = $module.Params.group

$module.Result.rules = @()

try {
    $fw_policy = New-Object -ComObject HNetCfg.FwPolicy2
    $raw_rules = $fw_policy.Rules
}
catch {
    $module.FailJson("Failed to initialize Windows Firewall Policy COM Object: $($_.Exception.Message)", $_)
}

foreach ($rule in $raw_rules) {
    # Filter by Name if provided
    if ($null -ne $name -and $rule.Name -ne $name) {
        continue
    }

    # Filter by Group if provided
    if ($null -ne $group -and $rule.Grouping -ne $group) {
        continue
    }

    $rule_info = @{
        name = $rule.Name
        description = $rule.Description
        enabled = $rule.Enabled
        action = $rule.Action
        direction = $rule.Direction
        protocol = $rule.Protocol
        local_ports = $rule.LocalPorts
        remote_ports = $rule.RemotePorts
        local_addresses = $rule.LocalAddresses
        remote_addresses = $rule.RemoteAddresses
        application_name = $rule.ApplicationName
        service_name = $rule.ServiceName
        profiles = $rule.Profiles
        group = $rule.Grouping
    }

    $module.Result.rules += $rule_info
}

$module.ExitJson()
