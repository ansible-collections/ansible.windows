#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2012, Michael DeHaan <michael.dehaan@gmail.com>, and others
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_ping
short_description: A windows version of the classic ping module
description:
  - Checks management connectivity of a windows host.
  - This is NOT ICMP ping, this is just a trivial test module.
  - For non-Windows targets, use the M(ansible.builtin.ping) module instead.
options:
  data:
    description:
      - Alternate data to return instead of 'pong'.
      - If this parameter is set to C(crash), the module will cause an exception.
    type: str
    default: pong
seealso:
- module: ansible.builtin.ping
author:
- Chris Church (@cchurch)
'''

EXAMPLES = r'''
# Test connectivity to a windows host
# ansible winserver -m ansible.windows.win_ping

- name: Example from an Ansible Playbook
  ansible.windows.win_ping:

- name: Induce an exception to see what happens
  ansible.windows.win_ping:
    data: crash
'''

RETURN = r'''
ping:
    description: Value provided with the data parameter.
    returned: success
    type: str
    sample: pong
'''
