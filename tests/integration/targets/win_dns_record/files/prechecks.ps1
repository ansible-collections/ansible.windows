# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
param(
    [bool]$AllowDomainController = $false,
    [bool]$ManageDnsFeature = $true
)

$Ansible.Changed = $false
$ErrorActionPreference = 'Stop'
$system = Get-CimInstance -ClassName Win32_ComputerSystem
if ($system.DomainRole -ge 4) {
    if (-not $AllowDomainController) {
        throw ('DNS record integration fixtures require an isolated server. For an isolated test domain controller, ' +
            'set win_dns_record_allow_domain_controller=true and win_dns_record_manage_dns_feature=false.')
    }
    if ($ManageDnsFeature) {
        throw 'Set win_dns_record_manage_dns_feature=false when testing on a domain controller; the target must not install or remove its DNS feature.'
    }
}
$id = [Guid]::NewGuid().ToString('N')
$Ansible.Result = @{
    zone = "win-dns-$id.test"
    reverse_zone = "$(Get-Random -Minimum 1 -Maximum 255).$(Get-Random -Minimum 1 -Maximum 255).198.in-addr.arpa"
    computer_name = $env:COMPUTERNAME
    dns_directory = Join-Path -Path $env:SystemRoot -ChildPath 'System32\dns'
}
