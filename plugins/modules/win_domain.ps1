#!powershell

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -PowerShell Ansible.ModuleUtils.Legacy

Set-StrictMode -Version 2
$ErrorActionPreference = "Stop"

# FUTURE: Consider action wrapper to manage reboots and credential changes

# Set of features required for a domain controller
$dc_required_features = @("AD-Domain-Services", "RSAT-ADDS")

Function Get-MissingFeature {
    Param(
        [string[]]$required_features
    )
    $features = @(Get-WindowsFeature $required_features)
    # Check for $required_features that are not in $features
    $unavailable_features = @(Compare-Object -ReferenceObject $required_features -DifferenceObject ($features | Select-Object -ExpandProperty Name) -PassThru)

    if ($unavailable_features) {
        Throw "The following features required for a domain controller are unavailable: $($unavailable_features -join ',')"
    }

    $missing_features = @($features | Where-Object InstallState -ne Installed)

    return @($missing_features)
}

Function Install-Prereq {
    $missing_features = Get-MissingFeature $dc_required_features
    if ($missing_features) {
        $result.changed = $true

        $awf = Add-WindowsFeature $missing_features -WhatIf:$check_mode
        $result.reboot_required = $awf.RestartNeeded
        # FUTURE: Check if reboot necessary

        return $true
    }
    return $false
}

Function Get-DomainForest {
    <#
    .SYNOPSIS
    Gets the domain forest similar to Get-ADForest but without requiring credential delegation.

    .PARAMETER DnsName
    The DNS name of the forest, for example 'sales.corp.fabrikam.com'.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$DnsName
    )

    try {
        $forest_context = New-Object -TypeName System.DirectoryServices.ActiveDirectory.DirectoryContext -ArgumentList @(
            'Forest', $DnsName
        )
        [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($forest_context)
    }
    catch [System.DirectoryServices.ActiveDirectory.ActiveDirectoryObjectNotFoundException] {
        Write-Error -Message "AD Object not found: $($_.Exception.Message)" -Exception $_.Exception
    }
    catch [System.DirectoryServices.ActiveDirectory.ActiveDirectoryOperationException] {
        Write-Error -Message "AD Operation Exception: $($_.Exception.Message)" -Exception $_.Exception
    }
}

$params = Parse-Args $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -default $false
$dns_domain_name = Get-AnsibleParam -obj $params -name "dns_domain_name" -failifempty $true
$domain_netbios_name = Get-AnsibleParam -obj $params -name "domain_netbios_name"
$safe_mode_admin_password = Get-AnsibleParam -obj $params -name "safe_mode_password" -failifempty $true
$database_path = Get-AnsibleParam -obj $params -name "database_path" -type "path"
$sysvol_path = Get-AnsibleParam -obj $params -name "sysvol_path" -type "path"
$log_path = Get-AnsibleParam -obj $params -name "log_path" -type "path"
$create_dns_delegation = Get-AnsibleParam -obj $params -name "create_dns_delegation" -type "bool"
$domain_mode = Get-AnsibleParam -obj $params -name "domain_mode" -type "str"
$forest_mode = Get-AnsibleParam -obj $params -name "forest_mode" -type "str"
$install_dns = Get-AnsibleParam -obj $params -name "install_dns" -type "bool" -default $true

# FUTURE: Support down to Server 2012?
if ([System.Environment]::OSVersion.Version -lt [Version]"6.3.9600.0") {
    Fail-Json -message "win_domain requires Windows Server 2012R2 or higher"
}

# Check that domain_netbios_name is less than 15 characters
if ($domain_netbios_name -and $domain_netbios_name.length -gt 15) {
    Fail-Json -message "The parameter 'domain_netbios_name' should not exceed 15 characters in length"
}

$result = @{
    changed = $false
    reboot_required = $false
}

# FUTURE: Any sane way to do the detection under check-mode *without* installing the feature?
$installed = Install-Prereq

# when in check mode and the prereq was "installed" we need to exit early as
# the AD cmdlets weren't really installed
if ($check_mode -and $installed) {
    Exit-Json -obj $result
}

# Check that we got a valid domain_mode
$valid_domain_modes = [Enum]::GetNames((Get-Command -Name Install-ADDSForest).Parameters.DomainMode.ParameterType)
if (($null -ne $domain_mode) -and -not ($domain_mode -in $valid_domain_modes)) {
    Fail-Json -obj $result -message "The parameter 'domain_mode' does not accept '$domain_mode', please use one of: $valid_domain_modes"
}

# Check that we got a valid forest_mode
$valid_forest_modes = [Enum]::GetNames((Get-Command -Name Install-ADDSForest).Parameters.ForestMode.ParameterType)
if (($null -ne $forest_mode) -and -not ($forest_mode -in $valid_forest_modes)) {
    Fail-Json -obj $result -message "The parameter 'forest_mode' does not accept '$forest_mode', please use one of: $valid_forest_modes"
}

$forest = Get-DomainForest -DnsName $dns_domain_name -ErrorAction SilentlyContinue
if (-not $forest) {
    $result.changed = $true

    $sm_cred = ConvertTo-SecureString $safe_mode_admin_password -AsPlainText -Force

    $install_params = @{
        DomainName = $dns_domain_name
        SafeModeAdministratorPassword = $sm_cred
        Confirm = $false
        SkipPreChecks = $true
        InstallDns = $install_dns
        NoRebootOnCompletion = $true
        WhatIf = $check_mode
    }

    if ($database_path) {
        $install_params.DatabasePath = $database_path
    }

    if ($sysvol_path) {
        $install_params.SysvolPath = $sysvol_path
    }

    if ($log_path) {
        $install_params.LogPath = $log_path
    }

    if ($domain_netbios_name) {
        $install_params.DomainNetBiosName = $domain_netbios_name
    }

    if ($null -ne $create_dns_delegation) {
        $install_params.CreateDnsDelegation = $create_dns_delegation
    }

    if ($domain_mode) {
        $install_params.DomainMode = $domain_mode
    }

    if ($forest_mode) {
        $install_params.ForestMode = $forest_mode
    }

    $iaf = $null
    try {
        $iaf = Install-ADDSForest @install_params
    }
    catch [Microsoft.DirectoryServices.Deployment.DCPromoExecutionException] {
        # ExitCode 15 == 'Role change is in progress or this computer needs to be restarted.'
        # DCPromo exit codes details can be found at
        # https://docs.microsoft.com/en-us/windows-server/identity/ad-ds/deploy/troubleshooting-domain-controller-deployment
        if ($_.Exception.ExitCode -in @(15, 19)) {
            $result.reboot_required = $true
        }
        else {
            Fail-Json -obj $result -message "Failed to install ADDSForest, DCPromo exited with $($_.Exception.ExitCode): $($_.Exception.Message)"
        }
    }

    if ($check_mode) {
        # the return value after -WhatIf does not have RebootRequired populated
        # manually set to True as the domain would have been installed
        $result.reboot_required = $true
    }
    elseif ($null -ne $iaf) {
        $result.reboot_required = $iaf.RebootRequired

        # The Netlogon service is set to auto start but is not started. This is
        # required for Ansible to connect back to the host and reboot in a
        # later task. Even if this fails Ansible can still connect but only
        # with ansible_winrm_transport=basic so we just display a warning if
        # this fails.
        try {
            Start-Service -Name Netlogon
        }
        catch {
            $msg = -join @(
                "Failed to start the Netlogon service after promoting the host, "
                "Ansible may be unable to connect until the host is manually rebooting: $($_.Exception.Message)"
            )
            Add-Warning -obj $result -message $msg
        }
    }
}

Exit-Json $result
