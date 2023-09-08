// Note: The contents of this file are for internal use only! Do not depend on these classes
//       or their methods and properties. The API can change without any warning or respect to
//       semantic versioning.

using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Cryptography.X509Certificates;
using Microsoft.Win32.SafeHandles;
using System.Security.Principal;

//TypeAccelerator -Name Ansible.Windows._CertAclHelper.CertAccessRights -TypeName CertAccessRights
//TypeAccelerator -Name Ansible.Windows._CertAclHelper.CertAclHelper -TypeName CertAclHelper

namespace ansible_collections.ansible.windows.plugins.module_utils._CertACLHelper
{
    internal class SafeCryptHandle : SafeHandleZeroOrMinusOneIsInvalid
    {
        private enum SecurityStatus : int
        {
            ERROR_SUCCESS = 0
        }

        public bool ShouldFree { get; set; }
        public bool NCrypt { get; set; }

        public SafeCryptHandle()
            : base(true)
        {
        }

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CryptReleaseContext(IntPtr safeProvHandle, uint dwFlags);

        [DllImport("ncrypt.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern int NCryptFreeObject(IntPtr safeProvHandle);

        protected override bool ReleaseHandle()
        {
            if (!ShouldFree)
            {
                return true;
            }

            return NCrypt
                ? NCryptFreeObject(this.handle) == (int)SecurityStatus.ERROR_SUCCESS
                : CryptReleaseContext(this.handle, 0);
        }
    }

    internal class SafeSecurityDescriptorPtr : SafeHandleZeroOrMinusOneIsInvalid
    {        
        private int size = -1;

        public SafeSecurityDescriptorPtr()
            : base(true)
        {
        }

        public SafeSecurityDescriptorPtr(uint size)
            : base(true)
        {
            this.size = (int)size;
            this.SetHandle(Marshal.AllocHGlobal(this.size));
        }

        protected override bool ReleaseHandle()
        {
            try
            {
                Marshal.FreeHGlobal(this.handle);
                return true;
            }
            catch
            {
                // semantics of this function are to never throw an exception so we must eat the underlying error and 
                // return false. 
                return false;
            }
        }
    }

    internal class KeyStorageProperty
    {
        public const string NCRYPT_SECURITY_DESCR_PROPERTY = "Security Descr";
    }

    [Flags]
    public enum CertAccessRights : int
    {
        Read = -2146303863,
        FullControl = -803274241
    }

    public class CertAclHelper
    {
        [Flags]
        private enum SecurityInformationFlags : uint
        {
            DACL_SECURITY_INFORMATION = 0x00000004,
            NCRYPT_SILENT_FLAG = 0x00000040,
        }

        [Flags]
        private enum CryptAcquireKeyFlags : uint
        {
            CRYPT_ACQUIRE_SILENT_FLAG = 0x00000040,
        }

        [Flags]
        private enum CryptAcquireKeyFlagControl : uint
        {
            CRYPT_ACQUIRE_ALLOW_NCRYPT_KEY_FLAG = 0x00010000,
            CRYPT_ACQUIRE_PREFER_NCRYPT_KEY_FLAG = 0x00020000,
        }

        private enum KeySpec : uint
        {
            NONE = 0x0,
            AT_KEYEXCHANGE = 0x1,
            AT_SIGNATURE = 2,
            CERT_NCRYPT_KEY_SPEC = 0xFFFFFFFF
        }

        private enum CryptProvParam : uint
        {
            PP_KEYSET_SEC_DESCR = 8
        }

        [DllImport("crypt32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CryptAcquireCertificatePrivateKey(IntPtr pCert, uint dwFlags, IntPtr pvParameters, out SafeCryptHandle phCryptProvOrNCryptKey, out KeySpec pdwKeySpec, out bool pfCallerFreeProvOrNCryptKey);

        [DllImport("ncrypt.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern int NCryptGetProperty(SafeCryptHandle hObject, [MarshalAs(UnmanagedType.LPWStr)] string pszProperty, SafeSecurityDescriptorPtr pbOutput, uint cbOutput, ref uint pcbResult, SecurityInformationFlags dwFlags);

        [DllImport("ncrypt.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern int NCryptSetProperty(SafeCryptHandle hObject, [MarshalAs(UnmanagedType.LPWStr)] string pszProperty, [MarshalAs(UnmanagedType.LPArray)] byte[] pbInput, uint cbInput, SecurityInformationFlags dwFlags);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CryptGetProvParam(SafeCryptHandle safeProvHandle, CryptProvParam dwParam, SafeSecurityDescriptorPtr pbData, ref uint dwDataLen, SecurityInformationFlags dwFlags);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CryptSetProvParam(SafeCryptHandle safeProvHandle, CryptProvParam dwParam, [MarshalAs(UnmanagedType.LPArray)] byte[] pbData, SecurityInformationFlags dwFlags);

        private SafeCryptHandle handle;

        public CertAclHelper(X509Certificate2 certificate)
        {
            KeySpec keySpec;
            bool shouldFreeKey;
            if (!CryptAcquireCertificatePrivateKey(
                    certificate.Handle,
                    (uint)CryptAcquireKeyFlags.CRYPT_ACQUIRE_SILENT_FLAG | (uint)CryptAcquireKeyFlagControl.CRYPT_ACQUIRE_ALLOW_NCRYPT_KEY_FLAG,
                    IntPtr.Zero,
                    out handle,
                    out keySpec,
                    out shouldFreeKey))
            {
                throw new Win32Exception();
            }

            handle.ShouldFree = shouldFreeKey;
            handle.NCrypt = keySpec == KeySpec.CERT_NCRYPT_KEY_SPEC;
        }

        public FileSecurity Acl
        {
            get
            {
                SafeSecurityDescriptorPtr securityDescriptorBuffer;
                var securityDescriptorSize = 0U;
                if (handle.NCrypt)
                {
                    // We first have to find out how large of a buffer to reserve, so the docs say that
                    // we should pass NULL for the buffer address, then the penultimate parameter will
                    // get assigned the required size.
                    //
                    // Note: Despite the documentation saying we should pass NULL for the buffer address,
                    //       the marshalling between C# and C misbehaves when this happens. When I tried
                    //       this, the entire getter mysteriously returned null (instead of throwing).
                    //       Instead, we must pass a non-null empty buffer (`new SafeSecurityDescriptorPtr`)
                    var securityDescriptorResult = NCryptGetProperty(
                        handle,
                        KeyStorageProperty.NCRYPT_SECURITY_DESCR_PROPERTY,
                        new SafeSecurityDescriptorPtr(),
                        0,
                        ref securityDescriptorSize,
                        SecurityInformationFlags.DACL_SECURITY_INFORMATION | SecurityInformationFlags.NCRYPT_SILENT_FLAG);
                    if (securityDescriptorResult != 0)
                    {
                        throw new Win32Exception(securityDescriptorResult);
                    }

                    // Now that we know the required size, we can allocate a buffer and actually ask NCrypt
                    // to copy the security description into it.
                    securityDescriptorBuffer = new SafeSecurityDescriptorPtr(securityDescriptorSize);
                    securityDescriptorResult = NCryptGetProperty(
                        handle,
                        KeyStorageProperty.NCRYPT_SECURITY_DESCR_PROPERTY,
                        securityDescriptorBuffer,
                        securityDescriptorSize,
                        ref securityDescriptorSize,
                        SecurityInformationFlags.DACL_SECURITY_INFORMATION | SecurityInformationFlags.NCRYPT_SILENT_FLAG);
                    if (securityDescriptorResult != 0)
                    {
                        throw new Win32Exception(securityDescriptorResult);
                    }
                }
                else
                {
                    // We first have to find out how large of a buffer to reserve, so the docs say that
                    // we should pass NULL for the buffer address, then the penultimate parameter will
                    // get assigned the required size.
                    //
                    // Note: Despite the documentation saying we should pass NULL for the buffer address,
                    //       the marshalling between C# and C misbehaves when this happens. When I tried
                    //       this, the entire getter mysteriously returned null (instead of throwing).
                    //       Instead, we must pass a non-null empty buffer (`new SafeSecurityDescriptorPtr`)
                    if (!CryptGetProvParam(
                            handle,
                            CryptProvParam.PP_KEYSET_SEC_DESCR,
                            new SafeSecurityDescriptorPtr(),
                            ref securityDescriptorSize,
                            SecurityInformationFlags.DACL_SECURITY_INFORMATION))
                    {
                        throw new Win32Exception();
                    }

                    // Now that we know the required size, we can allocate a buffer and actually ask NCrypt
                    // to copy the security description into it.
                    securityDescriptorBuffer = new SafeSecurityDescriptorPtr(securityDescriptorSize);
                    if (!CryptGetProvParam(
                            handle,
                            CryptProvParam.PP_KEYSET_SEC_DESCR,
                            securityDescriptorBuffer,
                            ref securityDescriptorSize,
                            SecurityInformationFlags.DACL_SECURITY_INFORMATION))
                    {
                        throw new Win32Exception();
                    }
                }
                var buffer = new byte[securityDescriptorSize];
                Marshal.Copy(securityDescriptorBuffer.DangerousGetHandle(), buffer, 0, buffer.Length);
                var acl = new FileSecurity();
                acl.SetSecurityDescriptorBinaryForm(buffer);

                return acl;
            }
            set
            {
                if (handle.NCrypt)
                {
                    var securityDescriptor = value.GetSecurityDescriptorBinaryForm();
                    var setPropertyResult = NCryptSetProperty(
                        handle,
                        KeyStorageProperty.NCRYPT_SECURITY_DESCR_PROPERTY,
                        securityDescriptor,
                        (uint)securityDescriptor.Length,
                        SecurityInformationFlags.DACL_SECURITY_INFORMATION | SecurityInformationFlags.NCRYPT_SILENT_FLAG);
                    if (setPropertyResult != 0)
                    {
                        throw new Win32Exception(setPropertyResult);
                    }
                }
                else
                {
                    if (!CryptSetProvParam(
                        handle, 
                        CryptProvParam.PP_KEYSET_SEC_DESCR,
                        value.GetSecurityDescriptorBinaryForm(), 
                        SecurityInformationFlags.DACL_SECURITY_INFORMATION))
                    {
                        throw new Win32Exception();
                    }
                }
            }
        }
    }
}