#!/usr/bin/python
# coding: utf-8 -*-

# Copyright: (c) 2017, Dag Wieers <dag@wieers.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_tempfile
short_description: Creates temporary files and directories
description:
  - Creates temporary files and directories.
  - For non-Windows targets, please use the M(ansible.builtin.tempfile) module instead.
options:
  state:
    description:
      - Whether to create file or directory.
    type: str
    choices: [ directory, file ]
    default: file
  path:
    description:
      - Location where temporary file or directory should be created.
      - If path is not specified default system temporary directory (%TEMP%) will be used.
    type: path
    default: '%TEMP%'
    aliases: [ dest ]
  prefix:
    description:
      - Prefix of file/directory name created by module.
    type: str
    default: ansible.
  suffix:
    description:
      - Suffix of file/directory name created by module.
    type: str
seealso:
- module: ansible.builtin.tempfile
author:
- Dag Wieers (@dagwieers)
'''

EXAMPLES = r"""
- name: Create temporary build directory
  ansible.windows.win_tempfile:
    state: directory
    suffix: build

- name: Create temporary file with custom prefix
  ansible.windows.win_tempfile:
    state: file
    prefix: customlog_

- name: Create temporary file
  ansible.windows.win_tempfile:
    state: file
    suffix: temp
"""

RETURN = r'''
path:
  description: The absolute path to the created file or directory.
  returned: success
  type: str
  sample: C:\Users\Administrator\AppData\Local\Temp\ansible.bMlvdk
'''
