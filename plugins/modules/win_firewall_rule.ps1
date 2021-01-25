#!powershell

# Copyright: (c) 2014, Timothy Vandenbrande <timothy.vandenbrande@gmail.com>
# Copyright: (c) 2017, Artem Zinenko <zinenkoartem@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy

function ConvertTo-ProtocolType {
    param($protocol)

    $protocolNumber = $protocol -as [int]
    if ($protocolNumber -is [int]) {
        return $protocolNumber
    }

    switch -wildcard ($protocol) {
        "tcp" { return [System.Net.Sockets.ProtocolType]::Tcp -as [int] }
        "udp" { return [System.Net.Sockets.ProtocolType]::Udp -as [int] }
        "icmpv4*" { return [System.Net.Sockets.ProtocolType]::Icmp -as [int] }
        "icmpv6*" { return [System.Net.Sockets.ProtocolType]::IcmpV6 -as [int] }
        default { throw "Unknown protocol '$protocol'." }
    }
}

# See 'Direction' constants here: https://msdn.microsoft.com/en-us/library/windows/desktop/aa364724(v=vs.85).aspx
function ConvertTo-Direction {
    param($directionStr)

    switch ($directionStr) {
        "in" { return 1 }
        "out" { return 2 }
        default { throw "Unknown direction '$directionStr'." }
    }
}

# See 'Action' constants here: https://msdn.microsoft.com/en-us/library/windows/desktop/aa364724(v=vs.85).aspx
function ConvertTo-Action {
    param($actionStr)

    switch ($actionStr) {
        "block" { return 0 }
        "allow" { return 1 }
        default { throw "Unknown action '$actionStr'." }
    }
}

# Profile enum values: https://msdn.microsoft.com/en-us/library/windows/desktop/aa366303(v=vs.85).aspx
function ConvertTo-Profiles
{
    param($profilesList)

    $profiles = ($profilesList | Select-Object -Unique | ForEach-Object {
        switch ($_) {
            "domain" { return 1 }
            "private" { return 2 }
            "public" { return 4 }
            default { throw "Unknown profile '$_'." }
        }
    } | Measure-Object -Sum).Sum

    if ($profiles -eq 7) { return 0x7fffffff }
    return $profiles
}

function ConvertTo-InterfaceTypes
{
    param($interfaceTypes)

    return ($interfaceTypes | Select-Object -Unique | ForEach-Object {
        switch ($_) {
            "wireless" { return "Wireless" }
            "lan" { return "Lan" }
            "ras" { return "RemoteAccess" }
            default { throw "Unknown interface type '$_'." }
        }
    }) -Join ","
}

function ConvertTo-EdgeTraversalOptions
{
    param($edgeTraversalOptionsStr)

    switch ($edgeTraversalOptionsStr) {
        "yes" { return 1 }
        "deferapp" { return 2 }
        "deferuser" { return 3 }
        default { throw "Unknown edge traversal options '$edgeTraversalOptionsStr'." }
    }
}

function ConvertTo-SecureFlags
{
    param($secureFlagsStr)

    switch ($secureFlagsStr) {
        "authnoencap" { return 1 }
        "authenticate" { return 2 }
        "authdynenc" { return 3 }
        "authenc" { return 4 }
        default { throw "Unknown secure flags '$secureFlagsStr'." }
    }
}

$ErrorActionPreference = "Stop"

$result = @{
    changed = $false
}

$params = Parse-Args $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false
$diff_support = Get-AnsibleParam -obj $params -name "_ansible_diff" -type "bool" -default $false

$name = Get-AnsibleParam -obj $params -name "name"
$description = Get-AnsibleParam -obj $params -name "description" -type "str"
$direction = Get-AnsibleParam -obj $params -name "direction" -type "str" -validateset "in","out"
$action = Get-AnsibleParam -obj $params -name "action" -type "str" -validateset "allow","block"
$program = Get-AnsibleParam -obj $params -name "program" -type "str"
$group = Get-AnsibleParam -obj $params -name "group" -type "str"
$service = Get-AnsibleParam -obj $params -name "service" -type "str"
$enabled = Get-AnsibleParam -obj $params -name "enabled" -type "bool" -aliases "enable"
$profiles = Get-AnsibleParam -obj $params -name "profiles" -type "list" -aliases "profile"
$localip = Get-AnsibleParam -obj $params -name "localip" -type "str"
$remoteip = Get-AnsibleParam -obj $params -name "remoteip" -type "str"
$localport = Get-AnsibleParam -obj $params -name "localport" -type "str"
$remoteport = Get-AnsibleParam -obj $params -name "remoteport" -type "str"
$protocol = Get-AnsibleParam -obj $params -name "protocol" -type "str"
$interfacetypes = Get-AnsibleParam -obj $params -name "interfacetypes" -type "list"
$edge = Get-AnsibleParam -obj $params -name "edge" -type "str" -validateset "no","yes","deferapp","deferuser"
$security = Get-AnsibleParam -obj $params -name "security" -type "str" -validateset "notrequired","authnoencap","authenticate","authdynenc","authenc"
$icmp_type_code = Get-AnsibleParam -obj $params -name "icmp_type_code" -type "list"

