# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

param([string]$ComputerName, [bool]$RequireRemoteHost = $false)

$Ansible.Changed = $false
$executionHost = [Environment]::MachineName
if ($RequireRemoteHost -and $executionHost.Equals($ComputerName, [StringComparison]::OrdinalIgnoreCase)) {
    throw 'The selected remote execution host is the DNS server itself. Choose a distinct Windows host for remote authentication coverage.'
}

try {
    $null = Get-Command -Name Get-DnsServerResourceRecord, Add-DnsServerResourceRecord, `
        Set-DnsServerResourceRecord, Remove-DnsServerResourceRecord -ErrorAction Stop
}
catch {
    throw "The execution host requires the DnsServer PowerShell tools before running this target: $($_.Exception.Message)"
}

try {
    $null = Get-DnsServerZone -ComputerName $ComputerName -ErrorAction Stop
}
catch {
    throw "Cannot query DNS server '$ComputerName' from '$executionHost'. Check DNS permissions and remote authentication: $($_.Exception.Message)"
}
$Ansible.Result = @{ execution_host = $executionHost; dns_server = $ComputerName; remote = $RequireRemoteHost }
