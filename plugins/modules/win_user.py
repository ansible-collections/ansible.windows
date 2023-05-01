#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2014, Matt Martz <matt@sivel.net>, and others
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_user
short_description: Manages local Windows user accounts
description:
- Manages local Windows user accounts.
- For non-Windows targets, use the M(ansible.builtin.user) module instead.
options:
  account_disabled:
    description:
    - C(true) will disable the user account.
    - C(false) will clear the disabled flag.
    type: bool
  account_locked:
    description:
    - Only C(false) can be set and it will unlock the user account if locked.
    type: bool
  description:
    description:
    - Description of the user.
    type: str
  fullname:
    description:
    - Full name of the user.
    type: str
  groups:
    description:
    - Adds or removes the user from this comma-separated list of groups, depending on the value of I(groups_action).
    - When I(groups_action) is C(replace) and I(groups) is set to the empty string ('groups='), the user is removed
      from all groups.
    - Since C(ansible.windows v1.5.0) it is possible to specify a group using it's security identifier.
    type: list
    elements: str
  groups_action:
    description:
    - If C(add), the user is added to each group in I(groups) where not already a member.
    - If C(replace), the user is added as a member of each group in I(groups) and removed from any other groups.
    - If C(remove), the user is removed from each group in I(groups).
    type: str
    choices: [ add, replace, remove ]
    default: replace
  home_directory:
    description:
    - The designated home directory of the user.
    type: str
    version_added: 1.0.0
  login_script:
    description:
    - The login script of the user.
    type: str
    version_added: 1.0.0
  name:
    description:
    - Name of the user to create, remove or modify.
    type: str
    required: yes
  password:
    description:
    - Optionally set the user's password to this (plain text) value.
    type: str
  password_expired:
    description:
    - C(true) will require the user to change their password at next login.
    - C(false) will clear the expired password flag.
    type: bool
  password_never_expires:
    description:
    - C(true) will set the password to never expire.
    - C(false) will allow the password to expire.
    type: bool
  profile:
    description:
    - The profile path of the user.
    type: str
    version_added: 1.0.0
  state:
    description:
    - When C(absent), removes the user account if it exists.
    - When C(present), creates or updates the user account.
    - When C(query), retrieves the user account details without making any changes.
    type: str
    choices: [ absent, present, query ]
    default: present
  update_password:
    description:
    - C(always) will update passwords if they differ.
    - C(on_create) will only set the password for newly created users.
    type: str
    choices: [ always, on_create ]
    default: always
  user_cannot_change_password:
    description:
    - C(true) will prevent the user from changing their password.
    - C(false) will allow the user to change their password.
    type: bool
notes:
- The return values are based on the user object after the module options have been set. When running in check mode
  the values will still reflect the existing user settings and not what they would have been changed to.
seealso:
- module: ansible.builtin.user
- module: ansible.windows.win_domain_membership
- module: community.windows.win_domain_user
- module: ansible.windows.win_group
- module: ansible.windows.win_group_membership
- module: community.windows.win_user_profile
author:
- Paul Durivage (@angstwad)
- Chris Church (@cchurch)
'''

EXAMPLES = r'''
- name: Ensure user bob is present
  ansible.windows.win_user:
    name: bob
    password: B0bP4ssw0rd
    state: present
    groups:
      - Users

- name: Ensure user bob is absent
  ansible.windows.win_user:
    name: bob
    state: absent
'''

RETURN = r'''
account_disabled:
  description: Whether the user is disabled.
  returned: user exists
  type: bool
  sample: false
account_locked:
  description: Whether the user is locked.
  returned: user exists
  type: bool
  sample: false
description:
  description: The description set for the user.
  returned: user exists
  type: str
  sample: Username for test
fullname:
  description: The full name set for the user.
  returned: user exists
  type: str
  sample: Test Username
groups:
  description: A list of groups and their ADSI path the user is a member of.
  returned: user exists
  type: list
  sample: [
    {
      "name": "Administrators",
      "path": "WinNT://WORKGROUP/USER-PC/Administrators"
    }
  ]
name:
  description: The name of the user
  returned: always
  type: str
  sample: username
password_expired:
  description: Whether the password is expired.
  returned: user exists
  type: bool
  sample: false
password_never_expires:
  description: Whether the password is set to never expire.
  returned: user exists
  type: bool
  sample: true
path:
  description: The ADSI path for the user.
  returned: user exists
  type: str
  sample: "WinNT://WORKGROUP/USER-PC/username"
sid:
  description: The SID for the user.
  returned: user exists
  type: str
  sample: S-1-5-21-3322259488-2828151810-3939402796-1001
user_cannot_change_password:
  description: Whether the user can change their own password.
  returned: user exists
  type: bool
  sample: false
'''
