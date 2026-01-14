#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2015, Jon Hawkesworth (@jhawkesworth) <figs@unity.demon.co.uk>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_file
short_description: Creates, touches or removes files or directories
description:
     - Creates (empty) files, updates file modification stamps of existing files,
       and can create or remove directories.
     - Timestamp values are interpreted as local time on the target Windows system if no time zone offset is specified.
     - Unlike M(ansible.builtin.file), does not modify ownership, permissions or manipulate links.
     - For non-Windows targets, use the M(ansible.builtin.file) module instead.
options:
  path:
    description:
      - Path to the file being managed.
    required: yes
    type: path
    aliases: [ dest, name ]
  state:
    description:
      - If C(directory), all immediate subdirectories will be created if they
        do not exist.
      - If C(file), the file will NOT be created if it does not exist, see the M(ansible.windows.win_copy)
        or M(ansible.windows.win_template) module if you want that behavior.
      - If C(absent), directories will be recursively deleted, and files will be removed.
      - If C(touch), an empty file will be created if the C(path) does not
        exist, while an existing file or directory will receive updated file access and
        modification times (similar to the way C(touch) works from the command line).
    type: str
    choices: [ absent, directory, file, touch ]
  modification_time:
    description:
      - The desired modification time for the file or directory.
      - A DateTime string in the format specified by O(modification_time_format).
      - The timestamp is interpreted as local time on the target system.
      - Timezone offsets are supported when included in the timestamp format.
        (for example, using C(z), C(zz) or C(zzz) format specifiers).
      - When unset, the default is V(preserve) when O(state=[file, directory]) and V(now) when O(state=touch).
    type: str
    version_added: 3.4.0
  modification_time_format:
    description:
      - The format to use when parsing C(modification_time).
      - Defaults to C(yyyy-MM-dd HH:mm:ss).
      - See L(.NET DateTime format strings,https://learn.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings).
    type: str
    default: yyyy-MM-dd HH:mm:ss
    version_added: 3.4.0
  access_time:
    description:
      - The desired access time for the file or directory.
      - A DateTime string in the format specified by O(access_time_format).
      - The timestamp is interpreted as local time on the target system.
      - Timezone offsets are supported when included in the timestamp format.
        (for example, using C(z), C(zz) or C(zzz) format specifiers).
      - When unset, the default is V(preserve) when O(state=[file, directory]) and V(now) when O(state=touch).
    type: str
    version_added: 3.4.0
  access_time_format:
    description:
      - The format to use when parsing C(access_time).
      - Defaults to C(yyyy-MM-dd HH:mm:ss).
      - See L(.NET DateTime format strings,https://learn.microsoft.com/en-us/dotnet/standard/base-types/standard-date-and-time-format-strings).
    type: str
    default: yyyy-MM-dd HH:mm:ss
    version_added: 3.4.0
seealso:
- module: ansible.builtin.file
- module: ansible.windows.win_acl
- module: ansible.windows.win_acl_inheritance
- module: ansible.windows.win_owner
- module: ansible.windows.win_stat
author:
- Jon Hawkesworth (@jhawkesworth)
- Bishal Prasad (@bishalprasad321)
'''

EXAMPLES = r'''
- name: Touch a file (creates if not present, updates modification time if present)
  ansible.windows.win_file:
    path: C:\Temp\foo.conf
    state: touch

- name: Remove a file, if present
  ansible.windows.win_file:
    path: C:\Temp\foo.conf
    state: absent

- name: Create directory structure
  ansible.windows.win_file:
    path: C:\Temp\folder\subfolder
    state: directory

- name: Remove directory structure
  ansible.windows.win_file:
    path: C:\Temp
    state: absent

- name: Touch a file and set modification and access times to now
  ansible.windows.win_file:
    path: C:\Temp\foo.conf
    state: touch
    modification_time: now
    access_time: now

- name: Set specific modification and access times for a file
  ansible.windows.win_file:
    path: C:\Temp\foo.conf
    state: touch
    modification_time: "2025-12-29 12:34:56"
    access_time: "2025-12-29 12:34:56"

- name: Set specific modification as UTC datetime
  ansible.windows.win_file:
    path: C:\Temp\foo.conf
    state: touch
    modification_time: "2025-12-29 12:34:56 +0"
    modification_time_format: "yyyy-MM-dd HH:mm:ss z"

- name: Create a directory and set the timestamps to now
  ansible.windows.win_file:
    path: C:\Temp\folder
    state: directory
    modification_time: now
    access_time: now
'''
