#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2022, Oleg Galushko (@inorangestylee)
# Copyright: (c) 2015, Hans-Joachim Kliemeck <git@kliemeck.de>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_acl_inheritance
short_description: Change ACL inheritance
description:
    - Change ACL (Access Control List) inheritance and optionally copy inherited ACE's (Access Control Entry) to dedicated ACE's or vice versa.
options:
  path:
    description:
      - Path to be used for changing inheritance
      - Support for registry keys have been added in C(ansible.windows>=1.11.0)
    required: true
    type: str
  state:
    description:
      - Specify whether to enable I(present) or disable I(absent) ACL inheritance.
    type: str
    choices: [ absent, present ]
    default: absent
  reorganize:
    description:
      - For C(state=absent), indicates if the inherited ACE's should be copied from the parent.
        This is necessary (in combination with removal) for a simple ACL instead of using multiple ACE deny entries.
      - For C(state=present), indicates if the inherited ACE's should be deduplicated compared to the parent.
        This removes complexity of the ACL structure.
    type: bool
    default: false
seealso:
- module: ansible.windows.win_acl
- module: ansible.windows.win_file
- module: ansible.windows.win_stat
author:
- Oleg Galushko (@inorangestylee)
- Hans-Joachim Kliemeck (@h0nIg)
'''

EXAMPLES = r'''
- name: Disable inherited ACE's
  ansible.windows.win_acl_inheritance:
    path: C:\apache
    state: absent

- name: Disable and copy inherited ACE's
  ansible.windows.win_acl_inheritance:
    path: C:\apache
    state: absent
    reorganize: true

- name: Enable and remove dedicated ACE's
  ansible.windows.win_acl_inheritance:
    path: C:\apache
    state: present
    reorganize: true

- name: Disable registry key inherited ACE's
  ansible.windows.win_acl_inheritance:
    path: HKLM:\SOFTWARE\Secrets
    state: absent

- name: Disable and copy registry key inherited ACE's
  ansible.windows.win_acl_inheritance:
    path: HKLM:\SOFTWARE\Secrets
    state: absent
    reorganize: true

- name: Enable and remove registry key dedicated ACE's
  ansible.windows.win_acl_inheritance:
    path: HKLM:\SOFTWARE\Secrets
    state: present
    reorganize: true
'''

RETURN = r'''

'''
