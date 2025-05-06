#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2017, Red Hat, Inc.
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_dns_client
short_description: Configures DNS lookup on Windows hosts
description:
  - The M(ansible.windows.win_dns_client) module configures the DNS client on Windows network adapters.
options:
  adapter_names:
    description:
      - Adapter name or list of adapter names for which to manage DNS settings ('*' is supported as a wildcard value).
      - The adapter name used is the connection caption in the Network Control Panel or the InterfaceAlias of C(Get-DnsClientServerAddress).
    type: list
    elements: str
    required: yes
  dns_servers:
    description:
      - Single or ordered list of DNS servers (IPv4 and IPv6 addresses) to configure for lookup.
      - An empty list will configure the adapter to use the DHCP-assigned values on connections where DHCP is enabled,
        or disable DNS lookup on statically-configured connections.
      - IPv6 DNS servers can only be set on Windows Server 2012 or newer, older hosts can only set IPv4 addresses.
    type: list
    elements: str
    required: yes
    aliases: [ "ipv4_addresses", "ip_addresses", "addresses" ]
  suffix_search_list:
    description:
      - Specifies a list of global suffixes that can be used in the specified order by the DNS client for resolving the IP address.
    type: list
    elements: str
    required: no
    version_added: 3.1.0
author:
- Matt Davis (@nitzmahone)
- Brian Scholer (@briantist)
'''

EXAMPLES = r'''
- name: Set a single address on the adapter named Ethernet
  ansible.windows.win_dns_client:
    adapter_names: Ethernet
    dns_servers: 192.168.34.5

- name: Set multiple lookup addresses on all visible adapters (usually physical adapters that are in the Up state), with debug logging to a file
  ansible.windows.win_dns_client:
    adapter_names: '*'
    dns_servers:
      - 192.168.34.5
      - 192.168.34.6
    suffix_search_list:
      - "corp.contoso.com"
      - "na.corp.contoso.com"
    log_path: C:\dns_log.txt

- name: Set IPv6 DNS servers on the adapter named Ethernet
  ansible.windows.win_dns_client:
    adapter_names: Ethernet
    dns_servers:
      - '2001:db8::2'
      - '2001:db8::3'

- name: Configure all adapters whose names begin with Ethernet to use DHCP-assigned DNS values
  ansible.windows.win_dns_client:
    adapter_names: 'Ethernet*'
    dns_servers: []
'''

RETURN = r'''
'''
