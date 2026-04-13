#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils._TaskSchedulerRunner

$module = [Ansible.Basic.AnsibleModule]::Create($args, @{
        options = @{
            pwsh_path = @{ type = 'str'; required = $true }
        }
    })

$pwshPath = $module.Params.pwsh_path

$expected = (Get-Command -Name $pwshPath -CommandType Application).Path

$session = New-ScheduledTaskSession -PowerShellPath $pwshPath
try {
    $actual = Invoke-Command -Session $session -ScriptBlock {
        [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    }
}
finally {
    $session | Remove-PSSession
}

if ($actual -ne $expected) {
    $module.Result.actual = $actual
    $module.Result.expected = $expected
    $module.FailJson("PowerShellPath did not resolve to expected path")
}

$module.Result.data = "success"

$module.ExitJson()
