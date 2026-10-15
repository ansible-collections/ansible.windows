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
seealso:
  - module: ansible.windows.win_dns_record_info
  - module: ansible.windows.win_dns_zone
options:
  name:
    description:
    - The record owner, relative to O(zone), or its fully qualified name within that zone.
    - A matching zone suffix is removed before querying or modifying the record.
    - Use C(@) or the zone's fully qualified name for a record at the zone apex.
    - An absolute name ending in a period must belong to O(zone).
    required: yes
    type: str
  port:
    description:
    - The port number of the record.
    - Required when C(type=SRV).
    - Supported only for C(type=SRV).
    - Valid range is 0 - 65535.
    type: int
  priority:
    description:
    - The priority number for each service in SRV record.
    - Required when C(type=SRV).
    - Supported only for C(type=SRV).
    - Valid range is 0 - 65535.
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
    default: 3600
    type: int
  aging:
    description:
    - Should aging be activated for the record.
    - If set to C(false), the record will be static.
    default: false
    type: bool
  allow_update_any:
    description:
    - Specifies if any authenticated user can update the record.
    - Applies when creating a record. Changing this option does not modify permissions on an existing record.
    - If set to C(true), any authenticated user can update the record.
    - If set to C(false), only the account that created the record or accounts
      with appropriate permissions can update it.
    - For non-SRV records, this was previously hardcoded to C(true). Since C(ansible.windows>=3.5.0) it now
      defaults to C(false) to ensure records are secure by default.
    default: false
    type: bool
    version_added: '3.5.0'
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
    - For C(type=PTR), supply the target host name here and the partial IP address in O(name).
    - Multiple values can be supplied for record types that permit multiple records at the same owner.
    aliases: [ values ]
    default: []
    type: list
    elements: str
  weight:
    description:
    - Weightage given to each service record in SRV record.
    - Required when C(type=SRV).
    - Supported only for C(type=SRV).
    - Valid range is 0 - 65535.
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
      - The execution host requires the C(DnsServer) PowerShell module and permission to manage records on this server.
      - When using WinRM through another host, configure authentication that permits access to the DNS server.
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
      - ns1.example.com
      - ns2.example.com
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
    name: "cgyl1404p"
    type: "A"
    value: "10.1.1.1"
    zone: "amer.example.com"
    zone_scope: "external"
'''

RETURN = r'''
'''
