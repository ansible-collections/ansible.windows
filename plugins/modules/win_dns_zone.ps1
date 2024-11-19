#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = "str"; required = $true }
        type = @{ type = "str"; choices = "primary", "secondary", "forwarder", "stub" }
        replication = @{ type = "str"; choices = "forest", "domain", "legacy", "none" }
        dynamic_update = @{ type = "str"; choices = "secure", "none", "nonsecureandsecure" }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
        forwarder_timeout = @{ type = "int" }
        dns_servers = @{ type = "list"; elements = "str" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$name = $module.Params.name
$type = $module.Params.type
$replication = $module.Params.replication
$dynamic_update = $module.Params.dynamic_update
$state = $module.Params.state
$dns_servers = $module.Params.dns_servers
$forwarder_timeout = $module.Params.forwarder_timeout

$parms = @{ name = $name }

Function Get-DnsZoneObject {
    Param([PSObject]$Object)
    $parms = @{
        name = $Object.ZoneName.toLower()
        type = $Object.ZoneType.toLower()
        paused = $Object.IsPaused
        shutdown = $Object.IsShutdown
    }

    if ($Object.DynamicUpdate) { $parms.dynamic_update = $Object.DynamicUpdate.toLower() }
    if ($Object.IsReverseLookupZone) { $parms.reverse_lookup = $Object.IsReverseLookupZone }
    if ($Object.ZoneType -like 'forwarder' ) { $parms.forwarder_timeout = $Object.ForwarderTimeout }
    if ($Object.MasterServers) { $parms.dns_servers = $Object.MasterServers.IPAddressToString }
    if (-not $Object.IsDsIntegrated) {
        $parms.replication = "none"
        $parms.zone_file = $Object.ZoneFile
    }
    else {
        $parms.replication = $Object.ReplicationScope.toLower()
    }

    return $parms | Sort-Object
}

Function Compare-DnsZone {
    Param(
        [PSObject]$Original,
        [PSObject]$Updated)

    if ($Original -eq $false) { return $false }
    $props = @('ZoneType', 'DynamicUpdate', 'IsDsIntegrated', 'MasterServers', 'ForwarderTimeout', 'ReplicationScope')
    $x = Compare-Object $Original $Updated -Property $props
    $x.Count -eq 0
}

# attempt import of module
Try { Import-Module DnsServer }
Catch { $module.FailJson("The DnsServer module failed to load properly: $($_.Exception.Message)", $_) }

Try {
    # determine current zone state
    $current_zone = Get-DnsServerZone -name $name
    $module.Diff.before = Get-DnsZoneObject -Object $current_zone
    if (-not $type) { $type = $current_zone.ZoneType.toLower() }
    if ($current_zone.ZoneType -like $type) { $current_zone_type_match = $true }
    # check for fast fails
    if ($current_zone.ReplicationScope -like 'none' -and $replication -in @('legacy', 'forest', 'domain')) {
        $module.FailJson("Converting a file backed DNS zone to Active Directory integrated zone is unsupported")
    }
    if ($current_zone.ReplicationScope -in @('legacy', 'forest', 'domain') -and $replication -like 'none') {
        $module.FailJson("Converting Active Directory integrated zone to a file backed DNS zone is unsupported")
    }
    if ($current_zone.IsDsIntegrated -eq $false -and $parms.DynamicUpdate -eq 'secure') {
        $module.FailJson("The secure dynamic update option is only available for Active Directory integrated zones")
    }
}
Catch {
    $module.Diff.before = ""
    $current_zone = $false
}

if ($state -eq "present") {
    # parse replication/zonefile
    if (-not $replication -and $current_zone) {
        $parms.ReplicationScope = $current_zone.ReplicationScope
    }
    elseif ((($replication -eq 'none') -or (-not $replication)) -and (-not $current_zone)) {
        $parms.ZoneFile = "$name.dns"
    }
    elseif (($replication -eq 'none') -and ($current_zone)) {
        $parms.ZoneFile = "$name.dns"
    }
    else {
        $parms.ReplicationScope = $replication
    }
    # parse param
    if ($dynamic_update) { $parms.DynamicUpdate = $dynamic_update }
    if ($dns_servers) { $parms.MasterServers = $dns_servers }
    if ($type -in @('stub', 'forwarder', 'secondary') -and -not $current_zone -and -not $dns_servers) {
        $module.FailJson("The dns_servers param is required when creating new stub, forwarder or secondary zones")
    }
    switch ($type) {
        "primary" {
            # remove irrelevant params
            $parms.Remove('MasterServers')
            if ($parms.ZoneFile -and ($dynamic_update -in @('secure', 'nonsecureandsecure'))) {
                $parms.Remove('DynamicUpdate')
                $module.Warn("Secure DNS updates are available only for Active Directory-integrated zones")
            }
            if (-not $current_zone) {
                # create zone
                Try { Add-DnsServerPrimaryZone @parms -WhatIf:$check_mode }
                Catch { $module.FailJson("Failed to add $type zone $($name): $($_.Exception.Message)", $_) }
            }
            else {
                # update zone
                if (-not $current_zone_type_match) {
                    Try {
                        if ($current_zone.ReplicationScope) {
                            $parms.ReplicationScope = $current_zone.ReplicationScope
                        }
                        else {
                            $parms.Remove('ReplicationScope')
                        }
                        if ($current_zone.ZoneFile) { $parms.ZoneFile = $current_zone.ZoneFile } else { $parms.Remove('ReplicationScope') }
                        if ($current_zone.IsShutdown) { $module.FailJson("Failed to convert DNS zone $($name): this zone is shutdown and cannot be modified") }
                        ConvertTo-DnsServerPrimaryZone @parms -Force -WhatIf:$check_mode
                    }
                    Catch { $module.FailJson("Failed to convert DNS zone $($name): $($_.Exception.Message)", $_) }
                }
                Try {
                    if (-not $parms.ZoneFile) { Set-DnsServerPrimaryZone -Name $name -ReplicationScope $parms.ReplicationScope -WhatIf:$check_mode }
                    if ($dynamic_update) { Set-DnsServerPrimaryZone -Name $name -DynamicUpdate $parms.DynamicUpdate -WhatIf:$check_mode }
                }
                Catch { $module.FailJson("Failed to set properties on the zone $($name): $($_.Exception.Message)", $_) }
            }
        }
        "secondary" {
            # remove irrelevant params
            $parms.Remove('ReplicationScope')
            $parms.Remove('DynamicUpdate')
            if (-not $current_zone) {
                # enforce param
                $parms.ZoneFile = "$name.dns"
                # create zone
                Try { Add-DnsServerSecondaryZone @parms -WhatIf:$check_mode }
                Catch { $module.FailJson("Failed to add $type zone $($name): $($_.Exception.Message)", $_) }
            }
            else {
                # update zone
                if (-not $current_zone_type_match) {
                    $parms.MasterServers = $current_zone.MasterServers
                    $parms.ZoneFile = $current_zone.ZoneFile
                    if ($current_zone.IsShutdown) { $module.FailJson("Failed to convert DNS zone $($name): this zone is shutdown and cannot be modified") }
                    Try { ConvertTo-DnsServerSecondaryZone @parms -Force -WhatIf:$check_mode }
                    Catch { $module.FailJson("Failed to convert DNS zone $($name): $($_.Exception.Message)", $_) }
                }
                Try { if ($dns_servers) { Set-DnsServerSecondaryZone -Name $name -MasterServers $dns_servers -WhatIf:$check_mode } }
                Catch { $module.FailJson("Failed to set properties on the zone $($name): $($_.Exception.Message)", $_) }
            }
        }
        "stub" {
            $parms.Remove('DynamicUpdate')
            if (-not $current_zone) {
                # create zone
                Try { Add-DnsServerStubZone @parms -WhatIf:$check_mode }
                Catch { $module.FailJson("Failed to add $type zone $($name): $($_.Exception.Message)", $_) }
            }
            else {
                # update zone
                if (-not $current_zone_type_match) { $module.FailJson("Failed to convert DNS zone $($name) to $type, unsupported conversion") }
                Try {
                    if ($parms.ReplicationScope) { Set-DnsServerStubZone -Name $name -ReplicationScope $parms.ReplicationScope -WhatIf:$check_mode }
                    if ($forwarder_timeout) { Set-DnsServerStubZone -Name $name -ForwarderTimeout $forwarder_timeout -WhatIf:$check_mode }
                    if ($dns_servers) { Set-DnsServerStubZone -Name $name -MasterServers $dns_servers -WhatIf:$check_mode }
                }
                Catch { $module.FailJson("Failed to set properties on the zone $($name): $($_.Exception.Message)", $_) }
            }
        }
        "forwarder" {
            # remove irrelevant params
            $parms.Remove('DynamicUpdate')
            $parms.Remove('ZoneFile')
            if ($forwarder_timeout -and ($forwarder_timeout -in 0..15)) {
                $parms.ForwarderTimeout = $forwarder_timeout
            }
            if ($forwarder_timeout -and -not ($forwarder_timeout -in 0..15)) {
                $module.Warn("The forwarder_timeout param must be an integer value between 0 and 15")
            }
            if ($parms.ReplicationScope -eq 'none') { $parms.Remove('ReplicationScope') }
            if (-not $current_zone) {
                # create zone
                Try { Add-DnsServerConditionalForwarderZone @parms -WhatIf:$check_mode }
                Catch { $module.FailJson("Failed to add $type zone $($name): $($_.Exception.Message)", $_) }
            }
            else {
                # update zone
                if (-not $current_zone_type_match) { $module.FailJson("Failed to convert DNS zone $($name) to $type, unsupported conversion") }
                Try {
                    if ($parms.ReplicationScope) {
                        Set-DnsServerConditionalForwarderZone -Name $name -ReplicationScope $parms.ReplicationScope -WhatIf:$check_mode
                    }
                    if ($forwarder_timeout) { Set-DnsServerConditionalForwarderZone -Name $name -ForwarderTimeout $forwarder_timeout -WhatIf:$check_mode }
                    if ($dns_servers) { Set-DnsServerConditionalForwarderZone -Name $name -MasterServers $dns_servers -WhatIf:$check_mode }
                }
                Catch { $module.FailJson("Failed to set properties on the zone $($name): $($_.Exception.Message)", $_) }
            }
        }
    }
}

if ($state -eq "absent") {
    if ($current_zone -and -not $check_mode) {
        Try {
            Remove-DnsServerZone -Name $name -Force -WhatIf:$check_mode
            $module.Result.changed = $true
            $module.Diff.after = ""
        }
        Catch {
            $module.FailJson("Failed to remove DNS zone: $($_.Exception.Message)", $_)
        }
    }
    $module.ExitJson()
}

# determine if a change was made
Try {
    $new_zone = Get-DnsServerZone -Name $name
    if (-not (Compare-DnsZone -Original $current_zone -Updated $new_zone)) {
        $module.Result.changed = $true
        $module.Result.zone = Get-DnsZoneObject -Object $new_zone
        $module.Diff.after = Get-DnsZoneObject -Object $new_zone
    }

    # simulate changes if check mode
    if ($check_mode) {
        $new_zone = @{}
        $current_zone.PSObject.Properties | ForEach-Object {
            if ($parms[$_.Name]) {
                $new_zone[$_.Name] = $parms[$_.Name]
            }
            else {
                $new_zone[$_.Name] = $_.Value
            }
        }
        $module.Diff.after = Get-DnsZoneObject -Object $new_zone
    }
}
Catch {
    $module.FailJson("Failed to lookup new zone $($name): $($_.Exception.Message)", $_)
}

$module.ExitJson()