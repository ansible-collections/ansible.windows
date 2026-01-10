#!powershell

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell Ansible.ModuleUtils.AddType

$spec = @{
    options = @{
        name = @{ type = "str"; default = "PATH" }
        elements = @{ type = "list"; elements = "str"; required = $true }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
        scope = @{ type = "str"; choices = "machine", "user"; default = "machine" }
        insert_at = @{ type = "str"; choices = "start", "end"; default = "end" }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$var_name = $module.Params.name
$elements = $module.Params.elements
$state = $module.Params.state
$scope = $module.Params.scope
$insert_at = $module.Params.insert_at

$check_mode = $module.CheckMode

$system_path = "System\CurrentControlSet\Control\Session Manager\Environment"
$user_path = "Environment"

# list/arraylist methods don't allow IEqualityComparer override for case/backslash/quote-insensitivity, roll our own search
Function Get-IndexOfPathElement ($list, [string]$value) {
    $idx = 0
    $value = $value.Trim('"').Trim('\')
    ForEach ($el in $list) {
        If ([string]$el.Trim('"').Trim('\') -ieq $value) {
            return $idx
        }

        $idx++
    }

    return -1
}

# alters list in place, returns true if at least one element was added
Function Add-Element ($existing_elements, $elements_to_add, $insert_at) {
    $last_idx = -1
    $insert_anchor_idx = -1
    $changed = $false

    # interate to find the first anchor index for inserting of new element
    # only needed for insert_at=start
    For ($i = 0; $i -lt $elements_to_add.Count; $i++) {
        $el = $elements_to_add[$i]
        $idx = Get-IndexOfPathElement $existing_elements $el
        If ($idx -eq -1) {
            $insert_anchor_idx = $i
            break
        }
    }
    If (($insert_at -eq "start") -and ($insert_anchor_idx -gt -1)) {
        If ($insert_anchor_idx -gt -1) {
            # iterate left of anchor to insert defined elements before it
            # to maintain relative order
            For ($i = $insert_anchor_idx - 1; $i -ge 0; $i--) {
                $el = $elements_to_add[$i]
                $idx = Get-IndexOfPathElement $existing_elements $el
                If ($idx -ne -1) {
                    $existing_elements.RemoveAt($idx) | Out-Null
                    $existing_elements.Insert($insert_anchor_idx, $el) | Out-Null
                    $insert_anchor_idx--;
                    $changed = $true
                }
            }
            # iterate right of anchor to insert defined elements after it
            # to maintain relative order
            For ($i = $insert_anchor_idx; $i -lt $elements_to_add.Count; $i++) {
                $el = $elements_to_add[$i]
                $idx = Get-IndexOfPathElement $existing_elements $el
                # if new element then add and reorder in place
                If ($idx -eq -1) {
                    $existing_elements.Insert($insert_anchor_idx, $el) | Out-Null
                    $insert_anchor_idx++;
                    $changed = $true
                }
                ElseIf ($idx -ne $insert_anchor_idx) {
                    # element exists, but a relative reorder is needed
                    $existing_elements.RemoveAt($idx) | Out-Null
                    $existing_elements.Insert($insert_anchor_idx, $el) | Out-Null
                    $insert_anchor_idx++;
                    $changed = $true
                }
                Else {
                    $insert_anchor_idx++;
                }
            }
        }
        return $changed
    }
    Else {
        ForEach ($el in $elements_to_add) {
            $idx = Get-IndexOfPathElement $existing_elements $el

            # add missing elements at the end
            If ($idx -eq -1) {
                $last_idx = $existing_elements.Add($el)
                $changed = $true
            }
            ElseIf ($idx -lt $last_idx) {
                $existing_elements.RemoveAt($idx) | Out-Null
                $existing_elements.Add($el) | Out-Null
                $last_idx = $existing_elements.Count - 1
                $changed = $true
            }
            Else {
                $last_idx = $idx
            }
        }
        return $changed
    }
}

# alters list in place, returns true if at least one element was removed
Function Remove-Element ($existing_elements, $elements_to_remove) {
    $count = $existing_elements.Count

    ForEach ($el in $elements_to_remove) {
        $idx = Get-IndexOfPathElement $existing_elements $el
        $module.Result.removed_idx = $idx
        If ($idx -gt -1) {
            $existing_elements.RemoveAt($idx)
        }
    }

    return $count -ne $existing_elements.Count
}

# PS registry provider doesn't allow access to unexpanded REG_EXPAND_SZ; fall back to .NET
Function Get-RawPathVar ($scope) {
    If ($scope -eq "user") {
        $env_key = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey($user_path)
    }
    ElseIf ($scope -eq "machine") {
        $env_key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey($system_path)
    }

    try {
        return $env_key.GetValue($var_name, "", [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
    }
    finally {
        $env_key.Dispose()
    }
}

Function Set-RawPathVar($path_value, $scope) {
    If ($scope -eq "user") {
        $var_path = "HKCU:\" + $user_path
    }
    ElseIf ($scope -eq "machine") {
        $var_path = "HKLM:\" + $system_path
    }

    Set-ItemProperty $var_path -Name $var_name -Value $path_value -Type ExpandString | Out-Null

    return $path_value
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

namespace Ansible.Windows.WinPath
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
    $null = [Ansible.Windows.WinPath.Native]::SendMessageTimeout(
        $HWND_BROADCAST,
        $WM_SETTINGCHANGE,
        [UIntPtr]::Zero,
        "Environment",
        "AbortIfHung",
        5000)
}

$current_value = Get-RawPathVar $scope
$module.Result.path_value = $current_value

# TODO: test case-canonicalization on wacky unicode values (eg turkish i)
# TODO: detect and warn/fail on unparseable path? (eg, unbalanced quotes, invalid path chars)
# TODO: detect and warn/fail if system path and Powershell isn't on it?

$existing_elements = New-Object System.Collections.ArrayList

# split on semicolons, accounting for quoted values with embedded semicolons (which may or may not be wrapped in whitespace)
$pathsplit_re = [regex] '((?<q>\s*"[^"]+"\s*)|(?<q>[^;]+))(;$|$|;)'

ForEach ($m in $pathsplit_re.Matches($current_value)) {
    $existing_elements.Add($m.Groups['q'].Value) | Out-Null
}

If ($state -eq "absent") {
    $module.Result.changed = Remove-Element $existing_elements $elements
}
ElseIf ($state -eq "present") {
    $module.Result.changed = Add-Element -existing_elements $existing_elements -elements_to_add $elements -insert_at $insert_at
}

# calculate the new path value from the existing elements
$path_value = [String]::Join(";", $existing_elements.ToArray())
$module.Result.path_value = $path_value

If ($module.Result.changed -and -not $check_mode) {
    Set-RawPathVar $path_value $scope | Out-Null
    Register-EnvironmentChange -Module $module
}

$module.ExitJson()
