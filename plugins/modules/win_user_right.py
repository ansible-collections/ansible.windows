#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_user_right
short_description: Manage Windows User Rights
description:
- Add, remove or set User Rights for a group or users or groups.
- You can set user rights for both local and domain accounts.
options:
  name:
    description:
    - The name of the User Right as shown by the C(Constant Name) value from
      U(https://technet.microsoft.com/en-us/library/dd349804.aspx).
    - The module will return an error if the right is invalid.
    type: str
    required: yes
  users:
    description:
    - A list of users or groups to add/remove on the User Right.
    - These can be in the form DOMAIN\user-group, user-group@DOMAIN.COM for
      domain users/groups.
    - For local users/groups it can be in the form user-group, .\user-group,
      SERVERNAME\user-group where SERVERNAME is the name of the remote server.
    - It is highly recommended to use the C(.\) or C(SERVERNAME\) prefix to
      avoid any ambiguity with domain account names or errors trying to lookup
      an account on a domain controller.
    - You can also add special local accounts like SYSTEM and others.
    - Can be set to an empty list with I(action=set) to remove all accounts
      from the right.
    type: list
    elements: str
    required: yes
  action:
    description:
    - C(add) will add the users/groups to the existing right.
    - C(remove) will remove the users/groups from the existing right.
    - C(set) will replace the users/groups of the existing right.
    type: str
    default: set
    choices: [ add, remove, set ]
notes:
- If the server is domain joined this module can change a right but if a GPO
  governs this right then the changes won't last.
seealso:
- module: ansible.windows.win_group
- module: ansible.windows.win_group_membership
- module: ansible.windows.win_user
author:
- Jordan Borean (@jborean93)
'''

EXAMPLES = r'''
---
- name: Replace the entries of Deny log on locally
  ansible.windows.win_user_right:
    name: SeDenyInteractiveLogonRight
    users:
    - Guest
    - Users
    action: set

- name: Add account to Log on as a service
  ansible.windows.win_user_right:
    name: SeServiceLogonRight
    users:
    - .\Administrator
    - '{{ansible_hostname}}\local-user'
    action: add

- name: Remove accounts who can create Symbolic links
  ansible.windows.win_user_right:
    name: SeCreateSymbolicLinkPrivilege
    users:
    - SYSTEM
    - Administrators
    - DOMAIN\User
    - group@DOMAIN.COM
    action: remove

- name: Remove all accounts who cannot log on remote interactively
  ansible.windows.win_user_right:
    name: SeDenyRemoteInteractiveLogonRight
    users: []
'''

RETURN = r'''
added:
  description: A list of accounts that were added to the right, this is empty
    if no accounts were added.
  returned: success
  type: list
  sample: ["NT AUTHORITY\\SYSTEM", "DOMAIN\\User"]
removed:
  description: A list of accounts that were removed from the right, this is
    empty if no accounts were removed.
  returned: success
  type: list
  sample: ["SERVERNAME\\Administrator", "BUILTIN\\Administrators"]
'''
