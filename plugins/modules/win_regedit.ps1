#!powershell

# Copyright: (c) 2015, Adam Keech <akeech@chathamfinancial.com>
# Copyright: (c) 2015, Josh Ludwig <jludwig@chathamfinancial.com>
# Copyright: (c) 2017, Jordan Borean <jborean93@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Module Ansible.ModuleUtils.AddType
#Requires -Module Ansible.ModuleUtils.PrivilegeUtil

$spec = @{
    options = @{
        path = @{ type = 'str'; required = $true; aliases = 'key' }
        name = @{ type = 'str'; aliases = 'entry', 'value' }
        data = @{ type = 'raw' }
        type = @{
            type = 'str'
            default = 'string'
            choices = 'none', 'binary', 'dword', 'expandstring', 'multistring', 'string', 'qword'
            aliases = 'datatype'
        }
        state = @{ type = 'str'; default = 'present'; choices = 'present', 'absent' }
        delete_key = @{ type = 'bool'; default = $true }
        hive = @{ type = 'path' }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$path = $module.Params.path
$name = $module.Params.name
$data = $module.Params.data
$type = $module.Params.type
$state = $module.Params.state
$delete_key = $module.Params.delete_key
$hive = $module.Params.hive

$module.Result.data_changed = $false
$module.Result.data_type_changed = $false

$module.Diff.before = ""
$module.Diff.after = ""

$registry_util = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace Ansible.WinRegedit
{
    internal class NativeMethods
    {
        [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
        public static extern int RegLoadKeyW(
            UInt32 hKey,
            string lpSubKey,
            string lpFile);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode)]
        public static extern int RegUnLoadKeyW(
            UInt32 hKey,
            string lpSubKey);
    }

    public class Win32Exception : System.ComponentModel.Win32Exception
    {
        private string _msg;
        public Win32Exception(string message) : this(Marshal.GetLastWin32Error(), message) { }
        public Win32Exception(int errorCode, string message) : base(errorCode)
        {
            _msg = String.Format("{0} ({1}, Win32ErrorCode {2})", message, base.Message, errorCode);
        }
        public override string Message { get { return _msg; } }
        public static explicit operator Win32Exception(string message) { return new Win32Exception(message); }
    }

    public class Hive : IDisposable
    {
        private const UInt32 SCOPE = 0x80000002;  // HKLM
        private string hiveKey;
        private bool loaded = false;

        public Hive(string hiveKey, string hivePath)
        {
            this.hiveKey = hiveKey;
            int ret = NativeMethods.RegLoadKeyW(SCOPE, hiveKey, hivePath);
            if (ret != 0)
                throw new Win32Exception(ret, String.Format("Failed to load registry hive at {0}", hivePath));
            loaded = true;
        }

        public static void UnloadHive(string hiveKey)
        {
            int ret = NativeMethods.RegUnLoadKeyW(SCOPE, hiveKey);
            if (ret != 0)
                throw new Win32Exception(ret, String.Format("Failed to unload registry hive at {0}", hiveKey));
        }

        public void Dispose()
        {
            if (loaded)
            {
                // Make sure the garbage collector disposes all unused handles and waits until it is complete
                GC.Collect();
                GC.WaitForPendingFinalizers();

                UnloadHive(hiveKey);
                loaded = false;
            }
            GC.SuppressFinalize(this);
        }
        ~Hive() { this.Dispose(); }
    }
}
'@

# fire a warning if the property name isn't specified, the (Default) key ($null) can only be a string
if ($null -eq $name -and $type -ne "string") {
    $module.Warn("the data type when name is not specified can only be 'string', the type has automatically been converted")
    $type = "string"
}

# Check that the registry path is in PSDrive format: HKCC, HKCR, HKCU, HKLM, HKU
if ($path -notmatch "^HK(CC|CR|CU|LM|U):\\") {
    $module.FailJson("path: $path is not a valid powershell path, see module documentation for examples.")
}
$registry_path = (Split-Path -Path $path -NoQualifier).Substring(1)  # removes the hive: and leading \

# Simplified version of Convert-HexStringToByteArray from
# https://cyber-defense.sans.org/blog/2010/02/11/powershell-byte-array-hex-convert
# Expects a hex in the format you get when you run reg.exe export,
# and converts to a byte array so powershell can modify binary registry entries
# import format is like 'hex:be,ef,be,ef,be,ef,be,ef,be,ef'
Function Convert-RegExportHexStringToByteArray($string) {
    # Remove 'hex:' from the front of the string if present
    $string = $string.ToLower() -replace '^hex\:', ''

    # Remove whitespace and any other non-hex crud.
    $string = $string -replace '[^a-f0-9\\,x\-\:]', ''

    # Turn commas into colons
    $string = $string -replace ',', ':'

    # Maybe there's nothing left over to convert...
    if ($string.Length -eq 0) {
        return , @()
    }

    # Split string with or without colon delimiters.
    if ($string.Length -eq 1) {
        return , @([System.Convert]::ToByte($string, 16))
    }
    elseif (($string.Length % 2 -eq 0) -and ($string.IndexOf(":") -eq -1)) {
        return , @($string -split '([a-f0-9]{2})' | ForEach-Object { if ($_) { [System.Convert]::ToByte($_, 16) } })
    }
    elseif ($string.IndexOf(":") -ne -1) {
        return , @($string -split ':+' | ForEach-Object { [System.Convert]::ToByte($_, 16) })
    }
    else {
        return , @()
    }
}

Function Compare-RegistryProperty($existing, $new) {
    # Outputs $true if the property values don't match
    if ($existing -is [Array]) {
        (Compare-Object -ReferenceObject $existing -DifferenceObject $new -SyncWindow 0).Length -ne 0
    }
    else {
        $existing -cne $new
    }
}

Function Get-DiffValue {
    param(
        [Parameter(Mandatory = $true)][Object]$Type,
        [Parameter(Mandatory = $true)][Object]$Value
    )

    $diff = @{ type = $Type.ToString(); value = $Value }

    $enum = [Microsoft.Win32.RegistryValueKind]
    if ($Type -in @($enum::Binary, $enum::None)) {
        $diff.value = [System.Collections.Generic.List`1[String]]@()
        foreach ($dec_value in $Value) {
            $diff.value.Add("0x{0:x2}" -f $dec_value)
        }
    }
    elseif ($Type -eq $enum::DWord) {
        $diff.value = "0x{0:x8}" -f $Value
    }
    elseif ($Type -eq $enum::QWord) {
        $diff.value = "0x{0:x16}" -f $Value
    }

    return $diff
}

Function Set-StateAbsent {
    param(
        # Used for diffs and exception messages to match up against Ansible input
        [Parameter(Mandatory = $true)][String]$PrintPath,
        [Parameter(Mandatory = $true)][Microsoft.Win32.RegistryKey]$Hive,
        [Parameter(Mandatory = $true)][String]$Path,
        [Parameter(Mandatory = $true)]$Module,
        [String]$Name,
        [Switch]$DeleteKey
    )

    $key = $Hive.OpenSubKey($Path, $true)
    if ($null -eq $key) {
        # Key does not exist, no need to delete anything
        return
    }

    try {
        if ($DeleteKey -and -not $Name) {
            # delete_key=yes is set and name is null/empty, so delete the entire key
            $key.Dispose()
            $key = $null
            if (-not $Module.CheckMode) {
                try {
                    $Hive.DeleteSubKeyTree($Path, $false)
                }
                catch {
                    $Module.FailJson("failed to delete registry key at $($PrintPath): $($_.Exception.Message)", $_)
                }
            }
            $Module.Result.changed = $true

            $Module.Diff.before = @{$PrintPath = @{} }
            $Module.Diff.after = @{}
        }
        else {
            # delete_key=no or name is not null/empty, delete the property not the full key
            $property = $key.GetValue($Name)
            if ($null -eq $property) {
                # property does not exist
                return
            }
            $property_type = $key.GetValueKind($Name)  # used for the diff

            if (-not $Module.CheckMode) {
                try {
                    $key.DeleteValue($Name)
                }
                catch {
                    $Module.FailJson("failed to delete registry property '$Name' at $($PrintPath): $($_.Exception.Message)", $_)
                }
            }

            $Module.Result.changed = $true
            $diff_value = Get-DiffValue -Type $property_type -Value $property
            $Module.Diff.before = @{ $PrintPath = @{ $Name = $diff_value } }
            $Module.Diff.after = @{ $PrintPath = @{} }
        }
    }
    finally {
        if ($key) {
            $key.Dispose()
        }
    }
}

Function Set-StatePresent {
    param(
        [Parameter(Mandatory = $true)][String]$PrintPath,
        [Parameter(Mandatory = $true)][Microsoft.Win32.RegistryKey]$Hive,
        [Parameter(Mandatory = $true)][String]$Path,
        [Parameter(Mandatory = $true)]$Module,
        [String]$Name,
        [Object]$Data,
        [Object]$Type
    )

    $key = $Hive.OpenSubKey($Path, $true)
    try {
        if ($null -eq $key) {
            # the key does not exist, create it so the next steps work
            if (-not $Module.CheckMode) {
                try {
                    $key = $Hive.CreateSubKey($Path)
                }
                catch {
                    $Module.FailJson("failed to create registry key at $($PrintPath): $($_.Exception.Message)", $_)
                }
            }
            $Module.Result.changed = $true

            $Module.Diff.before = @{}
            $Module.Diff.after = @{$PrintPath = @{} }
        }
        else {
            # Make sure the diff is in an expected state for the key
            $Module.Diff.before = @{$PrintPath = @{} }
            $Module.Diff.after = @{$PrintPath = @{} }
        }

        if ($null -eq $key -or $null -eq $Data) {
            # Check mode and key was created above, we cannot do any more work, or $Data is $null which happens when
            # we create a new key but haven't explicitly set the data
            return
        }

        $property = $key.GetValue($Name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        if ($null -ne $property) {
            # property exists, need to compare the values and type
            $existing_type = $key.GetValueKind($name)
            $change_value = $false

            if ($Type -ne $existing_type) {
                $change_value = $true
                $Module.Result.data_type_changed = $true
                $data_mismatch = Compare-RegistryProperty -existing $property -new $Data
                if ($data_mismatch) {
                    $Module.Result.data_changed = $true
                }
            }
            else {
                $data_mismatch = Compare-RegistryProperty -existing $property -new $Data
                if ($data_mismatch) {
                    $change_value = $true
                    $Module.Result.data_changed = $true
                }
            }

            if ($change_value) {
                if (-not $Module.CheckMode) {
                    try {
                        $key.SetValue($Name, $Data, $Type)
                    }
                    catch {
                        $Module.FailJson("failed to change registry property '$Name' at $($PrintPath): $($_.Exception.Message)", $_)
                    }
                }
                $Module.Result.changed = $true

                $Module.Diff.before.$PrintPath.$Name = Get-DiffValue -Type $existing_type -Value $property
                $Module.Diff.after.$PrintPath.$Name = Get-DiffValue -Type $Type -Value $Data
            }
            else {
                $diff_value = Get-DiffValue -Type $existing_type -Value $property
                $Module.Diff.before.$PrintPath.$Name = $diff_value
                $Module.Diff.after.$PrintPath.$Name = $diff_value
            }
        }
        else {
            # property doesn't exist just create a new one
            if (-not $Module.CheckMode) {
                try {
                    $key.SetValue($Name, $Data, $Type)
                }
                catch {
                    $Module.FailJson("failed to create registry property '$Name' at $($PrintPath): $($_.Exception.Message)", $_)
                }
            }
            $Module.Result.changed = $true

            $Module.Diff.after.$PrintPath.$Name = Get-DiffValue -Type $Type -Value $Data
        }
    }
    finally {
        if ($key) {
            $key.Dispose()
        }
    }
}

# convert property names "" to $null as "" refers to (Default)
if ($name -eq "") {
    $name = $null
}

# convert the data to the required format
if ($type -in @("binary", "none")) {
    if ($null -eq $data) {
        $data = ""
    }

    # convert the data from string to byte array if in hex: format
    if ($data -is [String]) {
        $data = [byte[]](Convert-RegExportHexStringToByteArray -string $data)
    }
    elseif ($data -is [Int]) {
        if ($data -gt 255) {
            $msg = "cannot convert binary data '$data' to byte array, please specify this value as a yaml byte array or a comma separated hex value string"
            $module.FailJson($msg)
        }
        $data = [byte[]]@([byte]$data)
    }
    elseif ($data -is [Array]) {
        $data = [byte[]]$data
    }
}
elseif ($type -in @("dword", "qword")) {
    # dword's and dword's don't allow null values, set to 0
    if ($null -eq $data) {
        $data = 0
    }

    $too_large = $false
    if ($data -is [String]) {
        # if the data is a string we need to convert it to an unsigned int64
        # it needs to be unsigned as Ansible passes in an unsigned value while
        # powershell uses a signed data type. The value will then be converted
        # below
        $data = [UInt64]$data
    }
    elseif ($data -is [Decimal] -or $data -is [Single] -or $data -is [Float]) {
        if ($data % 1 -ne 0) {
            $module.FailJson("data '$data' cannot be a decimal or float value with a remainder when type is dword or qword")
        }
        elseif ($data -gt [UInt64]::MaxValue) {
            $too_large = $true
        }
        else {
            $data = [UInt64]$data
        }
    }

    if ($type -eq "dword") {
        if ($too_large -or $data -gt [UInt32]::MaxValue) {
            $module.FailJson("data cannot be larger than 0xffffffff when type is dword")
        }
        elseif ($data -gt [Int32]::MaxValue) {
            # when dealing with larger int32 (> 2147483647 or 0x7FFFFFFF) powershell
            # automatically converts it to a signed int64. We need to convert this to
            # signed int32 by parsing the hex string value.
            $data = "0x$("{0:x}" -f $data)"
        }
        $data = [Int32]$data
    }
    else {
        if ($too_large -or $data -gt [UInt64]::MaxValue) {
            $module.FailJson("data cannot be larger than 0xffffffffffffffff when type is qword")
        }
        elseif ($data -gt [Int64]::MaxValue) {
            $data = "0x$("{0:x}" -f $data)"
        }
        $data = [Int64]$data
    }
}
elseif ($type -in @("string", "expandstring") -and $name) {
    # a null string or expandstring must be empty quotes
    # Only do this if $name has been defined (not the default key)
    if ($null -eq $data) {
        $data = ""
    }
}
elseif ($type -eq "multistring") {
    # convert the data for a multistring to a String[] array
    if ($null -eq $data) {
        [string[]]$data = @()
    }
    elseif ($data -is [System.Collections.IList]) {
        [string[]]$data = foreach ($entry in $data) {
            $entry.ToString([CultureInfo]::InvariantCulture)
        }
    }
    else {
        [string[]]$data = @($data.ToString([CultureInfo]::InvariantCulture))
    }
}

# convert the type string to the .NET class
$type = [System.Enum]::Parse([Microsoft.Win32.RegistryValueKind], $type, $true)

# Cannot get field from switch as it causes issues with PSScriptAnalyzer parsing the module on linux
$registry_hive = switch (Split-Path -Path $path -Qualifier) {
    "HKCR:" { 'ClassesRoot' }
    "HKCC:" { 'CurrentConfig' }
    "HKCU:" { 'CurrentUser' }
    "HKLM:" { 'LocalMachine' }
    "HKU:" { 'Users' }
}
$registry_hive = [Microsoft.Win32.Registry]::"$registry_hive"
$loaded_hive = $null
try {
    if ($hive) {
        if (-not (Test-Path -LiteralPath $hive)) {
            $module.FailJson("hive at path '$hive' is not valid or accessible, cannot load hive")
        }

        Add-CSharpType -References $registry_util -AnsibleModule $module

        try {
            Set-AnsiblePrivilege -Name SeBackupPrivilege -Value $true
            Set-AnsiblePrivilege -Name SeRestorePrivilege -Value $true
        }
        catch [System.ComponentModel.Win32Exception] {
            $module.FailJson("failed to enable SeBackupPrivilege and SeRestorePrivilege for the current process: $($_.Exception.Message)", $_)
        }

        if (Test-Path -LiteralPath HKLM:\ANSIBLE) {
            $module.Warn("hive already loaded at HKLM:\ANSIBLE, had to unload hive for win_regedit to continue")
            try {
                [Ansible.WinRegedit.Hive]::UnloadHive("ANSIBLE")
            }
            catch [System.ComponentModel.Win32Exception] {
                $module.FailJson("failed to unload registry hive HKLM:\ANSIBLE from $($hive): $($_.Exception.Message)", $_)
            }
        }

        try {
            $loaded_hive = New-Object -TypeName Ansible.WinRegedit.Hive -ArgumentList "ANSIBLE", $hive
        }
        catch [System.ComponentModel.Win32Exception] {
            $module.FailJson("failed to load registry hive from '$hive' to HKLM:\ANSIBLE: $($_.Exception.Message)", $_)
        }
    }

    $set_params = @{
        PrintPath = $path
        Hive = $registry_hive
        Path = $registry_path
        Module = $module
        Name = $name
    }
    if ($state -eq "present") {
        Set-StatePresent @set_params -Data $data -Type $type
    }
    else {
        Set-StateAbsent @set_params -DeleteKey:$delete_key
    }
}
finally {
    $registry_hive.Dispose()
    if ($loaded_hive) {
        $loaded_hive.Dispose()
    }
}

$module.ExitJson()
