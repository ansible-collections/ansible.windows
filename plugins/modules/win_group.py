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
  - Adds and removes members of local groups.
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
      - Set to an empty string C("") to unset the description.
    type: str
  members:
    description:
      - The members of the group to set.
      - The value is a dictionary that contains 3 keys, I(add), I(remove),
        or I(set).
      - Each subkey value is a list of users or domain groups to add, remove,
        or set respectively.
      - The members can either be the username in the form of C(SERVER\user),
        C(DOMAIN\user), C(.\user) to represent a local user, a UPN
        C(user@DOMAIN.COM), or a security identifier C(S-1-5-....).
      - A local group member cannot be another local group, it must be either a
        local user, domain user, or a domain group.
      - The I(add) and I(remove) keys can be set together but I(set) can only
        be set by itself.
    type: dict
    version_added: 2.7.0
    suboptions:
      add:
        description:
          - The members to add to the group.
          - This will add the members without removing any existing members
            not listed.
        default: []
        type: list
        elements: str
      remove:
        description:
          - The members to remove.
          - This will remove the members from the group without removing any
            existing members not listed.
        default: []
        type: list
        elements: str
      set:
        description:
          - The members to set the group to.
          - This will replace the existing membership with the users provided
            in this value.
          - Can be set to C([]) to clear all members from the group.
        type: list
        elements: str
  state:
    description:
      - Create or remove the group.
    type: str
    choices: [ absent, present ]
    default: present
seealso:
  - module: ansible.builtin.group
  - module: community.windows.win_domain_group
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

- name: Remove the group description
  ansible.windows.win_group:
    name: MyGroup
    description: ""
    state: present

- name: Add a user to a group
  ansible.windows.win_group:
    name: deploy
    members:
      add:
        - .\LocalUser1
        - LocalUser2
        - DOMAIN\User
        - user@DOMAIN.COM
        - S-1-5-0-10-204-0189-500
    state: present

- name: Remove a user from a group
  ansible.windows.win_group:
    name: deploy
    members:
      remove:
        - .\LocalUser1

- name: Set the members of a group
  ansible.windows.win_group:
    name: deploy
    members:
      set:
        - .\LocalUser1
        - LocalUser2
        - DOMAIN\User

- name: Remove all members of a group
  ansible.windows.win_group:
    name: deploy
    members:
      set: []
'''

RETURN = r'''
sid:
  description:
    - The Security Identifier (SID) of the group being managed.
    - If a new group was created in check mode, the SID will be C(S-1-5-0000).
    - When the group is not present, the SID will be C(None).
  returned: always
  type: str
  sample: S-1-5-21-2528685370-1724360342-165486190-1208
'''
