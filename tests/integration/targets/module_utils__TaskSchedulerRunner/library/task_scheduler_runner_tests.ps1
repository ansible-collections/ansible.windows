#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils._TaskSchedulerRunner

$module = [Ansible.Basic.AnsibleModule]::Create($args, @{
        options = @{
            username = @{ type = "str"; required = $true }
            password = @{ type = "str"; required = $true; no_log = $true }
        }
    })

$userCredential = [PSCredential]::new(
    $module.Params.username,
    (ConvertTo-SecureString -String $module.Params.password -AsPlainText -Force))

Function Assert-Equal {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][AllowNull()]$Actual,
        [Parameter(Mandatory = $true, Position = 0)][AllowNull()]$Expected
    )

    process {
        $matched = $false
        if ($Actual -is [System.Collections.ArrayList] -or $Actual -is [Array]) {
            $Actual.Count | Assert-Equal -Expected $Expected.Count
            for ($i = 0; $i -lt $Actual.Count; $i++) {
                $actual_value = $Actual[$i]
                $expected_value = $Expected[$i]
                Assert-Equal -Actual $actual_value -Expected $expected_value
            }
            $matched = $true
        }
        else {
            $matched = $Actual -ceq $Expected
        }

        if (-not $matched) {
            if ($Actual -is [PSObject]) {
                $Actual = $Actual.ToString()
            }

            $call_stack = (Get-PSCallStack)[1]
            $module.Result.test = $test
            $module.Result.actual = $Actual
            $module.Result.expected = $Expected
            $module.Result.line = $call_stack.ScriptLineNumber
            $module.Result.method = $call_stack.Position.Text
            $module.FailJson("AssertionError: actual != expected")
        }
    }
}

$tests = [Ordered]@{
    "Create session as current user S4U" = {
        $session = New-ScheduledTaskSession
        try {
            $result = Invoke-Command -Session $session {
                $groups = [System.Security.Principal.WindowsIdentity]::GetCurrent().Groups.Value

                [PSCustomObject]@{
                    Pid = $PID
                    UserName = [Environment]::UserName
                    IsNetwork = $groups -contains 'S-1-5-2'
                    IsBatch = $groups -contains 'S-1-5-3'
                    IsInteractive = $groups -contains 'S-1-5-4'
                    IsService = $groups -contains 'S-1-5-6'
                }
            }

            $result.PID -eq $PID | Assert-Equal -Expected $false
            $result.UserName | Assert-Equal -Expected ([Environment]::UserName)
            $result.IsNetwork | Assert-Equal -Expected $false
            $result.IsBatch | Assert-Equal -Expected $true
            $result.IsInteractive | Assert-Equal -Expected $false
            $result.IsService | Assert-Equal -Expected $false

            $sessionProc = Get-Process -Id $result.Pid -ErrorAction Ignore
            $null -ne $sessionProc | Assert-Equal -Expected $true
        }
        finally {
            $session | Remove-PSSession
        }
    }

    "Create session as current user with credentials" = {
        $session = New-ScheduledTaskSession -Credential $userCredential
        try {
            # Short of trying to use the actual credentials I don't know of a
            # way to verify the session is running with delegatable credentials.
            $result = Invoke-Command -Session $session {
                $groups = [System.Security.Principal.WindowsIdentity]::GetCurrent().Groups.Value

                [PSCustomObject]@{
                    Pid = $PID
                    UserName = [Environment]::UserName
                    IsNetwork = $groups -contains 'S-1-5-2'
                    IsBatch = $groups -contains 'S-1-5-3'
                    IsInteractive = $groups -contains 'S-1-5-4'
                    IsService = $groups -contains 'S-1-5-6'
                }
            }

            $result.PID -eq $PID | Assert-Equal -Expected $false
            $result.UserName | Assert-Equal -Expected ([Environment]::UserName)
            $result.IsNetwork | Assert-Equal -Expected $false
            $result.IsBatch | Assert-Equal -Expected $true
            $result.IsInteractive | Assert-Equal -Expected $false
            $result.IsService | Assert-Equal -Expected $false

            $sessionProc = Get-Process -Id $result.Pid -ErrorAction Ignore
            $null -ne $sessionProc | Assert-Equal -Expected $true
        }
        finally {
            $session | Remove-PSSession
        }
    }

    "Create session as SYSTEM" = {
        $session = New-ScheduledTaskSession -UserName SYSTEM
        try {
            $result = Invoke-Command -Session $session {
                $groups = [System.Security.Principal.WindowsIdentity]::GetCurrent().Groups.Value

                [PSCustomObject]@{
                    Pid = $PID
                    UserName = [Environment]::UserName
                    IsNetwork = $groups -contains 'S-1-5-2'
                    IsBatch = $groups -contains 'S-1-5-3'
                    IsInteractive = $groups -contains 'S-1-5-4'
                    IsService = $groups -contains 'S-1-5-6'
                }
            }

            $result.PID -eq $PID | Assert-Equal -Expected $false

            # [Environment]::UserName returns the hostname$ on newer .NET versions.
            if ($IsCoreCLR) {
                $result.UserName | Assert-Equal -Expected "${env:COMPUTERNAME}$"
            }
            else {
                $result.UserName | Assert-Equal -Expected 'SYSTEM'
            }

            $result.IsNetwork | Assert-Equal -Expected $false
            $result.IsBatch | Assert-Equal -Expected $false
            $result.IsInteractive | Assert-Equal -Expected $false
            $result.IsService | Assert-Equal -Expected $true

            $sessionProc = Get-Process -Id $result.Pid -ErrorAction Ignore
            $null -ne $sessionProc | Assert-Equal -Expected $true
        }
        finally {
            $session | Remove-PSSession
        }
    }

    "Expect failure if custom PowerShell path doesn't exist" = {
        $session = $null
        $msg = $null

        $failed = $false
        try {
            $session = New-ScheduledTaskSession -PowerShellPath "C:\this\does\not\exist\powershell.exe"
        }
        catch {
            $failed = $true
            $msg = $_.Exception.Message
            # $_.Exception.Message | Assert-Equal -Expected "Failed to find PowerShellPath 'C:\this\does\not\exist\powershell.exe'"
        }

        $session -eq $null | Assert-Equal -Expected $true
        $failed | Assert-Equal -Expected $true
        $msg | Assert-Equal -Expected "Failed to find PowerShellPath 'C:\this\does\not\exist\powershell.exe'"
    }
}

foreach ($test_impl in $tests.GetEnumerator()) {
    $test = $test_impl.Key
    &$test_impl.Value
}

$module.Result.data = "success"

$module.ExitJson()
