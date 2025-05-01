#!powershell

# Copyright: (c) 2014, Trond Hindenes <trond@hindenes.com>, and others
# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Module Ansible.ModuleUtils.AddType
#AnsibleRequires -PowerShell ..module_utils.Process
#AnsibleRequires -PowerShell ..module_utils.WebRequest

Function Import-PInvokeCode {
    param (
        [Object]
        $Module
    )
    Add-CSharpType -AnsibleModule $Module -References @'
using Microsoft.Win32.SafeHandles;
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Runtime.InteropServices.ComTypes;
using System.Security.Principal;
using System.Text;

//AssemblyReference -Type System.Security.Principal.IdentityReference -CLR Core

namespace Ansible.WinPackage
{
    internal class NativeHelpers
    {
        [StructLayout(LayoutKind.Sequential)]
        public struct PACKAGE_VERSION
        {
            public UInt16 Revision;
            public UInt16 Build;
            public UInt16 Minor;
            public UInt16 Major;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public struct PACKAGE_ID
        {
            public UInt32 reserved;
            public MsixArchitecture processorArchitecture;
            public PACKAGE_VERSION version;
            public string name;
            public string publisher;
            public string resourceId;
            public string publisherId;
        }
    }

    internal class NativeMethods
    {
        [DllImport("Ole32.dll", CharSet = CharSet.Unicode)]
        public static extern UInt32 GetClassFile(
            [MarshalAs(UnmanagedType.LPWStr)] string szFilename,
            ref Guid pclsid);

        [DllImport("Msi.dll")]
        public static extern UInt32 MsiCloseHandle(
            IntPtr hAny);

        [DllImport("Msi.dll", CharSet = CharSet.Unicode)]
        public static extern UInt32 MsiEnumPatchesExW(
            [MarshalAs(UnmanagedType.LPWStr)] string szProductCode,
            [MarshalAs(UnmanagedType.LPWStr)] string szUserSid,
            InstallContext dwContext,
            PatchState dwFilter,
            UInt32 dwIndex,
            StringBuilder szPatchCode,
            StringBuilder szTargetProductCode,
            out InstallContext pdwTargetProductContext,
            StringBuilder szTargetUserSid,
            ref UInt32 pcchTargetUserSid);

        [DllImport("Msi.dll", CharSet = CharSet.Unicode)]
        public static extern UInt32 MsiGetPatchInfoExW(
            [MarshalAs(UnmanagedType.LPWStr)] string szPatchCode,
            [MarshalAs(UnmanagedType.LPWStr)] string szProductCode,
            [MarshalAs(UnmanagedType.LPWStr)] string szUserSid,
            InstallContext dwContext,
            [MarshalAs(UnmanagedType.LPWStr)] string szProperty,
            StringBuilder lpValue,
            ref UInt32 pcchValue);

        [DllImport("Msi.dll", CharSet = CharSet.Unicode)]
        public static extern UInt32 MsiGetPropertyW(
            SafeMsiHandle hInstall,
            [MarshalAs(UnmanagedType.LPWStr)] string szName,
            StringBuilder szValueBuf,
            ref UInt32 pcchValueBuf);

        [DllImport("Msi.dll", CharSet = CharSet.Unicode)]
        public static extern UInt32 MsiGetSummaryInformationW(
            IntPtr hDatabase,
            [MarshalAs(UnmanagedType.LPWStr)] string szDatabasePath,
            UInt32 uiUpdateCount,
            out SafeMsiHandle phSummaryInfo);

        [DllImport("Msi.dll", CharSet = CharSet.Unicode)]
        public static extern UInt32 MsiOpenPackageExW(
            [MarshalAs(UnmanagedType.LPWStr)] string szPackagePath,
            UInt32 dwOptions,
            out SafeMsiHandle hProduct);

        [DllImport("Msi.dll", CharSet = CharSet.Unicode)]
        public static extern InstallState MsiQueryProductStateW(
            [MarshalAs(UnmanagedType.LPWStr)] string szProduct);

        [DllImport("Msi.dll", CharSet = CharSet.Unicode)]
        public static extern UInt32 MsiSummaryInfoGetPropertyW(
            SafeHandle hSummaryInfo,
            UInt32 uiProperty,
            out UInt32 puiDataType,
            out Int32 piValue,
            ref System.Runtime.InteropServices.ComTypes.FILETIME pftValue,
            StringBuilder szValueBuf,
            ref UInt32 pcchValueBuf);

        [DllImport("Kernel32.dll", CharSet = CharSet.Unicode)]
        public static extern UInt32 PackageFullNameFromId(
            NativeHelpers.PACKAGE_ID packageId,
            ref UInt32 packageFamilyNameLength,
            StringBuilder packageFamilyName);
    }

    [Flags]
    public enum InstallContext : uint
    {
        None = 0x00000000,
        UserManaged = 0x00000001,
        UserUnmanaged = 0x00000002,
        Machine = 0x00000004,
        AllUserManaged = 0x00000008,
        All = UserManaged | UserUnmanaged | Machine,
    }

    public enum InstallState : int
    {
        NotUsed = -7,
        BadConfig = -6,
        Incomplete = -5,
        SourceAbsent = -4,
        MoreData = -3,
        InvalidArg = -2,
        Unknown = -1,
        Broken = 0,
        Advertised = 1,
        Absent = 2,
        Local = 3,
        Source = 4,
        Default = 5,
    }

    public enum MsixArchitecture : uint
    {
        X86 = 0,
        Arm = 5,
        X64 = 9,
        Neutral = 11,
        Arm64 = 12,
    }

    [Flags]
    public enum PatchState : uint
    {
        Invalid = 0x00000000,
        Applied = 0x00000001,
        Superseded = 0x00000002,
        Obsoleted = 0x00000004,
        Registered = 0x00000008,
        All = Applied | Superseded | Obsoleted | Registered,
    }

    public class SafeMsiHandle : SafeHandleZeroOrMinusOneIsInvalid
    {
        public SafeMsiHandle() : base(true) { }

        protected override bool ReleaseHandle()
        {
            UInt32 res = NativeMethods.MsiCloseHandle(handle);
            return res == 0;
        }
    }

    public class PatchInfo
    {
        public string PatchCode;
        public string ProductCode;
        public InstallContext Context;
        public SecurityIdentifier UserSid;
    }

    public class MsixHelper
    {
        public static string GetPackageFullName(string identity, string version, string publisher,
            MsixArchitecture architecture, string resourceId)
        {
            string[] versionSplit = version.Split(new char[] {'.'}, 4);
            NativeHelpers.PACKAGE_ID id = new NativeHelpers.PACKAGE_ID()
            {
                processorArchitecture = architecture,
                version = new NativeHelpers.PACKAGE_VERSION()
                {
                    Revision = Convert.ToUInt16(versionSplit.Length > 3 ? versionSplit[3] : "0"),
                    Build = Convert.ToUInt16(versionSplit.Length > 2 ? versionSplit[2] : "0"),
                    Minor = Convert.ToUInt16(versionSplit.Length > 1 ? versionSplit[1] : "0"),
                    Major = Convert.ToUInt16(versionSplit[0]),
                },
                name = identity,
                publisher = publisher,
                resourceId = resourceId,
            };

            UInt32 fullNameLength = 0;
            UInt32 res = NativeMethods.PackageFullNameFromId(id, ref fullNameLength, null);
            if (res != 122)  // ERROR_INSUFFICIENT_BUFFER
                throw new Win32Exception((int)res);

            StringBuilder fullName = new StringBuilder((int)fullNameLength);
            res = NativeMethods.PackageFullNameFromId(id, ref fullNameLength, fullName);
            if (res != 0)
                throw new Win32Exception((int)res);

            return fullName.ToString();
        }
    }

    public class MsiHelper
    {
        public static UInt32 SUMMARY_PID_TEMPLATE = 7;
        public static UInt32 SUMMARY_PID_REVNUMBER = 9;

        private static Guid MSI_CLSID = new Guid("000c1084-0000-0000-c000-000000000046");
        private static Guid MSP_CLSID = new Guid("000c1086-0000-0000-c000-000000000046");

        public static IEnumerable<PatchInfo> EnumPatches(string productCode, string userSid, InstallContext context,
            PatchState filter)
        {
            // PowerShell -> .NET, $null for a string parameter becomes an empty string, make sure we convert back.
            productCode = String.IsNullOrEmpty(productCode) ? null : productCode;
            userSid = String.IsNullOrEmpty(userSid) ? null : userSid;

            UInt32 idx = 0;
            while (true)
            {
                StringBuilder targetPatchCode = new StringBuilder(39);
                StringBuilder targetProductCode = new StringBuilder(39);
                InstallContext targetContext;
                StringBuilder targetUserSid = new StringBuilder(0);
                UInt32 targetUserSidLength = 0;

                UInt32 res = NativeMethods.MsiEnumPatchesExW(productCode, userSid, context, filter, idx,
                    targetPatchCode, targetProductCode, out targetContext, targetUserSid, ref targetUserSidLength);

                SecurityIdentifier sid = null;
                if (res == 0x000000EA)  // ERROR_MORE_DATA
                {
                    targetUserSidLength++;
                    targetUserSid.EnsureCapacity((int)targetUserSidLength);

                    res = NativeMethods.MsiEnumPatchesExW(productCode, userSid, context, filter, idx,
                        targetPatchCode, targetProductCode, out targetContext, targetUserSid, ref targetUserSidLength);

                    sid = new SecurityIdentifier(targetUserSid.ToString());
                }

                if (res == 0x00000103)  // ERROR_NO_MORE_ITEMS
                    break;
                else if (res != 0)
                    throw new Win32Exception((int)res);

                yield return new PatchInfo()
                {
                    PatchCode = targetPatchCode.ToString(),
                    ProductCode = targetProductCode.ToString(),
                    Context = targetContext,
                    UserSid = sid,
                };
                idx++;
            }
        }

        public static string GetPatchInfo(string patchCode, string productCode, string userSid, InstallContext context,
            string property)
        {
            // PowerShell -> .NET, $null for a string parameter becomes an empty string, make sure we convert back.
            userSid = String.IsNullOrEmpty(userSid) ? null : userSid;

            StringBuilder buffer = new StringBuilder(0);
            UInt32 bufferLength = 0;
            NativeMethods.MsiGetPatchInfoExW(patchCode, productCode, userSid, context, property, buffer,
                ref bufferLength);

            bufferLength++;
            buffer.EnsureCapacity((int)bufferLength);

            UInt32 res = NativeMethods.MsiGetPatchInfoExW(patchCode, productCode, userSid, context, property, buffer,
                ref bufferLength);
            if (res != 0)
                throw new Win32Exception((int)res);

            return buffer.ToString();
        }

        public static string GetProperty(SafeMsiHandle productHandle, string property)
        {
            StringBuilder buffer = new StringBuilder(0);
            UInt32 bufferLength = 0;
            NativeMethods.MsiGetPropertyW(productHandle, property, buffer, ref bufferLength);

            // Make sure we include the null byte char at the end.
            bufferLength += 1;
            buffer.EnsureCapacity((int)bufferLength);

            UInt32 res = NativeMethods.MsiGetPropertyW(productHandle, property, buffer, ref bufferLength);
            if (res != 0)
                throw new Win32Exception((int)res);

            return buffer.ToString();
        }

        public static SafeMsiHandle GetSummaryHandle(string databasePath)
        {
            SafeMsiHandle summaryInfo = null;
            UInt32 res = NativeMethods.MsiGetSummaryInformationW(IntPtr.Zero, databasePath, 0, out summaryInfo);
            if (res != 0)
                throw new Win32Exception((int)res);

            return summaryInfo;
        }

        public static string GetSummaryPropertyString(SafeMsiHandle summaryHandle, UInt32 propertyId)
        {
            UInt32 dataType = 0;
            Int32 intPropValue = 0;
            System.Runtime.InteropServices.ComTypes.FILETIME propertyFiletime =
                new System.Runtime.InteropServices.ComTypes.FILETIME();
            StringBuilder buffer = new StringBuilder(0);
            UInt32 bufferLength = 0;

            NativeMethods.MsiSummaryInfoGetPropertyW(summaryHandle, propertyId, out dataType, out intPropValue,
                ref propertyFiletime, buffer, ref bufferLength);

            // Make sure we include the null byte char at the end.
            bufferLength += 1;
            buffer.EnsureCapacity((int)bufferLength);

            UInt32 res = NativeMethods.MsiSummaryInfoGetPropertyW(summaryHandle, propertyId, out dataType,
                out intPropValue, ref propertyFiletime, buffer, ref bufferLength);
            if (res != 0)
                throw new Win32Exception((int)res);

            return buffer.ToString();
        }

        public static bool IsMsi(string filename)
        {
            return GetClsid(filename) == MSI_CLSID;
        }

        public static bool IsMsp(string filename)
        {
            return GetClsid(filename) == MSP_CLSID;
        }

        public static SafeMsiHandle OpenPackage(string packagePath, bool ignoreMachineState)
        {
            SafeMsiHandle packageHandle = null;
            UInt32 options = 0;
            if (ignoreMachineState)
                options |= 1;  // MSIOPENPACKAGEFLAGS_IGNOREMACHINESTATE

            UInt32 res = NativeMethods.MsiOpenPackageExW(packagePath, options, out packageHandle);
            if (res != 0)
                throw new Win32Exception((int)res);

            return packageHandle;
        }

        public static InstallState QueryProductState(string productCode)
        {
            return NativeMethods.MsiQueryProductStateW(productCode);
        }

        private static Guid GetClsid(string filename)
        {
            Guid clsid = Guid.Empty;
            NativeMethods.GetClassFile(filename, ref clsid);

            return clsid;
        }
    }
}
'@
}

Function Add-SystemReadAce {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingEmptyCatchBlock', '',
        Justification = 'Failing to get or set the ACE is not critical, SYSTEM could still have access without it.')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Path
    )

    # Don't set the System ACE if the path is a UNC path as the SID won't be valid.
    if (([Uri]$Path).IsUnc) {
        return
    }

    # If $Path is on a read only file system or one that doesn't support ACLs then this will fail. SYSTEM might still
    # have access to the path so don't treat it as critical.
    # https://github.com/ansible-collections/ansible.windows/issues/142
    try {
        $acl = Get-Acl -LiteralPath $Path
    }
    catch {
        return
    }

    $ace = New-Object -TypeName System.Security.AccessControl.FileSystemAccessRule -ArgumentList @(
        (New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList ('S-1-5-18')),
        [System.Security.AccessControl.FileSystemRights]::Read,
        [System.Security.AccessControl.AccessControlType]::Allow
    )
    $acl.AddAccessRule($ace)

    try {
        $acl | Set-Acl -LiteralPath $path
    }
    catch {}
}

