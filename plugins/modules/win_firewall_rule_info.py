#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2014, Timothy Vandenbrande <timothy.vandenbrande@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_firewall_rule_info
short_description: Gather information about Windows firewall rules
description:
  - Gathers detailed information about existing Windows firewall rules.
  - Allows filtering rules by display name or group name.
options:
  name:
    description:
      - The rule's display name to filter by.
      - If omitted, rules will not be filtered by name.
    type: str
  group:
    description:
      - The group name to filter rules by.
      - If omitted, rules will not be filtered by group.
    type: str
seealso:
  - module: ansible.windows.win_firewall_rule
author:
  - Timothy Vandenbrande (@TimothyVandenbrande)
'''

EXAMPLES = r'''
- name: Get information about a specific firewall rule
  ansible.windows.win_firewall_rule_info:
    name: http
  register: http_rule_info

- name: Get information about all firewall rules in a specific group
  ansible.windows.win_firewall_rule_info:
    group: application
  register: app_group_rules

- name: Get information about all firewall rules on the target host
  ansible.windows.win_firewall_rule_info:
  register: all_firewall_rules
'''

RETURN = r'''
rules:
  description: List of firewall rules matching the specified criteria.
  returned: always
  type: list
  elements: dict
  contains:
    name:
      description: Display name of the firewall rule.
      returned: always
      type: str
      sample: http
    description:
      description: Description of the firewall rule.
      returned: always
      type: str
      sample: Allows inbound HTTP traffic
    enabled:
      description: Whether the firewall rule is enabled.
      returned: always
      type: bool
      sample: true
    action:
      description: The action for the firewall rule (0 = block, 1 = allow).
      returned: always
      type: int
      sample: 1
    direction:
      description: Traffic direction (1 = in, 2 = out).
      returned: always
      type: int
      sample: 1
    protocol:
      description: Protocol number associated with the rule (e.g. 6 for TCP, 17 for UDP).
      returned: always
      type: int
      sample: 6
    local_ports:
      description: Local port numbers or ranges.
      returned: always
      type: str
      sample: "80"
    remote_ports:
      description: Remote port numbers or ranges.
      returned: always
      type: str
      sample: "*"
    local_addresses:
      description: Local IP addresses or ranges.
      returned: always
      type: str
      sample: "*"
    remote_addresses:
      description: Remote IP addresses or ranges.
      returned: always
      type: str
      sample: "*"
    application_name:
      description: Path to the executable/application associated with the rule, or null if applies to any.
      returned: always
      type: str
      sample: "%SystemRoot%\\system32\\svchost.exe"
    service_name:
      description: Service short name associated with the rule.
      returned: always
      type: str
      sample: null
    profiles:
      description: Bitmask representing active profiles (1 = Domain, 2 = Private, 4 = Public).
      returned: always
      type: int
      sample: 2147483647
    group:
      description: Group name the firewall rule belongs to.
      returned: always
      type: str
      sample: application
'''
