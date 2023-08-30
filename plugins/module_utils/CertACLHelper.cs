using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Cryptography.X509Certificates;
using Microsoft.Win32.SafeHandles;
using System.Security.Principal;

//TypeAccelerator -Name Ansible.Windows.CertAclHelper.CryptHandle -TypeName CryptHandle
//TypeAccelerator -Name Ansible.Windows.CertAclHelper.SafeSecurityDescriptorPtr -TypeName SafeSecurityDescriptorPtr
//TypeAccelerator -Name Ansible.Windows.CertAclHelper.CertAccessRights -TypeName CertAccessRights
//TypeAccelerator -Name Ansible.Windows.CertAclHelper.CertAclHelper -TypeName CertAclHelper

namespace ansible_collections.ansible.windows.plugins.module_utils.CertACLHelper
{
    class CryptHandle : SafeHandleZeroOrMinusOneIsInvalid
    {
        public CryptHandle()
            : base(true)
        {
        }

        public CryptHandle(IntPtr handle)
            : base(true)
        {
            this.SetHandle(handle);
        }

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CryptReleaseContext(IntPtr safeProvHandle, uint dwFlags);

        protected override bool ReleaseHandle()
        {
            return CryptReleaseContext(this.handle, 0);
        }
    }

    class SafeSecurityDescriptorPtr : SafeHandleZeroOrMinusOneIsInvalid
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

        public SafeSecurityDescriptorPtr(IntPtr handle)
            : base(true)
        {
            this.SetHandle(handle);
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
        public enum SecurityInformationFlags : uint
        {
            DACL_SECURITY_INFORMATION = 0x00000004,
        }
        [Flags]
        public enum CryptAcquireKeyFlags : uint
        {
            CRYPT_ACQUIRE_SILENT_FLAG = 0x00000040,
        }
        [Flags]
        public enum CryptAcquireKeyFlagControl : uint
        {
            CRYPT_ACQUIRE_ALLOW_NCRYPT_KEY_FLAG = 0x00010000,
            CRYPT_ACQUIRE_PREFER_NCRYPT_KEY_FLAG = 0x00020000,
            CRYPT_ACQUIRE_ONLY_NCRYPT_KEY_FLAG = 0x00040000,
        }
        public enum KeySpec : uint
        {
            NONE = 0x0,
            AT_KEYEXCHANGE = 0x1,
            AT_SIGNATURE = 2,
            CERT_NCRYPT_KEY_SPEC = 0xFFFFFFFF
        }

        [DllImport("crypt32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern bool CryptAcquireCertificatePrivateKey(IntPtr pCert, uint dwFlags, IntPtr pvParameters, out CryptHandle phCryptProvOrNCryptKey, out KeySpec pdwKeySpec, out bool pfCallerFreeProvOrNCryptKey);

        [DllImport("ncrypt.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern int NCryptGetProperty(CryptHandle hObject, [MarshalAs(UnmanagedType.LPWStr)] string pszProperty, SafeSecurityDescriptorPtr pbOutput, uint cbOutput, ref uint pcbResult, SecurityInformationFlags dwFlags);

        [DllImport("ncrypt.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        private static extern int NCryptSetProperty(CryptHandle hObject, [MarshalAs(UnmanagedType.LPWStr)] string pszProperty, [MarshalAs(UnmanagedType.LPArray)] byte[] pbInput, uint cbInput, SecurityInformationFlags dwFlags);

        public enum CryptProvParam : uint
        {
            PP_KEYSET_SEC_DESCR = 8
        }

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CryptGetProvParam(CryptHandle safeProvHandle, CryptProvParam dwParam, SafeSecurityDescriptorPtr pbData, ref uint dwDataLen, SecurityInformationFlags dwFlags);

        [DllImport("advapi32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        [return: MarshalAs(UnmanagedType.Bool)]
        private static extern bool CryptSetProvParam(CryptHandle safeProvHandle, CryptProvParam dwParam, [MarshalAs(UnmanagedType.LPArray)] byte[] pbData, SecurityInformationFlags dwFlags);

        CryptHandle handle;
        bool ncrypt = false;

        public CertAclHelper(X509Certificate2 certificate)
        {
            CryptHandle certPkeyHandle;
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
                throw new Win32Exception(Marshal.GetLastWin32Error());
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
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                    }

                    securityDescriptorBuffer = new SafeSecurityDescriptorPtr(securityDescriptorSize);
                    if (!CryptGetProvParam(
                            handle,
                            CryptProvParam.PP_KEYSET_SEC_DESCR,
                            securityDescriptorBuffer,
                            ref securityDescriptorSize,
                            SecurityInformationFlags.DACL_SECURITY_INFORMATION))
                    {
                        throw new Win32Exception(Marshal.GetLastWin32Error());
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
                        throw new Win32Exception(Marshal.GetLastWin32Error());
                    }
                }
            }
        }
    }
}