Function Get-UrlFile {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Object]
        $Module,

        [Parameter(Mandatory = $true)]
        [String]
        $Url
    )

    $request = (Get-AnsibleWindowsWebRequest -Url $Url -Module $module)
    Invoke-AnsibleWindowsWebRequest -Module $module -Request $request -Script {
        Param ([System.Net.WebResponse]$Response, [System.IO.Stream]$Stream)

        $tempPath = Join-Path -Path $module.Tmpdir -ChildPath $Response.ResponseUri.Segments[-1]
        $fs = [System.IO.File]::Create($tempPath)
        try {
            $Stream.CopyTo($fs)
            $fs.Flush()
        }
        finally {
            $fs.Dispose()
        }

        $tempPath
    }
}

Function Format-PackageStatus {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [String]
        $Id,

        [Parameter(Mandatory = $true)]
        [String]
        $Provider,

        [Switch]
        $Installed,

        [Switch]
        $Skip,

        [Switch]
        $SkipFileForRemove,

        [Hashtable]
        $ExtraInfo = @{}
    )

    @{
        Id = $Id
        Installed = $Installed.IsPresent
        Provider = $Provider
        Skip = $Skip.IsPresent
        SkipFileForRemove = $SkipFileForRemove.IsPresent
        ExtraInfo = $ExtraInfo
    }
}

