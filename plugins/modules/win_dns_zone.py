#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_dns_zone
short_description: Manage Windows Server DNS Zones
author: Joe Zollo (@joezollo)
version_added: 2.6.0
requirements:
  - This module requires Windows Server 2012R2 or Newer
description:
  - Manage Windows Server DNS Zones
  - Adds, Removes and Modifies DNS Zones - Primary, Secondary, Forwarder & Stub
  - Task should be delegated to a Windows DNS Server
options:
  name:
    description:
      - Fully qualified name of the DNS zone.
    type: str
    required: true
  type:
    description:
      - Specifies the type of DNS zone.
      - When l(type=secondary), the DNS server will immediately attempt to
        perform a zone transfer from the servers in this list. If this initial
        transfer fails, then the zone will be left in an unworkable state.
        This module does not verify the initial transfer.
    type: str
    choices: [ primary, secondary, stub, forwarder ]
  dynamic_update:
    description:
      - Specifies how a zone handles dynamic updates.
      - Secure DNS updates are available only for Active Directory-integrated
        zones.
      - When not specified during new zone creation, Windows will default this
        to l(none).
    type: str
    choices: [ secure, none, nonsecureandsecure ]
  state:
    description:
      - Specifies the desired state of the DNS zone.
      - When l(state=present) the module will attempt to create the specified
        DNS zone if it does not already exist.
      - When l(state=absent), the module will remove the specified DNS
        zone and all subsequent DNS records.
    type: str
    default: present
    choices: [ present, absent ]
  forwarder_timeout:
    description:
      - Specifies a length of time, in seconds, that a DNS server waits for a
        remote DNS server to resolve a query.
      - Accepts integer values between 0 and 15.
      - If the provided value is not valid, it will be omitted and a warning
        will be issued.
    type: int
  replication:
    description:
      - Specifies the replication scope for the DNS zone.
      - l(replication=forest) will replicate the DNS zone to all domain
        controllers in the Active Directory forest.
      - l(replication=domain) will replicate the DNS zone to all domain
        controllers in the Active Directory domain.
      - l(replication=none) disables Active Directory integration and
        creates a local file with the name of the zone.
      - This is the equivalent of selecting l(store the zone in Active
        Directory) in the GUI.
    type: str
    choices: [ forest, domain, legacy, none ]
  dns_servers:
    description:
      - Specifies an list of IP addresses of the primary servers of the zone.
      - DNS queries for a forwarded zone are sent to primary servers.
      - Required if l(type=secondary), l(type=forwarder) or l(type=stub),
        otherwise ignored.
      - At least one server is required.
    elements: str
    type: list
'''

EXAMPLES = r'''
- name: Ensure primary zone is present
  ansible.windows.win_dns_zone:
    name: wpinner.euc.vmware.com
    replication: domain
    type: primary
    state: present

- name: Ensure DNS zone is absent
  ansible.windows.win_dns_zone:
    name: jamals.euc.vmware.com
    state: absent

- name: Ensure forwarder has specific DNS servers
  ansible.windows.win_dns_zone:
    name: jamals.euc.vmware.com
    type: forwarder
    dns_servers:
      - 10.245.51.100
      - 10.245.51.101
      - 10.245.51.102

- name: Ensure stub zone has specific DNS servers
  ansible.windows.win_dns_zone:
    name: virajp.euc.vmware.com
    type: stub
    dns_servers:
      - 10.58.2.100
      - 10.58.2.101

- name: Ensure stub zone is converted to a secondary zone
  ansible.windows.win_dns_zone:
    name: virajp.euc.vmware.com
    type: secondary

- name: Ensure secondary zone is present with no replication
  ansible.windows.win_dns_zone:
    name: dgemzer.euc.vmware.com
    type: secondary
    replication: none
    dns_servers:
      - 10.19.20.1

- name: Ensure secondary zone is converted to a primary zone
  ansible.windows.win_dns_zone:
    name: dgemzer.euc.vmware.com
    type: primary
    replication: none
    dns_servers:
      - 10.19.20.1

- name: Ensure primary DNS zone is present without replication
  ansible.windows.win_dns_zone:
    name: basavaraju.euc.vmware.com
    replication: none
    type: primary

- name: Ensure primary DNS zone has nonsecureandsecure dynamic updates enabled
  ansible.windows.win_dns_zone:
    name: basavaraju.euc.vmware.com
    replication: none
    dynamic_update: nonsecureandsecure
    type: primary

- name: Ensure DNS zone is absent
  ansible.windows.win_dns_zone:
    name: marshallb.euc.vmware.com
    state: absent

- name: Ensure DNS zones are absent
  ansible.windows.win_dns_zone:
    name: "{{ item }}"
    state: absent
  loop:
    - jamals.euc.vmware.com
    - dgemzer.euc.vmware.com
    - wpinner.euc.vmware.com
    - marshallb.euc.vmware.com
    - basavaraju.euc.vmware.com
'''

RETURN = r'''
zone:
  description: New/Updated DNS zone parameters
  returned: When l(state=present)
  type: dict
  sample:
    name:
    type:
    dynamic_update:
    reverse_lookup:
    forwarder_timeout:
    paused:
    shutdown:
    zone_file:
    replication:
    dns_servers:
'''
