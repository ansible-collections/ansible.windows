#!powershell

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Module Ansible.ModuleUtils.AddType

$spec = @{
    options = @{
        name = @{ type = "str" }
        type = @{
            type = "str"
            choices = @("domain_certificate", "domain_password", "generic_certificate", "generic_password")
        }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

Add-CSharpType -AnsibleModule $module -References @'
using Microsoft.Win32.SafeHandles;
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace Ansible.CredentialManagerInfo
{
    internal class NativeMethods
    {
        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CredEnumerateW(
            [MarshalAs(UnmanagedType.LPWStr)] string Filter,
            UInt32 Flags,
            out UInt32 Count,
            out IntPtr Credentials);

        [DllImport("advapi32.dll")]
        public static extern void CredFree(IntPtr Buffer);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CredReadW(
            [MarshalAs(UnmanagedType.LPWStr)] string TargetName,
            CredentialType Type,
            UInt32 Flags,
            out IntPtr Credential);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CredUnmarshalCredentialW(
            [MarshalAs(UnmanagedType.LPWStr)] string MarshaledCredential,
            out uint CredType,
            out IntPtr Credential);
    }

    public enum CredentialType
    {
        Generic = 1,
        DomainPassword = 2,
        DomainCertificate = 3,
        DomainVisiblePassword = 4,
        GenericCertificate = 5,
        DomainExtended = 6,
    }

    public enum CredentialPersist
    {
        Session = 1,
        LocalMachine = 2,
        Enterprise = 3,
    }

    [Flags]
    public enum CredentialFlags
    {
        None = 0,
        PromptNow = 2,
        UsernameTarget = 4,
    }

    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    internal class CREDENTIAL
    {
        public CredentialFlags Flags;
        public CredentialType Type;
        [MarshalAs(UnmanagedType.LPWStr)] public string TargetName;
        [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
        public long LastWritten;
        public UInt32 CredentialBlobSize;
        public IntPtr CredentialBlob;
        public CredentialPersist Persist;
        public UInt32 AttributeCount;
        public IntPtr Attributes;
        [MarshalAs(UnmanagedType.LPWStr)] public string TargetAlias;
        [MarshalAs(UnmanagedType.LPWStr)] public string UserName;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct CREDENTIAL_ATTRIBUTE
    {
        [MarshalAs(UnmanagedType.LPWStr)] public string Keyword;
        public UInt32 Flags;
        public UInt32 ValueSize;
        public IntPtr Value;
    }

    public class CredentialAttribute
    {
        public string Keyword;
        public byte[] Value;
    }

    public class CredentialInfo
    {
        public CredentialType Type;
        public string TargetName;
        public string Comment;
        public CredentialPersist Persist;
        public List<CredentialAttribute> Attributes;
        public string TargetAlias;
        public string UserName;
    }

    public static class CredentialHelper
    {
        public static CredentialInfo GetCredential(string target, CredentialType type)
        {
            IntPtr pCredential;
            if (!NativeMethods.CredReadW(target, type, 0, out pCredential))
            {
                int err = Marshal.GetLastWin32Error();
                if (err == 0x00000520)
                    throw new InvalidOperationException("Failed to access the user's credential store, run the module with become");
                if (err == 0x00000490)
                    return null;
                throw new System.ComponentModel.Win32Exception(err);
            }

            try
            {
                return ParseCredential(pCredential);
            }
            finally
            {
                NativeMethods.CredFree(pCredential);
            }
        }

        public static List<CredentialInfo> EnumerateCredentials(string filter)
        {
            if (filter != null && filter.Length == 0)
                filter = null;

            UInt32 count;
            IntPtr pCredentials;
            var results = new List<CredentialInfo>();

            if (!NativeMethods.CredEnumerateW(filter, 0, out count, out pCredentials))
            {
                int err = Marshal.GetLastWin32Error();
                if (err == 0x00000520)
                    throw new InvalidOperationException("Failed to access the user's credential store, run the module with become");
                if (err == 0x00000490)
                    return results;
                throw new System.ComponentModel.Win32Exception(err);
            }

            try
            {
                for (int i = 0; i < count; i++)
                {
                    IntPtr pCred = Marshal.ReadIntPtr(pCredentials, i * IntPtr.Size);
                    results.Add(ParseCredential(pCred));
                }
            }
            finally
            {
                NativeMethods.CredFree(pCredentials);
            }

            return results;
        }

        private static CredentialInfo ParseCredential(IntPtr pCredential)
        {
            CREDENTIAL raw = (CREDENTIAL)Marshal.PtrToStructure(pCredential, typeof(CREDENTIAL));

            var attributes = new List<CredentialAttribute>();
            if (raw.AttributeCount > 0)
            {
                IntPtr pAttr = raw.Attributes;
                int attrSize = Marshal.SizeOf(typeof(CREDENTIAL_ATTRIBUTE));
                for (int i = 0; i < raw.AttributeCount; i++)
                {
                    CREDENTIAL_ATTRIBUTE attr = (CREDENTIAL_ATTRIBUTE)Marshal.PtrToStructure(
                        IntPtr.Add(pAttr, i * attrSize), typeof(CREDENTIAL_ATTRIBUTE));
                    byte[] value = new byte[attr.ValueSize];
                    if (attr.Value != IntPtr.Zero && attr.ValueSize > 0)
                        Marshal.Copy(attr.Value, value, 0, (int)attr.ValueSize);
                    attributes.Add(new CredentialAttribute { Keyword = attr.Keyword, Value = value });
                }
            }

            string userName = raw.UserName;
            if ((raw.Type == CredentialType.DomainCertificate || raw.Type == CredentialType.GenericCertificate)
                && !string.IsNullOrEmpty(userName))
            {
                userName = UnmarshalCertificateCredential(userName);
            }

            return new CredentialInfo
            {
                Type = raw.Type,
                TargetName = raw.TargetName,
                Comment = raw.Comment,
                Persist = raw.Persist,
                Attributes = attributes,
                TargetAlias = raw.TargetAlias,
                UserName = userName,
            };
        }

        private static string UnmarshalCertificateCredential(string marshaledValue)
        {
            uint credType;
            IntPtr pCredInfo;
            if (!NativeMethods.CredUnmarshalCredentialW(marshaledValue, out credType, out pCredInfo))
                return marshaledValue;

            try
            {
                byte[] sizeBytes = new byte[sizeof(uint)];
                Marshal.Copy(pCredInfo, sizeBytes, 0, sizeof(uint));
                uint structSize = BitConverter.ToUInt32(sizeBytes, 0);

                byte[] certInfo = new byte[structSize];
                Marshal.Copy(pCredInfo, certInfo, 0, certInfo.Length);

                var hex = new System.Text.StringBuilder((certInfo.Length - sizeof(uint)) * 2);
                for (int i = sizeof(uint); i < certInfo.Length; i++)
                    hex.AppendFormat("{0:x2}", certInfo[i]);

                return hex.ToString().ToUpperInvariant();
            }
            finally
            {
                NativeMethods.CredFree(pCredInfo);
            }
        }
    }
}
'@

$name = $module.Params.name
$type = $module.Params.type

$type_map = @{
    "domain_password" = [Ansible.CredentialManagerInfo.CredentialType]::DomainPassword
    "domain_certificate" = [Ansible.CredentialManagerInfo.CredentialType]::DomainCertificate
    "generic_password" = [Ansible.CredentialManagerInfo.CredentialType]::Generic
    "generic_certificate" = [Ansible.CredentialManagerInfo.CredentialType]::GenericCertificate
}

Function ConvertTo-CredentialOutput {
    param($InputObject)

    $info = @{
        name = $InputObject.TargetName
        type = $InputObject.Type.ToString()
        username = $InputObject.UserName
        alias = $InputObject.TargetAlias
        comment = $InputObject.Comment
        persistence = $InputObject.Persist.ToString()
        attributes = @()
    }

    foreach ($attribute in $InputObject.Attributes) {
        $attr_info = @{
            name = $attribute.Keyword
            data = $null
        }
        if ($null -ne $attribute.Value -and $attribute.Value.Length -gt 0) {
            $attr_info.data = [System.Convert]::ToBase64String($attribute.Value)
        }
        $info.attributes += $attr_info
    }

    return $info
}

$module.Result.exists = $false
$module.Result.credentials = @()

if ($null -ne $name -and $null -ne $type -and $name -notlike '*`**') {
    # Exact name + type: use CredReadW for single lookup
    $mapped_type = $type_map[$type]
    $credential = [Ansible.CredentialManagerInfo.CredentialHelper]::GetCredential($name, $mapped_type)

    if ($null -ne $credential) {
        $module.Result.exists = $true
        $module.Result.credentials = @(ConvertTo-CredentialOutput -InputObject $credential)
    }
}
elseif ($null -ne $name -and $name -notlike '*`**') {
    # Name without wildcard - CredEnumerateW requires a wildcard in the filter,
    # so try CredReadW across all credential types
    $all_types = @(
        [Ansible.CredentialManagerInfo.CredentialType]::Generic,
        [Ansible.CredentialManagerInfo.CredentialType]::DomainPassword,
        [Ansible.CredentialManagerInfo.CredentialType]::DomainCertificate,
        [Ansible.CredentialManagerInfo.CredentialType]::GenericCertificate
    )
    $found = [System.Collections.Generic.List[object]]::new()
    foreach ($cred_type in $all_types) {
        $credential = [Ansible.CredentialManagerInfo.CredentialHelper]::GetCredential($name, $cred_type)
        if ($null -ne $credential) {
            $found.Add((ConvertTo-CredentialOutput -InputObject $credential))
        }
    }

    if ($found.Count -gt 0) {
        $module.Result.exists = $true
        [array]$module.Result.credentials = $found | Sort-Object -Property { $_.name }
    }
}
else {
    # Use CredEnumerateW - filter is either null (all) or contains a wildcard
    $filter = $name
    $credentials = [Ansible.CredentialManagerInfo.CredentialHelper]::EnumerateCredentials($filter)

    if ($null -ne $type) {
        $mapped_type = $type_map[$type]
        $credentials = @($credentials | Where-Object { $_.Type -eq $mapped_type })
    }

    if ($credentials.Count -gt 0) {
        $module.Result.exists = $true
        [array]$module.Result.credentials = $credentials | ForEach-Object {
            ConvertTo-CredentialOutput -InputObject $_
        } | Sort-Object -Property { $_.name }
    }
}

$module.ExitJson()
