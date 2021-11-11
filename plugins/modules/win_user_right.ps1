#!powershell

# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Module Ansible.ModuleUtils.AddType

$spec = @{
    options = @{
        name = @{ type = 'str'; required = $true }
        users = @{ type = 'list'; elements = 'str'; required = $true }
        action = @{ type = 'str'; choices = 'add', 'remove', 'set'; default = 'set' }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$users = $module.Params.users
$action = $module.Params.action

$module.Result.added = [System.Collections.Generic.List[String]]@()
$module.Result.removed = [System.Collections.Generic.List[String]]@()

$module.Diff.before = ""
$module.Diff.after = ""

Add-CSharpType -AnsibleModule $module -References @'
using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.Principal;

namespace Ansible
{
    public class LsaRightHelper : IDisposable
    {
        // Code modified from https://gallery.technet.microsoft.com/scriptcenter/Grant-Revoke-Query-user-26e259b0

        enum Access : int
        {
            POLICY_READ = 0x20006,
            POLICY_ALL_ACCESS = 0x00F0FFF,
            POLICY_EXECUTE = 0X20801,
            POLICY_WRITE = 0X207F8
        }

        IntPtr lsaHandle;

        const string LSA_DLL = "advapi32.dll";
        const CharSet DEFAULT_CHAR_SET = CharSet.Unicode;

        const uint STATUS_NO_MORE_ENTRIES = 0x8000001a;
        const uint STATUS_NO_SUCH_PRIVILEGE = 0xc0000060;

        internal sealed class Sid : IDisposable
        {
            public IntPtr pSid = IntPtr.Zero;
            public SecurityIdentifier sid = null;

            public Sid(string sidString)
            {
                try
                {
                    sid = new SecurityIdentifier(sidString);
                } catch
                {
                    throw new ArgumentException(String.Format("SID string {0} could not be converted to SecurityIdentifier", sidString));
                }

                Byte[] buffer = new Byte[sid.BinaryLength];
                sid.GetBinaryForm(buffer, 0);

                pSid = Marshal.AllocHGlobal(sid.BinaryLength);
                Marshal.Copy(buffer, 0, pSid, sid.BinaryLength);
            }

            public void Dispose()
            {
                if (pSid != IntPtr.Zero)
                {
                    Marshal.FreeHGlobal(pSid);
                    pSid = IntPtr.Zero;
                }
                GC.SuppressFinalize(this);
            }
            ~Sid() { Dispose(); }
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct LSA_OBJECT_ATTRIBUTES
        {
            public int Length;
            public IntPtr RootDirectory;
            public IntPtr ObjectName;
            public int Attributes;
            public IntPtr SecurityDescriptor;
            public IntPtr SecurityQualityOfService;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = DEFAULT_CHAR_SET)]
        private struct LSA_UNICODE_STRING
        {
            public ushort Length;
            public ushort MaximumLength;
            [MarshalAs(UnmanagedType.LPWStr)]
            public string Buffer;
        }

        [StructLayout(LayoutKind.Sequential)]
        private struct LSA_ENUMERATION_INFORMATION
        {
            public IntPtr Sid;
        }

        [DllImport(LSA_DLL, CharSet = DEFAULT_CHAR_SET, SetLastError = true)]
        private static extern uint LsaOpenPolicy(
            LSA_UNICODE_STRING[] SystemName,
            ref LSA_OBJECT_ATTRIBUTES ObjectAttributes,
            int AccessMask,
            out IntPtr PolicyHandle
        );

        [DllImport(LSA_DLL, CharSet = DEFAULT_CHAR_SET, SetLastError = true)]
        private static extern uint LsaAddAccountRights(
            IntPtr PolicyHandle,
            IntPtr pSID,
            LSA_UNICODE_STRING[] UserRights,
            int CountOfRights
        );

        [DllImport(LSA_DLL, CharSet = DEFAULT_CHAR_SET, SetLastError = true)]
        private static extern uint LsaRemoveAccountRights(
            IntPtr PolicyHandle,
            IntPtr pSID,
            bool AllRights,
            LSA_UNICODE_STRING[] UserRights,
            int CountOfRights
        );

        [DllImport(LSA_DLL, CharSet = DEFAULT_CHAR_SET, SetLastError = true)]
        private static extern uint LsaEnumerateAccountsWithUserRight(
            IntPtr PolicyHandle,
            LSA_UNICODE_STRING[] UserRights,
            out IntPtr EnumerationBuffer,
            out ulong CountReturned
        );

        [DllImport(LSA_DLL)]
        private static extern int LsaNtStatusToWinError(int NTSTATUS);

        [DllImport(LSA_DLL)]
        private static extern int LsaClose(IntPtr PolicyHandle);

        [DllImport(LSA_DLL)]
        private static extern int LsaFreeMemory(IntPtr Buffer);

        public LsaRightHelper()
        {
            LSA_OBJECT_ATTRIBUTES lsaAttr;
            lsaAttr.RootDirectory = IntPtr.Zero;
            lsaAttr.ObjectName = IntPtr.Zero;
            lsaAttr.Attributes = 0;
            lsaAttr.SecurityDescriptor = IntPtr.Zero;
            lsaAttr.SecurityQualityOfService = IntPtr.Zero;
            lsaAttr.Length = Marshal.SizeOf(typeof(LSA_OBJECT_ATTRIBUTES));

            lsaHandle = IntPtr.Zero;

            LSA_UNICODE_STRING[] system = new LSA_UNICODE_STRING[1];
            system[0] = InitLsaString("");

            uint ret = LsaOpenPolicy(system, ref lsaAttr, (int)Access.POLICY_ALL_ACCESS, out lsaHandle);
            if (ret != 0)
                throw new Win32Exception(LsaNtStatusToWinError((int)ret));
        }

        public void AddPrivilege(string sidString, string privilege)
        {
            uint ret = 0;
            using (Sid sid = new Sid(sidString))
            {
                LSA_UNICODE_STRING[] privileges = new LSA_UNICODE_STRING[1];
                privileges[0] = InitLsaString(privilege);
                ret = LsaAddAccountRights(lsaHandle, sid.pSid, privileges, 1);
            }
            if (ret != 0)
                throw new Win32Exception(LsaNtStatusToWinError((int)ret));
        }

        public void RemovePrivilege(string sidString, string privilege)
        {
            uint ret = 0;
            using (Sid sid = new Sid(sidString))
            {
                LSA_UNICODE_STRING[] privileges = new LSA_UNICODE_STRING[1];
                privileges[0] = InitLsaString(privilege);
                ret = LsaRemoveAccountRights(lsaHandle, sid.pSid, false, privileges, 1);
            }
            if (ret != 0)
                throw new Win32Exception(LsaNtStatusToWinError((int)ret));
        }

        public string[] EnumerateAccountsWithUserRight(string privilege)
        {
            uint ret = 0;
            ulong count = 0;
            LSA_UNICODE_STRING[] rights = new LSA_UNICODE_STRING[1];
            rights[0] = InitLsaString(privilege);
            IntPtr buffer = IntPtr.Zero;

            ret = LsaEnumerateAccountsWithUserRight(lsaHandle, rights, out buffer, out count);
            switch (ret)
            {
                case 0:
                    string[] accounts = new string[count];
                    for (int i = 0; i < (int)count; i++)
                    {
                        LSA_ENUMERATION_INFORMATION LsaInfo = (LSA_ENUMERATION_INFORMATION)Marshal.PtrToStructure(
                            IntPtr.Add(buffer, i * Marshal.SizeOf(typeof(LSA_ENUMERATION_INFORMATION))),
                            typeof(LSA_ENUMERATION_INFORMATION));

                        accounts[i] = new SecurityIdentifier(LsaInfo.Sid).ToString();
                    }
                    LsaFreeMemory(buffer);
                    return accounts;

                case STATUS_NO_MORE_ENTRIES:
                    return new string[0];

                case STATUS_NO_SUCH_PRIVILEGE:
                    throw new ArgumentException(String.Format("Invalid privilege {0} not found in LSA database", privilege));

                default:
                    throw new Win32Exception(LsaNtStatusToWinError((int)ret));
            }
        }

        static LSA_UNICODE_STRING InitLsaString(string s)
        {
            // Unicode strings max. 32KB
            if (s.Length > 0x7ffe)
                throw new ArgumentException("String too long");

            LSA_UNICODE_STRING lus = new LSA_UNICODE_STRING();
            lus.Buffer = s;
            lus.Length = (ushort)(s.Length * sizeof(char));
            lus.MaximumLength = (ushort)(lus.Length + sizeof(char));

            return lus;
        }

        public void Dispose()
        {
            if (lsaHandle != IntPtr.Zero)
            {
                LsaClose(lsaHandle);
                lsaHandle = IntPtr.Zero;
            }
            GC.SuppressFinalize(this);
        }
        ~LsaRightHelper() { Dispose(); }
    }
}
'@

Function ConvertFrom-SecurityIdentifier {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String]
        $InputObject
    )

    process {
        $sid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $InputObject

        try {
            $sid.Translate([System.Security.Principal.NTAccount]).Value
        }
        catch [System.Security.Principal.IdentityNotMappedException] {
            # The SID isn't valid, just return the raw SID back
            $sid.Value
        }
    }
}

