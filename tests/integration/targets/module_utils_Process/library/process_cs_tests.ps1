#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -CSharpUtil ansible_collections.ansible.windows.plugins.module_utils.Process

$module = [Ansible.Basic.AnsibleModule]::Create($args, @{})

Function Assert-Equals {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)][AllowNull()]$Actual,
        [Parameter(Mandatory=$true, Position=0)][AllowNull()]$Expected
    )

    $matched = $false
    if ($Actual -is [System.Collections.ArrayList] -or $Actual -is [Array]) {
        $Actual.Count | Assert-Equals -Expected $Expected.Count
        for ($i = 0; $i -lt $Actual.Count; $i++) {
            $actual_value = $Actual[$i]
            $expected_value = $Expected[$i]
            Assert-Equals -Actual $actual_value -Expected $expected_value
        }
        $matched = $true
    } else {
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

$tests = @{
    "CommandLineToArgv empty string" = {
        $expected = [Ansible.Windows.Process.ProcessUtil]::CommandLineToArgv((Get-Process -Id $pid).Path)
        $actual = [Ansible.Windows.Process.ProcessUtil]::CommandLineToArgv("")
        Assert-Equals -Actual $actual -Expected $expected
    }

    "CommandLineToArgv single argument" = {
        $expected = @("powershell.exe")
        $actual = [Ansible.Windows.Process.ProcessUtil]::CommandLineToArgv("powershell.exe")
        Assert-Equals -Actual $actual -Expected $expected
    }

    "CommandLineToArgv multiple arguments" = {
        $expected = @("powershell.exe", "-File", "C:\temp\script.ps1")
        $actual = [Ansible.Windows.Process.ProcessUtil]::CommandLineToArgv("powershell.exe -File C:\temp\script.ps1")
        Assert-Equals -Actual $actual -Expected $expected
    }

    "CommandLineToArgv comples arguments" = {
        $expected = @('abc', 'd', 'ef gh', 'i\j', 'k"l', 'm\n op', 'ADDLOCAL=qr, s', 'tuv\', 'w''x', 'yz')
        $actual = [Ansible.Windows.Process.ProcessUtil]::CommandLineToArgv('abc d "ef gh" i\j k\"l m\\"n op" ADDLOCAL="qr, s" tuv\ w''x yz')
        Assert-Equals -Actual $actual -Expected $expected
    }

    "CreateProcess basic" = {
        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, "whoami.exe", $null, $null, $null, $null, $false)
        $actual.GetType().FullName | Assert-Equals -Expected "ansible_collections.ansible.windows.plugins.module_utils.Process.Result"
        $actual.StandardOut | Assert-Equals -Expected "$(&whoami.exe)`r`n"
        $actual.StandardError | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "CreateProcess stderr" = {
        $cmd = "powershell.exe [System.Console]::Error.WriteLine('hi')"
        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, $cmd, $null, $null, $null, $null, $false)
        $actual.StandardOut | Assert-Equals -Expected ""
        $actual.StandardError | Assert-Equals -Expected "hi`r`n"
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "CreateProcess exit code" = {
        $cmd = "powershell.exe exit 10"
        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, $cmd, $null, $null, $null, $null, $false)
        $actual.StandardOut | Assert-Equals -Expected ""
        $actual.StandardError | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 10
    }

    "CreateProcess bad executable" = {
        $failed = $false
        try {
            [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, "fake.exe", $null, $null, $null, $null, $false)
        } catch {
            $failed = $true
            $_.Exception.InnerException.GetType().FullName | Assert-Equals -Expected "ansible_collections.ansible.windows.plugins.module_utils.Process.Win32Exception"
            $expected = 'Exception calling "CreateProcess" with "7" argument(s): "CreateProcessW() failed '
            $expected += '(The system cannot find the file specified, Win32ErrorCode 2 - 0x00000002)"'
            $_.Exception.Message | Assert-Equals -Expected $expected
        }
        $failed | Assert-Equals -Expected $true
    }

    "CreateProcess with unicode" = {
        $cmd = "cmd.exe /c echo 💩 café"
        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, $cmd, $null, $null, $null, $null, $false)
        $actual.StandardOut | Assert-Equals -Expected "💩 café`r`n"
        $actual.StandardError | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "CreateProcess without working dir" = {
        $expected = $pwd.Path + "`r`n"
        $cmd = 'powershell.exe $pwd.Path'
        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, $cmd, $null, $null, $null, $null, $false)
        $actual.StandardOut | Assert-Equals -Expected $expected
        $actual.StandardError | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "CreateProcess with working dir" = {
        $expected = "C:\Windows`r`n"
        $cmd = 'powershell.exe $pwd.Path'
        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, $cmd, 'C:\Windows', $null, $null, $null, $false)
        $actual.StandardOut | Assert-Equals -Expected $expected
        $actual.StandardError | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "CreateProcess without environment" = {
        $expected = "$($env:USERNAME)`r`n"
        $cmd = 'powershell.exe $env:TEST; $env:USERNAME'
        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, $cmd, $null, $null, $null, $null, $false)
        $actual.StandardOut | Assert-Equals -Expected $expected
        $actual.StandardError | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "CreateProcess with environment" = {
        $env_vars = @{
            TEST = "tesTing"
            TEST2 = "Testing 2"
        }
        $cmd = 'cmd.exe /c set'
        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, $cmd, $null, $env_vars, $null, $null, $false)
        ("TEST=tesTing" -cin $actual.StandardOut.Split("`r`n")) | Assert-Equals -Expected $true
        ("TEST2=Testing 2" -cin $actual.StandardOut.Split("`r`n")) | Assert-Equals -Expected $true
        ("USERNAME=$($env:USERNAME)" -cnotin $actual.StandardOut.Split("`r`n")) | Assert-Equals -Expected $true
        $actual.StandardError | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "CreateProcess with byte stdin" = {
        $expected = "input value`r`n"
        $cmd = 'powershell.exe [System.Console]::In.ReadToEnd()'
        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, $cmd, $null, $null,
            [System.Text.Encoding]::UTF8.GetBytes("input value"), $null, $false)
        $actual.StandardOut | Assert-Equals -Expected $expected
        $actual.StandardError | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "CreateProcess with byte stdin and newline" = {
        $expected = "input value`r`n`r`n"
        $cmd = 'powershell.exe [System.Console]::In.ReadToEnd()'
        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, $cmd, $null, $null,
            [System.Text.Encoding]::UTF8.GetBytes("input value`r`n"), $null, $false)
        $actual.StandardOut | Assert-Equals -Expected $expected
        $actual.StandardError | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "CreateProcess with lpApplicationName" = {
        $expected = "abc`r`n"
        $full_path = "$($env:SystemRoot)\System32\WindowsPowerShell\v1.0\powershell.exe"
        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($full_path, "Write-Output 'abc'", $null, $null, $null, $null, $false)
        $actual.StandardOut | Assert-Equals -Expected $expected
        $actual.StandardError | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0

        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($full_path, "powershell.exe Write-Output 'abc'", $null, $null, $null, $Null, $false)
        $actual.StandardOut | Assert-Equals -Expected $expected
        $actual.StandardError | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "CreateProcess with unicode and us-ascii encoding" = {
        $poop = [System.Char]::ConvertFromUtf32(0xE05A)  # Coverage breaks due to script parsing encoding issues with unicode chars, just use the code point instead
        $cmd = "cmd.exe /c echo $poop café"
        $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, $cmd, $null, $null, $null, 'us-ascii', $false)
        $actual.StandardOut | Assert-Equals -Expected "??? caf??`r`n"
        $actual.StandardError | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "CreateProcess while waiting for grandchildren" = {
        $subCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(@'
Start-Sleep -Seconds 2
exit 1
'@))
        $cmd = "powershell.exe Start-Process powershell.exe -ArgumentList '-EncodedCommand', '$subCommand'"

        $actual = $null
        $time = Measure-Command -Expression {
            $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, $cmd, $null, $null, $null, $null, $false)
            $actual.ExitCode | Assert-Equals -Expected 0
        }
        $time.TotalSeconds -lt 2 | Assert-Equals -Expected $true

        $time = Measure-Command -Expression {
            $actual = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($null, $cmd, $null, $null, $null, $null, $true)
            $actual.ExitCode | Assert-Equals -Expected 0  # We still don't expect to get the grandchild rc
        }
        $time.TotalSeconds -ge 2 | Assert-Equals -Expected $true
    }
}

foreach ($test_impl in $tests.GetEnumerator()) {
    $test = $test_impl.Key
    &$test_impl.Value
}

$module.Result.data = "success"
$module.ExitJson()
