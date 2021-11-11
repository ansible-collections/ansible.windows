#!powershell

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -CSharpUtil ansible_collections.ansible.windows.plugins.module_utils.SCManager
#Requires -Module Ansible.ModuleUtils.ArgvParser
#Requires -Module Ansible.ModuleUtils.CommandUtil

$module = [Ansible.Basic.AnsibleModule]::Create($args, @{})

$path = "$env:SystemRoot\System32\svchost.exe"

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

Function Invoke-Sc {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Action,

        [Parameter(Mandatory = $true)]
        [String]
        $Name,

        [Object]
        $Arguments
    )

    $commandArgs = [System.Collections.Generic.List[String]]@("sc.exe", $Action, $Name)
    if ($null -ne $Arguments) {
        if ($Arguments -is [System.Collections.IDictionary]) {
            foreach ($arg in $Arguments.GetEnumerator()) {
                $commandArgs.Add("$($arg.Key)=")
                $commandArgs.Add($arg.Value)
            }
        }
        else {
            foreach ($arg in $Arguments) {
                $commandArgs.Add($arg)
            }
        }
    }

    $command = Argv-ToString -arguments $commandArgs

    $res = Run-Command -command $command
    if ($res.rc -ne 0) {
        $module.Result.rc = $res.rc
        $module.Result.stdout = $res.stdout
        $module.Result.stderr = $res.stderr
        $module.FailJson("Failed to invoke sc with: $command")
    }

    $info = @{ Name = $Name }

    if ($Action -eq 'qtriggerinfo') {
        # qtriggerinfo is in a different format which requires some manual parsing from the norm.
        $info.Triggers = [System.Collections.Generic.List[PSObject]]@()
    }

    $currentKey = $null
    $qtriggerSection = @{}
    $res.stdout -split "`r`n" | Foreach-Object -Process {
        $line = $_.Trim()

        if ($Action -eq 'qtriggerinfo' -and $line -in @('START SERVICE', 'STOP SERVICE')) {
            if ($qtriggerSection.Count -gt 0) {
                $info.Triggers.Add([PSCustomObject]$qtriggerSection)
                $qtriggerSection = @{}
            }

            $qtriggerSection = @{
                Action = $line
            }
        }

        if (-not $line -or (-not $line.Contains(':') -and $null -eq $currentKey)) {
            return
        }

        $lineSplit = $line.Split(':', 2)
        if ($lineSplit.Length -eq 2) {
            $k = $lineSplit[0].Trim()
            if (-not $k) {
                $k = $currentKey
            }

            $v = $lineSplit[1].Trim()
        }
        else {
            $k = $currentKey
            $v = $line
        }

        if ($qtriggerSection.Count -gt 0) {
            if ($k -eq 'DATA') {
                $qtriggerSection.Data.Add($v)
            }
            else {
                $qtriggerSection.Type = $k
                $qtriggerSection.SubType = $v
                $qtriggerSection.Data = [System.Collections.Generic.List[String]]@()
            }
        }
        else {
            if ($info.ContainsKey($k)) {
                if ($info[$k] -isnot [System.Collections.Generic.List[String]]) {
                    $info[$k] = [System.Collections.Generic.List[String]]@($info[$k])
                }
                $info[$k].Add($v)
            }
            else {
                $currentKey = $k
                $info[$k] = $v
            }
        }
    }

    if ($qtriggerSection.Count -gt 0) {
        $info.Triggers.Add([PSCustomObject]$qtriggerSection)
    }

    [PSCustomObject]$info
}

