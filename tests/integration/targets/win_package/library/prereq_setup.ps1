#!powershell

# Copyright: (c) 2024, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic


$module = [Ansible.Basic.AnsibleModule]::Create($args, @{})

# Server 2025 fails to run Get-AppxPackage and other DISM module commands in
# a PSRemoting (psrp) session as it has a dependency on some dll's not present
# in the GAC and only in the powershell.exe directory. As PSRP runs through
# wsmprovhost.exe, it fails to find those dlls. This hack will manually load
# the 4 requires dlls into the GAC so our tests can work. This is a hack and
# should be removed in the future if MS fix their bug on 2025.
try {
    $null = Get-AppxPackage
}
catch {
    Add-Type -AssemblyName "System.EnterpriseServices"
    $publish = [System.EnterpriseServices.Internal.Publish]::new()

    @(
        'System.Numerics.Vectors.dll',
        'System.Runtime.CompilerServices.Unsafe.dll',
        'System.Security.Principal.Windows.dll',
        'System.Memory.dll'
    ) | ForEach-Object {
        $dllPath = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\$_"
        $publish.GacInstall($dllPath)
    }

    $module.Result.changed = $true
}

$module.ExitJson()
