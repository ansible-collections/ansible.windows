# Prerequisites - ACA-6275: Package Management Modernization

**Epic**: ACA-6275  
**Collection**: ansible.windows  
**Generated**: 2026-06-01

---

## Platform Characteristics

**Target Platform**: Windows (modern versions with package management support)

**Key Characteristics**:
1. **Winget support**: Built-in on Windows 11 and Windows Server 2025; installable on Windows 10/Server 2019-2022
2. **PackageManagement module**: Built-in PowerShell module on Windows 10+ and Server 2016+
3. **PowerShell version**: Requires PowerShell 5.1+ for PackageManagement cmdlets
4. **Execution policy**: May need to set execution policy for PackageManagement operations

---

## Test Environment Prerequisites

**For win_winget module testing**:

1. **Winget availability**:
   - **Preferred**: Windows 11 or Windows Server 2025 (winget pre-installed)
   - **Alternative**: Windows 10/Server 2019-2022 with winget manually installed
   - **Verification**: `winget --version` should return version number
   - **Installation method** (if needed): Download App Installer from Microsoft Store or install via GitHub release

2. **Internet connectivity**:
   - Required for winget to access default package sources
   - Or configure custom/internal winget sources if air-gapped

3. **Permissions**:
   - Administrator rights for machine-scope installations
   - User rights for user-scope installations

---

**For win_package enhancement testing**:

1. **PackageManagement module**:
   - **Availability**: Built-in on Windows 10+ and Server 2016+
   - **Verification**: `Get-Module -ListAvailable PackageManagement`
   - **Installation method** (if needed): `Install-Module -Name PackageManagement -Force`

2. **PowerShellGet module** (for testing PowerShellGet provider):
   - **Availability**: Built-in on Windows 10+ with PowerShell 5.1+
   - **Verification**: `Get-Module -ListAvailable PowerShellGet`
   - **Installation method** (if needed): `Install-Module -Name PowerShellGet -Force`

3. **NuGet provider** (for testing NuGet packages):
   - **Installation**: Auto-installed when first using NuGet provider
   - **Verification**: `Get-PackageProvider -Name NuGet`
   - **Installation method** (if needed): `Install-PackageProvider -Name NuGet -Force`

4. **Internet connectivity**:
   - Required for accessing PowerShell Gallery (PowerShellGet)
   - Required for accessing NuGet.org (NuGet provider)
   - Or configure custom/internal package sources

---

## Installation Strategy

**For test environment (10.46.109.224 - Windows Server 2025)**:

1. **Winget**: Should be pre-installed on Server 2025
   - Verify with: `winget --version`
   - If missing, install App Installer from Microsoft

2. **PackageManagement**: Built-in on Server 2025
   - Verify with: `Get-Module -ListAvailable PackageManagement`

3. **PowerShellGet**: Built-in on Server 2025
   - Verify with: `Get-Module -ListAvailable PowerShellGet`

4. **NuGet Provider**: Install on first use
   - Command: `Install-PackageProvider -Name NuGet -Force -Scope AllUsers`

**Expected outcome**: All prerequisites should be available or easily installable on Windows Server 2025.

---

## Fallback Strategy

**If winget is not available on test environment**:
- Mark `win_winget` module as `[!] CODE COMPLETE, TESTS BLOCKED`
- Document in `blocked_modules.md`
- Provide manual testing instructions
- Module can still be reviewed for code quality

**If PackageManagement providers fail**:
- Test with available providers only
- Mark unsupported provider tests as skipped
- Document provider availability requirements in module documentation

---

## Runtime Dependencies

**For win_winget module**:
- Winget CLI (App Installer)
- Windows 10/11 or Server 2019/2022/2025

**For win_package enhancement**:
- PackageManagement PowerShell module (built-in)
- Specific providers as needed (NuGet, PowerShellGet, etc.)

**No collection-level dependencies required** - all dependencies are runtime platform requirements.
