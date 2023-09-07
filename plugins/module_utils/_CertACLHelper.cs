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
        public SafeCryptHandle()
            : base(true)
        {
        }

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CryptReleaseContext(IntPtr safeProvHandle, uint dwFlags);

        protected override bool ReleaseHandle()
        {
            return CryptReleaseContext(this.handle, 0);
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
            CRYPT_ACQUIRE_ONLY_NCRYPT_KEY_FLAG = 0x00040000,
        }

        private enum KeySpec : uint
        {
            NONE = 0x0,
            AT_KEYEXCHANGE = 0x1,
            AT_SIGNATURE = 2,
            CERT_NCRYPT_KEY_SPEC = 0xFFFFFFFF
        }

        [DllImport("crypt32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CryptAcquireCertificatePrivateKey(IntPtr pCert, uint dwFlags, IntPtr pvParameters, out SafeCryptHandle phCryptProvOrNCryptKey, out KeySpec pdwKeySpec, out bool pfCallerFreeProvOrNCryptKey);

        [DllImport("ncrypt.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern int NCryptGetProperty(SafeCryptHandle hObject, [MarshalAs(UnmanagedType.LPWStr)] string pszProperty, SafeSecurityDescriptorPtr pbOutput, uint cbOutput, ref uint pcbResult, SecurityInformationFlags dwFlags);

        [DllImport("ncrypt.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern int NCryptSetProperty(SafeCryptHandle hObject, [MarshalAs(UnmanagedType.LPWStr)] string pszProperty, [MarshalAs(UnmanagedType.LPArray)] byte[] pbInput, uint cbInput, SecurityInformationFlags dwFlags);

        private enum CryptProvParam : uint
        {
            PP_KEYSET_SEC_DESCR = 8
        }

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CryptGetProvParam(SafeCryptHandle safeProvHandle, CryptProvParam dwParam, SafeSecurityDescriptorPtr pbData, ref uint dwDataLen, SecurityInformationFlags dwFlags);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CryptSetProvParam(SafeCryptHandle safeProvHandle, CryptProvParam dwParam, [MarshalAs(UnmanagedType.LPArray)] byte[] pbData, SecurityInformationFlags dwFlags);

        SafeCryptHandle handle;
        bool ncrypt = false;

        public CertAclHelper(X509Certificate2 certificate)
        {
            SafeCryptHandle certPkeyHandle;
            KeySpec keySpec;

            bool ownHandle;
            if (CryptAcquireCertificatePrivateKey(
                    certificate.Handle,
                    (uint)CryptAcquireKeyFlags.CRYPT_ACQUIRE_SILENT_FLAG | (uint)CryptAcquireKeyFlagControl.CRYPT_ACQUIRE_ALLOW_NCRYPT_KEY_FLAG,
                    IntPtr.Zero,
                    out certPkeyHandle,
                    out keySpec,
                    out ownHandle))
            {
                if (!ownHandle)
                {
                    throw new NotSupportedException("Could not take ownership of certificate private key handle");
                }

                if (keySpec == KeySpec.CERT_NCRYPT_KEY_SPEC)
                {
                    ncrypt = true;
                }

                handle = certPkeyHandle;
            }
            else
            {
                throw new Win32Exception();
            }
        }

        public FileSecurity Acl
        {
            get
            {
                SafeSecurityDescriptorPtr securityDescriptorBuffer;
                uint securityDescriptorSize = 0;
                if (ncrypt)
                {
                    int securityDescriptorResult = NCryptGetProperty(
                        handle,
                        "Security Descr",
                        new SafeSecurityDescriptorPtr(),
                        0,
                        ref securityDescriptorSize,
                        SecurityInformationFlags.DACL_SECURITY_INFORMATION);
                    if (securityDescriptorResult != 0)
                    {
                        throw new Win32Exception(securityDescriptorResult);
                    }
                    securityDescriptorBuffer = new SafeSecurityDescriptorPtr(securityDescriptorSize);

                    securityDescriptorResult = NCryptGetProperty(
                        handle,
                        "Security Descr",
                        securityDescriptorBuffer,
                        securityDescriptorSize,
                        ref securityDescriptorSize,
                        SecurityInformationFlags.DACL_SECURITY_INFORMATION);
                    if (securityDescriptorResult != 0)
                    {
                        throw new Win32Exception(securityDescriptorResult);
                    }

                }
                else
                {
                    if (!CryptGetProvParam(
                            handle,
                            CryptProvParam.PP_KEYSET_SEC_DESCR,
                            new SafeSecurityDescriptorPtr(),
                            ref securityDescriptorSize,
                            SecurityInformationFlags.DACL_SECURITY_INFORMATION))
                    {
                        throw new Win32Exception();
                    }

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
                byte[] buffer = new byte[securityDescriptorSize];
                Marshal.Copy(securityDescriptorBuffer.DangerousGetHandle(), buffer, 0, buffer.Length);
                FileSecurity acl = new FileSecurity();
                acl.SetSecurityDescriptorBinaryForm(buffer);

                return acl;
            }
            set
            {
                if (ncrypt)
                {
                    byte[] sd = value.GetSecurityDescriptorBinaryForm();
                    int setPropertyResult = NCryptSetProperty(
                        handle,
                        "Security Descr",
                        sd,
                        (uint)sd.Length,
                        SecurityInformationFlags.DACL_SECURITY_INFORMATION);
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