Function Get-InstalledStatus {
    [CmdletBinding()]
    param (
        [String]
        $Path,

        [String]
        $Id,

        [String]
        $Provider,

        [String]
        $CreatesPath,

        [String]
        $CreatesService,

        [String]
        $CreatesVersion
    )

    if ($Path) {
        if ($Provider -eq 'auto') {
            foreach ($info in $providerInfo.GetEnumerator()) {
                if ((&$info.Value.FileSupported -Path $Path)) {
                    $Provider = $info.Key
                    break
                }
            }
        }

        $status = &$providerInfo."$Provider".Test -Path $Path -Id $Id
    }
    else {
        if ($Provider -eq 'auto') {
            # While we only technically support 2012+ this is a fairly small thing to do to ensure this
            # continues to run on Server 2008 and 2008 R2. This should be removed sometime in the future.
            # https://github.com/ansible-collections/ansible.windows/issues/362
            $msixAvailable = [bool](Get-Command -Name Get-AppxPackage -ErrorAction SilentlyContinue)
            $providerList = [String[]]$providerInfo.Keys | Where-Object { $_ -ne 'msix' -or $msixAvailable }
        }
        else {
            $providerList = @($Provider)
        }

        foreach ($name in $providerList) {
            $status = &$providerInfo."$name".Test -Id $Id

            # If the package was installed for the provider (or was the last provider available).
            if ($status.Installed -or $providerList[-1] -eq $name) {
                break
            }
        }
    }

    if ($CreatesPath) {
        $exists = Test-Path -LiteralPath $CreatesPath
        $status.Installed = $exists

        if ($CreatesVersion -and $exists) {
            if (Test-Path -LiteralPath $CreatesPath -PathType Leaf) {
                $versionRaw = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($CreatesPath)
                $existingVersion = New-Object -TypeName System.Version -ArgumentList @(
                    $versionRaw.FileMajorPart, $versionRaw.FileMinorPart, $versionRaw.FileBuildPart,
                    $versionRaw.FilePrivatePart
                )
                $status.Installed = $CreatesVersion -eq $existingVersion
            }
            else {
                throw "creates_path must be a file not a directory when creates_version is set"
            }
        }
    }

    if ($CreatesService) {
        $serviceInfo = Get-Service -Name $CreatesService -ErrorAction SilentlyContinue
        $status.Installed = $null -ne $serviceInfo
    }

    Format-PackageStatus @status
}

