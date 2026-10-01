#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2014, Timothy Vandenbrande <timothy.vandenbrande@gmail.com>
# Copyright: (c) 2017, Artem Zinenko <zinenkoartem@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_firewall_rule
short_description: Windows firewall automation
description:
  - Allows you to create/remove/update firewall rules.
options:
  enabled:
    description:
      - Whether this firewall rule is enabled or disabled.
      - Defaults to C(true) when creating a new rule.
    type: bool
    aliases: [ enable ]
  state:
    description:
      - Should this rule be added or removed.
    type: str
    choices: [ absent, present ]
    default: present
  name:
    description:
      - The rule's display name.
      - This is required unless I(group) is specified.
    type: str
  group:
    description:
      - The group name for the rule.
      - If I(name) is not specified then the module will set the firewall options for all the rules in this group.
    type: str
  direction:
    description:
      - Whether this rule is for inbound or outbound traffic.
      - Defaults to C(in) when creating a new rule.
    type: str
    choices: [ in, out ]
  action:
    description:
      - What to do with the items this rule is for.
      - Defaults to C(allow) when creating a new rule.
    type: str
    choices: [ allow, block ]
  description:
    description:
      - Description for the firewall rule.
    type: str
  localip:
    description:
      - The local ip address this rule applies to.
      - Set to C(any) to apply to all local ip addresses.
      - Defaults to C(any) when creating a new rule.
    type: str
  remoteip:
    description:
      - The remote ip address/range this rule applies to.
      - Set to C(any) to apply to all remote ip addresses.
      - Defaults to C(any) when creating a new rule.
    type: str
  localport:
    description:
      - The local port this rule applies to.
      - Set to C(any) to apply to all local ports.
      - Defaults to C(any) when creating a new rule.
      - Must have I(protocol) set
    type: str
  remoteport:
    description:
      - The remote port this rule applies to.
      - Set to C(any) to apply to all remote ports.
      - Defaults to C(any) when creating a new rule.
      - Must have I(protocol) set
    type: str
  program:
    description:
      - The program this rule applies to.
      - Set to C(any) to apply to all programs.
      - Defaults to C(any) when creating a new rule.
    type: str
  service:
    description:
      - The service this rule applies to.
      - Set to C(any) to apply to all services.
      - Defaults to C(any) when creating a new rule.
    type: str
  protocol:
    description:
      - The protocol this rule applies to.
      - Set to C(any) to apply to all services.
      - Defaults to C(any) when creating a new rule.
    type: str
  profiles:
    description:
      - The profile this rule applies to.
      - Defaults to C(domain,private,public) when creating a new rule.
    type: list
    elements: str
    aliases: [ profile ]
  icmp_type_code:
    description:
      - The ICMP types and codes for the rule.
      - This is only valid when I(protocol) is C(icmpv4) or C(icmpv6).
      - Each entry follows the format C(type:code) where C(type) is the type
        number and C(code) is the code number for that type or C(*) for all
        codes.
      - Set the value to just C(*) to apply the rule for all ICMP type codes.
      - See U(https://www.iana.org/assignments/icmp-parameters/icmp-parameters.xhtml)
        for a list of ICMP types and the codes that apply to them.
      - ICMP types and codes for IPV6 can be found at U(https://www.iana.org/assignments/icmpv6-parameters/icmpv6-parameters.xhtml).
    type: list
    elements: str
notes:
- Multiple firewall rules can share the same I(name), if there are multiple matches then the module will set the user
  defined options for each matching rule.
seealso:
- module: community.windows.win_firewall
author:
  - Artem Zinenko (@ar7z1)
  - Timothy Vandenbrande (@TimothyVandenbrande)
'''

EXAMPLES = r'''
- name: Firewall rule to allow SMTP on TCP port 25
  community.windows.win_firewall_rule:
    name: SMTP
    localport: 25
    action: allow
    direction: in
    protocol: tcp
    state: present
    enabled: true

- name: Firewall rule to allow RDP on TCP port 3389
  community.windows.win_firewall_rule:
    name: Remote Desktop
    localport: 3389
    action: allow
    direction: in
    protocol: tcp
    profiles: private
    state: present
    enabled: true

- name: Firewall rule to be created for application group
  community.windows.win_firewall_rule:
    name: SMTP
    group: application
    localport: 25
    action: allow
    direction: in
    protocol: tcp
    state: present
    enabled: true

- name: Enable all the Firewall rules in application group
  win_firewall_rule:
    group: application
    enabled: true

- name: Firewall rule to allow port range
  community.windows.win_firewall_rule:
    name: Sample port range
    localport: 5000-5010
    action: allow
    direction: in
    protocol: tcp
    state: present
    enabled: true

- name: Firewall rule to allow ICMP v4 echo (ping)
  community.windows.win_firewall_rule:
    name: ICMP Allow incoming V4 echo request
    enabled: true
    state: present
    profiles: private
    action: allow
    direction: in
    protocol: icmpv4
    icmp_type_code:
      - '8:*'

- name: Firewall rule to alloc ICMP v4 on all type codes
  community.windows.win_firewall_rule:
    name: ICMP Allow incoming V4 echo request
    enabled: true
    state: present
    profiles: private
    action: allow
    direction: in
    protocol: icmpv4
    icmp_type_code: '*'
'''
