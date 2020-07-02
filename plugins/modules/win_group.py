#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2014, Chris Hoffman <choffman@chathamfinancial.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_group
short_description: Add and remove local groups
description:
    - Add and remove local groups.
    - For non-Windows targets, please use the M(ansible.builtin.group) module instead.
options:
  name:
    description:
      - Name of the group.
    type: str
    required: yes
  description:
    description:
      - Description of the group.
    type: str
  state:
    description:
      - Create or remove the group.
    type: str
    choices: [ absent, present ]
    default: present
seealso:
- module: ansible.builtin.group
- module: community.windows.win_domain_group
- module: ansible.windows.win_group_membership
author:
- Chris Hoffman (@chrishoffman)
'''

EXAMPLES = r'''
- name: Create a new group
  ansible.windows.win_group:
    name: deploy
    description: Deploy Group
    state: present

- name: Remove a group
  ansible.windows.win_group:
    name: deploy
    state: absent
'''