Function Invoke-Executable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Object]
        $Module,

        [Parameter(Mandatory = $true)]
        [String]
        $CommandLine,

        [Int32[]]
        $ReturnCodes,

        [String]
        $LogPath,

        [String]
        $WorkingDirectory,

        [String]
        $ConsoleOutputEncoding,

        [Switch]
        $WaitChildren
    )

    $commandArgs = @{
        CommandLine = $CommandLine
        WaitChildren = $WaitForChildren
    }
    if ($WorkingDirectory) {
        $commandArgs.WorkingDirectory = $WorkingDirectory
    }
    if ($ConsoleOutputEncoding) {
        $commandArgs.OutputEncodingOverride = $ConsoleOutputEncoding
    }

    $result = Start-AnsibleWindowsProcess @commandArgs

    # Start-AnsibleWindowsProcess returns rc as a UInt32 but we need to compare it with a Int32, we get the byte
    # equivalent Int32 value instead. https://github.com/ansible-collections/ansible.windows/issues/46
    $rc = [BitConverter]::ToInt32([BitConverter]::GetBytes($result.ExitCode), 0)

    $module.Result.rc = $rc
    if ($ReturnCodes -notcontains $rc) {
        $module.Result.stdout = $result.Stdout
        $module.Result.stderr = $result.Stderr
        if ($LogPath -and (Test-Path -LiteralPath $LogPath)) {
            $module.Result.log = (Get-Content -LiteralPath $LogPath | Out-String)
        }

        $module.FailJson("unexpected rc from '$($result.Command)': see rc, stdout, and stderr for more details")
    }
    else {
        $module.Result.failed = $false
    }

    if ($rc -eq 3010) {
        $module.Result.reboot_required = $true
    }
}

Function Invoke-Msiexec {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Object]
        $Module,

        [Parameter(Mandatory = $true)]
        [String[]]
        $Actions,

        [String]
        $Arguments,

        [Int32[]]
        $ReturnCodes,

        [String]
        $LogPath,

        [String]
        $WorkingDirectory,

        [Switch]
        $WaitChildren
    )

    $tempFile = $null
    try {
        if (-not $LogPath) {
            $tempFile = Join-Path -Path $module.Tmpdir -ChildPath "msiexec.log"
            $LogPath = $tempFile
        }

        $cmd = [System.Collections.Generic.List[String]]@("$env:SystemRoot\System32\msiexec.exe")
        $cmd.AddRange([System.Collections.Generic.List[String]]$Actions)
        $cmd.AddRange([System.Collections.Generic.List[String]]@(
                '/L*V', $LogPath, '/qn', '/norestart'
            ))
        $commandLine = @($cmd | ConvertTo-EscapedArgument) -join ' '
        if ($Arguments) {
            $commandLine += " $Arguments"
        }

        $invokeParams = @{
            Module = $Module
            CommandLine = $commandLine
            ReturnCodes = $ReturnCodes
            LogPath = $LogPath
            WorkingDirectory = $WorkingDirectory
            WaitChildren = $WaitChildren

            # Msiexec is not a console application but in the case of a fatal error it does still send messages back
            # over the stdout pipe. These messages are UTF-16 encoded so we override the default UTF-8.
            ConsoleOutputEncoding = 'Unicode'
        }

        Invoke-Executable @invokeParams
    }
    finally {
        if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
            Remove-Item -LiteralPath $tempFile -Force
        }
    }
}

