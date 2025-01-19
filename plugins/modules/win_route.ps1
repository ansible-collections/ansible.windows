#!powershell

# Copyright: (c) 2025, Red Hat, Inc.
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)


#AnsibleRequires -CSharpUtil Ansible.Basic
$spec = @{
    options = @{
        destination = @{ type = 'str' ; required = $true }
        gateway = @{ type = 'str' ; default = "0.0.0.0" }
        state = @{ type = 'str' ; default = "present" ; choices = @( "present", "absent") }
        metric = @{ type = 'int' ; default = 1 }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$Destination = $module.Params.destination
$Gateway = $module.Params.gateway
$State = $module.Params.state
$Metric = $module.metric
$check_mode = $module.Checkmode

$IpAddress = $Destination.split('/')[0]
$Route = Get-CimInstance win32_ip4PersistedrouteTable -Filter "Destination = '$($IpAddress)'"

if ($State -eq "present") {
    if (!($Route)) {
        try {
            # Find Interface Index
            $InterfaceIndex = Find-NetRoute -RemoteIPAddress $Gateway | Select-Object -First 1 -ExpandProperty InterfaceIndex

            # Add network route
            $routeParams = @{
                DestinationPrefix = $Destination
                NextHop = $Gateway
                InterfaceIndex = $InterfaceIndex
                RouteMetric = $Metric
                ErrorAction = "Stop"
                WhatIf = $check_mode
            }
            New-NetRoute @routeParams | Out-Null
            $module.result.changed = $true
            $module.result.msg = "Route added"

        }
        catch { $module.FailJson("Failed to create a new route: $_", $_) }
    }
    else { $module.result.msg = "Static route already exists" }
}
else {
    if ($Route) {
        try {

            Remove-NetRoute -DestinationPrefix $Destination -Confirm:$false -ErrorAction Stop -WhatIf:$check_mode
            $module.result.changed = $true
            $module.result.msg = "Route removed"
        }
        catch { $module.FailJson("Failed to remove the requested route: $_", $_) }
    }
    else { $module.result.msg = "No route to remove" }
}

$module.ExitJson()
