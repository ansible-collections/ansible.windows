#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2014, Trond Hindenes <trond@hindenes.com>, and others
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_package
short_description: Installs/uninstalls an installable package
description:
- Installs or uninstalls software packages for Windows.
- Supports C(.exe), C(.msi), C(.msp), C(.appx), C(.appxbundle), C(.msix),
  and C(.msixbundle).
- These packages can be sourced from the local file system, network file share
  or a url.
- See I(provider) for more info on each package type that is supported.
options:
  arguments:
    description:
    - Any arguments the installer needs to either install or uninstall the
      package.
    - If the package is an MSI do not supply the C(/qn), C(/log) or
      C(/norestart) arguments.
    - This is only used for the C(msi), C(msp), and C(registry) providers.
    - Can be a list of arguments and the module will escape the arguments as
      necessary, it is recommended to use a string when dealing with MSI
      packages due to the unique escaping issues with msiexec.
    - When using a list of arguments each item in the list is considered to be
      a single argument. As such, if an argument in the list contains a space
      then Ansible will quote this to ensure that this is seen by Windows as
      a single argument. Should this behaviour not be what is required, the
      argument should be split into two separate list items. See the examples
      section for more detail.
    type: raw
  chdir:
    description:
    - Set the specified path as the current working directory before installing
      or uninstalling a package.
    - This is only used for the C(msi), C(msp), and C(registry) providers.
    type: path
  checksum:
    description:
      - If a I(checksum) is passed to this parameter, the digest of the
        package will be calculated before executing it to verify that the
        path or downloaded file has the expected contents.
    type: str
    version_added: 2.8.0
  checksum_algorithm:
    description:
      - Specifies the hashing algorithm used when calculating the checksum of
        the path provided.
    type: str
    choices:
      - md5
      - sha1
      - sha256
      - sha384
      - sha512
    default: sha1
    version_added: 2.8.0
  creates_path:
    description:
    - Will check the existence of the path specified and use the result to
      determine whether the package is already installed.
    - You can use this in conjunction with C(product_id) and other C(creates_*).
    type: path
  creates_service:
    description:
    - Will check the existing of the service specified and use the result to
      determine whether the package is already installed.
    - You can use this in conjunction with C(product_id) and other C(creates_*).
    type: str
  creates_version:
    description:
    - Will check the file version property of the file at C(creates_path) and
      use the result to determine whether the package is already installed.
    - C(creates_path) MUST be set and is a file.
    - You can use this in conjunction with C(product_id) and other C(creates_*).
    type: str
  expected_return_code:
    description:
    - One or more return codes from the package installation that indicates
      success.
    - The return codes are read as a signed integer, any values greater than
      2147483647 need to be represented as the signed equivalent, i.e.
      C(4294967295) is C(-1).
    - To convert a unsigned number to the signed equivalent you can run
      "[Int32]("0x{0:X}" -f ([UInt32]3221225477))".
    - A return code of C(3010) usually means that a reboot is required, the
      C(reboot_required) return value is set if the return code is C(3010).
    - This is only used for the C(msi), C(msp), and C(registry) providers.
    type: list
    elements: int
    default: [0, 3010]
  log_path:
    description:
    - Specifies the path to a log file that is persisted after a package is
      installed or uninstalled.
    - This is only used for the C(msi) or C(msp) provider.
    - When omitted, a temporary log file is used instead for those providers.
    - This is only valid for MSI files, use C(arguments) for the C(registry)
      provider.
    type: path
  path:
    description:
    - Location of the package to be installed or uninstalled.
    - This package can either be on the local file system, network share or a
      url.
    - When C(state=present), C(product_id) is not set and the path is a URL,
      this file will always be downloaded to a temporary directory for
      idempotency checks, otherwise the file will only be downloaded if the
      package has not been installed based on the C(product_id) checks.
    - If C(state=present) then this value MUST be set.
    - If C(state=absent) then this value does not need to be set if
      C(product_id) is.
    type: str
  product_id:
    description:
    - The product id of the installed packaged.
    - This is used for checking whether the product is already installed and
      getting the uninstall information if C(state=absent).
    - For msi packages, this is the C(ProductCode) (GUID) of the package. This
      can be found under the same registry paths as the C(registry) provider.
    - For msp packages, this is the C(PatchCode) (GUID) of the package which
      can found under the C(Details -> Revision number) of the file's properties.
    - For msix packages, this is the C(Name) or C(PackageFullName) of the
      package found under the C(Get-AppxPackage) cmdlet.
    - For registry (exe) packages, this is the registry key name under the
      registry paths specified in I(provider).
    - This value is ignored if C(path) is set to a local accesible file path
      and the package is not an C(exe).
    - This SHOULD be set when the package is an C(exe), or the path is a url
      or a network share and credential delegation is not being used. The
      C(creates_*) options can be used instead but is not recommended.
    type: str
  provider:
    description:
    - Set the package provider to use when searching for a package.
    - The C(auto) provider will select the proper provider if I(path)
      otherwise it scans all the other providers based on the I(product_id).
    - The C(msi) provider scans for MSI packages installed on a machine wide
      and current user context based on the C(ProductCode) of the MSI.
    - The C(msix) provider is used to install C(.appx), C(.msix),
      C(.appxbundle), or C(.msixbundle) packages. These packages are only
      installed or removed on the current use. The host must be set to allow
      sideloaded apps or in developer mode. See the examples for how to enable
      this. If a package is already installed but C(path) points to an updated
      package, this will be installed over the top of the existing one.
    - The C(msp) provider scans for all MSP patches installed on a machine wide
      and current user context based on the C(PatchCode) of the MSP. A C(msp)
      will be applied or removed on all C(msi) products that it applies to and
      is installed. If the patch is obsoleted or superseded then no action will
      be taken.
    - The C(registry) provider is used for traditional C(exe) installers and
      uses the following registry path to determine if a product was installed;
      C(HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall),
      C(HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall),
      C(HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall), and
      C(HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall).
    choices:
    - auto
    - msi
    - msix
    - msp
    - registry
    default: auto
    type: str
  state:
    description:
    - Whether to install or uninstall the package.
    - The module uses I(product_id) to determine whether the package is
      installed or not.
    - For all providers but C(auto), the I(path) can be used for idempotency
      checks if it is locally accesible filesystem path.
    type: str
    choices: [ absent, present ]
    default: present
  wait_for_children:
    description:
    - The module will wait for the process it spawns to finish but any
      processes spawned in that child process as ignored.
    - Set to C(true) to wait for all descendent processes to finish before the
      module returns.
    - This is useful if the install/uninstaller is just a wrapper which then
      calls the actual installer as its own child process. When this option is
      C(true) then the module will wait for both processes to finish before
      returning.
    - This should not be required for most installers and setting to C(true)
      could result in the module not returning until the process it is waiting
      for has been stopped manually.
    - Requires Windows Server 2012 or Windows 8 or newer to use.
    type: bool
    default: no
    version_added: 1.3.0
