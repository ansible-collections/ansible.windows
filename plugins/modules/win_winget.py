#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_winget
short_description: Manage packages using Windows Package Manager (winget)
description:
  - Install, upgrade, or uninstall packages using Microsoft's official Windows Package Manager (winget).
  - Winget is built-in on Windows 11 and Windows Server 2025.
  - For older Windows versions (10, Server 2019-2022), winget can be installed via the App Installer package from Microsoft Store or GitHub.
  - Manage custom package sources and repositories.
options:
  name:
    description:
      - The package identifier to install, upgrade, or uninstall.
      - Can be the package ID (e.g., C(Microsoft.VisualStudioCode)) or the package name.
      - Package ID is recommended for precision; name may return multiple matches.
    type: str
    required: yes
    aliases: [ id ]
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
    type: str
  source:
    description:
      - The source to use when installing or upgrading packages.
      - If not specified, winget will search all configured sources.
      - Common sources include C(winget) (official Microsoft repository) and C(msstore) (Microsoft Store).
      - Custom sources can be added using the C(winget source add) command.
    type: str
  scope:
    description:
      - Installation scope for the package.
      - V(user) installs for the current user only (no admin rights required).
      - V(machine) installs system-wide (requires admin rights).
      - If not specified, winget will use the package's default scope or require admin for machine-wide install.
    type: str
    choices: [ user, machine ]
  architecture:
    description:
      - The architecture to use when installing the package.
      - If not specified, winget will use the system's default architecture.
    type: str
    choices: [ x86, x64, arm, arm64 ]
  override_arguments:
    description:
      - Additional arguments to pass to the installer.
      - These arguments override the default installer arguments.
      - Use with caution as this may affect installer behavior.
    type: str
  accept_package_agreements:
    description:
      - Accept all license agreements for the package.
      - Required for packages that have license agreements.
      - When V(false), installation will fail if the package requires agreement acceptance.
    type: bool
    default: true
notes:
  - Winget must be installed on the target system. It is built-in on Windows 11 and Server 2025.
  - For Windows 10 and Server 2019-2022, install the App Installer package from Microsoft Store or download from GitHub.
  - Some operations may require administrator privileges depending on the package and scope.
  - Check mode is supported.
seealso:
  - module: ansible.windows.win_package
  - module: chocolatey.chocolatey.win_chocolatey
author:
  - Ansible Core Team
'''

EXAMPLES = r'''
- name: Install Visual Studio Code
  ansible.windows.win_winget:
    name: Microsoft.VisualStudioCode
    state: present

- name: Install a specific version of Git
  ansible.windows.win_winget:
    name: Git.Git
    version: 2.40.0
    state: present

- name: Ensure latest version of 7-Zip is installed
  ansible.windows.win_winget:
    name: 7zip.7zip
    state: latest

- name: Install package from a specific source
  ansible.windows.win_winget:
    name: Microsoft.PowerToys
    source: winget
    state: present

- name: Install package for current user only
  ansible.windows.win_winget:
    name: Microsoft.WindowsTerminal
    scope: user
    state: present

- name: Install package with custom installer arguments
  ansible.windows.win_winget:
    name: Python.Python.3.11
    override_arguments: /quiet PrependPath=1
    state: present

- name: Uninstall a package
  ansible.windows.win_winget:
    name: Microsoft.Edge
    state: absent

- name: Install package for specific architecture
  ansible.windows.win_winget:
    name: Notepad++.Notepad++
    architecture: x64
    state: present
'''

RETURN = r'''
changed:
  description: Whether the package state was changed.
  returned: always
  type: bool
  sample: true
package_id:
  description: The package ID that was processed.
  returned: success
  type: str
  sample: Microsoft.VisualStudioCode
installed_version:
  description: The version of the package that is now installed.
  returned: when state is present or latest
  type: str
  sample: 1.75.0
previous_version:
  description: The version of the package before the operation.
  returned: when package was already installed
  type: str
  sample: 1.74.0
rc:
  description: The return code from the winget command.
  returned: always
  type: int
  sample: 0
stdout:
  description: The standard output from the winget command.
  returned: always
  type: str
stderr:
  description: The standard error output from the winget command.
  returned: always
  type: str
'''
