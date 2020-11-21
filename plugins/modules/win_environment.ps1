#!powershell

# Copyright: (c) 2020, Brian Scholer (@briantist)
# Copyright: (c) 2015, Jon Hawkesworth (@jhawkesworth) <figs@unity.demon.co.uk>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        name = @{ type = "str" }
        level = @{ type = "str"; choices = "machine", "process", "user"; required = $true }
        state = @{ type = "str"; choices = "absent", "present" }
        value = @{ type = "str" }
        variables = @{ type = "dict" }
    }
    mutually_exclusive = @(
        ,@("variables", "name")
        ,@("variables", "value")
        ,@("variables", "state")
    )
    required_one_of = @(,@("name", "variables"))
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

function Set-EnvironmentVariableState {
    [CmdletBinding(SupportsShouldProcess=$true)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory=$true)]
        [System.EnvironmentVariableTarget]
        $Level ,

        [Parameter(Mandatory=$true, ValueFromPipelineByPropertyName=$true)]
        [Alias('Key')]
        [String]
        $Name ,

        [Parameter(ValueFromPipelineByPropertyName=$true)]
        [String]
        $Value,

        [Parameter()]
        [String]
        $State
    )

    Process {
        if (-not $State) {
            $State = if (-not $Value) {
                'absent'
            }
            else {
                'present'
            }
        }

        $before_value = [Environment]::GetEnvironmentVariable($name, $Level)

        $ret = @{
            changed = $false
            after = $Value
            before = $before_value
        }

        if ($State -eq "present" -and $before_value -ne $Value) {
            if ($PSCmdlet.ShouldProcess($Name, 'Set environment variable')) {
                [Environment]::SetEnvironmentVariable($Name, $Value, $Level)
            }
            $ret.changed = $true
        } elseif ($State -eq "absent" -and $null -ne $before_value) {
            if ($PSCmdlet.ShouldProcess($Name, 'Remove environment variable')) {
                [Environment]::SetEnvironmentVariable($Name, $null, $Level)
            }
            $ret.changed = $true
        }

        $ret
    }
}

$module.Result.values = @{}

$level = $module.Params.level
$state = $module.Params.state

$envvars = if ($module.Params.variables) {
    $module.Params.variables
}
else {
    @{
        $module.Params.name = $module.Params.value
    }
}

$module.Diff.before = @{ $level = @{} }
$module.Diff.after = @{ $level = @{} }

foreach ($kv in $envvars.GetEnumerator()) {
    $name = $kv.Key
    $value = $kv.Value

    # When removing environment, set value to $null if set
    if ($state -eq "absent" -and $value) {
        $module.Warn("When removing environment variable '$name' it should not have a value '$value' set")
        $value = $null
    } elseif ($state -eq "present" -and (-not $value)) {
        $module.FailJson("When state=present, value must be defined and not an empty string, if you wish to remove the envvar, set state=absent")
    }

    $status = $kv | Set-EnvironmentVariableState -Level $level -State $state -WhatIf:$($module.CheckMode)

    if ($status.before) {
        $module.Diff.before.$level.$name = $status.before
    }
    if ($status.after) {
        $module.Diff.after.$level.$name = $status.after
    }

    $module.Result.values.$name = $status
    $module.Result.changed = $module.Result.changed -or $status.changed

    $module.Result.before_value = $status.before
    $module.Result.value = $status.after
}

$module.ExitJson()
