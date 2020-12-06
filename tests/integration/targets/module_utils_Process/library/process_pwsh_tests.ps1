#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils.Process

$module = [Ansible.Basic.AnsibleModule]::Create($args, @{
    options = @{
        print_argv = @{ type = 'path'; required = $true }
    }
})

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

$tests = [Ordered]@{
    "Start-AnsibleWindowsProcess basic" = {
        $actual = Start-AnsibleWindowsProcess -FilePath whoami
        $actual.PSTypeNames[0] | Assert-Equals -Expected 'Ansible.Windows.Process.Info'
        $actual.Command | Assert-Equals -Expected (Get-Command whoami -CommandType Application).Path
        $actual.Stdout | Assert-Equals -Expected "$(&whoami.exe)`r`n"
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess -FilePath with -CommandLine" = {
        $printArgv = $module.Params.print_argv
        $actual = Start-AnsibleWindowsProcess -FilePath $printArgv -CommandLine '"abc def" arg2'
        $actual.PSTypeNames[0] | Assert-Equals -Expected 'Ansible.Windows.Process.Info'
        $actual.Command | Assert-Equals -Expected "`"abc def`" arg2"
        $actual.Stdout | Assert-Equals -Expected "{`"command_line`":`"\`"abc def\`" arg2`",`"args`":[`"arg2`"]}`r`n"
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess -CommandLine" = {
        $printArgv = $module.Params.print_argv
        $cmd = @($printArgv, 'abc def', 'arg2' | ConvertTo-EscapedArgument) -join ' '
        $expectedOutput = @{
            command_line = $cmd
            args = @('abc def', 'arg2')
        } | ConvertTo-Json -Compress

        $actual = Start-AnsibleWindowsProcess -CommandLine $cmd
        $actual.PSTypeNames[0] | Assert-Equals -Expected 'Ansible.Windows.Process.Info'
        $actual.Command | Assert-Equals -Expected $cmd
        $actual.Stdout | Assert-Equals -Expected "$expectedOutput`r`n"
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess -ArgumentList" = {
        $printArgv = $module.Params.print_argv
        $cmd = @($printArgv, 'abc def', 'arg2' | ConvertTo-EscapedArgument) -join ' '
        $expectedOutput = @{
            command_line = $cmd
            args = @('abc def', 'arg2')
        } | ConvertTo-Json -Compress

        $actual = Start-AnsibleWindowsProcess -FilePath $printArgv -ArgumentList @('abc def', 'arg2')
        $actual.PSTypeNames[0] | Assert-Equals -Expected 'Ansible.Windows.Process.Info'
        $actual.Command | Assert-Equals -Expected $cmd
        $actual.Stdout | Assert-Equals -Expected "$expectedOutput`r`n"
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess fail with -CommandLine and -ArgumentList" = {
        $failed = $false
        try {
            Start-AnsibleWindowsProcess -FilePath cmd -ArgumentList @('/c') -CommandLine 'echo hi'
        } catch {
            $failed = $true
            $_.Exception.Message -like 'Parameter set cannot be resolved using the specified named parameters*' | Assert-Equals -Expected $true
        }
        $failed | Assert-Equals -Expected $true
    }

    "Start-AnsibleWindowsProcess stderr" = {
        $pwshPath = (Get-Command powershell.exe -CommandType Application).Path
        $actual = Start-AnsibleWindowsProcess -FilePath powershell.exe -ArgumentList '[Console]::Error.WriteLine("hi")'
        $actual.PSTypeNames[0] | Assert-Equals -Expected 'Ansible.Windows.Process.Info'
        $actual.Command | Assert-Equals -Expected "$pwshPath `"[Console]::Error.WriteLine(\`"hi\`")`""
        $actual.Stdout | Assert-Equals -Expected ""
        $actual.Stderr | Assert-Equals -Expected "hi`r`n"
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess exit code" = {
        $pwshPath = (Get-Command powershell.exe -CommandType Application).Path
        $actual = Start-AnsibleWindowsProcess -FilePath powershell.exe -ArgumentList 'exit 10'
        $actual.PSTypeNames[0] | Assert-Equals -Expected 'Ansible.Windows.Process.Info'
        $actual.Command | Assert-Equals -Expected "$pwshPath `"exit 10`""
        $actual.Stdout | Assert-Equals -Expected ""
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 10
    }

    "Start-AnsibleWindowsProcess relative path" = {
        $pwshPath = (Get-Command powershell.exe -CommandType Application).Path
        $pwshParent = Split-Path $pwshPath -Parent
        $pwshGrandparent = Split-Path $pwshParent -Parent
        $pwshGrandparentName = Split-Path $pwshParent -Leaf

        Push-Location -LiteralPath $pwshGrandparent
        $actual = Start-AnsibleWindowsProcess -FilePath "$pwshGrandparentName\powershell" -ArgumentList '$pwd.Path'
        Pop-Location
        $actual.PSTypeNames[0] | Assert-Equals -Expected 'Ansible.Windows.Process.Info'
        $actual.Command | Assert-Equals -Expected "$pwshPath `$pwd.Path"
        $actual.Stdout | Assert-Equals -Expected "$pwshGrandparent`r`n"
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess path in WorkingDir" = {
        $argvDir = Split-Path $module.Params.print_argv -Parent
        $argvName = Split-Path $module.Params.print_argv -Leaf

        $actual = Start-AnsibleWindowsProcess -FilePath $argvName -WorkingDirectory $argvDir -ArgumentList 'hi'
        $actual.ExitCode | Assert-Equals -Expected 0
        $details = ConvertFrom-Json -InputObject ($actual.Stdout)
        $details.command_line | Assert-Equals -Expected $actual.Command
        $details.args | Assert-Equals -Expected @(,'hi')
    }

    "Start-AnsibleWindowsProcess with missing WorkingDir" = {
        $output = Start-AnsibleWindowsProcess -FilePath whoami -WorkingDirectory C:\fake -ErrorAction SilentlyContinue -ErrorVariable err
        Assert-Equals -Actual $output -Expected $null
        $err[0].Exception.Message | Assert-Equals -Expected "Could not find specified -WorkingDirectory 'C:\fake'"
    }

    "Start-AnsibleWindowsProcess with unicode output" = {
        $cmd = "cmd.exe /c echo 💩 café"

        $actual = Start-AnsibleWindowsProcess -CommandLine $cmd
        $actual.Command | Assert-Equals -Expected $cmd
        $actual.Stdout | Assert-Equals -Expected "💩 café`r`n"
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess without environment" = {
        $expected = "$($env:USERNAME)`r`n"
        $cmd = 'powershell.exe $env:TEST; $env:USERNAME'
        $actual = Start-AnsibleWindowsProcess -CommandLine $cmd
        $actual.Stdout | Assert-Equals -Expected $expected
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess with environment" = {
        $envVars = @{
            TEST = "tesTing"
            TEST2 = "Testing 2"
        }
        $cmd = 'cmd.exe /c set'
        $actual = Start-AnsibleWindowsProcess -CommandLine $cmd -Environment $envVars
        ("TEST=tesTing" -cin $actual.Stdout.Split("`r`n")) | Assert-Equals -Expected $true
        ("TEST2=Testing 2" -cin $actual.Stdout.Split("`r`n")) | Assert-Equals -Expected $true
        ("USERNAME=$($env:USERNAME)" -cnotin $actual.Stdout.Split("`r`n")) | Assert-Equals -Expected $true
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess with byte stdin" = {
        $expected = "input value`r`n"
        $cmd = 'powershell.exe [System.Console]::In.ReadToEnd()'
        $actual = Start-AnsibleWindowsProcess -CommandLine $cmd -InputObject ([System.Text.Encoding]::UTF8.GetBytes("input value"))
        $actual.Stdout | Assert-Equals -Expected $expected
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess with byte stdin and newline" = {
        $expected = "input value`r`n`r`n"
        $cmd = 'powershell.exe [System.Console]::In.ReadToEnd()'
        $actual = Start-AnsibleWindowsProcess -CommandLine $cmd -InputObject ([System.Text.Encoding]::UTF8.GetBytes("input value`r`n"))
        $actual.Stdout | Assert-Equals -Expected $expected
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess with string stdin" = {
        $expected = "input value`r`n"
        $cmd = 'powershell.exe [System.Console]::In.ReadToEnd()'
        $actual = Start-AnsibleWindowsProcess -CommandLine $cmd -InputObject "input value"
        $actual.Stdout | Assert-Equals -Expected $expected
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess with string stdin and newline" = {
        $expected = "input value`r`n`r`n"
        $cmd = 'powershell.exe [System.Console]::In.ReadToEnd()'
        $actual = Start-AnsibleWindowsProcess -CommandLine $cmd -InputObject "input value`r`n"
        $actual.Stdout | Assert-Equals -Expected $expected
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess with invalid stdin" = {
        $out = Start-AnsibleWindowsProcess -CommandLine 'cmd /c echo hi' -InputObject 1 -ErrorAction SilentlyContinue -ErrorVariable err
        Assert-Equals -Actual $out -Expected $null
        $err[0].Exception.Message | Assert-Equals -Expected 'InputObject must be a string or byte[]'
    }

    "Start-AnsibleWindowsProcess with unicode and us-ascii encoding" = {
        $poop = [System.Char]::ConvertFromUtf32(0xE05A)  # Coverage breaks due to script parsing encoding issues with unicode chars, just use the code point instead
        $cmd = "cmd.exe /c echo $poop café"

        $actual = Start-AnsibleWindowsProcess -CommandLine $cmd -OutputEncodingOverride 'us-ascii'
        $actual.Stdout | Assert-Equals -Expected "??? caf??`r`n"
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0

        # With alias
        $actual = Start-AnsibleWindowsProcess -CommandLine $cmd -OutputEncoding 'us-ascii'
        $actual.Stdout | Assert-Equals -Expected "??? caf??`r`n"
        $actual.Stderr | Assert-Equals -Expected ""
        $actual.ExitCode | Assert-Equals -Expected 0
    }

    "Start-AnsibleWindowsProcess while waiting for grandchildren" = {
        $subCommand = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes(@'
Start-Sleep -Seconds 2
exit 1
'@))
        $cmd = "powershell.exe Start-Process powershell.exe -ArgumentList '-EncodedCommand', '$subCommand'"

        $time = Measure-Command -Expression {
            $actual = Start-AnsibleWindowsProcess -CommandLine $cmd
            $actual.ExitCode | Assert-Equals -Expected 0
        }
        $time.TotalSeconds -lt 2 | Assert-Equals -Expected $true

        $time = Measure-Command -Expression {
            $actual = Start-AnsibleWindowsProcess -CommandLine $cmd -WaitChildren
            $actual.ExitCode | Assert-Equals -Expected 0  # We still don't expect to get the grandchild rc
        }
        $time.TotalSeconds -ge 2 | Assert-Equals -Expected $true
    }
}

# Add argv <-> argc tests
$argv_tests = [Ordered]@{
    # Key = argc - Value = argv
    # https://docs.microsoft.com/en-us/cpp/c-language/parsing-c-command-line-arguments?view=vs-2019
    '"a b c" d e' = @('a b c', 'd', 'e')
    '"ab\"c" \ d' = @('ab"c', '\', 'd')
    'a\\\b "de fg" h' = @('a\\\b', 'de fg', 'h')
    '"a\\b c" d e' = @('a\\b c', 'd', 'e')
    # http://daviddeley.com/autohotkey/parameters/parameters.htm#WINCREATE
    'CallMeIshmael' = @(,'CallMeIshmael')
    '"Call Me Ishmael"' = @(,'Call Me Ishmael')
    '"CallMe\"Ishmael"' = @(,'CallMe"Ishmael')
    '"Call Me Ishmael\\"' = @(,'Call Me Ishmael\')
    '"CallMe\\\"Ishmael"' = @(,'CallMe\"Ishmael')
    'a\\\b' = @(,'a\\\b')
    '"C:\TEST A\\"' = @(,'C:\TEST A\')
    '"\"C:\TEST A\\\""' = @(,'"C:\TEST A\"')
    # Other tests
    '"C:\Program Files\file\\" "arg with \" quote"' = @('C:\Program Files\file\', 'arg with " quote')
    '""' = @(,'')
    '"" "" ""' = @('', $null, '')
}
foreach ($kvp in $argv_tests.GetEnumerator()) {
    $tests."Test argument list to command line - '$($kvp.Key)" = {
        $argc = $kvp.Key
        $argv = $kvp.Value

        $escapedActual = @($argv | ConvertTo-EscapedArgument) -join ' '
        Assert-Equals -Expected $argc -Actual $escapedActual

        $commandActual = Start-AnsibleWindowsProcess -FilePath $module.Params.print_argv -ArgumentList $argv
        $actualArgs = ($commandActual.Stdout | ConvertFrom-Json)

        # Required to convert any $null args to ""
        $argv = @($argv | ForEach-Object { [String]$_ })
        Assert-Equals -Expected $argv -Actual $actualArgs.args
    }

    $tests."Test argument command line to list - '$($kvp.Key)" = {
        $argc = $kvp.Key
        $argv = $kvp.Value
        $escapedArgv = @($argv | ForEach-Object { [String]$_ })

        $listActual = $argc | ConvertFrom-EscapedArgument
        Assert-Equals -Expected $escapedArgv -Actual $listActual

        $cmd = '"{0}" {1}' -f $module.Params.print_argv, $argc
        $commandActual = Start-AnsibleWindowsProcess -FilePath $module.Params.print_argv -CommandLine $cmd
        $actualArgs = ($commandActual.Stdout | ConvertFrom-Json)
        Assert-Equals -Expected $escapedArgv -Actual $actualArgs.args
    }
}

foreach ($test_impl in $tests.GetEnumerator()) {
    $test = $test_impl.Key
    &$test_impl.Value
}

$module.Result.data = "success"
$module.ExitJson()
