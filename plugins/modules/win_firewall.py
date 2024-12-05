#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2017, Michael Eaton <meaton@iforium.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_firewall
short_description: Enable or disable the Windows Firewall
description:
- Enable or Disable Windows Firewall profiles.
requirements:
  - This module requires Windows Management Framework 5 or later.
version_added: 2.6.0
options:
  profiles:
    description:
    - Specify one or more profiles to change.
    type: list
    elements: str
    choices: [ Domain, Private, Public ]
    default: [ Domain, Private, Public ]
  state:
    description:
    - Set state of firewall for given profile.
    required: true
    type: str
    choices: [ disabled, enabled ]
  inbound_action:
    description:
    - Set to C(allow) or C(block) inbound network traffic in the profile.
    - C(not_configured) is valid when configuring a GPO.
    type: str
    choices: [ allow, block, not_configured ]
  outbound_action:
    description:
    - Set to C(allow) or C(block) inbound network traffic in the profile.
    - C(not_configured) is valid when configuring a GPO.
    type: str
    choices: [ allow, block, not_configured ]
seealso:
- module: community.windows.win_firewall_rule
author:
- Michael Eaton (@michaeldeaton)
'''

EXAMPLES = r'''
- name: Enable firewall for Domain, Public and Private profiles
  ansible.windows.win_firewall:
    state: enabled
    profiles:
      - Domain
      - Private
      - Public
  tags: enable_firewall

- name: Disable Domain firewall
  ansible.windows.win_firewall:
    state: disabled
    profiles:
      - Domain
  tags: disable_firewall

- name: Enable firewall for Domain profile and block outbound connections
  ansible.windows.win_firewall:
    profiles: Domain
    state: enabled
    outbound_action: block
  tags: block_connection
'''

RETURN = r'''
enabled:
    description: Current firewall status for chosen profile (after any potential change).
    returned: always
    type: bool
    sample: true
profiles:
    description: Chosen profile.
    returned: always
    type: str
    sample: Domain
state:
    description: Desired state of the given firewall profile(s).
    returned: always
    type: list
    sample: enabled
'''
