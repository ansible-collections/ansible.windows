#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils._SecurityIdentifier

$spec = @{
    options = @{
        user = @{ type = 'str'; required = $true }
        user_sid = @{ type = 'str'; required = $true }
        group = @{ type = 'str'; required = $true }
        group_sid = @{ type = 'str'; required = $true }
    }
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$user = $module.Params.user
$userSid = $module.Params.user_sid
$group = $module.Params.group
$groupSid = $module.Params.group_sid

Function Assert-Equal {
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)][AllowNull()]$Actual,
        [Parameter(Mandatory = $true, Position = 0)][AllowNull()]$Expected
    )

    process {
        $matched = $false
        if ($Actual -is [System.Collections.ArrayList] -or $Actual -is [Array] -or $Actual -is [System.Collections.IList]) {
            $Actual.Count | Assert-Equal -Expected $Expected.Count
            for ($i = 0; $i -lt $Actual.Count; $i++) {
                $actualValue = $Actual[$i]
                $expectedValue = $Expected[$i]
                Assert-Equal -Actual $actualValue -Expected $expectedValue
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
    'Converts local user with no domain' = {
        $actual = $user | ConvertTo-AnsibleWindowsSecurityIdentifier
        $actual.GetType().FullName | Assert-Equal System.Security.Principal.SecurityIdentifier
        $actual.Value | Assert-Equal $userSid
    }

    'Converts local user with . domain' = {
        $actual = ".\$user" | ConvertTo-AnsibleWindowsSecurityIdentifier
        $actual.GetType().FullName | Assert-Equal System.Security.Principal.SecurityIdentifier
        $actual.Value | Assert-Equal $userSid
    }

    'Converts local user with computer name prefix domain' = {
        $actual = "$env:COMPUTERNAME\$user" | ConvertTo-AnsibleWindowsSecurityIdentifier
        $actual.GetType().FullName | Assert-Equal System.Security.Principal.SecurityIdentifier
        $actual.Value | Assert-Equal $userSid
    }

    'Converts local group with no domain' = {
        $actual = $group | ConvertTo-AnsibleWindowsSecurityIdentifier
        $actual.GetType().FullName | Assert-Equal System.Security.Principal.SecurityIdentifier
        $actual.Value | Assert-Equal $groupSid
    }

    'Converts local group with . domain' = {
        $actual = ".\$group" | ConvertTo-AnsibleWindowsSecurityIdentifier
        $actual.GetType().FullName | Assert-Equal System.Security.Principal.SecurityIdentifier
        $actual.Value | Assert-Equal $groupSid
    }

    'Converts local group with computer name prefix domain' = {
        $actual = "$env:COMPUTERNAME\$group" | ConvertTo-AnsibleWindowsSecurityIdentifier
        $actual.GetType().FullName | Assert-Equal System.Security.Principal.SecurityIdentifier
        $actual.Value | Assert-Equal $groupSid
    }

    'Converts multiple input values' = {
        $actual = $user, $group | ConvertTo-AnsibleWindowsSecurityIdentifier
        $actual.Count | Assert-Equal 2
        $actual[0] | Assert-Equal $userSid
        $actual[1] | Assert-Equal $groupSid
    }

    'Converts multiple parameter values' = {
        $actual = ConvertTo-AnsibleWindowsSecurityIdentifier $user, $group
        $actual.Count | Assert-Equal 2
        $actual[0] | Assert-Equal $userSid
        $actual[1] | Assert-Equal $groupSid
    }

    'Converts from an existing SID string' = {
        $actual = $userSid | ConvertTo-AnsibleWindowsSecurityIdentifier
        $actual.GetType().FullName | Assert-Equal System.Security.Principal.SecurityIdentifier
        $actual.Value | Assert-Equal $userSid
    }

    'Fails to convert unknown user' = {
        $actual = $null
        $err = . {
            'unknown' | ConvertTo-AnsibleWindowsSecurityIdentifier -ErrorAction Continue |
                Set-Variable -Name actual
        } 2>&1
        $actual | Assert-Equal $null
        $err.Count | Assert-Equal 1
        $err.Exception.GetType().FullName | Assert-Equal System.Security.Principal.IdentityNotMappedException
        $err.FullyQualifiedErrorId | Assert-Equal 'InvalidSidIdentity,ConvertTo-AnsibleWindowsSecurityIdentifier'
        $err.CategoryInfo.Category | Assert-Equal InvalidArgument
        $err.CategoryInfo.TargetName | Assert-Equal unknown
        [string]$err | Assert-Equal "Failed to translate 'unknown' to a SecurityIdentifier: Some or all identity references could not be translated."
    }

    'Fails to convert unknown user but continues onto next user' = {
        $actual = $null
        $err = . {
            'unknown', $user | ConvertTo-AnsibleWindowsSecurityIdentifier -ErrorAction Continue |
                Set-Variable -Name actual
        } 2>&1
        $actual.Count | Assert-Equal 1
        $actual.GetType().FullName | Assert-Equal System.Security.Principal.SecurityIdentifier
        $actual.Value | Assert-Equal $userSid

        $err.Count | Assert-Equal 1
        $err.Exception.GetType().FullName | Assert-Equal System.Security.Principal.IdentityNotMappedException
        $err.FullyQualifiedErrorId | Assert-Equal 'InvalidSidIdentity,ConvertTo-AnsibleWindowsSecurityIdentifier'
        $err.CategoryInfo.Category | Assert-Equal InvalidArgument
        $err.CategoryInfo.TargetName | Assert-Equal unknown
        [string]$err | Assert-Equal "Failed to translate 'unknown' to a SecurityIdentifier: Some or all identity references could not be translated."
    }

    'Throws exception when ErrorAction is stop' = {
        $err = $null
        try {
            'unknown' | ConvertTo-AnsibleWindowsSecurityIdentifier -ErrorAction Stop
        }
        catch {
            $err = $_
        }

        $null -ne $err | Assert-Equal $true
        $err.Exception.GetType().FullName | Assert-Equal System.Security.Principal.IdentityNotMappedException
        $err.FullyQualifiedErrorId | Assert-Equal 'InvalidSidIdentity,ConvertTo-AnsibleWindowsSecurityIdentifier'
        $err.CategoryInfo.Category | Assert-Equal InvalidArgument
        $err.CategoryInfo.TargetName | Assert-Equal unknown
        [string]$err | Assert-Equal "Failed to translate 'unknown' to a SecurityIdentifier: Some or all identity references could not be translated."
    }
}

foreach ($testImpl in $tests.GetEnumerator()) {
    $test = $testImpl.Key
    $null = &$testImpl.Value
}

$module.ExitJson()
