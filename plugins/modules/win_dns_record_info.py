#!/usr/bin/python
# -*- coding: utf-8 -*-
# Copyright: (c) 2026, Ansible Project
# Copyright: (c) 2026, Hen Yaish (hyaish@redhat.com)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_dns_record_info
short_description: Get Windows Server DNS records
description:
  - List resource records in an existing Windows DNS zone or retrieve records by owner and type.
  - This module is read-only and supports check mode.
version_added: 3.10.0
author:
  - Ansible Project (@ansible)
requirements:
  - The C(DnsServer) PowerShell module on the execution host.
  - Permission to read the selected DNS server and zone.
options:
  zone:
    description:
      - The existing DNS zone to query.
      - A missing zone, access denial, or connection failure causes an error.
    type: str
    required: true
  name:
    description:
      - The record owner relative to O(zone), or its fully qualified name within that zone.
      - Use C(@) or the zone's fully qualified name to query the zone apex.
      - When omitted, query all owners in the zone.
      - When no records match, V(records) is empty and V(exists) is C(false).
    type: str
  type:
    description:
      - The resource record type accepted by the DNS server, such as C(A), C(AAAA), C(CNAME), C(SRV), or C(TXT).
      - When omitted, query all record types.
    type: str
  zone_scope:
    description:
      - The existing zone scope to query.
      - When omitted, use the default scope.
    type: str
  computer_name:
    description:
      - The DNS server to query. When omitted, use the execution host's local server.
      - When using WinRM through another host, configure authentication that permits access to this server.
    type: str
seealso:
  - module: ansible.windows.win_dns_record
  - module: ansible.windows.win_dns_zone
'''

EXAMPLES = r'''
- name: List records in a zone
  ansible.windows.win_dns_record_info:
    zone: example.com
  register: dns_records

- name: Get a host's IPv4 records from a selected server
  ansible.windows.win_dns_record_info:
    zone: example.com
    name: database.example.com
    type: A
    computer_name: dns.example.com
  register: database_records
'''

RETURN = r'''
exists:
  description: Whether any records matched the query.
  returned: always
  type: bool
  sample: true
records:
  description: Matching records sorted by owner, type, and value.
  returned: always
  type: list
  elements: dict
  contains:
    name:
      description: The owner relative to the zone.
      type: str
      sample: database
    type:
      description: The resource record type.
      type: str
      sample: A
    ttl:
      description: The time to live in seconds.
      type: int
      sample: 3600
    aging:
      description: Whether the record has an aging timestamp.
      type: bool
      sample: false
    timestamp:
      description: The provider timestamp in ISO 8601 format, or null for static records.
      type: str
      sample: null
    record_values:
      description:
        - Primary record values as strings for A, AAAA, CNAME, DHCID, NS, PTR, SRV, TXT, and MX records.
        - TXT segments are joined into a single value. Other record types have an empty list; inspect V(records[].data).
      type: list
      elements: str
      sample: ['192.0.2.1']
    data:
      description:
        - Type-specific provider fields with IP addresses converted to strings and arrays preserved.
        - Common fields use snake case, including C(ipv4_address), C(domain_name), C(port), C(priority), and C(weight).
        - Other provider field names are lowercased.
      type: dict
      sample: {ipv4_address: '192.0.2.1'}
'''