Function ConvertTo-SecurityIdentifier {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingEmptyCatchBlock", "",
        Justification = "We don't care if converting to a SID fails, just that it failed or not")]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String]
        $InputObject
    )

    process {
        # Try parse the raw string as a SID string first.
        try {
            $sid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $InputObject
            return $sid
        }
        catch {}

        # In the Netlogon form (DOMAIN\user). Check if the domain part is . and convert it to the current hostname.
        # Otherwise just treat the value as the full username and let Windows parse it.
        if ($InputObject.Contains('\')) {
            $nameSplit = $InputObject -split '\\', 2
            if ($nameSplit[0] -eq '.') {
                $domain = $env:COMPUTERNAME
            }
            else {
                $domain = $nameSplit[0]
            }
            $account = $nameSplit[1]

            # NTAccount fails to find a local group when used with the domain part. First check if the value references
            # a local group or not
            if ($domain -eq $env:COMPUTERNAME) {
                $adsi = [ADSI]("WinNT://$env:COMPUTERNAME,computer")
                $group = $adsi.psbase.children | Where-Object {
                    $_.schemaClassName -eq "group" -and $_.Name -eq $account
                }
                if ($group) {
                    $domain = $null
                }
            }
        }
        else {
            $domain = $null
            $account = $InputObject
        }

        if ($domain) {
            $account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $domain, $account
        }
        else {
            $account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $account
        }

        try {
            $account.Translate([System.Security.Principal.SecurityIdentifier])
        }
        catch [System.Security.Principal.IdentityNotMappedException] {
            $module.FailJson("Failed to translate the account '$InputObject' to a SID", $_)
        }
    }
}

