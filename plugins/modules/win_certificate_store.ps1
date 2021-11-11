#!powershell

# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell Ansible.ModuleUtils.AddType

$spec = @{
    options = @{
        state = @{ type = "str"; default = "present"; choices = "absent", "exported", "present" }
        path = @{ type = "path" }
        thumbprint = @{ type = "str" }
        store_name = @{ type = "str"; default = "My" }
        store_location = @{ type = "str"; default = "LocalMachine" }
        store_type = @{ type = "str"; default = "system"; choices = "service", "system" }
        password = @{ type = "str"; no_log = $true }
        key_exportable = @{ type = "bool"; default = $true }
        key_storage = @{ type = "str"; default = "default"; choices = "default", "machine", "user" }
        file_type = @{ type = "str"; default = "der"; choices = "der", "pem", "pkcs12" }
    }
    required_if = @(
        @("state", "absent", @("path", "thumbprint"), $true),
        @("state", "exported", @("path", "thumbprint")),
        @("state", "present", @("path"))
    )
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

Add-CSharpType -AnsibleModule $module -References @'
using Microsoft.Win32.SafeHandles;
using System;
using System.Runtime.InteropServices;
using System.Security.Cryptography.X509Certificates;

namespace ansible.windows.win_certificate_store
{
    internal class NativeMethods
    {
        [DllImport("Crypt32.dll")]
        public static extern bool CertCloseStore(
            IntPtr hCertStore,
            uint dwFlags);

        [DllImport("Crypt32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        public static extern SafeX509Store CertOpenStore(
            IntPtr lpszStoreProvider,
            uint dwEncodingType,
            IntPtr hCryptProv,
            uint dwFlags,
            string pvPara);

        [DllImport("Crypt32.dll", CharSet=CharSet.Unicode, SetLastError=true)]
        public static extern bool CertRegisterSystemStore(
            [MarshalAs(UnmanagedType.LPWStr)] string pvSystemStore,
            uint dwFlags,
            IntPtr pStoreInfo,
            IntPtr pvReserved);
    }

    internal class SafeX509Store : SafeHandle
    {
        public SafeX509Store() : this(true) { }

        protected SafeX509Store(bool ownsHandle): base(IntPtr.Zero, ownsHandle) {}

        public override bool IsInvalid {
            get { return handle == null || handle == IntPtr.Zero; }
        }

        protected override bool ReleaseHandle()
        {
            return NativeMethods.CertCloseStore(handle, 0);
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

    public enum StoreType : uint
    {
        LocalMachine = 0x00020000,
        CurrentUser = 0x00010000,
        Service = 0x00050000,
    }

    public class Store
    {
        public static X509Store Open(StoreType storeType, string name, OpenFlags openFlags)
        {
            uint flags = 0x00000004;  // CERT_STORE_DEFER_CLOSE_UNTIL_LAST_FREE_FLAG

            if (((uint)openFlags & 3) == (uint)OpenFlags.ReadOnly)
                flags |= 0x00008000;  // CERT_STORE_READONLY_FLAG
            else
                flags |= 0x00001000;  // CERT_STORE_MAXIMUM_ALLOWED_FLAG

            if (openFlags.HasFlag(OpenFlags.OpenExistingOnly))
                flags |= 0x00004000;  // CERT_STORE_OPEN_EXISTING_FLAG

            using (SafeX509Store store = OpenStore(storeType, name, flags))
            {
                // X509Store duplicates the handle so we can safely dispose ours
                return new X509Store(store.DangerousGetHandle());
            }
        }

        public static void Delete(StoreType storeType, string name)
        {
            // TODO: Need better logic for this, fails with file not found after 2nd run.
            // CERT_STORE_DELETE_FLAG
            OpenStore(storeType, name, 0x00000010);
        }

        public static void Register(StoreType storeType, string name)
        {
            if (!NativeMethods.CertRegisterSystemStore(name, (uint)storeType, IntPtr.Zero, IntPtr.Zero))
                throw new Win32Exception("CertRegisterSystemStore failed");
        }

        private static SafeX509Store OpenStore(StoreType storeType, string name, uint flags)
        {
            flags |= (uint)storeType;

            SafeX509Store store = NativeMethods.CertOpenStore(
                new IntPtr(10),  // CERT_STORE_PROV_SYSTEM_W
                0,
                IntPtr.Zero,
                flags,
                name
            );
            int err = Marshal.GetLastWin32Error();

            // DELETE returns NULL for store so we need to check the error code.
            bool wasDelete = (flags & 0x00000010) != 0;
            if ((wasDelete && err != 0) || (!wasDelete && store.IsInvalid))
                throw new Win32Exception(err, "CertOpenStore failed");

            return store;
        }
    }
}
'@

Function Get-CertStore {
    [CmdletBinding(DefaultParameterSetName = 'System')]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'System')]
        [Security.Cryptography.X509Certificates.Storelocation]
        $Location,

        [Parameter(Mandatory = $true, ParameterSetName = 'Service')]
        [string]
        $Service,

        [Parameter(Mandatory = $true)]
        [string]
        $Name,

        [Security.Cryptography.X509Certificates.OpenFlags]
        $OpenFlags
    )

    if ($PSCmdlet.ParameterSetName -eq 'System') {
        $store_type = [ansible.windows.win_certificate_store.StoreType]($Location.ToString())
    }
    else {
        $store_type = [ansible.windows.win_certificate_store.StoreType]::Service
        $Name = '{0}\{1}' -f ($Service, $Name)
    }

    try {
        [ansible.windows.win_certificate_store.Store]::Open($store_type, $Name, $OpenFlags)
    }
    catch [ansible.windows.win_certificate_store.Win32Exception] {
        # Yes this is necessary, without it anything catching this type for error flow will get
        # MethodInvocationException and will need to drill down into InnerException :(
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

Function Get-CertFile($module, $path, $password, $key_exportable, $key_storage) {
    # parses a certificate file and returns X509Certificate2Collection
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $module.FailJson("File at '$path' either does not exist or is not a file")
    }

    # must set at least the PersistKeySet flag so that the PrivateKey
    # is stored in a permanent container and not deleted once the handle
    # is gone.
    $store_flags = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::PersistKeySet

    $key_storage = $key_storage.substring(0, 1).ToUpper() + $key_storage.substring(1).ToLower()
    $store_flags = $store_flags -bor [Enum]::Parse([System.Security.Cryptography.X509Certificates.X509KeyStorageFlags], "$($key_storage)KeySet")
    if ($key_exportable) {
        $store_flags = $store_flags -bor [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable
    }

    # TODO: If I'm feeling adventurours, write code to parse PKCS#12 PEM encoded
    # file as .NET does not have an easy way to import this
    $certs = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2Collection

    try {
        $certs.Import($path, $password, $store_flags)
    }
    catch {
        $module.FailJson("Failed to load cert from file: $($_.Exception.Message)", $_)
    }

    return $certs
}

Function New-CertFile($module, $cert, $path, $type, $password) {
    $content_type = switch ($type) {
        "pem" { [System.Security.Cryptography.X509Certificates.X509ContentType]::Cert }
        "der" { [System.Security.Cryptography.X509Certificates.X509ContentType]::Cert }
        "pkcs12" { [System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12 }
    }
    if ($type -eq "pkcs12") {
        $missing_key = $false
        if ($null -eq $cert.PrivateKey) {
            $missing_key = $true
        }
        elseif ($cert.PrivateKey.CspKeyContainerInfo.Exportable -eq $false) {
            $missing_key = $true
        }
        if ($missing_key) {
            $module.FailJson("Cannot export cert with key as PKCS12 when the key is not marked as exportable or not accessible by the current user")
        }
    }

    if (Test-Path -LiteralPath $path) {
        Remove-Item -LiteralPath $path -Force
        $module.Result.changed = $true
    }
    try {
        $cert_bytes = $cert.Export($content_type, $password)
    }
    catch {
        $module.FailJson("Failed to export certificate as bytes: $($_.Exception.Message)", $_)
    }

    # Need to manually handle a PEM file
    if ($type -eq "pem") {
        $cert_content = "-----BEGIN CERTIFICATE-----`r`n"
        $base64_string = [System.Convert]::ToBase64String($cert_bytes, [System.Base64FormattingOptions]::InsertLineBreaks)
        $cert_content += $base64_string
        $cert_content += "`r`n-----END CERTIFICATE-----"
        $file_encoding = [System.Text.Encoding]::ASCII
        $cert_bytes = $file_encoding.GetBytes($cert_content)
    }
    elseif ($type -eq "pkcs12") {
        $module.Result.key_exported = $false
        if ($null -ne $cert.PrivateKey) {
            $module.Result.key_exportable = $cert.PrivateKey.CspKeyContainerInfo.Exportable
        }
    }

    if (-not $module.CheckMode) {
        try {
            [System.IO.File]::WriteAllBytes($path, $cert_bytes)
        }
        catch [System.ArgumentNullException] {
            $module.FailJson("Failed to write cert to file, cert was null: $($_.Exception.Message)", $_)
        }
        catch [System.IO.IOException] {
            $module.FailJson("Failed to write cert to file due to IO Exception: $($_.Exception.Message)", $_)
        }
        catch [System.UnauthorizedAccessException] {
            $module.FailJson("Failed to write cert to file due to permissions: $($_.Exception.Message)", $_)
        }
        catch {
            $module.FailJson("Failed to write cert to file: $($_.Exception.Message)", $_)
        }
    }
    $module.Result.changed = $true
}

Function Get-CertFileType($path, $password) {
    $certs = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    try {
        $certs.Import($path, $password, 0)
    }
    catch [System.Security.Cryptography.CryptographicException] {
        # the file is a pkcs12 we just had the wrong password
        return "pkcs12"
    }
    catch {
        return "unknown"
    }

    $file_contents = Get-Content -LiteralPath $path -Raw
    if ($file_contents.StartsWith("-----BEGIN CERTIFICATE-----")) {
        return "pem"
    }
    elseif ($file_contents.StartsWith("-----BEGIN PKCS7-----")) {
        return "pkcs7-ascii"
    }
    elseif ($certs.Count -gt 1) {
        # multiple certs must be pkcs7
        return "pkcs7-binary"
    }
    elseif ($certs[0].HasPrivateKey) {
        return "pkcs12"
    }
    elseif ($path.EndsWith(".pfx") -or $path.EndsWith(".p12")) {
        # no way to differenciate a pfx with a der file so we must rely on the
        # extension
        return "pkcs12"
    }
    else {
        return "der"
    }
}

$state = $module.Params.state
$path = $module.Params.path
$thumbprint = $module.Params.thumbprint
$store_name = $module.Params.store_name
$store_location = $module.Params.store_location
$store_type = $module.Params.store_type
$password = $module.Params.password
$key_exportable = $module.Params.key_exportable
$key_storage = $module.Params.key_storage
$file_type = $module.Params.file_type

$module.Result.thumbprints = @()

[Security.Cryptography.X509Certificates.OpenFlags]$open_flags = if ($state -eq 'exported') { 'ReadOnly' } else { 'ReadWrite' }
$open_flags = [int]$open_flags -bor [int][Security.Cryptography.X509Certificates.OpenFlags]::OpenExistingOnly

# We originally opened the store with [X509]::new($name, $location). Now that we call the necessary Win32 APIs we need
# map any of the StoreName enum values to the proper string name. Luckily that is just CertificateAuthority -> CA.
# https://github.com/microsoft/referencesource/blob/master/System/security/system/security/cryptography/x509/x509store.cs#L67-L91
if ($store_name -eq 'CertificateAuthority') {
    $store_name = 'CA'
}

$cert_params = @{
    Name = $store_name
}
if ($store_type -eq 'system') {
    $store_location_values = ([System.Security.Cryptography.X509Certificates.StoreLocation]).GetEnumValues() | ForEach-Object { $_.ToString() }
    if ($store_location -notin $store_location_values) {
        $module.FailJson("value of store_location must be one of: $($store_location_values -join ", "). Got no match for: $store_location")
    }
    $cert_params.Location = [System.Security.Cryptography.X509Certificates.Storelocation]$store_location
}
else {
    $service = Get-Service -Name $store_location -ErrorAction SilentlyContinue
    if (-not $service) {
        $module.FailJson("value of store_location '$store_location' is not a valid windows service")
    }
    $cert_params.Service = $service.Name

    # These keys are based on what mmc creates the first time you open the snapping for that service account.
    # Would be nice if there was a proper API for this but I cannot find any.
    $reg_path = "HKLM:\SOFTWARE\Microsoft\Cryptography\Services\$($service.Name)\SystemCertificates"
    'AuthRoot', 'CA', 'ClientAuthIssuer', 'Disallowed', 'My', 'Root', 'Trust', 'TrustedPeople', 'TrustedPublisher' |
        ForEach-Object -Process {
            $reg_store_path = Join-Path -Path $reg_path -ChildPath $_

            if (-not (Test-Path -LiteralPath $reg_store_path)) {
                if (-not $module.CheckMode) {
                    [ansible.windows.win_certificate_store.Store]::Register(
                        [ansible.windows.win_certificate_store.StoreType]::Service,
                        "$($service.Name)\$_"
                    )
                }
                $module.Result.changed = $true
            }
        }
}

try {
    $store = Get-CertStore @cert_params -OpenFlags $open_flags -ErrorAction SilentlyContinue

}
catch [ansible.windows.win_certificate_store.Win32Exception] {
    if ($_.Exception.NativeErrorCode -in @(2, 3)) {
        # ERROR_FILE_NOT_FOUND, ERROR_PATH_NOT_FOUND
        $msg = "unable to find store '$store_name'"
    }
    elseif ($_.Exception.NativeErrorCode -eq 5) {
        # ERROR_ACCESS_DENIED
        $msg = "unable to open the store with the current permissions"
    }
    else {
        $msg = "unable to open the store"
    }
    $module.FailJson("$($msg): ($($_.Exception.Message))", $_)
}

try {
    $store_certificates = $store.Certificates

    if ($state -eq "absent") {
        $cert_thumbprints = @()

        if ($null -ne $path) {
            $certs = Get-CertFile -module $module -path $path -password $password -key_exportable $key_exportable -key_storage $key_storage
            foreach ($cert in $certs) {
                $cert_thumbprints += $cert.Thumbprint
            }
        }
        elseif ($null -ne $thumbprint) {
            $cert_thumbprints += $thumbprint
        }

        foreach ($cert_thumbprint in $cert_thumbprints) {
            $module.Result.thumbprints += $cert_thumbprint
            $found_certs = $store_certificates.Find([System.Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint, $cert_thumbprint, $false)
            if ($found_certs.Count -gt 0) {
                foreach ($found_cert in $found_certs) {
                    try {
                        if (-not $module.CheckMode) {
                            $store.Remove($found_cert)
                        }
                    }
                    catch [System.Security.SecurityException] {
                        $module.FailJson("Unable to remove cert with thumbprint '$cert_thumbprint' with current permissions: $($_.Exception.Message)", $_)
                    }
                    catch {
                        $module.FailJson("Unable to remove cert with thumbprint '$cert_thumbprint': $($_.Exception.Message)", $_)
                    }
                    $module.Result.changed = $true
                }
            }
        }
    }
    elseif ($state -eq "exported") {
        # TODO: Add support for PKCS7 and exporting a cert chain
        $module.Result.thumbprints += $thumbprint
        $export = $true
        if (Test-Path -LiteralPath $path -PathType Container) {
            $module.FailJson("Cannot export cert to path '$path' as it is a directory")
        }
        elseif (Test-Path -LiteralPath $path -PathType Leaf) {
            $actual_cert_type = Get-CertFileType -path $path -password $password
            if ($actual_cert_type -eq $file_type) {
                try {
                    $certs = Get-CertFile -module $module -path $path -password $password -key_exportable $key_exportable -key_storage $key_storage
                }
                catch {
                    # failed to load the file so we set the thumbprint to something
                    # that will fail validation
                    $certs = @{Thumbprint = $null }
                }

                if ($certs.Thumbprint -eq $thumbprint) {
                    $export = $false
                }
            }
        }

        if ($export) {
            $found_certs = $store_certificates.Find([System.Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint, $thumbprint, $false)
            if ($found_certs.Count -ne 1) {
                $module.FailJson("Found $($found_certs.Count) certs when only expecting 1")
            }

            New-CertFile -module $module -cert $found_certs -path $path -type $file_type -password $password
        }
    }
    else {
        $certs = Get-CertFile -module $module -path $path -password $password -key_exportable $key_exportable -key_storage $key_storage
        foreach ($cert in $certs) {
            $module.Result.thumbprints += $cert.Thumbprint
            $found_certs = $store_certificates.Find([System.Security.Cryptography.X509Certificates.X509FindType]::FindByThumbprint, $cert.Thumbprint, $false)
            if ($found_certs.Count -eq 0) {
                try {
                    if (-not $module.CheckMode) {
                        $store.Add($cert)
                    }
                }
                catch [System.Security.Cryptography.CryptographicException] {
                    $msg = "Unable to import certificate with thumbprint '$($cert.Thumbprint)' with the current permissions: $($_.Exception.Message)"
                    $module.FailJson($msg, $_)
                }
                catch {
                    $module.FailJson("Unable to import certificate with thumbprint '$($cert.Thumbprint)': $($_.Exception.Message)", $_)
                }
                $module.Result.changed = $true
            }
        }
    }
}
finally {
    $store.Close()
}

$module.ExitJson()
