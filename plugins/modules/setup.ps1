#!powershell

# Copyright: (c) 2018, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.AddType
#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        # This is not meant to be publicly used, only for debugging how long it takes to capture a subset.
        _measure_subset = @{ type = 'bool'; default = $false }

        fact_path = @{ type = 'path' }
        gather_subset = @{ type = 'list'; elements = 'str'; default = 'all' }
        gather_timeout = @{ type = 'int'; default = 10 }
    }
    supports_check_mode = $true
}

# This module can be called by the gather_facts action plugin in ansible-base. While it shouldn't add any new options
# we need to make sure the module doesn't break if it does. To do this we need to add any options in the input args
if ($args.Length -gt 0) {
    $params = Get-Content -LiteralPath $args[0] | ConvertFrom-AnsibleJson
}
else {
    $params = $complex_args
}
if ($params) {
    foreach ($param in $params.GetEnumerator()) {
        if ($param.Key.StartsWith('_') -or $spec.options.ContainsKey($param.Key)) {
            continue
        }
        $spec.options."$($param.Key)" = @{ type = 'raw' }
    }
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$measureSubset = $module.Params._measure_subset
$factPath = $module.Params.fact_path
$gatherSubset = $module.Params.gather_subset
$gatherTimeout = $module.Params.gather_timeout

$osversion = [Environment]::OSVersion.Version
if ($osversion -lt [version]"6.2") {
    # Server 2008, 2008 R2, and Windows 7 are not tested in CI and we want to let customers know about it before
    # removing support altogether.
    $versionString = "{0}.{1}" -f ($osversion.Major, $osversion.Minor)
    $module.Warn("The Windows version '$versionString' will no longer be supported or tested in future releases")
}

Add-CSharpType -AnsibleModule $module -References @'
using Microsoft.Win32.SafeHandles;
using System;
using System.Collections.Generic;
using System.Runtime.ConstrainedExecution;
using System.Runtime.InteropServices;
using System.Text;

namespace Ansible.Windows.Setup
{
    public class NativeHelpers
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct DSROLE_PRIMARY_DOMAIN_INFO_BASIC
        {
            public Int32 MachineRole;
            public UInt32 Flags;
            public string DomainNameFlat;
            public string DomainNameDns;
            public string DomainForestName;
            public Guid DomainGuid;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct MEMORYSTATUSEX
        {
            public Int32 dwLength;
            public UInt32 dwMemoryLoad;
            public UInt64 ullTotalPhys;
            public UInt64 ullAvailPhys;
            public UInt64 ullTotalPageFile;
            public UInt64 ullAvailPageFile;
            public UInt64 ullTotalVirtual;
            public UInt64 ullAvailVirtual;
            public UInt64 ullAvailExtendedVirtual;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct OSVERSIONINFOEXW
        {
            public Int32 dwOSVersionInfoSize;
            public UInt32 dwMajorVersion;
            public UInt32 dwMinorVersion;
            public UInt32 dwBuildNumber;
            public UInt32 dwPlatformId;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string szCSDVersion;
            public UInt16 wServicePackMajor;
            public UInt16 wServicePackMinor;
            public UInt16 wSuiteMask;
            public byte wProductType;
            public byte wReserved;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct RawSMBIOSData
        {
            public byte Used20CallingMethod;
            public byte SMBIOSMajorVersion;
            public byte SMBIOSMinorVersion;
            public byte DmiRevision;
            public Int32 Length;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct SMBIOSHeader
        {
            public byte Type;
            public byte Length;
            public UInt16 Handle;
        }

        // Both BIOSData and SystemInformation is defined in the standard below.
        // https://www.dmtf.org/sites/default/files/standards/documents/DSP0134_3.3.0.pdf
        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        public struct BIOSData
        {
            public byte Vendor;
            public byte Version;
            public UInt16 StartingAddressSegment;
            public byte ReleaseDate;
            // There are more fields but we only need up to ReleaseDate.
        }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        public struct SystemInformation
        {
            public byte Manufacturer;
            public byte ProductName;
            public byte Version;
            public byte SerialNumber;
            // There are more fields but we only need up to SerialNumber.
        }

        [StructLayout(LayoutKind.Sequential, Pack = 1)]
        public struct ProcessorInformation
        {
            public byte SocketDesignation;
            public byte ProcessorType;
            public byte ProcessorFamily;
            public byte ProcessorManufacturer;
            public UInt64 ProcessorId;
            public byte ProcessorVersion;
            public byte Voltage;
            public UInt16 ExternalClock;
            public UInt16 MaxSpeed;
            public UInt16 CurrentSpeed;
            public byte Status;
            public byte ProcessorUpgrade;
            public UInt16 L1CacheHandle;
            public UInt16 L2CacheHandle;
            public UInt16 L3CacheHandle;
            public byte SerialNumber;
            public byte AssetTag;
            public byte PartNumber;
            public byte CoreCount;
            public byte CoreEnabled;
            public byte ThreadCount;
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct SYSTEM_INFO
        {
            public UInt16 wProcessorArchitecture;
            public UInt16 wReserved;
            public UInt32 dwPageSize;
            public IntPtr lpMinimumApplicationAddress;
            public IntPtr lpMaximumApplicationAddress;
            public UIntPtr dwActiveProcessorMask;
            public UInt32 dwNumberOfProcessors;
            public UInt32 dwProcessorType;
            public UInt32 dwAllocationGranularity;
            public UInt16 wProcessorLevel;
            public UInt16 wProcessorRevision;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct WKSTA_INFO_100
        {
            public UInt32 wki100_platform_id;
            public string wki100_computername;
            public string wki100_langroup;
            public UInt32 wki100_ver_major;
            public UInt32 wki100_ver_minor;
        }
    }

    public class NativeMethods
    {
        [DllImport("Netapi32.dll")]
        public static extern void DsRoleFreeMemory(
            IntPtr Buffer);

        [DllImport("Netapi32.dll")]
        public static extern Int32 DsRoleGetPrimaryDomainInformation(
            [MarshalAs(UnmanagedType.LPWStr)] string lpServer,
            UInt32 InfoLevel,
            out SafeDsMemoryBuffer Buffer);

        [DllImport("Kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern bool GetComputerNameExW(
            UInt32 NameType,
            [MarshalAs(UnmanagedType.LPWStr)] StringBuilder lpBuffer,
            ref Int32 nSize);

        [DllImport("Kernel32.dll")]
        public static extern void GetNativeSystemInfo(
            ref NativeHelpers.SYSTEM_INFO lpSystemInfo);

        [DllImport("Kernel32.dll", SetLastError = true)]
        public static extern Int32 GetSystemFirmwareTable(
            FirmwareProvider FirmwareTableProviderSignature,
            UInt32 FirmwareTableID,
            IntPtr pFirmwareTableBuffer,
            Int32 BufferSize);

        [DllImport("Kernel32.dll")]
        public static extern Int64 GetTickCount64();

        [DllImport("Kernel32.dll", SetLastError = true)]
        public static extern bool GetVersionExW(
            ref NativeHelpers.OSVERSIONINFOEXW lpVersionInformation);

        [DllImport("Kernel32.dll", SetLastError = true)]
        public static extern bool GlobalMemoryStatusEx(
            ref NativeHelpers.MEMORYSTATUSEX lpBuffer);

        [DllImport("Netapi32.dll")]
        public static extern UInt32 NetApiBufferFree(
            IntPtr Buffer);

        [DllImport("Netapi32.dll", CharSet = CharSet.Unicode)]
        public static extern Int32 NetWkstaGetInfo(
            string servername,
            UInt32 level,
            out SafeNetAPIBuffer bufptr);
    }

    public class SafeMemoryBuffer : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeMemoryBuffer(int cb) : base(true)
        {
            base.SetHandle(Marshal.AllocHGlobal(cb));
        }

        [ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
        protected override bool ReleaseHandle()
        {
            Marshal.FreeHGlobal(handle);
            return true;
        }
    }

    public class SafeDsMemoryBuffer : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeDsMemoryBuffer() : base(true) { }

        [ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
        protected override bool ReleaseHandle()
        {
            NativeMethods.DsRoleFreeMemory(this.handle);
            return true;
        }
    }

    public class SafeNetAPIBuffer : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeNetAPIBuffer() : base(true) { }

        [ReliabilityContract(Consistency.WillNotCorruptState, Cer.MayFail)]
        protected override bool ReleaseHandle()
        {
            NativeMethods.NetApiBufferFree(this.handle);
            return true;
        }
    }

    public class Win32Exception : System.ComponentModel.Win32Exception
    {
        private string _msg;

        public Win32Exception(string message) : this(Marshal.GetLastWin32Error(), message) { }
        public Win32Exception(int errorCode, string message) : base(errorCode)
        {
            _msg = String.Format("{0} ({1}, Win32ErrorCode {2} - 0x{2:X8})", message, base.Message, errorCode);
        }

        public override string Message { get { return _msg; } }
        public static explicit operator Win32Exception(string message) { return new Win32Exception(message); }
    }

    public enum FirmwareProvider : uint
    {
        ACPI = 0x41435049,
        FIRM = 0x4649524D,
        RSMB = 0x52534D42
    }

    public class DomainInfo
    {
        public string Domain;
        public Int32 DomainRole;
        public bool PartOfDomain;

        public DomainInfo()
        {
            SafeDsMemoryBuffer dsBuffer;
            // 1 == DsRolePrimaryDomainInfoBasic
            int res = NativeMethods.DsRoleGetPrimaryDomainInformation(null, 1, out dsBuffer);
            if (res != 0)
                throw new Win32Exception(res, "Failed to get domain information");

            using (dsBuffer)
            {
                var domainInfo = (NativeHelpers.DSROLE_PRIMARY_DOMAIN_INFO_BASIC)Marshal.PtrToStructure(
                    dsBuffer.DangerousGetHandle(), typeof(NativeHelpers.DSROLE_PRIMARY_DOMAIN_INFO_BASIC));

                Domain = domainInfo.DomainNameDns;
                DomainRole = domainInfo.MachineRole;
                PartOfDomain = !String.IsNullOrEmpty(Domain);
            }


            if (!PartOfDomain)
            {
                SafeNetAPIBuffer netBuffer;
                res = NativeMethods.NetWkstaGetInfo(null, 100, out netBuffer);
                if (res != 0)
                    throw new Win32Exception(res, "Failed to get workstation information");

                using (netBuffer)
                {
                    var netInfo = (NativeHelpers.WKSTA_INFO_100)Marshal.PtrToStructure(
                        netBuffer.DangerousGetHandle(), typeof(NativeHelpers.WKSTA_INFO_100));

                    Domain = netInfo.wki100_langroup;
                }
            }
        }
    }

    public class MemoryInfo
    {
        public UInt64 TotalPhysical;
        public UInt64 AvailablePhysical;

        public MemoryInfo()
        {
            var memoryInfo = new NativeHelpers.MEMORYSTATUSEX();
            memoryInfo.dwLength = Marshal.SizeOf(memoryInfo);

            if (!NativeMethods.GlobalMemoryStatusEx(ref memoryInfo))
                throw new Win32Exception("Failed to get memory info");

            TotalPhysical = memoryInfo.ullTotalPhys;
            AvailablePhysical = memoryInfo.ullAvailPhys;
        }
    }

    public class OSVersionInfo
    {
        public byte ProductType;

        public OSVersionInfo()
        {
            var versionInfo = new NativeHelpers.OSVERSIONINFOEXW() { };
            versionInfo.dwOSVersionInfoSize = Marshal.SizeOf(versionInfo);

            if (!NativeMethods.GetVersionExW(ref versionInfo))
                throw new Win32Exception("Failed to get version info");

            ProductType = versionInfo.wProductType;
        }
    }

    public class SMBIOSInfo
    {
        public DateTime? ReleaseDate;
        public string SMBIOSBIOSVersion;
        public string Manufacturer;
        public string Model;
        public string SerialNumber;
        public List<Tuple<byte, byte>> ProcessorInfo = new List<Tuple<byte, byte>>();

        public SMBIOSInfo()
        {
            using (SafeMemoryBuffer buffer = GetSMBIOSBuffer())
            {
                var rawData = (NativeHelpers.RawSMBIOSData)Marshal.PtrToStructure(buffer.DangerousGetHandle(),
                    typeof(NativeHelpers.RawSMBIOSData));

                IntPtr tablePtr = IntPtr.Add(buffer.DangerousGetHandle(), Marshal.SizeOf(rawData));
                int headerSize = Marshal.SizeOf(typeof(NativeHelpers.SMBIOSHeader));
                int offset = 0;

                while (offset < rawData.Length)
                {
                    var header = (NativeHelpers.SMBIOSHeader)Marshal.PtrToStructure(tablePtr,
                        typeof(NativeHelpers.SMBIOSHeader));
                    IntPtr headerDataPtr = IntPtr.Add(tablePtr, headerSize);

                    tablePtr = IntPtr.Add(tablePtr, header.Length);
                    offset += header.Length;
                    List<string> stringTable = ExtractStringTable(ref tablePtr, ref offset);

                    // We only care about the BIOS (0) or System Information (1) values.
                    if (header.Type == 0)
                    {
                        var biosInfo = (NativeHelpers.BIOSData)Marshal.PtrToStructure(headerDataPtr,
                            typeof(NativeHelpers.BIOSData));

                        ReleaseDate = ParseDateString(ExtractFromStringTable(stringTable, biosInfo.ReleaseDate));
                        SMBIOSBIOSVersion = ExtractFromStringTable(stringTable, biosInfo.Version);
                    }
                    else if (header.Type == 1)
                    {
                        var systemInfo = (NativeHelpers.SystemInformation)Marshal.PtrToStructure(headerDataPtr,
                            typeof(NativeHelpers.SystemInformation));

                        Manufacturer = ExtractFromStringTable(stringTable, systemInfo.Manufacturer);
                        Model = ExtractFromStringTable(stringTable, systemInfo.ProductName);
                        SerialNumber = ExtractFromStringTable(stringTable, systemInfo.SerialNumber);
                    }
                    else if (header.Type == 4)
                    {
                        var processorInfo = (NativeHelpers.ProcessorInformation)Marshal.PtrToStructure(headerDataPtr,
                            typeof(NativeHelpers.ProcessorInformation));

                        // TODO: Technically if CoreCount or ThreadCount == 255 then we should look at another field
                        // but the chances of that happening are slim compared to the complexity of the checks required.
                        ProcessorInfo.Add(Tuple.Create(processorInfo.CoreCount, processorInfo.ThreadCount));
                    }
                    else
                        continue;
                }
            }
        }

        private SafeMemoryBuffer GetSMBIOSBuffer()
        {
            Int32 size = NativeMethods.GetSystemFirmwareTable(FirmwareProvider.RSMB, 0, IntPtr.Zero, 0);
            SafeMemoryBuffer buffer = new SafeMemoryBuffer(size);

            NativeMethods.GetSystemFirmwareTable(FirmwareProvider.RSMB, 0, buffer.DangerousGetHandle(), size);
            int res = Marshal.GetLastWin32Error();
            if (res != 0)
                throw new Win32Exception(res, "Failed to get SMBIOS buffer information");

            return buffer;
        }

        private List<string> ExtractStringTable(ref IntPtr ptr, ref int offset)
        {
            // The string table is a list of null-terminated ASCII encoded strings right after the header.
            List<string> stringTable = new List<string>();

            while (true)
            {
                string stringValue = Marshal.PtrToStringAnsi(ptr);
                ptr = IntPtr.Add(ptr, stringValue.Length + 1);
                offset += stringValue.Length + 1;

                if (String.IsNullOrEmpty(stringValue))
                {
                    // If there were no string we still need to account for another null char.
                    if (stringTable.Count == 0)
                    {
                        ptr = IntPtr.Add(ptr, 1);
                        offset++;
                    }
                    break;
                }
                else
                    stringTable.Add(stringValue);
            }

            return stringTable;
        }

        private string ExtractFromStringTable(List<string> stringTable, byte index)
        {
            // StringTable indexes are 1 based, if the value is 0 then there is no value.
            if (index == 0)
                return null;

            return stringTable[index - 1].Trim();
        }

        private DateTime? ParseDateString(string date)
        {
            if (String.IsNullOrEmpty(date))
                return null;

            // Older standards could use a 2 digit year that indicates 19yy.
            string dateFormat = date.Length == 10 ? "MM/dd/yyyy" : "MM/dd/yy";

            DateTime rawDateTime = DateTime.ParseExact(date, dateFormat, null);
            return DateTime.SpecifyKind(rawDateTime, DateTimeKind.Utc);
        }
    }

    public class SystemInfo
    {
        public string NetBIOSName;
        public UInt32 NumberOfProcessors;
        public UInt32 ProcessorArchitecture;

        public SystemInfo()
        {
            var systemInfo = new NativeHelpers.SYSTEM_INFO();
            NativeMethods.GetNativeSystemInfo(ref systemInfo);

            NumberOfProcessors = systemInfo.dwNumberOfProcessors;
            ProcessorArchitecture = systemInfo.wProcessorArchitecture;

            StringBuilder buffer = new StringBuilder(0);
            int size = 0;

            // 0 == ComputerNameNetBIOS
            NativeMethods.GetComputerNameExW(0, buffer, ref size);
            buffer.EnsureCapacity(size);

            if (!NativeMethods.GetComputerNameExW(0, buffer, ref size))
                throw new Win32Exception("Failed to get ComputerName");
            NetBIOSName = buffer.ToString();
        }
    }
}
'@

$factMeta = @(
    @{
        Subsets = 'all_ipv4_addresses', 'all_ipv6_addresses'
        Code = {
            $interfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()
            $ips = @(foreach ($interface in $interfaces) {
                    # Win32_NetworkAdapterConfiguration did not return the local IPs so we replicate that here.
                    $interface.GetIPProperties().UnicastAddresses | Where-Object {
                        $_.Address.ToString() -notin @('::1', '127.0.0.1')
                    } | ForEach-Object -Process {
                        $_.Address.ToString()
                    }
                })

            $ansibleFacts.ansible_ip_addresses = $ips
        }
    },
    @{
        Subsets = 'bios'
        Code = {
            $bios = New-Object -TypeName Ansible.Windows.Setup.SMBIOSInfo

            $releaseDate = if ($bios.ReleaseDate) {
                $bios.ReleaseDate.ToUniversalTime().ToString('MM/dd/yyyy')
            }
            $ansibleFacts.ansible_bios_date = $releaseDate
            $ansibleFacts.ansible_bios_version = $bios.SMBIOSBIOSVersion
            $ansibleFacts.ansible_product_name = $bios.Model
            $ansibleFacts.ansible_product_serial = $bios.SerialNumber
        }
    },
    @{
        Subsets = 'date_time'
        Code = {
            $datetime = (Get-Date)
            $datetimeUtc = $datetime.ToUniversalTime()
            $epochDatetimeUtc = New-Object -TypeName DateTime -ArgumentList @(1970, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
            $epoch = (New-TimeSpan -Start $epochDatetimeUtc -End $dateTimeUtc).TotalSeconds

            $ansibleFacts.ansible_date_time = @{
                date = $datetime.ToString("yyyy-MM-dd")
                day = $datetime.ToString("dd")
                epoch_local = (Get-Date ($datetime) -UFormat '+%s')
                epoch = (Get-Date ($datetimeUtc) -UFormat '+%s')
                epoch_int = [int]$epoch
                hour = $datetime.ToString("HH")
                iso8601 = $datetimeUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
                iso8601_basic = $datetime.ToString("yyyyMMddTHHmmssffffff")
                iso8601_basic_short = $datetime.ToString("yyyyMMddTHHmmss")
                iso8601_micro = $datetimeUtc.ToString("yyyy-MM-ddTHH:mm:ss.ffffffZ")
                minute = $datetime.ToString("mm")
                month = $datetime.ToString("MM")
                second = $datetime.ToString("ss")
                time = $datetime.ToString("HH:mm:ss")
                tz = ([System.TimeZoneInfo]::Local.Id)
                tz_offset = $datetime.ToString("zzzz")
                # Ensure that the weekday is in English
                weekday = $datetime.ToString("dddd", [System.Globalization.CultureInfo]::InvariantCulture)
                weekday_number = (Get-Date -UFormat "%w")
                weeknumber = (Get-Date -UFormat "%W")
                year = $datetime.ToString("yyyy")
            }
        }
    },
    @{
        Subsets = 'distribution'
        Code = {
            $osversion = [Environment]::OSVersion.Version

            $osProductType = (New-Object -TypeName Ansible.Windows.Setup.OSVersionInfo).ProductType
            $productType = switch ($osProductType) {
                1 { "workstation" }
                2 { "domain_controller" }
                3 { "server" }
                default { "unknown" }
            }

            $osInfoParams = @{
                LiteralPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
                Name = 'InstallationType'
                ErrorAction = 'SilentlyContinue'
            }
            $osInfo = Get-ItemProperty @osInfoParams

            $ansibleFacts.ansible_distribution = $null
            $ansibleFacts.ansible_distribution_version = $osversion.ToString()
            $ansibleFacts.ansible_distribution_major_version = $osversion.Major.ToString()
            $ansibleFacts.ansible_os_family = "Windows"
            $ansibleFacts.ansible_os_name = $null
            $ansibleFacts.ansible_os_product_type = $productType
            $ansibleFacts.ansible_os_installation_type = $osInfo.InstallationType

            # We cannot call WMI if we aren't an admin (on a network logon), conditionally set these facts.
            $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            if ($currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                # These values are localized and I cannot find where they are sourced, we just need to continue
                # returning them for backwards compatibility.
                $win32OS = Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption, Name

                $ansibleFacts.ansible_distribution = $win32OS.Caption
                $ansibleFacts.ansible_os_name = ($win32OS.Name.Split('|')[0]).Trim()
            }
        }
    },
    @{
        Subsets = 'env'
        Code = {
            $envVars = @{}
            foreach ($item in Get-ChildItem -LiteralPath Env:) {
                # Powershell ConvertTo-Json fails if string ends with \
                $value = $item.Value.TrimEnd("\")
                $envVars.Add($item.Name, $value)
            }

            $ansibleFacts.ansible_env = $envVars
        }
    },
    @{
        Subsets = 'facter'
        Code = {
            # Get-Command can be slow to enumerate the paths, do this ourselves
            $facterDir = $env:PATH -split ([IO.Path]::PathSeparator) | Where-Object {
                # https://github.com/ansible-collections/ansible.windows/pull/78#issuecomment-745229594
                # PATHs with missing entries 'C:\Windows;;C:\Program Files' needs to be handled.
                if ([String]::IsNullOrWhiteSpace($_)) {
                    return $false
                }
                $facterPath = Join-Path -Path $_ -ChildPath facter.exe
                Test-Path -LiteralPath $facterPath
            } | Select-Object -First 1

            if ($facterDir) {
                # Get JSON from Facter, and parse it out.
                $facter = Join-Path -Path $facterDir -ChildPath facter.exe
                $facterOutput = &$facter -j
                $facts = "$facterOutput" | ConvertFrom-Json

                ForEach ($fact in $facts.PSObject.Properties) {
                    $ansibleFacts."facter_$($fact.Name)" = $fact.Value
                }
            }
        }
    },
    @{
        Subsets = 'interfaces'
        Code = {
            $interfaces = [System.Net.NetworkInformation.NetworkInterface]::GetAllNetworkInterfaces()

            $formattedNetCfg = @(foreach ($interface in $interfaces) {
                    $ipProps = $interface.GetIPProperties()

                    try {
                        $ipv4 = $ipProps.GetIPv4Properties()
                    }
                    catch [System.Net.NetworkInformation.NetworkInformationException] {
                        $ipv4 = $null
                    }
                    try {
                        $ipv6 = $ipProps.GetIPv6Properties()
                    }
                    catch [System.Net.NetworkInformation.NetworkInformationException] {
                        $ipv6 = $null
                    }

                    # Do not repo on either the loopback interface or any interfaces that did not have an IP address.
                    if (-not ($ipv4 -or $ipv6) -or $interface.NetworkInterfaceType -in @('Loopback', 'Tunnel')) {
                        continue
                    }

                    $defaultGateway = if ($ipProps.GatewayAddresses) {
                        $ipProps.GatewayAddresses[0].Address.IPAddressToString
                    }
                    $dnsDomain = $null
                    if ($ipProps.DnsSuffix) {
                        $dnsDomain = $ipProps.DnsSuffix
                    }
                    $index = if ($ipv4) {
                        $ipv4.Index
                    }
                    elseif ($ipv6) {
                        $ipv6.Index
                    }

                    $ipv4_address = $ipProps.UnicastAddresses | Where-Object {
                        $_.Address.AddressFamily -eq 2
                    } | Select-Object @{ N = 'address'; E = { $_.Address.ToString() } }, @{ N = 'prefix'; E = { $_.PrefixLength.ToString() } }

                    $ipv6_address = $ipProps.UnicastAddresses | Where-Object {
                        $_.Address.AddressFamily -eq 23
                    } | Select-Object @{ N = 'address'; E = { $_.Address.ToString() } }, @{ N = 'prefix'; E = { $_.PrefixLength.ToString() } }

                    $mac = ($interface.GetPhysicalAddress() -replace '(..)', '$1:').ToUpperInvariant().Trim(':')

                    @{
                        connection_name = $interface.Name
                        default_gateway = $defaultGateway
                        dns_domain = $dnsDomain
                        interface_index = $index
                        interface_name = $interface.Description
                        ipv4 = $ipv4_address
                        ipv6 = $ipv6_address
                        macaddress = $mac
                        mtu = $ipv4.Mtu
                        speed = $interface.Speed / 1000 / 1000
                    }
                })

            $ansibleFacts.ansible_interfaces = $formattedNetCfg
        }
    },
    @{
        Subsets = 'local'
        Code = {
            if (-not $factPath) {
                return
            }

            if (Test-Path -Path $factPath) {
                $factFiles = Get-ChildItem -Path $factpath | Where-Object {
                    -not $_.PSIsContainer -and $_.Extension -eq '.ps1'
                }

                foreach ($factsFile in $factFiles) {
                    $out = & $($FactsFile.FullName)
                    $ansibleFacts."ansible_$(($factsFile.Name).Split('.')[0])" = $out
                }
            }
            else {
                $module.Warn("Non existing path was set for local facts - $factPath")
            }
        }
    },
    @{
        Subsets = 'memory'
        Code = {
            $mem = New-Object -TypeName Ansible.Windows.Setup.MemoryInfo

            $ansibleFacts.ansible_memtotal_mb = ([Math]::Ceiling($mem.TotalPhysical / 1024 / 1024))
            $ansibleFacts.ansible_memfree_mb = ([Math]::Ceiling($mem.AvailablePhysical / 1024 / 1024))
            $ansibleFacts.ansible_swaptotal_mb = 0  # Swap memory does not apply to Windows

            # Cannot figure out how to get this info outside of WMI. That means we can only run this when we are an
            # an admin to avoid a 5 second execution time hit on a standard user logon.
            $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            if ($currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                $win32OS = Get-CimInstance -ClassName Win32_OperatingSystem -Property @(
                    'FreeSpaceInPagingFiles', 'SizeStoredInPagingFiles'
                )
                $ansibleFacts.ansible_pagefiletotal_mb = ([Math]::Round($win32OS.SizeStoredInPagingFiles / 1024))
                $ansibleFacts.ansible_pagefilefree_mb = ([Math]::Round($win32OS.FreeSpaceInPagingFiles / 1024))
            }
            else {
                $ansibleFacts.ansible_pagefiletotal_mb = $null
                $ansibleFacts.ansible_pagefilefree_mb = $null
            }
        }
    },
    @{
        Subsets = 'platform'
        Code = {
            $bios = New-Object -TypeName Ansible.Windows.Setup.SMBIOSInfo
            $domainInfo = New-Object -TypeName Ansible.Windows.Setup.DomainInfo
            $systemInfo = New-Object -TypeName Ansible.Windows.Setup.SystemInfo
            $osVersion = [Environment]::OSVersion

            # The Machine SID is stored in HKLM:\SECURITY\SAM\Domains\Account and is
            # only accessible by the Local System account. This method get's the local
            # admin account (ends with -500) and lops it off to get the machine sid.
            $machineSid = $null
            try {
                $adminGroup = (New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList @(
                        "S-1-5-32-544")).Translate([System.Security.Principal.NTAccount]).Value

                $namespace = 'System.DirectoryServices.AccountManagement'

                Add-Type -AssemblyName $namespace
                $context = New-Object -TypeName "$namespace.PrincipalContext" -ArgumentList @(
                    [System.DirectoryServices.AccountManagement.ContextType]::Machine)
                $principal = New-Object -TypeName "$namespace.GroupPrincipal" -ArgumentList $context, $adminGroup
                $searcher = New-Object -TypeName "$namespace.PrincipalSearcher" -ArgumentList $principal
                $groups = $searcher.FindOne()

                foreach ($user in $groups.Members) {
                    if ($user.Sid.Value.EndsWith("-500")) {
                        $machineSid = $user.Sid.AccountDomainSid.Value
                        break
                    }
                }
            }
            catch {
                $module.Warn("Error during machine sid retrieval: $($_.Exception.Message)")
            }

            $ipProps = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
            $fqdn = $ipProps.HostName
            if ($ipProps.DomainName) {
                $fqdn = "$($fqdn).$($ipProps.DomainName)"
            }
            $domainSuffix = if ($domainInfo.PartOfDomain) { [string]$domainInfo.Domain } else { "" }

            $ownerParams = @{
                LiteralPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
                Name = 'RegisteredOwner'
                ErrorAction = 'SilentlyContinue'
            }
            $ownerName = [String](Get-ItemProperty @ownerParams)."$($ownerParams.Name)"

            $descriptionParams = @{
                LiteralPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters'
                Name = 'srvcomment'
                ErrorAction = 'SilentlyContinue'
            }
            $description = [string](Get-ItemProperty @descriptionParams)."$($descriptionParams.Name)"

            $ansibleFacts.ansible_domain = [String]$domainSuffix
            $ansibleFacts.ansible_fqdn = $fqdn
            $ansibleFacts.ansible_hostname = $ipProps.HostName
            $ansibleFacts.ansible_netbios_name = $systemInfo.NetBIOSName
            $ansibleFacts.ansible_kernel = $osVersion.Version.ToString()
            $ansibleFacts.ansible_nodename = $fqdn
            $ansibleFacts.ansible_machine_id = $machineSid
            $ansibleFacts.ansible_owner_name = $ownerName
            $ansibleFacts.ansible_system = $osVersion.Platform.ToString()
            $ansibleFacts.ansible_system_description = $description
            $ansibleFacts.ansible_system_vendor = $bios.Manufacturer

            # Check if a reboot is pending, this is legacy behaviour from Legacy.psm1
            $pendingParams = @{
                LiteralPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
                Name = 'PendingFileRenameOperations'
                ErrorAction = 'SilentlyContinue'
            }
            $pendingRenames = (Get-ItemProperty @pendingParams)."$($pendingParams.Name)"

            $cbsPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
            $cbsReboot = Test-Path -LiteralPath $cbsPath

            $smParams = @{
                LiteralPath = 'HKLM:\SOFTWARE\Microsoft\ServerManager\ServicingStorage\ServerComponentCache'
                Name = 'RestartRequired'
                ErrorAction = 'SilentlyContinue'
            }
            $smRestart = (Get-ItemProperty @smParams)."$($smParams.Name)"
            $rebootPending = $pendingRenames -or $cbsReboot -or $smRestart

            # Cannot run Get-CimInstance on non-admin account as it takes 5 seconds to come back with an access denied
            # error. Set the original value to $null and use 'ansible_architecture2' instead.
            $currentUser = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
            if ($currentUser.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                $win32CS = Get-CimInstance -ClassName Win32_ComputerSystem -Property PrimaryOwnerContact
                $win32OS = Get-CimInstance -ClassName Win32_OperatingSystem -Property OSArchitecture

                $ansibleFacts.ansible_architecture = $win32OS.OSArchitecture

                # I don't even know if this even returns anything on Windows, cannot find any documentation for it.
                $ansibleFacts.ansible_owner_contact = ([string]$win32CS.PrimaryOwnerContact)
            }
            else {
                $ansibleFacts.ansible_architecture = $null
                $ansibleFacts.ansible_owner_contact = ""
            }
            $ansibleFacts.ansible_reboot_pending = $rebootPending

            # This is a non-localized value that tries to match the POSIX setup.py values. We cannot replace
            # ansible_architecture without a deprecation period so have both side by side. When we can deprecate facts
            # returned by a module we should deprecate the format and rename this.
            $ansibleFacts.ansible_architecture2 = switch ($systemInfo.ProcessorArchitecture) {
                0 { 'i386' }  # PROCESSOR_ARCHITECTURE_INTEL (x86)
                5 { 'arm' }  # PROCESSOR_ARCHITECTURE_ARM (ARM)
                6 { 'ia64' }  # PROCESSOR_ARCHITECTURE_IA64 (Intel Ithanium-based)
                9 { 'x86_64' }  # PROCESSOR_ARCHITECTURE_AMD64 (x64 (AMD or Intel))
                12 { 'arm64' }  # PROCESSOR_ARCHITECTURE_ARM64 (ARM664)
                default { 'unknown' }
            }
        }
    },
    @{
        Subsets = 'powershell_version'
        Code = {
            $ansibleFacts.ansible_powershell_version = $PSVersionTable.PSVersion.Major
        }
    },
    @{
        Subsets = 'processor'
        Code = {
            $bios = New-Object -TypeName Ansible.Windows.Setup.SMBIOSInfo
            $systemInfo = New-Object -TypeName Ansible.Windows.Setup.SystemInfo

            $getParams = @{
                LiteralPath = 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor'
                ErrorAction = 'SilentlyContinue'
            }
            $processorKeys = Get-ChildItem @getParams | Select-Object -Property @(
                'PSPath', @{ N = 'ID'; E = { [int]$_.PSChildName } }
            ) | Sort-Object -Property Id

            $processors = @(foreach ($proc in $processorKeys) {
                    $names = 'ProcessorNameString', 'VendorIdentifier'
                    $info = Get-ItemProperty -LiteralPath $proc.PSPath -Name $names -ErrorAction SilentlyContinue
                    [string]$proc.ID
                    $info.VendorIdentifier
                    $info.ProcessorNameString
                })

            $ansibleFacts.ansible_processor = $processors
            $ansibleFacts.ansible_processor_cores = $bios.ProcessorInfo[0].Item1
            $ansibleFacts.ansible_processor_count = $bios.ProcessorInfo.Count
            $ansibleFacts.ansible_processor_threads_per_core = $bios.ProcessorInfo[0].Item2
            $ansibleFacts.ansible_processor_vcpus = $systemInfo.NumberOfProcessors
        }
    },
    @{
        Subsets = 'uptime'
        Code = {
            $ticks = [Ansible.Windows.Setup.NativeMethods]::GetTickCount64()

            $ansibleFacts.ansible_lastboot = [DateTime]::Now.AddMilliseconds($ticks * -1).ToString('u')
            $ansibleFacts.ansible_uptime_seconds = [Math]::Round($ticks / 1000)
        }
    },
    @{
        Subsets = 'user'
        Code = {
            $user = [Security.Principal.WindowsIdentity]::GetCurrent()

            $ansibleFacts.ansible_user_dir = $env:userprofile
            # Win32_UserAccount.FullName is probably the right thing here, but it can be expensive to get on large domains
            $ansibleFacts.ansible_user_gecos = ""
            $ansibleFacts.ansible_user_id = $env:username
            $ansibleFacts.ansible_user_sid = $user.User.Value
        }
    },
    @{
        Subsets = 'windows_domain'
        Code = {
            $domainInfo = New-Object -TypeName Ansible.Windows.Setup.DomainInfo

            $domainRole = switch ($domainInfo.DomainRole) {
                0 { "Stand-alone workstation" }
                1 { "Member workstation" }
                2 { "Stand-alone server" }
                3 { "Member server" }
                4 { "Backup domain controller" }
                5 { "Primary domain controller" }
                default { "Unknown DomainRole $_" }
            }

            $ansibleFacts.ansible_windows_domain = $domainInfo.Domain
            $ansibleFacts.ansible_windows_domain_member = $domainInfo.PartOfDomain
            $ansibleFacts.ansible_windows_domain_role = $domainRole
        }
    },
    @{

        Subsets = 'winrm'
        Code = {
            try {
                $certs = @(Get-ChildItem -Path WSMan:\localhost\Listener\* -ErrorAction SilentlyContinue | Where-Object {
                        'Transport=HTTPS' -in $_.Keys
                    } | Get-ChildItem | Where-Object Name -eq 'CertificateThumbprint' | ForEach-Object {
                        Get-Item -LiteralPath Cert:\LocalMachine\My\$($_.Value)
                    })
            }
            catch {
                $certs = @()
                $module.Warn("Error during certificate expiration retrieval: $($_.Exception.Message)")
            }

            $certs | Sort-Object -Property NotAfter | Select-Object -First 1 | ForEach-Object -Process {
                # this fact was renamed from ansible_winrm_certificate_expires due to collision with ansible_winrm_X connection var pattern
                $ansibleFacts.ansible_win_rm_certificate_expires = $_.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
    },
    @{
        Subsets = 'virtual'
        Code = {
            $bios = New-Object -TypeName Ansible.Windows.Setup.SMBIOSInfo

            $modelMap = @{
                kvm = @('KVM', 'KVM Server', 'Bochs', 'AHV')
                RHEV = @('RHEV Hypervisor')
                VMware = @('VMWare Virtual Platform', 'VMware7,1')
                openstack = @('OpenStack Compute', 'OpenStack Nova')
                xen = @('xen', 'HVM domU')
                'Hyper-V' = @('Virtual Machine')
                VirtualBox = @('VirtualBox')
            }
            foreach ($modelInfo in $modelMap.GetEnumerator()) {
                if ($bios.Model -in $modelInfo.Value) {
                    $ansibleFacts.ansible_virtualization_role = 'guest'
                    $ansibleFacts.ansible_virtualization_type = $modelInfo.Key
                    return
                }
            }

            $manufacturerMap = @{
                kvm = @('QEMU', 'oVirt', 'Amazon EC2', 'DigitalOcean', 'Google', 'Scaleway', 'Nutanix')
                KubeVirt = @('KubVirt')
                parallels = @('Parallels Software International Inc.')
                openstack = @('OpenStack Foundation')
            }
            foreach ($manufacturerInfo in $manufacturerMap.GetEnumerator()) {
                if ($bios.Manufacturer -in $manufacturerInfo.Value) {
                    $ansibleFacts.ansible_virtualization_role = 'guest'
                    $ansibleFacts.ansible_virtualization_type = $manufacturerInfo.Key
                    return
                }
            }

            $ansibleFacts.ansible_virtualization_role = 'NA'
            $ansibleFacts.ansible_virtualization_type = 'NA'
        }
    }
)

$groupedSubsets = @{
    min = [System.Collections.Generic.List[string]]@('date_time', 'distribution', 'dns', 'env', 'local', 'platform', 'powershell_version', 'user')
    network = [System.Collections.Generic.List[string]]@('all_ipv4_addresses', 'all_ipv6_addresses', 'interfaces', 'windows_domain', 'winrm')
    hardware = [System.Collections.Generic.List[string]]@('bios', 'memory', 'processor', 'uptime', 'virtual')
    external = [System.Collections.Generic.List[string]]@('facter')
}
# build "all" set from everything mentioned in the group- this means every value must be in at least one subset to be considered legal
$allSet = [System.Collections.Generic.HashSet[string]]@()

foreach ($kv in $groupedSubsets.GetEnumerator()) {
    $null = $allSet.UnionWith($kv.Value)
}

# dynamically create an "all" subset now that we know what should be in it
$groupedSubsets.all = [System.Collections.Generic.List[string]]$allSet

# start with all, build up gather and exclude subsets
$actualSubset = [System.Collections.Generic.HashSet[string]]$groupedSubsets.all
$explicitSubset = [System.Collections.Generic.HashSet[string]]@()
$excludeSubset = [System.Collections.Generic.HashSet[string]]@()

foreach ($item in $gatherSubset) {
    if ($item.StartsWith('!')) {
        $item = $item.Substring(1)

        if ($item -eq "all") {
            $allMinusMin = [System.Collections.Generic.HashSet[string]]@($allSet)
            $null = $allMinusMin.ExceptWith($groupedSubsets.min)
            $null = $excludeSubset.UnionWith($allMinusMin)

        }
        elseif ($groupedSubsets.ContainsKey($item)) {
            $null = $excludeSubset.UnionWith($groupedSubsets[$item])

        }
        elseif ($allSet.Contains($item)) {
            $null = $excludeSubset.Add($item)
        }
        # NB: invalid exclude values are ignored, since that's what posix setup does
    }
    else {
        if ($groupedSubsets.ContainsKey($item)) {
            $null = $explicitSubset.UnionWith($groupedSubsets.$item)

        }
        elseif ($allSet.Contains($item)) {
            $null = $explicitSubset.Add($item)

        }
        else {
            # NB: POSIX setup fails on invalid value; we warn, because we don't implement the same set as POSIX
            # and we don't have platform-specific config for this...
            $module.Warn("invalid value $item specified in gather_subset")
        }
    }
}

$null = $actualSubset.ExceptWith($excludeSubset)
$null = $actualSubset.UnionWith($explicitSubset)

$ansibleFacts = @{
    gather_subset = $gatherSubset
    module_setup = $true
}
if ($measureSubset) {
    $ansibleFacts.measure_info = @{}
}
$module.Result.ansible_facts = $ansibleFacts

foreach ($meta in $factMeta.GetEnumerator()) {
    $metaSubsets = [System.Collections.Generic.HashSet[String]]@($meta.Subsets)

    $skip = $true
    foreach ($subset in $metaSubsets) {
        if ($actualSubset.Contains($subset)) {
            $skip = $false
            break
        }
    }

    if ($skip) {
        continue
    }

    # Originally tried running in parallel with a runspace pool, it didn't reduce the execution time and just added
    # more complexity. Keep running each fact sequentially.
    $ps = [PowerShell]::Create()

    foreach ($varName in @('ansibleFacts', 'factPath', 'module')) {
        $val = Get-Variable -Name $varName -ValueOnly
        $null = $ps.AddCommand('Set-Variable').AddParameters(@{Name = $varName; Value = $val })
    }

    $name = $metaSubsets -join ', '
    if ($measureSubset) {
        $null = $ps.AddScript('$subset = $args[0]; $time = Get-Date').AddArgument($name)
        $null = $ps.AddScript($meta.Code)
        $null = $ps.AddScript(@'
$end = (Get-Date) - $time
$ansibleFacts.measure_info.$subset = $end.TotalSeconds
'@)
    }
    else {
        $null = $ps.AddScript($meta.Code)
    }

    $asyncResult = $ps.BeginInvoke()
    $null = $asyncResult.AsyncWaitHandle.WaitOne($gatherTimeout * 1000)

    if ($asyncResult.IsCompleted) {
        # We don't care about any actual output as each scriptblock sets the ansibleFacts hashtable in the code.
        try {
            $null = $ps.EndInvoke($asyncResult)
        }
        catch {
            # We want to inner error record not the outer error from .EndInvoke()
            $errorRecord = $_.Exception.InnerException.ErrorRecord
            $err = "{0}`n{1}" -f (($errorRecord | Out-String), $errorRecord.ScriptStackTrace)
            $module.Warn("Error when collecting $($name) facts: $err")
        }

        # Make sure we warn on any errors that may have occurred.
        foreach ($errorRecord in $ps.Streams.Error) {
            $err = "{0}`n{1}" -f (($errorRecord | Out-String), $errorRecord.ScriptStackTrace)
            $module.Warn("Error when collecting $($name) facts: $err")
        }

        $ps.Dispose()
    }
    else {
        # Give a best effort chance to stop it, we can't call .Stop() in case it blocks.
        $null = $ps.BeginStop($null, $null)
        $module.Warn("Failed to collection $($name) due to timeout")
    }
}

$module.ExitJson()