# C# class we can use to enumerate/add/remove rights
$lsaHelper = New-Object -TypeName Ansible.LsaRightHelper
$userSids = [String[]]@($users | ConvertTo-SecurityIdentifier | ForEach-Object { $_.Value })

try {
    $existingSids = $lsaHelper.EnumerateAccountsWithUserRight($name)
}
catch [ArgumentException] {
    $module.FailJson("the specified right $name is not a valid right", $_)
}
catch {
    $module.FailJson("failed to enumerate eixsting accounts with the right $($name): $($_.Exception.Message)", $_)
}

$module.Diff.before = @{
    $name = @($existingSids | ConvertFrom-SecurityIdentifier)
}

$toAdd = [String[]]@()
$toRemove = [String[]]@()
if ($action -eq 'add') {
    $toAdd = [Linq.Enumerable]::Except($userSids, $existingSids)

}
elseif ($action -eq 'remove') {
    $toRemove = [Linq.Enumerable]::Intersect($userSids, $existingSids)

}
else {
    $toAdd = [Linq.Enumerable]::Except($userSids, $existingSids)
    $toRemove = [Linq.Enumerable]::Except($existingSids, $userSids)
}

$newSids = [System.Collections.Generic.List[String]]@($existingSids | ConvertFrom-SecurityIdentifier)
foreach ($sid in $toAdd) {
    $sidName = ConvertFrom-SecurityIdentifier -InputObject $sid

    if (-not $module.CheckMode) {
        try {
            $lsaHelper.AddPrivilege($sid, $name)
        }
        catch [System.ComponentModel.Win32Exception] {
            $msg = "Failed to add account $sidName to right $name"
            $module.FailJson("$($msg): $($_.Exception.Message)", $_)
        }
    }

    $module.Result.added.Add($sidName)
    $newSids.Add($sidName)
    $module.Result.changed = $true
}

foreach ($sid in $toRemove) {
    $sidName = ConvertFrom-SecurityIdentifier -InputObject $sid

    if (-not $module.CheckMode) {
        try {
            $lsaHelper.RemovePrivilege($sid, $name)
        }
        catch [System.ComponentModel.Win32Exception] {
            $msg = "Failed to remove account $sidName from right $name"
            $module.FailJson("$($msg): $($_.Exception.Message)", $_)
        }
    }

    $module.Result.removed.Add($sidName)
    $null = $newSids.Remove($sidName)
    $module.Result.changed = $true
}

$module.Diff.after = @{
    $name = $newSids
}

$module.ExitJson()