extends_documentation_fragment:
- ansible.windows.web_request

notes:
- When C(state=absent) and the product is an exe, the path may be different
  from what was used to install the package originally. If path is not set then
  the path used will be what is set under C(QuietUninstallString) or
  C(UninstallString) in the registry for that I(product_id).
- By default all msi installs and uninstalls will be run with the arguments
  C(/log, /qn, /norestart).
- All the installation checks under C(product_id) and C(creates_*) add
  together, if one fails then the program is considered to be absent.
seealso:
- module: chocolatey.chocolatey.win_chocolatey
- module: community.windows.win_hotfix
- module: ansible.windows.win_updates
author:
- Trond Hindenes (@trondhindenes)
- Jordan Borean (@jborean93)
'''

EXAMPLES = r'''
- name: Install the Visual C thingy
  ansible.windows.win_package:
    path: http://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe
    product_id: '{CF2BEA3C-26EA-32F8-AA9B-331F7E34BA97}'
    arguments: /install /passive /norestart

- name: Install Visual C thingy with list of arguments instead of a string
  ansible.windows.win_package:
    path: http://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe
    product_id: '{CF2BEA3C-26EA-32F8-AA9B-331F7E34BA97}'
    arguments:
      - /install
      - /passive
      - /norestart

- name: Install MSBuild thingy with arguments split to prevent quotes
  ansible.windows.win_package:
    path: https://download.visualstudio.microsoft.com/download/pr/9665567e-f580-4acd-85f2-bc94a1db745f/vs_BuildTools.exe
    product_id: '{D1437F51-786A-4F57-A99C-F8E94FBA1BD8}'
    arguments:
      - --norestart
      - --passive
      - --wait
      - --add
      - Microsoft.Net.Component.4.6.1.TargetingPack
      - --add
      - Microsoft.Net.Component.4.6.TargetingPack

- name: Install Remote Desktop Connection Manager from msi with a permanent log
  ansible.windows.win_package:
    path: https://download.microsoft.com/download/A/F/0/AF0071F3-B198-4A35-AA90-C68D103BDCCF/rdcman.msi
    product_id: '{0240359E-6A4C-4884-9E94-B397A02D893C}'
    state: present
    log_path: D:\logs\vcredist_x64-exe-{{lookup('pipe', 'date +%Y%m%dT%H%M%S')}}.log

