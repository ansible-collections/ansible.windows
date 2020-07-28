#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2015, Jon Hawkesworth (@jhawkesworth) <jhawkesworth@protonmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_regmerge
short_description: Merges the contents of a registry file into the Windows registry
description:
    - Wraps the reg.exe command to import the contents of a registry file.
    - Suitable for use with registry files created using M(ansible.windows.win_template).
    - Windows registry files have a specific format and must be constructed correctly with carriage return and line feed line endings otherwise they will not
      be merged.
    - Exported registry files often start with a Byte Order Mark which must be removed if the file is to templated using M(ansible.windows.win_template).
    - Registry file format is described at U(https://support.microsoft.com/en-us/kb/310516)
    - See also M(ansible.windows.win_template), M(ansible.windows.win_regedit)
options:
  path:
    description:
      - The full path including file name to the registry file on the remote machine to be merged
    type: path
    required: yes
  compare_key:
    description:
      - The parent key to use when comparing the contents of the registry to the contents of the file.  Needs to be in HKLM or HKCU part of registry.
        Use a PS-Drive style path for example HKLM:\SOFTWARE not HKEY_LOCAL_MACHINE\SOFTWARE
        If not supplied, or the registry key is not found, no comparison will be made, and the module will report changed.
    type: str
notes:
   - Organise your registry files so that they contain a single root registry
     key if you want to use the compare_to functionality.
   - This module does not force registry settings to be in the state
     described in the file.  If registry settings have been modified externally
     the module will merge the contents of the file but continue to report
     differences on subsequent runs.
   - To force registry change, use M(ansible.windows.win_regedit) with C(state=absent) before
     using C(community.windows.win_regmerge).
seealso:
- module: ansible.windows.win_reg_stat
- module: ansible.windows.win_regedit
author:
- Jon Hawkesworth (@jhawkesworth)
'''

EXAMPLES = r'''
- name: Merge in a registry file without comparing to current registry
  community.windows.win_regmerge:
    path: C:\autodeploy\myCompany-settings.reg

- name: Compare and merge registry file
  community.windows.win_regmerge:
    path: C:\autodeploy\myCompany-settings.reg
    compare_to: HKLM:\SOFTWARE\myCompany
'''

RETURN = r'''
compare_to_key_found:
    description: whether the parent registry key has been found for comparison
    returned: when comparison key not found in registry
    type: bool
    sample: false
difference_count:
    description: number of differences between the registry and the file
    returned: changed
    type: int
    sample: 1
compared:
    description: whether a comparison has taken place between the registry and the file
    returned: when a comparison key has been supplied and comparison has been attempted
    type: bool
    sample: true
'''
