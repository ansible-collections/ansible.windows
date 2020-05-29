#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2018, Ripon Banik (@riponbanik)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
module: win_hostname
short_description: Manages local Windows computer name
description:
- Manages local Windows computer name.
- A reboot is required for the computer name to take effect.
options:
  name:
    description:
    - The hostname to set for the computer.
    type: str
    required: true
seealso:
- module: ansible.windows.win_dns_client
author:
- Ripon Banik (@riponbanik)
'''

EXAMPLES = r'''
- name: Change the hostname to sample-hostname
  ansible.windows.win_hostname:
    name: sample-hostname
  register: res

- name: Reboot
  ansible.windows.win_reboot:
  when: res.reboot_required
'''

RETURN = r'''
old_name:
  description: The original hostname that was set before it was changed.
  returned: always
  type: str
  sample: old_hostname
reboot_required:
  description: Whether a reboot is required to complete the hostname change.
  returned: always
  type: bool
  sample: true
'''
