#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2025, Red Hat, Inc.
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_route
short_description: Add or remove a static route
description:
    - Add or remove a static route.
version_added: 2.7.0
options:
  destination:
    description:
      - Destination IP address in CIDR format (ip address/prefix length).
    type: str
    required: yes
  gateway:
    description:
        - The gateway used by the static route.
        - If C(gateway) is not provided it will be set to C(0.0.0.0).
    type: str
    default: 0.0.0.0
  metric:
    description:
        - Metric used by the static route.
    type: int
    default: 1
  state:
    description:
      - If C(absent), it removes a network static route.
      - If C(present), it adds a network static route.
    type: str
    choices: [ absent, present ]
    default: present
notes:
  - Works only with Windows 2012 R2 and newer.
author:
- Amit Weinstock (@amitosw15)
'''

EXAMPLES = r'''
---
- name: Add a network static route
  ansible.windows.win_route:
    destination: 192.168.2.10/32
    gateway: 192.168.1.1
    metric: 1
    state: present

- name: Remove a network static route
  ansible.windows.win_route:
    destination: 192.168.2.10/32
    state: absent
'''
RETURN = r'''
msg:
    description: A message describing the task result.
    returned: always
    type: str
    sample: "Route added"
'''