$providerInfo = [Ordered]@{
    msi = @{
        FileSupported = {
            param ([String]$Path)

            [Ansible.WInPackage.MsiHelper]::IsMsi($Path)
        }

        Test = {
            param ([String]$Path, [String]$Id)

            if ($Path) {
                # MSIs have 2 types of ids that are important here
                #     ProductCode: Unique id for the app, could change across major versions, minor stays the same
                #     PackageCode: Unique id for the msi itself, no msi should have a matching package code
                #
                # Because we cannot install multiple msi's with the same product code we use this to determine if its
                # installed or not. When we open a handle to the package we also need to ignore the current machine
                # state, without that MsiOpenPackage will fail with ERROR_PRODUCT_VERSION if the ProductCode of the
                # msi is already installed but under a different PackageCode. When ignoring it we can still get the
                # ProductCode and check the status ourselves.
                # https://github.com/ansible-collections/ansible.windows/issues/166

                $msiHandle = [Ansible.WinPackage.MsiHelper]::OpenPackage($Path, $true)
                try {
                    $Id = [Ansible.WinPackage.MsiHelper]::GetProperty($msiHandle, 'ProductCode')
                }
                finally {
                    $msiHandle.Dispose()
                }
            }

            $installState = [Ansible.WinPackage.MsiHelper]::QueryProductState($Id)

            @{
                Provider = 'msi'
                Id = $Id
                Installed = $installState -eq [Ansible.WinPackage.InstallState]::Default
                SkipFileForRemove = $true
            }
        }

        Set = {
            param (
                [String]
                $Arguments,

                [Int32[]]
                $ReturnCodes,

                [String]
                $Id,

                [String]
                $LogPath,

                [Object]
                $Module,

                [String]
                $Path,

                [String]
                $State,

                [String]
                $WorkingDirectory,

                [Switch]
                $WaitChildren
            )

            if ($state -eq 'present') {
                $actions = @('/i', $Path)

                # $Module.Tmpdir only gives rights to the current user but msiexec (as SYSTEM) needs access.
                Add-SystemReadAce -Path $Path
            }
            else {
                $actions = @('/x', $Id)
            }

            $invokeParams = @{
                Module = $Module
                Actions = $actions
                Arguments = $Arguments
                ReturnCodes = $ReturnCodes
                LogPath = $LogPath
                WorkingDirectory = $WorkingDirectory
                WaitChildren = $WaitChildren
            }
            Invoke-Msiexec @invokeParams
        }
    }

    msix = @{
        FileSupported = {
            param ([String]$Path)

            $extension = [System.IO.Path]::GetExtension($Path)

            $extension -in @('.appx', '.appxbundle', '.msix', '.msixbundle')
        }

        Test = {
            param ([String]$Path, [String]$Id)

            $package = $null

            if ($Path) {
                # Cannot find a native way to get the package info from the actual path so we need to inspect the XML
                # manually.
                $null = Add-Type -AssemblyName System.IO.Compression
                $null = Add-Type -AssemblyName System.IO.Compression.FileSystem

                $archive = [System.IO.Compression.ZipFile]::Open($Path, [System.IO.Compression.ZipArchiveMode]::Read,
                    [System.Text.Encoding]::UTF8)
                try {
                    $manifestEntry = $archive.Entries | Where-Object {
                        $_.FullName -in @('AppxManifest.xml', 'AppxMetadata/AppxBundleManifest.xml')
                    }
                    $manifestStream = New-Object -TypeName System.IO.StreamReader -ArgumentList $manifestEntry.Open()
                    try {
                        $manifest = [xml]$manifestStream.ReadToEnd()
                    }
                    finally {
                        $manifestStream.Dispose()
                    }
                }
                finally {
                    $archive.Dispose()
                }

                if ($manifestEntry.Name -eq 'AppxBundleManifest.xml') {
                    # https://docs.microsoft.com/en-us/uwp/schemas/bundlemanifestschema/element-identity
                    $name = $manifest.Bundle.Identity.Name
                    $publisher = $manifest.Bundle.Identity.Publisher

                    $Ids = foreach ($p in $manifest.Bundle.Packages.Package) {
                        $version = $p.Version

                        $architecture = 'neutral'
                        if ($p.HasAttribute('Architecture')) {
                            $architecture = $p.Architecture
                        }

                        $resourceId = ''
                        if ($p.HasAttribute('ResourceId')) {
                            $resourceId = $p.ResourceId
                        }

                        [Ansible.WinPackage.MsixHelper]::GetPackageFullName($name, $version, $publisher, $architecture,
                            $resourceId)
                    }
                }
                else {
                    # https://docs.microsoft.com/en-us/uwp/schemas/appxpackage/uapmanifestschema/element-identity
                    $name = $manifest.Package.Identity.Name
                    $version = $manifest.Package.Identity.Version
                    $publisher = $manifest.Package.Identity.Publisher

                    $architecture = 'neutral'
                    if ($manifest.Package.Identity.HasAttribute('ProcessorArchitecture')) {
                        $architecture = $manifest.Package.Identity.ProcessorArchitecture
                    }

                    $resourceId = ''
                    if ($manifest.Package.Identity.HasAttribute('ResourceId')) {
                        $resourceId = $manifest.$identityParent.Identity.ResourceId
                    }

                    $Ids = @(, [Ansible.WinPackage.MsixHelper]::GetPackageFullName($name, $version, $publisher,
                            $architecture, $resourceId)
                    )
                }
            }
            else {
                $package = Get-AppxPackage -Name $Id -ErrorAction SilentlyContinue
                $Ids = @($Id)
            }

            # In the case when a file is specified or the user has set the full name and not the name, scan again for
            # PackageFullName.
            if ($null -eq $package) {
                $package = Get-AppxPackage | Where-Object { $_.PackageFullName -in $Ids }
            }

            # Make sure the Id is set to the PackageFullName so state=absent works.
            if ($package) {
                $Id = $package.PackageFullName
            }

            @{
                Provider = 'msix'
                Id = $Id
                Installed = $null -ne $package
            }
        }

        Set = {
            param (
                [String]
                $Id,

                [Object]
                $Module,

                [String]
                $Path,

                [String]
                $State
            )
            $originalProgress = $ProgressPreference
            try {
                $ProgressPreference = 'SilentlyContinue'
                if ($State -eq 'present') {
                    # Add-AppxPackage does not support a -LiteralPath parameter and it chokes on wildcard characters.
                    # We need to escape those characters when calling the cmdlet.
                    Add-AppxPackage -Path ([WildcardPattern]::Escape($Path))
                }
                else {
                    Remove-AppxPackage -Package $Id
                }
            }
            catch {
                # Replicate the same return values as the other providers.
                $module.Result.rc = $_.Exception.HResult
                $module.Result.stdout = ""
                $module.Result.stderr = $_.Exception.Message

                $msg = "unexpected status from $($_.InvocationInfo.InvocationName): see rc and stderr for more details"
                $module.FailJson($msg, $_)
            }
            finally {
                $ProgressPreference = $originalProgress
            }

            # Just set to 0 to align with other providers
            $module.Result.rc = 0

            # It looks like the reboot checks are an insider feature so we can't do a check for that today.
            # https://docs.microsoft.com/en-us/windows/msix/packaging-tool/support-restart
        }
    }

    msp = @{
        FileSupported = {
            param ([String]$Path)

            [Ansible.WInPackage.MsiHelper]::IsMsp($Path)
        }

        Test = {
            param ([String]$Path, [String]$Id)

            $productCodes = [System.Collections.Generic.List[System.String]]@()
            if ($Path) {
                $summaryInfo = [Ansible.WinPackage.MsiHelper]::GetSummaryHandle($Path)
                try {
                    $productCodesRaw = [Ansible.WinPackage.MsiHelper]::GetSummaryPropertyString(
                        $summaryInfo, [Ansible.WinPackage.MsiHelper]::SUMMARY_PID_TEMPLATE
                    )

                    # Filter out product codes that are not installed on the host.
                    foreach ($code in ($productCodesRaw -split ';')) {
                        $productState = [Ansible.WinPackage.MsiHelper]::QueryProductState($code)
                        if ($productState -eq [Ansible.WinPackage.InstallState]::Default) {
                            $productCodes.Add($code)
                        }
                    }

                    if ($productCodes.Count -eq 0) {
                        throw "The specified patch does not apply to any installed MSI packages."
                    }

                    # The first guid in the REVNUMBER is the patch code, the subsequent values are obsoleted patches
                    # which we don't care about.
                    $Id = [Ansible.WinPackage.MsiHelper]::GetSummaryPropertyString($summaryInfo,
                        [Ansible.WinPackage.MsiHelper]::SUMMARY_PID_REVNUMBER).Substring(0, 38)
                }
                finally {
                    $summaryInfo.Dispose()
                }
            }
            else {
                foreach ($patch in ([Ansible.WinPackage.MsiHelper]::EnumPatches($null, $null, 'All', 'All'))) {
                    if ($patch.PatchCode -eq $Id) {
                        # We append "{guid}:{context}" so the check below checks the proper context, the context
                        # is then stripped out there.
                        $ProductCodes.Add("$($patch.ProductCode):$($patch.Context)")
                    }
                }
            }

            # Filter the product list even further to only ones that are applied and not obsolete.
            $skipCodes = [System.Collections.Generic.List[System.String]]@()
            $productCodes = @(@(foreach ($product in $productCodes) {
                        if ($product.Length -eq 38) {
                            # Guid length with braces is 38
                            $contextList = @('UserManaged', 'UserUnmanaged', 'Machine')
                        }
                        else {
                            # We already know the context and was appended to the product guid with ';context'
                            $productInfo = $product.Split(':', 2)
                            $product = $productInfo[0]
                            $contextList = @($productInfo[1])
                        }

                        foreach ($context in $contextList) {
                            try {
                                # GetPatchInfo('State') returns a string that is a number of an enum value.
                                $state = [Ansible.WinPackage.PatchState][UInt32]([Ansible.WinPackage.MsiHelper]::GetPatchInfo(
                                        $Id, $product, $null, $context, 'State'
                                    ))
                            }
                            catch [System.ComponentModel.Win32Exception] {
                                if ($_.Exception.NativeErrorCode -in @(0x00000645, 0x0000066F)) {
                                    # ERROR_UNKNOWN_PRODUCT can be raised if the product is not installed in the context
                                    # specified, just try the next one.
                                    # ERROR_UNKNOWN_PATCH can be raised if the patch is not installed but the product is.
                                    continue
                                }
                                throw
                            }

                            if ($state -eq [Ansible.WinPackage.PatchState]::Applied) {
                                # The patch is applied to the product code, output the code for the outer list to capture.
                                $product
                            }
                            elseif ($state.ToString() -in @('Obsoleted', 'Superseded')) {
                                # If the patch is obsoleted or suprseded we cannot install or remove but consider it equal to
                                # state=absent and present so we skip the set step.
                                $skipCodes.Add($product)
                            }
                        }
                    }) | Select-Object -Unique)

            @{
                Provider = 'msp'
                Id = $Id
                Installed = $productCodes.Length -gt 0
                Skip = $skipCodes.Length -eq $productCodes.Length
                SkipFileForRemove = $true
                ExtraInfo = @{
                    ProductCodes = $productCodes
                }
            }
        }

        Set = {
            param (
                [String]
                $Arguments,

                [Int32[]]
                $ReturnCodes,

                [String]
                $Id,

                [String]
                $LogPath,

                [Object]
                $Module,

                [String]
                $Path,

                [String]
                $State,

                [String]
                $WorkingDirectory,

                [Switch]
                $WaitChildren,

                [String[]]
                $ProductCodes
            )

            $tempLink = $null
            try {
                $actions = @(if ($state -eq 'present') {
                        # $Module.Tmpdir only gives rights to the current user but msiexec (as SYSTEM) needs access.
                        Add-SystemReadAce -Path $Path

                        # MsiApplyPatchW fails if the path contains a ';', we need to use a temporary symlink instead.
                        # https://docs.microsoft.com/en-us/windows/win32/api/msi/nf-msi-msiapplypatchw
                        if ($Path.Contains(';')) {
                            $tempLink = Join-Path -Path $env:TEMP -ChildPath "win_package-$([System.IO.Path]::GetRandomFileName()).msp"
                            $res = Start-AnsibleWindowsProcess -FilePath cmd.exe -ArgumentList @('/c', 'mklink', $tempLink, $Path)
                            if ($res.ExitCode -ne 0) {
                                $Module.Result.rc = $res.ExitCode
                                $Module.Result.stdout = $res.Stdout
                                $Module.Result.stderr = $res.Stderr

                                $msg = "Failed to create temporary symlink '$tempLink' -> '$Path' for msiexec patch install as path contains semicolon"
                                $Module.FailJson($msg)
                            }
                            $Path = $tempLink
                        }

                        , @('/update', $Path)
                    }
                    else {
                        foreach ($code in $ProductCodes) {
                            , @('/uninstall', $Id, '/package', $code)
                        }
                    })

                $invokeParams = @{
                    Arguments = $Arguments
                    Module = $Module
                    ReturnCodes = $ReturnCodes
                    LogPath = $LogPath
                    WorkingDirectory = $WorkingDirectory
                    WaitChildren = $WaitChildren
                }
                foreach ($action in $actions) {
                    Invoke-Msiexec -Actions $action @invokeParams
                }
            }
            finally {
                if ($tempLink -and (Test-Path -LiteralPath $tempLink)) {
                    Remove-Item -LiteralPath $tempLink -Force
                }
            }
        }
    }

    # Should always be last as the FileSupported is a catch all.
    registry = @{
        FileSupported = { $true }

        Test = {
            param ([String]$Id)

            $status = @{
                Provider = 'registry'
                Id = $Id
                Installed = $false
                ExtraInfo = @{
                    RegistryPath = $null
                }
            }

            if ($Id) {
                :regLoop foreach ($hive in @("HKLM", "HKCU")) {
                    # Search machine wide and user specific.
                    foreach ($key in @("SOFTWARE", "SOFTWARE\Wow6432Node")) {
                        # Search the 32 and 64-bit locations.
                        $regPath = "$($hive):\$key\Microsoft\Windows\CurrentVersion\Uninstall\$Id"
                        if (Test-Path -LiteralPath $regPath) {
                            $status.Installed = $true
                            $status.ExtraInfo.RegistryPath = $regPath
                            break regLoop
                        }
                    }
                }
            }

            $status
        }

        Set = {
            param (
                [String]
                $Arguments,

                [Int32[]]
                $ReturnCodes,

                [Object]
                $Module,

                [String]
                $Path,

                [String]
                $State,

                [String]
                $WorkingDirectory,

                [String]
                $RegistryPath,

                [Switch]
                $WaitChildren
            )

            $invokeParams = @{
                Module = $Module
                ReturnCodes = $ReturnCodes
                WorkingDirectory = $WorkingDirectory
                WaitChildren = $WaitChildren
            }

            if ($Path) {
                $invokeParams.CommandLine = ConvertTo-EscapedArgument -InputObject $Path
            }
            else {
                $registryProperties = Get-ItemProperty -LiteralPath $RegistryPath

                if ('QuietUninstallString' -in $registryProperties.PSObject.Properties.Name) {
                    $command = $registryProperties.QuietUninstallString
                }
                elseif ('UninstallString' -in $registryProperties.PSObject.Properties.Name) {
                    $command = $registryProperties.UninstallString
                }
                else {
                    $module.FailJson("Failed to find registry uninstall string at registry path '$RegistryPath'")
                }

                # If the uninstall string starts with '%', we need to expand the env vars.
                if ($command.StartsWith('%') -or $command.StartsWith('"%')) {
                    $command = [System.Environment]::ExpandEnvironmentVariables($command)
                }

                # If the command is not quoted and contains spaces we need to see if it needs to be manually quoted for the executable.
                if (-not $command.StartsWith('"') -and $command.Contains(' ')) {
                    $rawArguments = [System.Collections.Generic.List[String]]@()

                    $executable = New-Object -TypeName System.Text.StringBuilder
                    foreach ($cmd in ($command | ConvertFrom-EscapedArgument)) {
                        if ($rawArguments.Count -eq 0) {
                            # Still haven't found the path, append the arg to the executable path and see if it exists.
                            $null = $executable.Append($cmd)
                            $exe = $executable.ToString()
                            if (Test-Path -LiteralPath $exe -PathType Leaf) {
                                $rawArguments.Add($exe)
                            }
                            else {
                                $null = $executable.Append(" ")  # The arg had a space and we need to preserve that.
                            }
                        }
                        else {
                            $rawArguments.Add($cmd)
                        }
                    }

                    # If we still couldn't find a file just use the command literally and hope WIndows can handle it,
                    # otherwise recombine the args which will also quote whatever is needed.
                    if ($rawArguments.Count -gt 0) {
                        $command = @($rawArguments | ConvertTo-EscapedArgument) -join ' '
                    }
                }

                $invokeParams.CommandLine = $command
            }

            if ($Arguments) {
                $invokeParams.CommandLine += " $Arguments"
            }

            Invoke-Executable @invokeParams
        }
    }
}

