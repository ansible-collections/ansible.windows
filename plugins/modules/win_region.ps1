#!powershell

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -PowerShell Ansible.ModuleUtils.AddType
#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        location = @{ type = "str" }
        format = @{ type = "str" }
        unicode_language = @{ type = "str" }
        copy_settings = @{ type = "bool"; default = $false }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$check_mode = $module.CheckMode

$location = $module.Params.location
$format = $module.Params.format
$unicode_language = $module.Params.unicode_language
$copy_settings = $module.Params.copy_settings

$module.Result.restart_required = $false

# This is used to get the format values based on the LCType enum based through. When running Vista/7/2008/200R2
Add-CSharpType -AnsibleModule $module -References @'
using System;
using System.Text;
using System.Runtime.InteropServices;
using System.ComponentModel;

namespace Ansible.WinRegion {

    public class NativeMethods
    {
        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern int GetLocaleInfoEx(
            String lpLocaleName,
            UInt32 LCType,
            StringBuilder lpLCData,
            int cchData);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern int GetSystemDefaultLocaleName(
            IntPtr lpLocaleName,
            int cchLocaleName);

        [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern int GetUserDefaultLocaleName(
            IntPtr lpLocaleName,
            int cchLocaleName);

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
        private const UInt32 SCOPE = 0x80000003;  // HKU
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

    public class LocaleHelper {
        private String Locale;

        public LocaleHelper(String locale) {
            Locale = locale;
        }

        public String GetValueFromType(UInt32 LCType) {
            StringBuilder data = new StringBuilder(500);
            int result = NativeMethods.GetLocaleInfoEx(Locale, LCType, data, 500);
            if (result == 0)
                throw new Win32Exception("Error getting locale info with legacy method");

            return data.ToString();
        }
    }
}
'@


Function Get-LastWin32ExceptionMessage {
    param([int]$ErrorCode)
    $exp = New-Object -TypeName System.ComponentModel.Win32Exception -ArgumentList $ErrorCode
    $exp_msg = "{0} (Win32 ErrorCode {1} - 0x{1:X8})" -f $exp.Message, $ErrorCode
    return $exp_msg
}

Function Get-SystemLocaleName {
    $max_length = 85  # LOCALE_NAME_MAX_LENGTH
    $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($max_length)

    try {
        $res = [Ansible.WinRegion.NativeMethods]::GetSystemDefaultLocaleName($ptr, $max_length)

        if ($res -eq 0) {
            $err_code = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            $msg = Get-LastWin32ExceptionMessage -Error $err_code
            $module.FailJson("Failed to get system locale: $msg")
        }

        $system_locale = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
    }

    return $system_locale
}

Function Get-UserLocaleName {
    $max_length = 85  # LOCALE_NAME_MAX_LENGTH
    $ptr = [System.Runtime.InteropServices.Marshal]::AllocHGlobal($max_length)

    try {
        $res = [Ansible.WinRegion.NativeMethods]::GetUserDefaultLocaleName($ptr, $max_length)

        if ($res -eq 0) {
            $err_code = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error()
            $msg = Get-LastWin32ExceptionMessage -Error $err_code
            $module.FailJson("Failed to get user locale: $msg")
        }

        $user_locale = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
    } finally {
        [System.Runtime.InteropServices.Marshal]::FreeHGlobal($ptr)
    }

    return $user_locale
}

Function Get-ValidGeoIds($cultures) {
   $geo_ids = @()
   foreach($culture in $cultures) {
       try {
           $geo_id = [System.Globalization.RegionInfo]$culture.Name
           $geo_ids += $geo_id.GeoId
       } catch {}
   }
   $geo_ids
}

Function Test-RegistryProperty($reg_key, $property) {
    $type = Get-ItemProperty -LiteralPath $reg_key -Name $property -ErrorAction SilentlyContinue
    if ($null -eq $type) {
        $false
    } else {
        $true
    }
}

Function Copy-RegistryKey($source, $target) {
    # Using Copy-Item -Recurse is giving me weird results, doing it recursively
    Copy-Item -LiteralPath $source -Destination $target -WhatIf:$check_mode

    foreach($key in Get-ChildItem -LiteralPath $source) {
        $sourceKey = "$source\$($key.PSChildName)"
        $targetKey = (Get-Item -LiteralPath $source).PSChildName
        Copy-RegistryKey -source "$sourceKey" -target "$target\$targetKey"
    }
}

Function Set-UserLocale($culture) {
    $reg_key = 'HKCU:\Control Panel\International'

    $lookup = New-Object Ansible.WinRegion.LocaleHelper($culture)
    # hex values are from http://www.pinvoke.net/default.aspx/kernel32/GetLocaleInfoEx.html
    $wanted_values = @{
        Locale = '{0:x8}' -f ([System.Globalization.CultureInfo]$culture).LCID
        LocaleName = $culture
        s1159 = $lookup.GetValueFromType(0x00000028)
        s2359 = $lookup.GetValueFromType(0x00000029)
        sCountry = $lookup.GetValueFromType(0x00000006)
        sCurrency = $lookup.GetValueFromType(0x00000014)
        sDate = $lookup.GetValueFromType(0x0000001D)
        sDecimal = $lookup.GetValueFromType(0x0000000E)
        sGrouping = $lookup.GetValueFromType(0x00000010)
        sLanguage = $lookup.GetValueFromType(0x00000003) # LOCALE_ABBREVLANGNAME
        sList = $lookup.GetValueFromType(0x0000000C)
        sLongDate = $lookup.GetValueFromType(0x00000020)
        sMonDecimalSep = $lookup.GetValueFromType(0x00000016)
        sMonGrouping = $lookup.GetValueFromType(0x00000018)
        sMonThousandSep = $lookup.GetValueFromType(0x00000017)
        sNativeDigits = $lookup.GetValueFromType(0x00000013)
        sNegativeSign = $lookup.GetValueFromType(0x00000051)
        sPositiveSign = $lookup.GetValueFromType(0x00000050)
        sShortDate = $lookup.GetValueFromType(0x0000001F)
        sThousand = $lookup.GetValueFromType(0x0000000F)
        sTime = $lookup.GetValueFromType(0x0000001E)
        sTimeFormat = $lookup.GetValueFromType(0x00001003)
        sYearMonth = $lookup.GetValueFromType(0x00001006)
        iCalendarType = $lookup.GetValueFromType(0x00001009)
        iCountry = $lookup.GetValueFromType(0x00000005)
        iCurrDigits = $lookup.GetValueFromType(0x00000019)
        iCurrency = $lookup.GetValueFromType(0x0000001B)
        iDate = $lookup.GetValueFromType(0x00000021)
        iDigits = $lookup.GetValueFromType(0x00000011)
        NumShape = $lookup.GetValueFromType(0x00001014) # LOCALE_IDIGITSUBSTITUTION
        iFirstDayOfWeek = $lookup.GetValueFromType(0x0000100C)
        iFirstWeekOfYear = $lookup.GetValueFromType(0x0000100D)
        iLZero = $lookup.GetValueFromType(0x00000012)
        iMeasure = $lookup.GetValueFromType(0x0000000D)
        iNegCurr = $lookup.GetValueFromType(0x0000001C)
        iNegNumber = $lookup.GetValueFromType(0x00001010)
        iPaperSize = $lookup.GetValueFromType(0x0000100A)
        iTime = $lookup.GetValueFromType(0x00000023)
        iTimePrefix = $lookup.GetValueFromType(0x00001005)
        iTLZero = $lookup.GetValueFromType(0x00000025)
    }

    if (Test-RegistryProperty -reg_key $reg_key -property 'sShortTime') {
        # sShortTime was added after Vista, will check anyway and add in the value if it exists
        $wanted_values.sShortTime = $lookup.GetValueFromType(0x00000079)
    }

    $properties = Get-ItemProperty -LiteralPath $reg_key
    foreach($property in $properties.PSObject.Properties) {
        if (Test-RegistryProperty -reg_key $reg_key -property $property.Name) {
            $name = $property.Name
            $old_value = $property.Value
            $new_value = $wanted_values.$name

            if ($new_value -ne $old_value) {
                Set-ItemProperty -LiteralPath $reg_key -Name $name -Value $new_value -WhatIf:$check_mode
                $module.Result.changed = $true
            }
        }
    }
}

Function Set-SystemLocaleLegacy($unicode_language) {
    # For when Get/Set-WinSystemLocale is not available (Pre Windows 8 and Server 2012)
    $current_language_value = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\Language').Default
    $wanted_language_value = '{0:x4}' -f ([System.Globalization.CultureInfo]$unicode_language).LCID
    if ($current_language_value -ne $wanted_language_value) {
        Set-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\Language' -Name 'Default' -Value $wanted_language_value -WhatIf:$check_mode
        $module.Result.changed = $true
        $module.Result.restart_required = $true
    }

    # This reads from the non registry (Default) key, the extra prop called (Default) see below for more details
    $current_locale_value = (Get-ItemProperty -LiteralPath 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\Locale')."(Default)"
    $wanted_locale_value = '{0:x8}' -f ([System.Globalization.CultureInfo]$unicode_language).LCID
    if ($current_locale_value -ne $wanted_locale_value) {
        # Need to use .net to write property value, Locale has 2 (Default) properties
        # 1: The actual (Default) property, we don't want to change Set-ItemProperty writes to this value when using (Default)
        # 2: A property called (Default), this is what we want to change and only .net SetValue can do this one
        if (-not $check_mode) {
            $hive = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey("LocalMachine", $env:COMPUTERNAME)
            $key = $hive.OpenSubKey("SYSTEM\CurrentControlSet\Control\Nls\Locale", $true)
            $key.SetValue("(Default)", $wanted_locale_value, [Microsoft.Win32.RegistryValueKind]::String)
        }
        $module.Result.changed = $true
        $module.Result.restart_required = $true
    }

    $codepage_path = 'HKLM:\SYSTEM\CurrentControlSet\Control\Nls\CodePage'
    $current_codepage_info = Get-ItemProperty -LiteralPath $codepage_path
    $wanted_codepage_info = ([System.Globalization.CultureInfo]::GetCultureInfo($unicode_language)).TextInfo

    $current_a_cp = $current_codepage_info.ACP
    $current_oem_cp = $current_codepage_info.OEMCP
    $current_mac_cp = $current_codepage_info.MACCP
    $wanted_a_cp = $wanted_codepage_info.ANSICodePage
    $wanted_oem_cp = $wanted_codepage_info.OEMCodePage
    $wanted_mac_cp = $wanted_codepage_info.MacCodePage

    if ($current_a_cp -ne $wanted_a_cp) {
        Set-ItemProperty -LiteralPath $codepage_path -Name 'ACP' -Value $wanted_a_cp -WhatIf:$check_mode
        $module.Result.changed = $true
        $module.Result.restart_required = $true
    }
    if ($current_oem_cp -ne $wanted_oem_cp) {
        Set-ItemProperty -LiteralPath $codepage_path -Name 'OEMCP' -Value $wanted_oem_cp -WhatIf:$check_mode
        $module.Result.changed = $true
        $module.Result.restart_required = $true
    }
    if ($current_mac_cp -ne $wanted_mac_cp) {
        Set-ItemProperty -LiteralPath $codepage_path -Name 'MACCP' -Value $wanted_mac_cp -WhatIf:$check_mode
        $module.Result.changed = $true
        $module.Result.restart_required = $true
    }
}

if ($null -eq $format -and $null -eq $location -and $null -eq $unicode_language) {
    $module.FailJson("An argument for 'format', 'location' or 'unicode_language' needs to be supplied")
} else {
    $valid_cultures = [System.Globalization.CultureInfo]::GetCultures('InstalledWin32Cultures')
    $valid_geoids = Get-ValidGeoIds -cultures $valid_cultures

    if ($null -ne $location) {
        if ($valid_geoids -notcontains $location) {
            $module.FailJson("The argument location '$location' does not contain a valid Geo ID")
        }
    }

    if ($null -ne $format) {
        if ($valid_cultures.Name -notcontains $format) {
            $module.FailJson("The argument format '$format' does not contain a valid Culture Name")
        }
    }

    if ($null -ne $unicode_language) {
        if ($valid_cultures.Name -notcontains $unicode_language) {
            $module.FailJson("The argument unicode_language '$unicode_language' does not contain a valid Culture Name")
        }
    }
}

if ($null -ne $location) {
    # Get-WinHomeLocation was only added in Server 2012 and above
    # Use legacy option if older
    if (Get-Command 'Get-WinHomeLocation' -ErrorAction SilentlyContinue) {
        $current_location = (Get-WinHomeLocation).GeoId
        if ($current_location -ne $location) {
            if (-not $check_mode) {
                Set-WinHomeLocation -GeoId $location
            }
            $module.Result.changed = $true
        }
    } else {
        $current_location = (Get-ItemProperty -LiteralPath 'HKCU:\Control Panel\International\Geo').Nation
        if ($current_location -ne $location) {
            Set-ItemProperty -LiteralPath 'HKCU:\Control Panel\International\Geo' -Name 'Nation' -Value $location -WhatIf:$check_mode
            $module.Result.changed = $true
        }
    }
}

if ($null -ne $format) {
    # Cannot use Get/Set-Culture as that fails to get and set the culture when running in the PSRP runspace.
    $current_format = Get-UserLocaleName
    if ($current_format -ne $format) {
        Set-UserLocale -culture $format
        $module.Result.changed = $true
    }
}

if ($null -ne $unicode_language) {
    # Get/Set-WinSystemLocale was only added in Server 2012 and above, use legacy option if older
    if (Get-Command 'Get-WinSystemLocale' -ErrorAction SilentlyContinue) {
        $current_unicode_language = Get-SystemLocaleName
        if ($current_unicode_language -ne $unicode_language) {
            if (-not $check_mode) {
                Set-WinSystemLocale -SystemLocale $unicode_language
            }
            $module.Result.changed = $true
            $module.Result.restart_required = $true
        }
    } else {
        Set-SystemLocaleLegacy -unicode_language $unicode_language
    }
}

if ($copy_settings -eq $true -and $module.Result.changed -eq $true) {
    if (-not $check_mode) {
        New-PSDrive -Name HKU -PSProvider Registry -Root Registry::HKEY_USERS

        if (Test-Path -LiteralPath HKU:\ANSIBLE) {
            $module.Warn("hive already loaded at HKU:\ANSIBLE, had to unload hive for win_region to continue")
            [Ansible.WinRegion.Hive]::UnloadHive("ANSIBLE")
        }

        $loaded_hive = New-Object -TypeName Ansible.WinRegion.Hive -ArgumentList "ANSIBLE", 'C:\Users\Default\NTUSER.DAT'
        try {
            $sids = 'ANSIBLE', '.DEFAULT', 'S-1-5-19', 'S-1-5-20'
            foreach ($sid in $sids) {
                Copy-RegistryKey -source "HKCU:\Keyboard Layout" -target "HKU:\$sid"
                Copy-RegistryKey -source "HKCU:\Control Panel\International" -target "HKU:\$sid\Control Panel"
                Copy-RegistryKey -source "HKCU:\Control Panel\Input Method" -target "HKU:\$sid\Control Panel"
            }
        }
        finally {
            $loaded_hive.Dispose()
        }

        Remove-PSDrive HKU
    }
    $module.Result.changed = $true
}

$module.ExitJson()
