#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2018, daBONDi (@daBONDi)
# Copyright: (c) 2022, nsjoseph (@nsjoseph)
# Copyright: (c) 2026, ch0nx (@ch0nx)
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_inf_printer_driver
short_description: Manage INF-based Windows printer drivers
description:
  - Install or remove a Windows printer driver from an INF file.
version_added: 3.9.0
requirements:
  - This module requires Windows 8, Windows Server 2012, or newer.
options:
  inf_file:
    description:
      - Path to the printer driver C(.inf) file to install.
      - Required when O(state=present).
      - Ignored when O(state=absent).
    type: str
  driver_name:
    description:
      - Name of the printer driver as defined in the INF file.
      - This must match the driver name in the INF file exactly.
    type: str
    required: true
  printer_env:
    description:
      - The processor architecture that the driver targets.
    type: str
    choices:
      - x86
      - x64
    default: x64
  state:
    description:
      - When V(present), the driver is installed.
      - When V(absent), the driver is removed.
    type: str
    choices:
      - absent
      - present
    default: present
  remove_from_driver_store:
    description:
      - When removing a driver, also remove the driver package from the Windows driver store.
      - When V(false), only the printer driver is unregistered and the package remains in the driver store.
      - Only used when O(state=absent).
    type: bool
    default: false
  remove_all:
    description:
      - When removing the driver package from the driver store, also remove every other
        printer driver that shares the same INF file.
      - If multiple drivers share the INF file and this is V(false), the module fails
        instead of removing the shared package from the driver store.
      - Only used when O(state=absent) and O(remove_from_driver_store=true).
    type: bool
    default: false
author:
  - daBONDi (@daBONDi)
  - nsjoseph (@nsjoseph)
  - ch0nx (@ch0nx)
'''

EXAMPLES = r'''
- name: Install a printer driver from an INF file
  ansible.windows.win_inf_printer_driver:
    inf_file: C:\data\hp-upd-pcl6-x64-6.6.0.23029\hpcu215c.inf
    driver_name: HP Universal Printing PCL 6 (v6.6.0)
    printer_env: x64
    state: present

- name: Unregister a printer driver but keep the package in the driver store
  ansible.windows.win_inf_printer_driver:
    driver_name: HP Universal Printing PCL 6 (v6.6.0)
    state: absent

- name: Remove a printer driver and its package from the driver store
  ansible.windows.win_inf_printer_driver:
    driver_name: HP Universal Printing PCL 6 (v6.6.0)
    state: absent
    remove_from_driver_store: true

- name: Remove a driver and every other driver that shares its INF from the driver store
  ansible.windows.win_inf_printer_driver:
    driver_name: HP Universal Printing PCL 6 (v6.6.0)
    state: absent
    remove_from_driver_store: true
    remove_all: true
'''

RETURN = r'''
'''
