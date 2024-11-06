#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2021 Sebastian Gruber ,dacoso GmbH All Rights Reserved.
# Copyright: (c) 2019, Hitachi ID Systems, Inc.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_dns_record
short_description: Manage Windows Server DNS records
description:
- Manage DNS records within an existing Windows Server DNS zone.
version_added: 2.6.0
author:
 - Sebastian Gruber (@sgruber94)
 - John Nelson (@johnboy2)
requirements:
  - This module requires Windows 8, Server 2012, or newer.
options:
  name:
    description:
    - The name of the record.
    required: yes
    type: str
  port:
    description:
    - The port number of the record.
    - Required when C(type=SRV).
    - Supported only for C(type=SRV).
    type: int
  priority:
    description:
    - The priority number for each service in SRV record.
    - Required when C(type=SRV).
    - Supported only for C(type=SRV).
    type: int
  state:
    description:
    - Whether the record should exist or not.
    choices: [ absent, present ]
    default: present
    type: str
  ttl:
    description:
    - The "time to live" of the record, in seconds.
    - Ignored when C(state=absent).
    - Valid range is 1 - 31557600.
    - Note that an Active Directory forest can specify a minimum TTL, and will
      dynamically "round up" other values to that minimum.
    default: 3600
    type: int
  aging:
    description:
    - Should aging be activated for the record.
    - If set to C(false), the record will be static.
    default: false
    type: bool
  type:
    description:
    - The type of DNS record to manage.
    - C(SRV) was added in the 1.0.0 release of this collection.
    - C(NS) was added in the 1.1.0 release of this collection.
    - C(TXT) was added in the 1.6.0 release of this collection.
    - C(DHCID) was added in the 1.12.0 release of this collection.
    choices: [ A, AAAA, CNAME, DHCID, NS, PTR, SRV, TXT ]
    required: yes
    type: str
  value:
    description:
    - The value(s) to specify. Required when C(state=present).
    - When C(type=PTR) only the partial part of the IP should be given.
    - Multiple values can be passed when C(type=NS)
    aliases: [ values ]
    default: []
    type: list
    elements: str
  weight:
    description:
    - Weightage given to each service record in SRV record.
    - Required when C(type=SRV).
    - Supported only for C(type=SRV).
    type: int
  zone:
    description:
    - The name of the zone to manage (eg C(example.com)).
    - The zone must already exist.
    required: yes
    type: str
  zone_scope:
    description:
    - The name of the zone scope to manage (eg C(ScopeAZ)).
    - The zone must already exist.
    required: no
    type: str
  computer_name:
    description:
      - Specifies a DNS server.
      - You can specify an IP address or any value that resolves to an IP
        address, such as a fully qualified domain name (FQDN), host name, or
        NETBIOS name.
    type: str
'''

EXAMPLES = r'''
# Demonstrate creating a matching A and PTR record.

- name: Create database server record
  ansible.windows.win_dns_record:
    name: "cgyl1404p"
    type: "A"
    value: "10.1.1.1"
    zone: "amer.example.com"

- name: Create matching PTR record
  ansible.windows.win_dns_record:
    name: "1.1.1"
    type: "PTR"
    value: "db1"
    zone: "10.in-addr.arpa"

# Demonstrate replacing an A record with a CNAME

- name: Remove static record
  ansible.windows.win_dns_record:
    name: "db1"
    type: "A"
    state: absent
    zone: "amer.example.com"

- name: Create database server alias
  ansible.windows.win_dns_record:
    name: "db1"
    type: "CNAME"
    value: "cgyl1404p.amer.example.com"
    zone: "amer.example.com"

# Demonstrate creating multiple A records for the same name

- name: Create multiple A record values for www
  ansible.windows.win_dns_record:
    name: "www"
    type: "A"
    values:
      - 10.0.42.5
      - 10.0.42.6
      - 10.0.42.7
    zone: "example.com"

# Demonstrates a partial update (replace some existing values with new ones)
# for a pre-existing name

- name: Update www host with new addresses
  ansible.windows.win_dns_record:
    name: "www"
    type: "A"
    values:
      - 10.0.42.5  # this old value was kept (others removed)
      - 10.0.42.12  # this new value was added
    zone: "example.com"

# Demonstrate creating a SRV record

- name: Creating a SRV record with port number and priority
  ansible.windows.win_dns_record:
    name: "test"
    priority: 5
    port: 995
    state: present
    type: "SRV"
    weight: 2
    value: "amer.example.com"
    zone: "example.com"

# Demonstrate creating a NS record with multiple values

- name: Creating NS record
  ansible.windows.win_dns_record:
    name: "ansible.prog"
    state: present
    type: "NS"
    values:
      - 10.0.0.1
      - 10.0.0.2
      - 10.0.0.3
      - 10.0.0.4
    zone: "example.com"

# Demonstrate creating a TXT record

- name: Creating a TXT record with descriptive Text
  ansible.windows.win_dns_record:
    name: "test"
    state: present
    type: "TXT"
    value: "justavalue"
    zone: "example.com"

# Demostrate creating a A record to Zone Scope

- name: Create database server record
  ansible.windows.win_dns_record:
    name: "cgyl1404p.amer.example.com"
    type: "A"
    value: "10.1.1.1"
    zone: "amer.example.com"
    zone_scope: "external"
'''

RETURN = r'''
'''