$state = Get-AnsibleParam -obj $params -name "state" -type "str" -default "present" -validateset "present","absent"

if (-not $name -and -not $group) {
    Fail-Json -obj $result -message "Either name or group must be specified"
}

if ($diff_support) {
    $result.diff = @{}
    $result.diff.prepared = ""
}

if ($null -ne $icmp_type_code) {
    # COM representation is just "<type>:<code>,<type2>:<code>" so we just join our list
    $icmp_type_code = $icmp_type_code -join ","
}

try {
    $fw = New-Object -ComObject HNetCfg.FwPolicy2

    # If name was specified, filter the rules by name, otherwise find all the rules in the group.
    $existingRules = $fw.Rules | Where-Object {
        if ($name) {
            $_.Name -eq $name
        } else {
            $_.Grouping -eq $group
        }
    }

    # INetFwRule interface description: https://msdn.microsoft.com/en-us/library/windows/desktop/aa365344(v=vs.85).aspx
    $new_rule = New-Object -ComObject HNetCfg.FWRule
    if ($name) {
        $new_rule.Name = $name
    }
    # the default for enabled in module description is "true", but the actual COM object defaults to "false" when created
    if ($null -ne $enabled) { $new_rule.Enabled = $enabled } else { $new_rule.Enabled = $true }
    if ($null -ne $description) { $new_rule.Description = $description }
    if ($null -ne $group) { $new_rule.Grouping = $group }
    if ($null -ne $program -and $program -ne "any") { $new_rule.ApplicationName = [System.Environment]::ExpandEnvironmentVariables($program) }
    if ($null -ne $service -and $service -ne "any") { $new_rule.ServiceName = $service }
    if ($null -ne $protocol -and $protocol -ne "any") { $new_rule.Protocol = ConvertTo-ProtocolType -protocol $protocol }
    if ($null -ne $localport -and $localport -ne "any") { $new_rule.LocalPorts = $localport }
    if ($null -ne $remoteport -and $remoteport -ne "any") { $new_rule.RemotePorts = $remoteport }
    if ($null -ne $localip -and $localip -ne "any") { $new_rule.LocalAddresses = $localip }
    if ($null -ne $remoteip -and $remoteip -ne "any") { $new_rule.RemoteAddresses = $remoteip }
    if ($null -ne $icmp_type_code -and $icmp_type_code -ne "any") { $new_rule.IcmpTypesAndCodes = $icmp_type_code }
    if ($null -ne $direction) { $new_rule.Direction = ConvertTo-Direction -directionStr $direction }
    if ($null -ne $action) { $new_rule.Action = ConvertTo-Action -actionStr $action }
    # Profiles value cannot be a uint32, but the "all profiles" value (0x7FFFFFFF) will often become a uint32, so must cast to [int]
    if ($null -ne $profiles) { $new_rule.Profiles = [int](ConvertTo-Profiles -profilesList $profiles) }
    if ($null -ne $interfacetypes -and @(Compare-Object -ReferenceObject $interfacetypes -DifferenceObject @("any")).Count -ne 0) { $new_rule.InterfaceTypes = ConvertTo-InterfaceTypes -interfaceTypes $interfacetypes }
    if ($null -ne $edge -and $edge -ne "no") {
        # EdgeTraversalOptions property exists only from Windows 7/Windows Server 2008 R2: https://msdn.microsoft.com/en-us/library/windows/desktop/dd607256(v=vs.85).aspx
        if ($new_rule | Get-Member -Name 'EdgeTraversalOptions') {
            $new_rule.EdgeTraversalOptions = ConvertTo-EdgeTraversalOptions -edgeTraversalOptionsStr $edge
        }
    }
    if ($null -ne $security -and $security -ne "notrequired") {
        # SecureFlags property exists only from Windows 8/Windows Server 2012: https://msdn.microsoft.com/en-us/library/windows/desktop/hh447465(v=vs.85).aspx
        if ($new_rule | Get-Member -Name 'SecureFlags') {
            $new_rule.SecureFlags = ConvertTo-SecureFlags -secureFlagsStr $security
        }
    }

    $fwPropertiesToCompare = @('Description','Direction','Action','ApplicationName','Grouping','ServiceName','Enabled','Profiles','LocalAddresses','RemoteAddresses','LocalPorts','RemotePorts','Protocol','InterfaceTypes', 'EdgeTraversalOptions', 'SecureFlags','IcmpTypesAndCodes')
    $userPassedArguments = @($description, $direction, $action, $program, $group, $service, $enabled, $profiles, $localip, $remoteip, $localport, $remoteport, $protocol, $interfacetypes, $edge, $security, $icmp_type_code)

    if ($state -eq "absent") {
        if (-not $existingRules) {
            if ($name) {
                $result.msg = "Firewall rule '$name' does not exist."
            } else {
                $result.msg = "No firewall rules in group '$group' exist."
            }

        } else {
            $rules = foreach ($rule in $existingRules) {
                $rule.Name  # Output name for module msg string.

                if ($diff_support) {
                    $result.diff.prepared += "-[$($rule.Name)]`n"
                    foreach ($prop in $fwPropertiesToCompare) {
                        $result.diff.prepared += "-$($prop)='$($rule.$prop)'`n"
                    }
                }

                if (-not $check_mode) {
                    $fw.Rules.Remove($rule.Name)
                }
                $result.changed = $true
            }
            $result.msg = "Firewall rule(s) '$($rules -join "', '")' removed."
        }
    } elseif ($state -eq "present") {
        if (-not $existingRules -and $name) {
            # name was specified and no rules were found, create the rule
            if ($diff_support) {
                $result.diff.prepared += "+[$($new_rule.Name)]`n"
                foreach ($prop in $fwPropertiesToCompare) {
                    $result.diff.prepared += "+$($prop)='$($new_rule.$prop)'`n"
                }
            }

            if (-not $check_mode) {
                $fw.Rules.Add($new_rule)
            }
            $result.changed = $true
            $result.msg = "Firewall rule '$name' created."
        } elseif ($existingRules) {
            # Either name or group was specified which matched existing rules, check the properties
            $changedRules = [System.Collections.Generic.List[String]]@()
            $unchangedRules = [System.Collections.Generic.List[String]]@()

            foreach ($existingRule in $existingRules) {
                if ($diff_support) {
                    $result.diff.prepared += "[$($existingRule.Name)]`n"
                }

                $changed = $false
                for($i = 0; $i -lt $fwPropertiesToCompare.Length; $i++) {
                    $prop = $fwPropertiesToCompare[$i]
                    if($null -ne $userPassedArguments[$i]) { # only change values the user passes in task definition
                        if ($existingRule.$prop -ne $new_rule.$prop) {
                            if ($diff_support) {
                                $result.diff.prepared += "-$($prop)='$($existingRule.$prop)'`n"
                                $result.diff.prepared += "+$($prop)='$($new_rule.$prop)'`n"
                            }

                            if (-not $check_mode) {
                                # Profiles value cannot be a uint32, but the "all profiles" value (0x7FFFFFFF) will often become a uint32, so must cast to [int]
                                # to prevent InvalidCastException under PS5+
                                If($prop -eq 'Profiles') {
                                    $existingRule.Profiles = [int] $new_rule.$prop
                                }
                                Else {
                                    $existingRule.$prop = $new_rule.$prop
                                }
                            }
                            $changed = $true
                        }
                    }
                }

                if ($changed) {
                    $result.changed = $true
                    $changedRules.Add($existingRule.Name)
                } else {
                    $unchangedRules.Add($existingRule.Name)
                }
            }

            $result.msg = "Firewall rule(s) changed '$($changedRules -join "', '")' - unchanged '$($unchangedRules -join "', '")'"
        }
    }
} catch [Exception] {
    $ex = $_
    $result['exception'] = $($ex | Out-String)
    Fail-Json $result $ex.Exception.Message
}

Exit-Json $result