- name: Install Application from msi with multiple properties for installer
  ansible.windows.win_package:
    path: C:\temp\Application.msi
    state: present
    arguments: >-
      SERVICE=1
      DBNAME=ApplicationDB
      DBSERVER=.\SQLEXPRESS
      INSTALLDIR="C:\Program Files (x86)\App lication\App Server"

- name: Install Microsoft® SQL Server® 2019 Express (DPAPI example)
  ansible.windows.win_package:
    path: C:\temp\SQLEXPR_x64_ENU\SETUP.EXE
    product_id: Microsoft SQL Server SQL2019
    arguments:
      - SAPWD=VeryHardPassword
      - /ConfigurationFile=C:\temp\configuration.ini
  become: true
  vars:
    ansible_become_method: runas
    ansible_become_user: "{{ user }}"
    ansible_become_pass: "{{ password }}"

- name: Uninstall Remote Desktop Connection Manager
  ansible.windows.win_package:
    product_id: '{0240359E-6A4C-4884-9E94-B397A02D893C}'
    state: absent

- name: Install Remote Desktop Connection Manager locally omitting the product_id
  ansible.windows.win_package:
    path: C:\temp\rdcman.msi
    state: present

- name: Uninstall Remote Desktop Connection Manager from local MSI omitting the product_id
  ansible.windows.win_package:
    path: C:\temp\rdcman.msi
    state: absent

# 7-Zip exe doesn't use a guid for the Product ID
- name: Install 7zip from a network share with specific credentials
  ansible.windows.win_package:
    path: \\domain\programs\7z.exe
    product_id: 7-Zip
    arguments: /S
    state: present
  become: true
  become_method: runas
  become_flags: logon_type=new_credential logon_flags=netcredentials_only
  vars:
    ansible_become_user: DOMAIN\User
    ansible_become_password: Password

- name: Install 7zip and use a file version for the installation check
  ansible.windows.win_package:
    path: C:\temp\7z.exe
    creates_path: C:\Program Files\7-Zip\7z.exe
    creates_version: 16.04
    state: present

- name: Uninstall 7zip from the exe
  ansible.windows.win_package:
    path: C:\Program Files\7-Zip\Uninstall.exe
    product_id: 7-Zip
    arguments: /S
    state: absent

- name: Uninstall 7zip without specifying the path
  ansible.windows.win_package:
    product_id: 7-Zip
    arguments: /S
    state: absent

- name: Install application and override expected return codes
  ansible.windows.win_package:
    path: https://download.microsoft.com/download/1/6/7/167F0D79-9317-48AE-AEDB-17120579F8E2/NDP451-KB2858728-x86-x64-AllOS-ENU.exe
    product_id: '{7DEBE4EB-6B40-3766-BB35-5CBBC385DA37}'
    arguments: '/q /norestart'
    state: present
    expected_return_code: [0, 666, 3010]

- name: Install a .msp patch
  ansible.windows.win_package:
    path: C:\Patches\Product.msp
    state: present

- name: Remove a .msp patch
  ansible.windows.win_package:
    product_id: '{AC76BA86-A440-FFFF-A440-0C13154E5D00}'
    state: absent

- name: Enable installation of 3rd party MSIX packages
  ansible.windows.win_regedit:
    path: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock
    name: AllowAllTrustedApps
    data: 1
    type: dword
    state: present

- name: Install an MSIX package for the current user
  ansible.windows.win_package:
    path: C:\Installers\Calculator.msix  # Can be .appx, .msixbundle, or .appxbundle
    state: present

- name: Uninstall an MSIX package using the product_id
  ansible.windows.win_package:
    product_id: InputApp
    state: absent
'''

RETURN = r'''
checksum:
  description: <algorithm> checksum of the package
  returned: checksum_algorithm is set, package exists, and not check mode
  type: str
  version_added: 2.8.0
  sample: 6E642BB8DD5C2E027BF21DD923337CBB4214F827
log:
  description: The contents of the MSI or MSP log.
  returned: installation/uninstallation failure for MSI or MSP packages
  type: str
  sample: Installation completed successfully
rc:
  description: The return code of the package process.
  returned: change occurred
  type: int
  sample: 0
reboot_required:
  description: Whether a reboot is required to finalise package. This is set
    to true if the executable return code is 3010.
  returned: always
  type: bool
  sample: true
stdout:
  description: The stdout stream of the package process.
  returned: failure during install or uninstall
  type: str
  sample: Installing program
stderr:
  description: The stderr stream of the package process.
  returned: failure during install or uninstall
  type: str
  sample: Failed to install program
'''