$spec = @{
    options = @{
        arguments = @{ type = "raw" }
        expected_return_code = @{ type = "list"; elements = "int"; default = @(0, 3010) }
        path = @{ type = "str" }
        chdir = @{ type = "path" }
        checksum = @{ type = 'str' }
        checksum_algorithm = @{ type = 'str'; default = 'sha1'; choices = @("md5", "sha1", "sha256", "sha384", "sha512") }
        product_id = @{ type = "str" }
        state = @{
            type = "str"
            default = "present"
            choices = "absent", "present"
        }
        creates_path = @{ type = "path" }
        creates_version = @{ type = "str" }
        creates_service = @{ type = "str" }
        log_path = @{ type = "path" }
        provider = @{ type = "str"; default = "auto"; choices = $providerInfo.Keys + "auto" }
        wait_for_children = @{ type = 'bool'; default = $false }
    }
    required_by = @{
        creates_version = "creates_path"
    }
    required_if = @(
        @("state", "present", @("path")),
        @("state", "absent", @("path", "product_id"), $true)
    )
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec, @(Get-AnsibleWindowsWebRequestSpec))

$arguments = $module.Params.arguments
$expectedReturnCode = $module.Params.expected_return_code
$path = $module.Params.path
$chdir = $module.Params.chdir
$checksum = $module.Params.checksum
$checksum_algorithm = $module.Params.checksum_algorithm
$productId = $module.Params.product_id
$state = $module.Params.state
$createsPath = $module.Params.creates_path
$createsVersion = $module.Params.creates_version
$createsService = $module.Params.creates_service
$logPath = $module.Params.log_path
$provider = $module.Params.provider
$waitForChildren = $module.Params.wait_for_children

