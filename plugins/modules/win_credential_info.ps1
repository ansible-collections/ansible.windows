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
            choices = @("domain_password", "domain_certificate", "generic_password", "generic_certificate")
        }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$type = $module.Params.type

Add-CSharpType -AnsibleModule $module -References @'
using Microsoft.Win32.SafeHandles;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;

namespace Ansible.CredentialManagerInfo
{
    internal class NativeHelpers
    {
        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        public class CREDENTIAL
        {
            public CredentialFlags Flags;
            public CredentialType Type;
            [MarshalAs(UnmanagedType.LPWStr)] public string TargetName;
            [MarshalAs(UnmanagedType.LPWStr)] public string Comment;
            public FILETIME LastWritten;
            public UInt32 CredentialBlobSize;
            public IntPtr CredentialBlob;
            public CredentialPersist Persist;
            public UInt32 AttributeCount;
            public IntPtr Attributes;
            [MarshalAs(UnmanagedType.LPWStr)] public string TargetAlias;
            [MarshalAs(UnmanagedType.LPWStr)] public string UserName;

            public static explicit operator Credential(CREDENTIAL v)
            {
                List<CredentialAttribute> attributes = new List<CredentialAttribute>();
                if (v.AttributeCount > 0)
                {
                    CREDENTIAL_ATTRIBUTE[] rawAttributes = new CREDENTIAL_ATTRIBUTE[v.AttributeCount];
                    Credential.PtrToStructureArray(rawAttributes, v.Attributes);
                    attributes = rawAttributes.Select(x => (CredentialAttribute)x).ToList();
                }

                string userName = v.UserName;
                if (v.Type == CredentialType.DomainCertificate || v.Type == CredentialType.GenericCertificate)
                {
                    try
                    {
                        userName = Credential.UnmarshalCertificateCredential(userName);
                    }
                    catch
                    {
                        // If unmarshal fails, keep the raw username
                    }
                }

                return new Credential
                {
                    Type = v.Type,
                    TargetName = v.TargetName,
                    Comment = v.Comment,
                    Persist = v.Persist,
                    Attributes = attributes,
                    TargetAlias = v.TargetAlias,
                    UserName = userName,
                };
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct CREDENTIAL_ATTRIBUTE
        {
            [MarshalAs(UnmanagedType.LPWStr)] public string Keyword;
            public UInt32 Flags;
            public UInt32 ValueSize;
            public IntPtr Value;

            public static explicit operator CredentialAttribute(CREDENTIAL_ATTRIBUTE v)
            {
                byte[] value = new byte[v.ValueSize];
                Marshal.Copy(v.Value, value, 0, (int)v.ValueSize);

                return new CredentialAttribute
                {
                    Keyword = v.Keyword,
                    Flags = v.Flags,
                    Value = value,
                };
            }
        }

        [StructLayout(LayoutKind.Sequential)]
        public struct FILETIME
        {
            internal UInt32 dwLowDateTime;
            internal UInt32 dwHighDateTime;
        }

        [Flags]
        public enum CredentialFlags
        {
            None = 0,
            PromptNow = 2,
            UsernameTarget = 4,
        }

        public enum CredMarshalType : uint
        {
            CertCredential = 1,
            UsernameTargetCredential,
            BinaryBlobCredential,
            UsernameForPackedCredential,
            BinaryBlobForSystem,
        }
    }

    internal class NativeMethods
    {
        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CredEnumerateW(
            [MarshalAs(UnmanagedType.LPWStr)] string Filter,
            UInt32 Flags,
            out UInt32 Count,
            out IntPtr Credentials);

        [DllImport("advapi32.dll")]
        public static extern void CredFree(
            IntPtr Buffer);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CredReadW(
            [MarshalAs(UnmanagedType.LPWStr)] string TargetName,
            CredentialType Type,
            UInt32 Flags,
            out IntPtr Credential);

        [DllImport("advapi32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
        public static extern bool CredUnmarshalCredentialW(
            [MarshalAs(UnmanagedType.LPWStr)] string MarshaledCredential,
            out NativeHelpers.CredMarshalType CredType,
            out IntPtr Credential);
    }

    public class Win32Exception : System.ComponentModel.Win32Exception
    {
        private string _exception_msg;
        public Win32Exception(string message) : this(Marshal.GetLastWin32Error(), message) { }
        public Win32Exception(int errorCode, string message) : base(errorCode)
        {
            _exception_msg = String.Format("{0} - {1} (Win32 Error Code {2}: 0x{3})", message, base.Message, errorCode, errorCode.ToString("X8"));
        }
        public override string Message { get { return _exception_msg; } }
    }

    public enum CredentialPersist
    {
        Session = 1,
        LocalMachine = 2,
        Enterprise = 3,
    }

    public enum CredentialType
    {
        Generic = 1,
        DomainPassword = 2,
        DomainCertificate = 3,
        DomainVisiblePassword = 4,
        GenericCertificate = 5,
        DomainExtended = 6,
        Maximum = 7,
        MaximumEx = 1007,
    }

    public class CredentialAttribute
    {
        public string Keyword;
        public UInt32 Flags;
        public byte[] Value;
    }

    public class Credential
    {
        public CredentialType Type;
        public string TargetName;
        public string Comment;
        public CredentialPersist Persist;
        public List<CredentialAttribute> Attributes = new List<CredentialAttribute>();
        public string TargetAlias;
        public string UserName;

        public static Credential ReadCredential(string target, CredentialType type)
        {
            IntPtr buffer;
            if (!NativeMethods.CredReadW(target, type, 0, out buffer))
            {
                int lastErr = Marshal.GetLastWin32Error();
                if (lastErr == 0x00000520)
                    throw new InvalidOperationException("Failed to access the user's credential store, run the module with become");
                else if (lastErr == 0x00000490)
                    return null;
                throw new Win32Exception(lastErr, "CredReadW() failed");
            }

            try
            {
                NativeHelpers.CREDENTIAL credential = (NativeHelpers.CREDENTIAL)Marshal.PtrToStructure(
                    buffer, typeof(NativeHelpers.CREDENTIAL));
                return (Credential)credential;
            }
            finally
            {
                NativeMethods.CredFree(buffer);
            }
        }

        public static List<Credential> EnumerateCredentials(string filter)
        {
            UInt32 count;
            IntPtr pCredentials;
            List<Credential> results = new List<Credential>();

            if (!NativeMethods.CredEnumerateW(filter, 0, out count, out pCredentials))
            {
                int lastErr = Marshal.GetLastWin32Error();
                if (lastErr == 0x00000520)
                    throw new InvalidOperationException("Failed to access the user's credential store, run the module with become");
                else if (lastErr == 0x00000490)
                    return results;
                throw new Win32Exception(lastErr, "CredEnumerateW() failed");
            }

            try
            {
                for (int i = 0; i < count; i++)
                {
                    IntPtr pCredential = Marshal.ReadIntPtr(pCredentials, i * IntPtr.Size);
                    NativeHelpers.CREDENTIAL credential = (NativeHelpers.CREDENTIAL)Marshal.PtrToStructure(
                        pCredential, typeof(NativeHelpers.CREDENTIAL));
                    results.Add((Credential)credential);
                }
            }
            finally
            {
                NativeMethods.CredFree(pCredentials);
            }

            return results;
        }

        public static string UnmarshalCertificateCredential(string value)
        {
            NativeHelpers.CredMarshalType credType;
            IntPtr pCredInfo;
            if (!NativeMethods.CredUnmarshalCredentialW(value, out credType, out pCredInfo))
                throw new Win32Exception("CredUnmarshalCredentialW() failed");

            try
            {
                if (credType != NativeHelpers.CredMarshalType.CertCredential)
                    throw new InvalidOperationException(String.Format("Expected CertCredential, received {0}", credType));

                byte[] structSizeBytes = new byte[sizeof(UInt32)];
                Marshal.Copy(pCredInfo, structSizeBytes, 0, sizeof(UInt32));
                UInt32 structSize = BitConverter.ToUInt32(structSizeBytes, 0);

                byte[] certInfoBytes = new byte[structSize];
                Marshal.Copy(pCredInfo, certInfoBytes, 0, certInfoBytes.Length);

                StringBuilder hex = new StringBuilder((certInfoBytes.Length - sizeof(UInt32)) * 2);
                for (int i = 4; i < certInfoBytes.Length; i++)
                    hex.AppendFormat("{0:x2}", certInfoBytes[i]);

                return hex.ToString().ToUpperInvariant();
            }
            finally
            {
                NativeMethods.CredFree(pCredInfo);
            }
        }

        internal static void PtrToStructureArray<T>(T[] array, IntPtr ptr)
        {
            IntPtr ptrOffset = ptr;
            for (int i = 0; i < array.Length; i++, ptrOffset = IntPtr.Add(ptrOffset, Marshal.SizeOf(typeof(T))))
                array[i] = (T)Marshal.PtrToStructure(ptrOffset, typeof(T));
        }
    }
}
'@

# Map user-friendly type names to enum values
$type_map = @{
    "domain_password" = [Ansible.CredentialManagerInfo.CredentialType]::DomainPassword
    "domain_certificate" = [Ansible.CredentialManagerInfo.CredentialType]::DomainCertificate
    "generic_password" = [Ansible.CredentialManagerInfo.CredentialType]::Generic
    "generic_certificate" = [Ansible.CredentialManagerInfo.CredentialType]::GenericCertificate
}

Function ConvertTo-CredentialInfo {
    param($Credential)

    $info = @{
        name = $Credential.TargetName
        type = $Credential.Type.ToString()
        username = $Credential.UserName
        alias = $Credential.TargetAlias
        comment = $Credential.Comment
        persistence = $Credential.Persist.ToString()
        attributes = @()
    }

    foreach ($attribute in $Credential.Attributes) {
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

try {
    if ($null -ne $name -and $null -ne $type) {
        # When both name and type are specified, use CredReadW for exact lookup
        $mapped_type = $type_map[$type]
        $credential = [Ansible.CredentialManagerInfo.Credential]::ReadCredential($name, $mapped_type)

        if ($null -ne $credential) {
            $module.Result.exists = $true
            $module.Result.credentials = @(ConvertTo-CredentialInfo -Credential $credential)
        }
    }
    elseif ($null -ne $name -and $name -notlike '*`**') {
        # Name specified without wildcard and no type — CredEnumerateW requires
        # a wildcard in the filter, so try CredReadW across all credential types
        $all_types = @(
            [Ansible.CredentialManagerInfo.CredentialType]::Generic,
            [Ansible.CredentialManagerInfo.CredentialType]::DomainPassword,
            [Ansible.CredentialManagerInfo.CredentialType]::DomainCertificate,
            [Ansible.CredentialManagerInfo.CredentialType]::GenericCertificate
        )
        $found = [System.Collections.Generic.List[object]]::new()
        foreach ($cred_type in $all_types) {
            $credential = [Ansible.CredentialManagerInfo.Credential]::ReadCredential($name, $cred_type)
            if ($null -ne $credential) {
                $found.Add((ConvertTo-CredentialInfo -Credential $credential))
            }
        }

        if ($found.Count -gt 0) {
            $module.Result.exists = $true
            [array]$module.Result.credentials = $found | Sort-Object -Property { $_.name }
        }
    }
    else {
        # Use CredEnumerateW — filter is either null (all) or contains a wildcard
        $filter = $name  # null filter returns all credentials
        $credentials = [Ansible.CredentialManagerInfo.Credential]::EnumerateCredentials($filter)

        # Filter by type if specified
        if ($null -ne $type) {
            $mapped_type = $type_map[$type]
            $credentials = @($credentials | Where-Object { $_.Type -eq $mapped_type })
        }

        if ($credentials.Count -gt 0) {
            $module.Result.exists = $true
            [array]$module.Result.credentials = $credentials | ForEach-Object {
                ConvertTo-CredentialInfo -Credential $_
            } | Sort-Object -Property { $_.name }
        }
    }
}
catch [InvalidOperationException] {
    $module.FailJson("$($_.Exception.Message)")
}

$module.ExitJson()
