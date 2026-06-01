#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_package_management
short_description: Manage packages using PowerShell PackageManagement providers
description:
  - Install, upgrade, or uninstall packages using PowerShell PackageManagement (OneGet) providers.
  - PackageManagement is built-in on Windows 10+ and Server 2016+.
  - Supports various providers including NuGet, PowerShellGet, Chocolatey, and custom providers.
  - Can manage packages from PowerShell Gallery, NuGet.org, and custom repositories.
options:
  name:
    description:
      - The name of the package to install, upgrade, or uninstall.
      - Package names are provider-specific.
    type: str
    required: yes
  state:
    description:
      - Desired state of the package.
      - V(present) ensures the package is installed.
      - V(absent) ensures the package is uninstalled.
      - V(latest) ensures the package is installed and upgraded to the latest version.
    type: str
    choices: [ present, absent, latest ]
    default: present
  version:
    description:
      - Specific version of the package to install.
      - If not specified, the latest version will be installed.
      - Only applies when I(state=present).
      - Cannot be used with I(state=latest).
      - Version format is provider-specific (e.g., "1.2.3" for NuGet packages).
    type: str
  provider:
    description:
      - The PackageManagement provider to use.
      - If not specified, PackageManagement will auto-detect the appropriate provider.
      - Common providers include C(NuGet), C(PowerShellGet), C(Chocolatey), C(msi), C(Programs).
      - Use C(Get-PackageProvider -ListAvailable) to see available providers.
    type: str
  source:
    description:
      - The package source (repository) to use.
      - If not specified, will search all registered sources for the provider.
      - For PowerShellGet: typically C(PSGallery)
      - For NuGet: typically C(nuget.org) or custom feeds
      - Use C(Get-PackageSource) to see registered sources.
    type: str
  scope:
    description:
      - Installation scope for the package.
      - V(currentuser) installs for the current user only.
      - V(allusers) installs system-wide (may require admin rights).
      - Only supported by some providers (e.g., PowerShellGet).
    type: str
    choices: [ currentuser, allusers ]
  minimum_version:
    description:
      - Minimum version of the package to install.
      - Can be used with I(state=present) to ensure at least this version is installed.
      - Cannot be used with I(version) or I(state=latest).
    type: str
  maximum_version:
    description:
      - Maximum version of the package to install.
      - Can be used with I(state=present) to cap the maximum version.
      - Cannot be used with I(version) or I(state=latest).
    type: str
  force:
    description:
      - Force installation even if the package is already installed.
      - Useful for reinstalling packages or installing side-by-side versions.
      - When V(true), skips some validation checks.
    type: bool
    default: false
  allow_clobber:
    description:
      - Allow installation even if commands from the package conflict with existing commands.
      - Only applies to PowerShellGet provider.
      - When V(false), installation will fail if command conflicts are detected.
    type: bool
    default: false
  skip_dependencies:
    description:
      - Skip installation of package dependencies.
      - When V(true), only the specified package is installed/uninstalled.
      - When V(false), dependencies are also processed.
    type: bool
    default: false
notes:
  - PackageManagement module must be available on the target system (built-in on Windows 10+ and Server 2016+).
  - Some providers may need to be installed before use (e.g., C(Install-PackageProvider -Name NuGet -Force)).
  - Administrator privileges may be required for some operations depending on the scope and provider.
  - Check mode is supported.
seealso:
  - module: ansible.windows.win_package
  - module: ansible.windows.win_winget
  - module: chocolatey.chocolatey.win_chocolatey
author:
  - Ansible Core Team
'''

EXAMPLES = r'''
- name: Install a PowerShell module from PSGallery
  ansible.windows.win_package_management:
    name: Pester
    provider: PowerShellGet
    source: PSGallery
    state: present

- name: Install a specific version of a PowerShell module
  ansible.windows.win_package_management:
    name: Pester
    version: 5.3.3
    provider: PowerShellGet
    state: present

- name: Install a NuGet package
  ansible.windows.win_package_management:
    name: Newtonsoft.Json
    provider: NuGet
    state: present

- name: Ensure latest version of a package
  ansible.windows.win_package_management:
    name: Pester
    provider: PowerShellGet
    state: latest

- name: Install package for current user only
  ansible.windows.win_package_management:
    name: PSReadLine
    provider: PowerShellGet
    scope: currentuser
    state: present

- name: Install with minimum version constraint
  ansible.windows.win_package_management:
    name: Pester
    provider: PowerShellGet
    minimum_version: 5.0.0
    state: present

- name: Install with version range
  ansible.windows.win_package_management:
    name: Pester
    provider: PowerShellGet
    minimum_version: 5.0.0
    maximum_version: 5.9.9
    state: present

- name: Force reinstall a package
  ansible.windows.win_package_management:
    name: Pester
    provider: PowerShellGet
    force: true
    state: present

- name: Install with command clobbering allowed
  ansible.windows.win_package_management:
    name: AzureRM
    provider: PowerShellGet
    allow_clobber: true
    state: present

- name: Uninstall a package
  ansible.windows.win_package_management:
    name: Pester
    provider: PowerShellGet
    state: absent

- name: Install without dependencies
  ansible.windows.win_package_management:
    name: MyPackage
    provider: PowerShellGet
    skip_dependencies: true
    state: present
'''

RETURN = r'''
changed:
  description: Whether the package state was changed.
  returned: always
  type: bool
  sample: true
package_name:
  description: The package name that was processed.
  returned: success
  type: str
  sample: Pester
provider:
  description: The PackageManagement provider that was used.
  returned: success
  type: str
  sample: PowerShellGet
installed_version:
  description: The version of the package that is now installed.
  returned: when state is present or latest
  type: str
  sample: 5.3.3
previous_version:
  description: The version of the package before the operation.
  returned: when package was already installed
  type: str
  sample: 5.2.0
rc:
  description: The return code from the operation (0 = success).
  returned: always
  type: int
  sample: 0
msg:
  description: Additional information about the operation.
  returned: always
  type: str
  sample: Package 'Pester' installed successfully
'''
