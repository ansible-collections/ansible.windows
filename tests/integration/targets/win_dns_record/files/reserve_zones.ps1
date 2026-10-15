# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
param([string[]]$ZoneNames, [string]$DnsDirectory)
$Ansible.Changed = $false
$ErrorActionPreference = 'Stop'
$existing = @(Get-DnsServerZone)
$existingNames = @($existing | ForEach-Object { $_.ZoneName })
foreach ($zone in $ZoneNames) {
    if ($zone -in $existingNames -or (Test-Path -LiteralPath (Join-Path -Path $DnsDirectory -ChildPath "$zone.dns"))) {
        throw "Refusing to reuse the existing zone or zone file '$zone'."
    }
}
