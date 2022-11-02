#!powershell

# Copyright: (c) 2020, Brian Scholer (@briantist)
# Copyright: (c) 2015, Jon Hawkesworth (@jhawkesworth) <figs@unity.demon.co.uk>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell Ansible.ModuleUtils.AddType

$spec = @{
    options = @{
        name = @{ type = "str" }
        level = @{ type = "str"; choices = "machine", "process", "user"; required = $true }
        state = @{ type = "str"; choices = "absent", "present" }
        value = @{ type = "str" }
        variables = @{ type = "dict" }
    }
    mutually_exclusive = @(
        , @("variables", "name")
        , @("variables", "value")
        , @("variables", "state")
    )
    required_one_of = @(, @("name", "variables"))
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

function Set-EnvironmentVariableState {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [Ansible.Basic.AnsibleModule]
        $Module,

        [Parameter(Mandatory = $true)]
        [System.EnvironmentVariableTarget]
        $Level ,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [Alias('Key')]
        [String]
        $Name ,

        [Parameter(ValueFromPipelineByPropertyName = $true)]
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
                Register-EnvironmentChange -Module $Module
            }
            $ret.changed = $true
        }
        elseif ($State -eq "absent" -and $null -ne $before_value) {
            if ($PSCmdlet.ShouldProcess($Name, 'Remove environment variable')) {
                [Environment]::SetEnvironmentVariable($Name, $null, $Level)
                Register-EnvironmentChange -Module $Module
            }
            $ret.changed = $true
        }

        $ret
    }
}

Function Register-EnvironmentChange {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Ansible.Basic.AnsibleModule]
        $Module
    )

    Add-CSharpType -AnsibleModule $Module -References @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;

namespace Ansible.Windows.WinEnvironment
{
    public class Native
    {
        [DllImport("User32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern IntPtr SendMessageTimeoutW(
            IntPtr hWnd,
            uint Msg,
            UIntPtr wParam,
            string lParam,
            SendMessageFlags fuFlags,
            uint uTimeout,
            out UIntPtr lpdwResult);

        public static UIntPtr SendMessageTimeout(IntPtr windowHandle, uint msg, UIntPtr wParam, string lParam,
            SendMessageFlags flags, uint timeout)
        {
            UIntPtr result = UIntPtr.Zero;
            IntPtr funcRes = SendMessageTimeoutW(windowHandle, msg, wParam, lParam, flags, timeout, out result);
            if (funcRes == IntPtr.Zero)
                throw new Win32Exception();

            return result;
        }
    }

    [Flags()]
    public enum SendMessageFlags : uint
    {
        Normal = 0x0000,
        Block = 0x0001,
        AbortIfHung = 0x0002,
        NoTimeoutIfNotHung = 0x0008,
        ErrorOnExit = 0x0020,
    }
}
'@

    $HWND_BROADCAST = [IntPtr]0xFFFF
    $WM_SETTINGCHANGE = 0x001A
    $null = [Ansible.Windows.WinEnvironment.Native]::SendMessageTimeout(
        $HWND_BROADCAST,
        $WM_SETTINGCHANGE,
        [UIntPtr]::Zero,
        "Environment",
        "AbortIfHung",
        5000)
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
    }
    elseif ($state -eq "present" -and (-not $value)) {
        $module.FailJson("When state=present, value must be defined and not an empty string, if you wish to remove the envvar, set state=absent")
    }

    $status = $kv | Set-EnvironmentVariableState -Module $module -Level $level -State $state -WhatIf:$($module.CheckMode)

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