$tests = [Ordered]@{
    "Props on service created by New-Service" = {
        $actual = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName

        $actual.ServiceName | Assert-Equal -Expected $serviceName
        $actual.ServiceType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceType]::Win32OwnProcess)
        $actual.StartType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceStartType]::DemandStart)
        $actual.ErrorControl | Assert-Equal -Expected ([Ansible.Windows.SCManager.ErrorControl]::Normal)
        $actual.Path | Assert-Equal -Expected ('"{0}"' -f $path)
        $actual.LoadOrderGroup | Assert-Equal -Expected ""
        $actual.DependentOn.Count | Assert-Equal -Expected 0
        $actual.Account | Assert-Equal -Expected (
            [System.Security.Principal.SecurityIdentifier]'S-1-5-18').Translate([System.Security.Principal.NTAccount]
        )
        $actual.DisplayName | Assert-Equal -Expected $serviceName
        $actual.Description | Assert-Equal -Expected $null
        $actual.FailureActions.ResetPeriod | Assert-Equal -Expected 0
        $actual.FailureActions.RebootMsg | Assert-Equal -Expected $null
        $actual.FailureActions.Command | Assert-Equal -Expected $null
        $actual.FailureActions.Actions.Count | Assert-Equal -Expected 0
        $actual.FailureActionsOnNonCrashFailures | Assert-Equal -Expected $false
        $actual.ServiceSidInfo | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceSidInfo]::None)
        $actual.RequiredPrivileges.Count | Assert-Equal -Expected 0
        # Cannot test default values as it differs per OS version
        $null -ne $actual.PreShutdownTimeout | Assert-Equal -Expected $true
        $actual.Triggers.Count | Assert-Equal -Expected 0
        $actual.PreferredNode | Assert-Equal -Expected $null
        if ([Environment]::OSVersion.Version -ge [Version]'6.3') {
            $actual.LaunchProtection | Assert-Equal -Expected ([Ansible.Windows.SCManager.LaunchProtection]::None)
        }
        else {
            $actual.LaunchProtection | Assert-Equal -Expected $null
        }
        $actual.State | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceStatus]::Stopped)
        $actual.Win32ExitCode | Assert-Equal -Expected 1077  # ERROR_SERVICE_NEVER_STARTED
        $actual.ServiceExitCode | Assert-Equal -Expected 0
        $actual.Checkpoint | Assert-Equal -Expected 0
        $actual.WaitHint | Assert-Equal -Expected 0
        $actual.ProcessId | Assert-Equal -Expected 0
        $actual.ServiceFlags | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceFlags]::None)
        $actual.DependedBy.Count | Assert-Equal 0
    }

    "Service creation through util" = {
        $testName = "$($serviceName)_2"
        $actual = [Ansible.Windows.SCManager.Service]::Create($testName, '"{0}"' -f $path)

        try {
            $cmdletService = Get-Service -Name $testName -ErrorAction SilentlyContinue
            $null -ne $cmdletService | Assert-Equal -Expected $true

            $actual.ServiceName | Assert-Equal -Expected $testName
            $actual.ServiceType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceType]::Win32OwnProcess)
            $actual.StartType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceStartType]::DemandStart)
            $actual.ErrorControl | Assert-Equal -Expected ([Ansible.Windows.SCManager.ErrorControl]::Normal)
            $actual.Path | Assert-Equal -Expected ('"{0}"' -f $path)
            $actual.LoadOrderGroup | Assert-Equal -Expected ""
            $actual.DependentOn.Count | Assert-Equal -Expected 0
            $actual.Account | Assert-Equal -Expected (
                [System.Security.Principal.SecurityIdentifier]'S-1-5-18').Translate([System.Security.Principal.NTAccount]
            )
            $actual.DisplayName | Assert-Equal -Expected $testName
            $actual.Description | Assert-Equal -Expected $null
            $actual.FailureActions.ResetPeriod | Assert-Equal -Expected 0
            $actual.FailureActions.RebootMsg | Assert-Equal -Expected $null
            $actual.FailureActions.Command | Assert-Equal -Expected $null
            $actual.FailureActions.Actions.Count | Assert-Equal -Expected 0
            $actual.FailureActionsOnNonCrashFailures | Assert-Equal -Expected $false
            $actual.ServiceSidInfo | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceSidInfo]::None)
            $actual.RequiredPrivileges.Count | Assert-Equal -Expected 0
            $null -ne $actual.PreShutdownTimeout | Assert-Equal -Expected $true
            $actual.Triggers.Count | Assert-Equal -Expected 0
            $actual.PreferredNode | Assert-Equal -Expected $null
            if ([Environment]::OSVersion.Version -ge [Version]'6.3') {
                $actual.LaunchProtection | Assert-Equal -Expected ([Ansible.Windows.SCManager.LaunchProtection]::None)
            }
            else {
                $actual.LaunchProtection | Assert-Equal -Expected $null
            }
            $actual.State | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceStatus]::Stopped)
            $actual.Win32ExitCode | Assert-Equal -Expected 1077  # ERROR_SERVICE_NEVER_STARTED
            $actual.ServiceExitCode | Assert-Equal -Expected 0
            $actual.Checkpoint | Assert-Equal -Expected 0
            $actual.WaitHint | Assert-Equal -Expected 0
            $actual.ProcessId | Assert-Equal -Expected 0
            $actual.ServiceFlags | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceFlags]::None)
            $actual.DependedBy.Count | Assert-Equal 0
        }
        finally {
            $actual.Delete()
        }
    }

    "Fail to open non-existing service" = {
        $failed = $false
        try {
            $null = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList 'fake_service'
        }
        catch [Ansible.Windows.SCManager.ServiceManagerException] {
            # 1060 == ERROR_SERVICE_DOES_NOT_EXIST
            $_.Exception.Message -like '*Win32ErrorCode 1060 - 0x00000424*' | Assert-Equal -Expected $true
            $failed = $true
        }

        $failed | Assert-Equal -Expected $true
    }

    "Open with specific access rights" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList @(
            $serviceName, [Ansible.Windows.SCManager.ServiceRights]'QueryConfig, QueryStatus'
        )

        # QueryStatus can get the status
        $service.State | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceStatus]::Stopped)

        # Should fail to get the config because we did not request that right
        $failed = $false
        try {
            $service.Path = 'fail'
        }
        catch [Ansible.Windows.SCManager.ServiceManagerException] {
            # 5 == ERROR_ACCESS_DENIED
            $_.Exception.Message -like '*Win32ErrorCode 5 - 0x00000005*' | Assert-Equal -Expected $true
            $failed = $true
        }

        $failed | Assert-Equal -Expected $true

    }

    "Modfiy ServiceType" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.ServiceType = [Ansible.Windows.SCManager.ServiceType]::Win32ShareProcess

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.ServiceType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceType]::Win32ShareProcess)
        $actual.TYPE | Assert-Equal -Expected "20  WIN32_SHARE_PROCESS"

        $null = Invoke-Sc -Action config -Name $serviceName -Arguments @{type = "own" }
        $service.Refresh()
        $service.ServiceType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceType]::Win32OwnProcess)
    }

    "Create desktop interactive service" = {
        $service = New-Object -Typename Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.ServiceType = [Ansible.Windows.SCManager.ServiceType]'Win32OwnProcess, InteractiveProcess'

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $actual.TYPE | Assert-Equal -Expected "110  WIN32_OWN_PROCESS (interactive)"
        $service.ServiceType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceType]'Win32OwnProcess, InteractiveProcess')

        # Change back from interactive process
        $service.ServiceType = [Ansible.Windows.SCManager.ServiceType]::Win32OwnProcess

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $actual.TYPE | Assert-Equal -Expected "10  WIN32_OWN_PROCESS"
        $service.ServiceType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceType]::Win32OwnProcess)

        $service.Account = [System.Security.Principal.SecurityIdentifier]'S-1-5-20'

        $failed = $false
        try {
            $service.ServiceType = [Ansible.Windows.SCManager.ServiceType]'Win32OwnProcess, InteractiveProcess'
        }
        catch [Ansible.Windows.SCManager.ServiceManagerException] {
            $failed = $true
            $_.Exception.NativeErrorCode | Assert-Equal -Expected 87  # ERROR_INVALID_PARAMETER
        }
        $failed | Assert-Equal -Expected $true

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $actual.TYPE | Assert-Equal -Expected "10  WIN32_OWN_PROCESS"
    }

    "Modify StartType" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.StartType = [Ansible.Windows.SCManager.ServiceStartType]::Disabled

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.StartType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceStartType]::Disabled)
        $actual.START_TYPE | Assert-Equal -Expected "4   DISABLED"

        $null = Invoke-Sc -Action config -Name $serviceName -Arguments @{start = "demand" }
        $service.Refresh()
        $service.StartType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceStartType]::DemandStart)
    }

    "Modify StartType auto delayed" = {
        # Delayed start type is a modifier of the AutoStart type. It uses a separate config entry to define and this
        # makes sure the util does that correctly from various types and back.
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.StartType = [Ansible.Windows.SCManager.ServiceStartType]::Disabled  # Start from Disabled

        # Disabled -> Auto Start Delayed
        $service.StartType = [Ansible.Windows.SCManager.ServiceStartType]::AutoStartDelayed

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.StartType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceStartType]::AutoStartDelayed)
        $actual.START_TYPE | Assert-Equal -Expected "2   AUTO_START  (DELAYED)"

        # Auto Start Delayed -> Auto Start
        $service.StartType = [Ansible.Windows.SCManager.ServiceStartType]::AutoStart

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.StartType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceStartType]::AutoStart)
        $actual.START_TYPE | Assert-Equal -Expected "2   AUTO_START"

        # Auto Start -> Auto Start Delayed
        $service.StartType = [Ansible.Windows.SCManager.ServiceStartType]::AutoStartDelayed

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.StartType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceStartType]::AutoStartDelayed)
        $actual.START_TYPE | Assert-Equal -Expected "2   AUTO_START  (DELAYED)"

        # Auto Start Delayed -> Manual
        $service.StartType = [Ansible.Windows.SCManager.ServiceStartType]::DemandStart

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.StartType | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceStartType]::DemandStart)
        $actual.START_TYPE | Assert-Equal -Expected "3   DEMAND_START"
    }

    "Modify ErrorControl" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.ErrorControl = [Ansible.Windows.SCManager.ErrorControl]::Severe

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.ErrorControl | Assert-Equal -Expected ([Ansible.Windows.SCManager.ErrorControl]::Severe)
        $actual.ERROR_CONTROL | Assert-Equal -Expected "2   SEVERE"

        $null = Invoke-Sc -Action config -Name $serviceName -Arguments @{error = "ignore" }
        $service.Refresh()
        $service.ErrorControl | Assert-Equal -Expected ([Ansible.Windows.SCManager.ErrorControl]::Ignore)
    }

    "Modify Path" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.Path = "Fake path"

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.Path | Assert-Equal -Expected "Fake path"
        $actual.BINARY_PATH_NAME | Assert-Equal -Expected "Fake path"

        $null = Invoke-Sc -Action config -Name $serviceName -Arguments @{binpath = "other fake path" }
        $service.Refresh()
        $service.Path | Assert-Equal -Expected "other fake path"
    }

    "Modify LoadOrderGroup" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.LoadOrderGroup = "my group"

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.LoadOrderGroup | Assert-Equal -Expected "my group"
        $actual.LOAD_ORDER_GROUP | Assert-Equal -Expected "my group"

        $null = Invoke-Sc -Action config -Name $serviceName -Arguments @{group = "" }
        $service.Refresh()
        $service.LoadOrderGroup | Assert-Equal -Expected ""
    }

    "Modify DependentOn" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.DependentOn = @("HTTP", "WinRM")

        $actual = Invoke-Sc -Action qc -Name $serviceName
        @(, $service.DependentOn) | Assert-Equal -Expected @("HTTP", "WinRM")
        @(, $actual.DEPENDENCIES) | Assert-Equal -Expected @("HTTP", "WinRM")

        $null = Invoke-Sc -Action config -Name $serviceName -Arguments @{depend = "" }
        $service.Refresh()
        $service.DependentOn.Count | Assert-Equal -Expected 0
    }

    "Modify Account - service account" = {
        $systemSid = [System.Security.Principal.SecurityIdentifier]'S-1-5-18'
        $systemName = $systemSid.Translate([System.Security.Principal.NTAccount])
        $localSid = [System.Security.Principal.SecurityIdentifier]'S-1-5-19'
        $localName = $localSid.Translate([System.Security.Principal.NTAccount])
        $networkSid = [System.Security.Principal.SecurityIdentifier]'S-1-5-20'
        $networkName = $networkSid.Translate([System.Security.Principal.NTAccount])

        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.Account = $networkSid

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.Account | Assert-Equal -Expected $networkName
        $actual.SERVICE_START_NAME | Assert-Equal -Expected $networkName.Value

        $null = Invoke-Sc -Action config -Name $serviceName -Arguments @{obj = $localName.Value }
        $service.Refresh()
        $service.Account | Assert-Equal -Expected $localName

        $service.Account = $systemSid
        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.Account | Assert-Equal -Expected $systemName
        $actual.SERVICE_START_NAME | Assert-Equal -Expected "LocalSystem"
    }

    "Modify Account - user" = {
        $currentSid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User

        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.Account = $currentSid
        $service.Password = 'password'

        $actual = Invoke-Sc -Action qc -Name $serviceName

        # When running tests in CI this seems to become .\Administrator
        if ($service.Account.Value.StartsWith('.\')) {
            $username = $service.Account.Value.Substring(2, $service.Account.Value.Length - 2)
            $actualSid = ([System.Security.Principal.NTAccount]"$env:COMPUTERNAME\$username").Translate(
                [System.Security.Principal.SecurityIdentifier]
            )
        }
        else {
            $actualSid = $service.Account.Translate([System.Security.Principal.SecurityIdentifier])
        }
        $actualSid.Value | Assert-Equal -Expected $currentSid.Value
        $actual.SERVICE_START_NAME | Assert-Equal -Expected $service.Account.Value

        # Go back to SYSTEM from account
        $systemSid = [System.Security.Principal.SecurityIdentifier]'S-1-5-18'
        $service.Account = $systemSid

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.Account | Assert-Equal -Expected $systemSid.Translate([System.Security.Principal.NTAccount])
        $actual.SERVICE_START_NAME | Assert-Equal -Expected "LocalSystem"
    }

    "Modify Account - virtual account" = {
        $account = [System.Security.Principal.NTAccount]"NT SERVICE\$serviceName"

        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.Account = $account

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.Account | Assert-Equal -Expected $account
        $actual.SERVICE_START_NAME | Assert-Equal -Expected $account.Value
    }

    "Modify Account - gMSA" = {
        # This cannot be tested through CI, only done on manual tests.
        return

        $gmsaName = [System.Security.Principal.NTAccount]'gMSA$@DOMAIN.LOCAL'  # Make sure this is UPN.
        $gmsaSid = $gmsaName.Translate([System.Security.Principal.SecurityIdentifier])
        $gmsaNetlogon = $gmsaSid.Translate([System.Security.Principal.NTAccount])

        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.Account = $gmsaName

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.Account | Assert-Equal -Expected $gmsaName
        $actual.SERVICE_START_NAME | Assert-Equal -Expected $gmsaName

        # Go from gMSA to account and back to verify the Password doesn't matter.
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
        $service.Account = $currentUser
        $service.Password = 'fake password'
        $service.Password = 'fake password2'

        # Now test in the Netlogon format.
        $service.Account = $gmsaSid

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.Account | Assert-Equal -Expected $gmsaNetlogon
        $actual.SERVICE_START_NAME | Assert-Equal -Expected $gmsaNetlogon.Value
    }

    "Modify DisplayName" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.DisplayName = "Custom Service Name"

        $actual = Invoke-Sc -Action qc -Name $serviceName
        $service.DisplayName | Assert-Equal -Expected "Custom Service Name"
        $actual.DISPLAY_NAME | Assert-Equal -Expected "Custom Service Name"

        $null = Invoke-Sc -Action config -Name $serviceName -Arguments @{displayname = "New Service Name" }
        $service.Refresh()
        $service.DisplayName | Assert-Equal -Expected "New Service Name"
    }

    "Modify Description" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.Description = "My custom service description"

        $actual = Invoke-Sc -Action qdescription -Name $serviceName
        $service.Description | Assert-Equal -Expected "My custom service description"
        $actual.DESCRIPTION | Assert-Equal -Expected "My custom service description"

        $null = Invoke-Sc -Action description -Name $serviceName -Arguments @(, "new description")
        $service.Description | Assert-Equal -Expected "new description"

        $service.Description = $null

        $actual = Invoke-Sc -Action qdescription -Name $serviceName
        $service.Description | Assert-Equal -Expected $null
        $actual.DESCRIPTION | Assert-Equal -Expected ""
    }

    "Modify FailureActions" = {
        $newAction = [Ansible.Windows.SCManager.FailureActions]@{
            ResetPeriod = 86400
            RebootMsg = 'Reboot msg'
            Command = 'Command line'
            Actions = @(
                [Ansible.Windows.SCManager.Action]@{Type = [Ansible.Windows.SCManager.FailureAction]::RunCommand; Delay = 1000 },
                [Ansible.Windows.SCManager.Action]@{Type = [Ansible.Windows.SCManager.FailureAction]::RunCommand; Delay = 2000 },
                [Ansible.Windows.SCManager.Action]@{Type = [Ansible.Windows.SCManager.FailureAction]::Restart; Delay = 1000 },
                [Ansible.Windows.SCManager.Action]@{Type = [Ansible.Windows.SCManager.FailureAction]::Reboot; Delay = 1000 }
            )
        }
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.FailureActions = $newAction

        $actual = Invoke-Sc -Action qfailure -Name $serviceName
        $actual.'RESET_PERIOD (in seconds)' | Assert-Equal -Expected 86400
        $actual.REBOOT_MESSAGE | Assert-Equal -Expected 'Reboot msg'
        $actual.COMMAND_LINE | Assert-Equal -Expected 'Command line'
        $actual.FAILURE_ACTIONS.Count | Assert-Equal -Expected 4
        $actual.FAILURE_ACTIONS[0] | Assert-Equal -Expected "RUN PROCESS -- Delay = 1000 milliseconds."
        $actual.FAILURE_ACTIONS[1] | Assert-Equal -Expected "RUN PROCESS -- Delay = 2000 milliseconds."
        $actual.FAILURE_ACTIONS[2] | Assert-Equal -Expected "RESTART -- Delay = 1000 milliseconds."
        $actual.FAILURE_ACTIONS[3] | Assert-Equal -Expected "REBOOT -- Delay = 1000 milliseconds."
        $service.FailureActions.Actions.Count | Assert-Equal -Expected 4

        # Test that we can change individual settings and it doesn't change all
        $service.FailureActions = [Ansible.Windows.SCManager.FailureActions]@{ResetPeriod = 172800 }

        $actual = Invoke-Sc -Action qfailure -Name $serviceName
        $actual.'RESET_PERIOD (in seconds)' | Assert-Equal -Expected 172800
        $actual.REBOOT_MESSAGE | Assert-Equal -Expected 'Reboot msg'
        $actual.COMMAND_LINE | Assert-Equal -Expected 'Command line'
        $actual.FAILURE_ACTIONS.Count | Assert-Equal -Expected 4
        $service.FailureActions.Actions.Count | Assert-Equal -Expected 4

        $service.FailureActions = [Ansible.Windows.SCManager.FailureActions]@{RebootMsg = "New reboot msg" }

        $actual = Invoke-Sc -Action qfailure -Name $serviceName
        $actual.'RESET_PERIOD (in seconds)' | Assert-Equal -Expected 172800
        $actual.REBOOT_MESSAGE | Assert-Equal -Expected 'New reboot msg'
        $actual.COMMAND_LINE | Assert-Equal -Expected 'Command line'
        $actual.FAILURE_ACTIONS.Count | Assert-Equal -Expected 4
        $service.FailureActions.Actions.Count | Assert-Equal -Expected 4

        $service.FailureActions = [Ansible.Windows.SCManager.FailureActions]@{Command = "New command line" }

        $actual = Invoke-Sc -Action qfailure -Name $serviceName
        $actual.'RESET_PERIOD (in seconds)' | Assert-Equal -Expected 172800
        $actual.REBOOT_MESSAGE | Assert-Equal -Expected 'New reboot msg'
        $actual.COMMAND_LINE | Assert-Equal -Expected 'New command line'
        $actual.FAILURE_ACTIONS.Count | Assert-Equal -Expected 4
        $service.FailureActions.Actions.Count | Assert-Equal -Expected 4

        # Test setting both ResetPeriod and Actions together
        $service.FailureActions = [Ansible.Windows.SCManager.FailureActions]@{
            ResetPeriod = 86400
            Actions = @(
                [Ansible.Windows.SCManager.Action]@{Type = [Ansible.Windows.SCManager.FailureAction]::RunCommand; Delay = 5000 },
                [Ansible.Windows.SCManager.Action]@{Type = [Ansible.Windows.SCManager.FailureAction]::None; Delay = 0 }
            )
        }

        $actual = Invoke-Sc -Action qfailure -Name $serviceName
        $actual.'RESET_PERIOD (in seconds)' | Assert-Equal -Expected 86400
        $actual.REBOOT_MESSAGE | Assert-Equal -Expected 'New reboot msg'
        $actual.COMMAND_LINE | Assert-Equal -Expected 'New command line'
        # sc.exe does not show the None action it just ends the list, so we verify from get_FailureActions
        $actual.FAILURE_ACTIONS | Assert-Equal -Expected "RUN PROCESS -- Delay = 5000 milliseconds."
        $service.FailureActions.Actions.Count | Assert-Equal -Expected 2
        $service.FailureActions.Actions[1].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.FailureAction]::None)

        # Test setting just Actions without ResetPeriod
        $service.FailureActions = [Ansible.Windows.SCManager.FailureActions]@{
            Actions = [Ansible.Windows.SCManager.Action]@{Type = [Ansible.Windows.SCManager.FailureAction]::RunCommand; Delay = 10000 }
        }
        $actual = Invoke-Sc -Action qfailure -Name $serviceName
        $actual.'RESET_PERIOD (in seconds)' | Assert-Equal -Expected 86400
        $actual.REBOOT_MESSAGE | Assert-Equal -Expected 'New reboot msg'
        $actual.COMMAND_LINE | Assert-Equal -Expected 'New command line'
        $actual.FAILURE_ACTIONS | Assert-Equal -Expected "RUN PROCESS -- Delay = 10000 milliseconds."
        $service.FailureActions.Actions.Count | Assert-Equal -Expected 1

        # Test removing all actions
        $service.FailureActions = [Ansible.Windows.SCManager.FailureActions]@{
            Actions = @()
        }
        $actual = Invoke-Sc -Action qfailure -Name $serviceName
        $actual.'RESET_PERIOD (in seconds)' | Assert-Equal -Expected 0  # ChangeServiceConfig2W resets this back to 0.
        $actual.REBOOT_MESSAGE | Assert-Equal -Expected 'New reboot msg'
        $actual.COMMAND_LINE | Assert-Equal -Expected 'New command line'
        $actual.PSObject.Properties.Name.Contains('FAILURE_ACTIONS') | Assert-Equal -Expected $false
        $service.FailureActions.Actions.Count | Assert-Equal -Expected 0

        # Test that we are reading the right values
        $null = Invoke-Sc -Action failure -Name $serviceName -Arguments @{
            reset = 172800
            reboot = "sc reboot msg"
            command = "sc command line"
            actions = "run/5000/reboot/800"
        }

        $actual = $service.FailureActions
        $actual.ResetPeriod | Assert-Equal -Expected 172800
        $actual.RebootMsg | Assert-Equal -Expected "sc reboot msg"
        $actual.Command | Assert-Equal -Expected "sc command line"
        $actual.Actions.Count | Assert-Equal -Expected 2
        $actual.Actions[0].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.FailureAction]::RunCommand)
        $actual.Actions[0].Delay | Assert-Equal -Expected 5000
        $actual.Actions[1].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.FailureAction]::Reboot)
        $actual.Actions[1].Delay | Assert-Equal -Expected 800
    }

    "Modify FailureActionsOnNonCrashFailures" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.FailureActionsOnNonCrashFailures = $true

        $actual = Invoke-Sc -Action qfailureflag -Name $serviceName
        $service.FailureActionsOnNonCrashFailures | Assert-Equal -Expected $true
        $actual.FAILURE_ACTIONS_ON_NONCRASH_FAILURES | Assert-Equal -Expected "TRUE"

        $null = Invoke-Sc -Action failureflag -Name $serviceName -Arguments @(, 0)
        $service.FailureActionsOnNonCrashFailures | Assert-Equal -Expected $false
    }

    "Modify ServiceSidInfo" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.ServiceSidInfo = [Ansible.Windows.SCManager.ServiceSidInfo]::None

        $actual = Invoke-Sc -Action qsidtype -Name $serviceName
        $service.ServiceSidInfo | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceSidInfo]::None)
        $actual.SERVICE_SID_TYPE | Assert-Equal -Expected 'NONE'

        $null = Invoke-Sc -Action sidtype -Name $serviceName -Arguments @(, 'unrestricted')
        $service.ServiceSidInfo | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceSidInfo]::Unrestricted)

        $service.ServiceSidInfo = [Ansible.Windows.SCManager.ServiceSidInfo]::Restricted

        $actual = Invoke-Sc -Action qsidtype -Name $serviceName
        $service.ServiceSidInfo | Assert-Equal -Expected ([Ansible.Windows.SCManager.ServiceSidInfo]::Restricted)
        $actual.SERVICE_SID_TYPE | Assert-Equal -Expected 'RESTRICTED'
    }

    "Modify RequiredPrivileges" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.RequiredPrivileges = @("SeBackupPrivilege", "SeTcbPrivilege")

        $actual = Invoke-Sc -Action qprivs -Name $serviceName
        , $service.RequiredPrivileges | Assert-Equal -Expected @("SeBackupPrivilege", "SeTcbPrivilege")
        , $actual.PRIVILEGES | Assert-Equal -Expected @("SeBackupPrivilege", "SeTcbPrivilege")

        # Ensure setting to $null is the same as an empty array
        $service.RequiredPrivileges = $null

        $actual = Invoke-Sc -Action qprivs -Name $serviceName
        , $service.RequiredPrivileges | Assert-Equal -Expected @()
        , $actual.PRIVILEGES | Assert-Equal -Expected @()

        $service.RequiredPrivileges = @("SeBackupPrivilege", "SeTcbPrivilege")
        $service.RequiredPrivileges = @()

        $actual = Invoke-Sc -Action qprivs -Name $serviceName
        , $service.RequiredPrivileges | Assert-Equal -Expected @()
        , $actual.PRIVILEGES | Assert-Equal -Expected @()

        $null = Invoke-Sc -Action privs -Name $serviceName -Arguments @(, "SeCreateTokenPrivilege/SeRestorePrivilege")
        , $service.RequiredPrivileges | Assert-Equal -Expected @("SeCreateTokenPrivilege", "SeRestorePrivilege")
    }

    "Modify PreShutdownTimeout" = {
        $service = New-Object -TypeName Ansible.Windows.SCManager.Service -ArgumentList $serviceName
        $service.PreShutdownTimeout = 60000

        # sc.exe doesn't seem to have a query argument for this, just get it from the registry
        $actual = (
            Get-ItemProperty -LiteralPath "HKLM:\SYSTEM\CurrentControlSet\Services\$serviceName" -Name PreshutdownTimeout
        ).PreshutdownTimeout
        $actual | Assert-Equal -Expected 60000
    }

    "Modify Triggers" = {
        $service = [Ansible.Windows.SCManager.Service]$serviceName
        $service.Triggers = @(
            [Ansible.Windows.SCManager.Trigger]@{
                Type = [Ansible.Windows.SCManager.TriggerType]::DomainJoin
                Action = [Ansible.Windows.SCManager.TriggerAction]::ServiceStop
                SubType = [Guid][Ansible.Windows.SCManager.Trigger]::DOMAIN_JOIN_GUID
            },
            [Ansible.Windows.SCManager.Trigger]@{
                Type = [Ansible.Windows.SCManager.TriggerType]::NetworkEndpoint
                Action = [Ansible.Windows.SCManager.TriggerAction]::ServiceStart
                SubType = [Guid][Ansible.Windows.SCManager.Trigger]::NAMED_PIPE_EVENT_GUID
                DataItems = [Ansible.Windows.SCManager.TriggerItem]@{
                    Type = [Ansible.Windows.SCManager.TriggerDataType]::String
                    Data = 'my named pipe'
                }
            },
            [Ansible.Windows.SCManager.Trigger]@{
                Type = [Ansible.Windows.SCManager.TriggerType]::NetworkEndpoint
                Action = [Ansible.Windows.SCManager.TriggerAction]::ServiceStart
                SubType = [Guid][Ansible.Windows.SCManager.Trigger]::NAMED_PIPE_EVENT_GUID
                DataItems = [Ansible.Windows.SCManager.TriggerItem]@{
                    Type = [Ansible.Windows.SCManager.TriggerDataType]::String
                    Data = 'my named pipe 2'
                }
            },
            [Ansible.Windows.SCManager.Trigger]@{
                Type = [Ansible.Windows.SCManager.TriggerType]::Custom
                Action = [Ansible.Windows.SCManager.TriggerAction]::ServiceStart
                SubType = [Guid]'9bf04e57-05dc-4914-9ed9-84bf992db88c'
                DataItems = @(
                    [Ansible.Windows.SCManager.TriggerItem]@{
                        Type = [Ansible.Windows.SCManager.TriggerDataType]::Binary
                        Data = [byte[]]@(1, 2, 3, 4)
                    },
                    [Ansible.Windows.SCManager.TriggerItem]@{
                        Type = [Ansible.Windows.SCManager.TriggerDataType]::Binary
                        Data = [byte[]]@(5, 6, 7, 8, 9)
                    }
                )
            }
            [Ansible.Windows.SCManager.Trigger]@{
                Type = [Ansible.Windows.SCManager.TriggerType]::Custom
                Action = [Ansible.Windows.SCManager.TriggerAction]::ServiceStart
                SubType = [Guid]'9fbcfc7e-7581-4d46-913b-53bb15c80c51'
                DataItems = @(
                    [Ansible.Windows.SCManager.TriggerItem]@{
                        Type = [Ansible.Windows.SCManager.TriggerDataType]::String
                        Data = 'entry 1'
                    },
                    [Ansible.Windows.SCManager.TriggerItem]@{
                        Type = [Ansible.Windows.SCManager.TriggerDataType]::String
                        Data = 'entry 2'
                    }
                )
            },
            [Ansible.Windows.SCManager.Trigger]@{
                Type = [Ansible.Windows.SCManager.TriggerType]::FirewallPortEvent
                Action = [Ansible.Windows.SCManager.TriggerAction]::ServiceStop
                SubType = [Guid][Ansible.Windows.SCManager.Trigger]::FIREWALL_PORT_CLOSE_GUID
                DataItems = [Ansible.Windows.SCManager.TriggerItem]@{
                    Type = [Ansible.Windows.SCManager.TriggerDataType]::String
                    Data = [System.Collections.Generic.List[String]]@("1234", "tcp", "imagepath", "servicename")
                }
            }
        )

        $actual = Invoke-Sc -Action qtriggerinfo -Name $serviceName

        $actual.Triggers.Count | Assert-Equal -Expected 6
        $actual.Triggers[0].Type | Assert-Equal -Expected 'DOMAIN JOINED STATUS'
        $actual.Triggers[0].Action | Assert-Equal -Expected 'STOP SERVICE'
        $actual.Triggers[0].SubType | Assert-Equal -Expected "$([Ansible.Windows.SCManager.Trigger]::DOMAIN_JOIN_GUID) [DOMAIN JOINED]"
        $actual.Triggers[0].Data.Count | Assert-Equal -Expected 0

        $actual.Triggers[1].Type | Assert-Equal -Expected 'NETWORK EVENT'
        $actual.Triggers[1].Action | Assert-Equal -Expected 'START SERVICE'
        $actual.Triggers[1].SubType | Assert-Equal -Expected "$([Ansible.Windows.SCManager.Trigger]::NAMED_PIPE_EVENT_GUID) [NAMED PIPE EVENT]"
        $actual.Triggers[1].Data.Count | Assert-Equal -Expected 1
        $actual.Triggers[1].Data[0] | Assert-Equal -Expected 'my named pipe'

        $actual.Triggers[2].Type | Assert-Equal -Expected 'NETWORK EVENT'
        $actual.Triggers[2].Action | Assert-Equal -Expected 'START SERVICE'
        $actual.Triggers[2].SubType | Assert-Equal -Expected "$([Ansible.Windows.SCManager.Trigger]::NAMED_PIPE_EVENT_GUID) [NAMED PIPE EVENT]"
        $actual.Triggers[2].Data.Count | Assert-Equal -Expected 1
        $actual.Triggers[2].Data[0] | Assert-Equal -Expected 'my named pipe 2'

        $actual.Triggers[3].Type | Assert-Equal -Expected 'CUSTOM'
        $actual.Triggers[3].Action | Assert-Equal -Expected 'START SERVICE'
        $actual.Triggers[3].SubType | Assert-Equal -Expected '9bf04e57-05dc-4914-9ed9-84bf992db88c [ETW PROVIDER UUID]'
        $actual.Triggers[3].Data.Count | Assert-Equal -Expected 2
        $actual.Triggers[3].Data[0] | Assert-Equal -Expected '01 02 03 04'
        $actual.Triggers[3].Data[1] | Assert-Equal -Expected '05 06 07 08 09'

        $actual.Triggers[4].Type | Assert-Equal -Expected 'CUSTOM'
        $actual.Triggers[4].Action | Assert-Equal -Expected 'START SERVICE'
        $actual.Triggers[4].SubType | Assert-Equal -Expected '9fbcfc7e-7581-4d46-913b-53bb15c80c51 [ETW PROVIDER UUID]'
        $actual.Triggers[4].Data.Count | Assert-Equal -Expected 2
        $actual.Triggers[4].Data[0] | Assert-Equal -Expected "entry 1"
        $actual.Triggers[4].Data[1] | Assert-Equal -Expected "entry 2"

        $actual.Triggers[5].Type | Assert-Equal -Expected 'FIREWALL PORT EVENT'
        $actual.Triggers[5].Action | Assert-Equal -Expected 'STOP SERVICE'
        $actual.Triggers[5].SubType | Assert-Equal -Expected "$([Ansible.Windows.SCManager.Trigger]::FIREWALL_PORT_CLOSE_GUID) [PORT CLOSE]"
        $actual.Triggers[5].Data.Count | Assert-Equal -Expected 1
        $actual.Triggers[5].Data[0] | Assert-Equal -Expected '1234;tcp;imagepath;servicename'

        # Remove trigger with $null
        $service.Triggers = $null

        $actual = Invoke-Sc -Action qtriggerinfo -Name $serviceName
        $actual.Triggers.Count | Assert-Equal -Expected 0

        # Add a single trigger
        $service.Triggers = [Ansible.Windows.SCManager.Trigger]@{
            Type = [Ansible.Windows.SCManager.TriggerType]::GroupPolicy
            Action = [Ansible.Windows.SCManager.TriggerAction]::ServiceStart
            SubType = [Guid][Ansible.Windows.SCManager.Trigger]::MACHINE_POLICY_PRESENT_GUID
        }

        $actual = Invoke-Sc -Action qtriggerinfo -Name $serviceName
        $actual.Triggers.Count | Assert-Equal -Expected 1
        $actual.Triggers[0].Type | Assert-Equal -Expected 'GROUP POLICY'
        $actual.Triggers[0].Action | Assert-Equal -Expected 'START SERVICE'
        $actual.Triggers[0].SubType | Assert-Equal -Expected "$([Ansible.Windows.SCManager.Trigger]::MACHINE_POLICY_PRESENT_GUID) [MACHINE POLICY PRESENT]"
        $actual.Triggers[0].Data.Count | Assert-Equal -Expected 0

        # Remove trigger with empty list
        $service.Triggers = @()

        $actual = Invoke-Sc -Action qtriggerinfo -Name $serviceName
        $actual.Triggers.Count | Assert-Equal -Expected 0

        # Add triggers through sc and check we get the values correctly
        $null = Invoke-Sc -Action triggerinfo -Name $serviceName -Arguments @(
            'start/namedpipe/abc',
            'start/namedpipe/def',
            'start/custom/d4497e12-ac36-4823-af61-92db0dbd4a76/11223344/aabbccdd',
            'start/strcustom/435a1742-22c5-4234-9db3-e32dafde695c/11223344/aabbccdd',
            'stop/portclose/1234;tcp;imagepath;servicename',
            'stop/networkoff'
        )

        $actual = $service.Triggers
        $actual.Count | Assert-Equal -Expected 6

        $actual[0].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerType]::NetworkEndpoint)
        $actual[0].Action | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerAction]::ServiceStart)
        $actual[0].SubType = [Guid][Ansible.Windows.SCManager.Trigger]::NAMED_PIPE_EVENT_GUID
        $actual[0].DataItems.Count | Assert-Equal -Expected 1
        $actual[0].DataItems[0].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerDataType]::String)
        $actual[0].DataItems[0].Data | Assert-Equal -Expected 'abc'

        $actual[1].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerType]::NetworkEndpoint)
        $actual[1].Action | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerAction]::ServiceStart)
        $actual[1].SubType = [Guid][Ansible.Windows.SCManager.Trigger]::NAMED_PIPE_EVENT_GUID
        $actual[1].DataItems.Count | Assert-Equal -Expected 1
        $actual[1].DataItems[0].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerDataType]::String)
        $actual[1].DataItems[0].Data | Assert-Equal -Expected 'def'

        $actual[2].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerType]::Custom)
        $actual[2].Action | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerAction]::ServiceStart)
        $actual[2].SubType = [Guid]'d4497e12-ac36-4823-af61-92db0dbd4a76'
        $actual[2].DataItems.Count | Assert-Equal -Expected 2
        $actual[2].DataItems[0].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerDataType]::Binary)
        , $actual[2].DataItems[0].Data | Assert-Equal -Expected ([byte[]]@(17, 34, 51, 68))
        $actual[2].DataItems[1].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerDataType]::Binary)
        , $actual[2].DataItems[1].Data | Assert-Equal -Expected ([byte[]]@(170, 187, 204, 221))

        $actual[3].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerType]::Custom)
        $actual[3].Action | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerAction]::ServiceStart)
        $actual[3].SubType = [Guid]'435a1742-22c5-4234-9db3-e32dafde695c'
        $actual[3].DataItems.Count | Assert-Equal -Expected 2
        $actual[3].DataItems[0].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerDataType]::String)
        $actual[3].DataItems[0].Data | Assert-Equal -Expected '11223344'
        $actual[3].DataItems[1].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerDataType]::String)
        $actual[3].DataItems[1].Data | Assert-Equal -Expected 'aabbccdd'

        $actual[4].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerType]::FirewallPortEvent)
        $actual[4].Action | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerAction]::ServiceStop)
        $actual[4].SubType = [Guid][Ansible.Windows.SCManager.Trigger]::FIREWALL_PORT_CLOSE_GUID
        $actual[4].DataItems.Count | Assert-Equal -Expected 1
        $actual[4].DataItems[0].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerDataType]::String)
        , $actual[4].DataItems[0].Data | Assert-Equal -Expected @('1234', 'tcp', 'imagepath', 'servicename')

        $actual[5].Type | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerType]::IpAddressAvailability)
        $actual[5].Action | Assert-Equal -Expected ([Ansible.Windows.SCManager.TriggerAction]::ServiceStop)
        $actual[5].SubType = [Guid][Ansible.Windows.SCManager.Trigger]::NETWORK_MANAGER_LAST_IP_ADDRESS_REMOVAL_GUID
        $actual[5].DataItems.Count | Assert-Equal -Expected 0
    }

    # Cannot test PreferredNode as we can't guarantee CI is set up with NUMA support.
    # Cannot test LaunchProtection as once set we cannot remove unless rebooting
}

# setup and teardown should favour native tools to create and delete the service and not the util we are testing.
foreach ($testImpl in $tests.GetEnumerator()) {
    $serviceName = "ansible_$([System.IO.Path]::GetRandomFileName())"
    $null = New-Service -Name $serviceName -BinaryPathName ('"{0}"' -f $path) -StartupType Manual

    try {
        $test = $testImpl.Key
        &$testImpl.Value
    }
    finally {
        $null = Invoke-Sc -Action delete -Name $serviceName
    }
}

$module.Result.data = "success"
$module.ExitJson()