$module.Result.reboot_required = $false

if ($null -ne $arguments) {
    # convert a list to a string and escape the values
    if ($arguments -is [array]) {
        $arguments = @($arguments | ConvertTo-EscapedArgument) -join ' '
    }
}

# This must be set after the module spec so the validate-modules sanity-test can get the arg spec.
Import-PInvokeCode -Module $module

$pathType = $null
if ($path -and $path.StartsWith('http', [System.StringComparison]::InvariantCultureIgnoreCase)) {
    $pathType = 'url'
}

$tempFile = $null
try {
    $getParams = @{
        Id = $productId
        Provider = $provider
        CreatesPath = $createsPath
        CreatesVersion = $createsVersion
        CreatesService = $createsService
    }

    # If the package is a remote file, productId is set and state is set to present
    # then check if the package is installed and avoid downloading the package to a temp file.
    if ($pathType -and $productId -and ($state -eq 'present')) {
        $packageStatus = Get-InstalledStatus @getParams
    }
    # If the path is a URL and no productId is set or we already checked and the package is not installed
    # then create a temp copy for idempotency checks.
    if (($pathType) -and (-not $productId -or -not $packageStatus.Installed)) {
        $tempFile = switch ($pathType) {
            url { Get-UrlFile -Module $module -Url $path }
        }
        $path = $tempFile
        $getParams.Path = $path
    }
    elseif ($path -and -not $pathType) {
        if (-not (Test-Path -LiteralPath $path) -and -not $module.CheckMode) {
            $module.FailJson("the file at the path '$path' cannot be reached")
        }
        $getParams.Path = $path
    }

    # Check package installation status unless this was already done and we know the package is installed
    if (-not $packageStatus.Installed) {
        $packageStatus = Get-InstalledStatus @getParams
    }

    $changed = -not $packageStatus.Skip -and (($state -eq 'present') -ne $packageStatus.Installed)
    $module.Result.rc = 0  # Make sure rc is always set
    if ($changed -and -not $module.CheckMode) {
        # Make sure we get a temp copy of the file if the provider requires it and we haven't already done so.
        if ($pathType -and -not $tempFile -and ($state -eq 'present' -or -not $packageStatus.SkipFileForRemove)) {
            $tempFile = switch ($pathType) {
                url { Get-UrlFile -Module $module -Url $path }
            }
            $path = $tempFile
        }

        if ($checksum_algorithm -and $state -eq 'present' -and $path) {
            $tmp_checksum = (Get-FileHash -LiteralPath $path -Algorithm $checksum_algorithm).Hash
            $module.Result.checksum = $tmp_checksum

            # If the checksum has been set, verify the checksum of the remote against the input checksum.
            if ($checksum -and $checksum -ne $tmp_checksum) {
                $Module.FailJson(("The checksum for {0} did not match '{1}', it was '{2}'" -f $path, $checksum, $tmp_checksum))
            }
        }

        $setParams = @{
            Arguments = $arguments
            ReturnCodes = $expectedReturnCode
            Id = $packageStatus.Id
            LogPath = $logPath
            Module = $module
            Path = $path
            State = $state
            WorkingDirectory = $chdir
            WaitChildren = $waitForChildren
        }
        $setParams += $packageStatus.ExtraInfo
        &$providerInfo."$($packageStatus.Provider)".Set @setParams
    }
    if ($state -eq 'absent' -and $null -eq $productId -and $pathType -eq 'url') {
        $Module.FailJson("Unable to find Product ID from the URL path. Please specify product_id when using state=absent")
    }
    $module.Result.changed = $changed
}
finally {
    if ($tempFile -and (Test-Path -LiteralPath $tempFile)) {
        Remove-Item -LiteralPath $tempFile -Force
    }
}

$module.ExitJson()
