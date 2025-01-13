#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2022, DataDope (@datadope-io)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_listen_ports_facts
version_added: '1.10.0'
short_description: Recopilates the facts of the listening ports of the machine
description:
    - Recopilates the information of the TCP and UDP ports of the machine and
      the related processes.
    - State of the TCP ports could be filtered, as well as the format of the
      date when the parent process was launched.
    - The module's goal is to replicate the functionality of the linux module
      listen_ports_facts, mantaining the format of the said module.
options:
  date_format:
    description:
      - The format of the date when the process that owns the port started.
      - The date specification is UFormat
    type: str
    default: '%c'
  tcp_filter:
    description:
      - Filter for the state of the TCP ports that will be recopilated.
      - Supports multiple states (Bound, Closed, CloseWait, Closing, DeleteTCB,
        Established, FinWait1, FinWait2, LastAck, Listen, SynReceived, SynSent
        and TimeWait), that can be used alone or combined. Note that the Bound
        state is only available on PowerShell version 4.0 or later.
    type: list
    elements: str
    default: [ Listen ]
notes:
- The generated data (tcp_listen and udp_listen) and the fields within follows
  the listen_ports_facts schema to achieve compatibility with the said module
  output, even though this module if capable of extracting ports with a state
  other than Listen
seealso:
- module: community.general.listen_ports_facts
author:
- David Nieto (@david-ns)
'''

EXAMPLES = r'''
- name: Recopilate ports facts
  community.windows.win_listen_ports_facts:

- name: Retrieve only ports with Closing and Established states
  community.windows.win_listen_ports_facts:
    tcp_filter:
      - Closing
      - Established

- name: Get ports facts with only the year within the date field
  community.windows.win_listen_ports_facts:
    date_format: '%Y'
'''

RETURN = r'''
tcp_listen:
    description: List of dicts with the detected TCP ports
    returned: success
    type: list
    elements: dict
    sample: [
        {
            "address": "127.0.0.1",
            "name": "python",
            "pid": 5332,
            "port": 82,
            "protocol": "tcp",
            "stime": "Thu Nov 18 15:27:42 2021",
            "user": "SERVER\\Administrator"
        }
    ]
udp_listen:
    description: List of dicts with the detected UDP ports
    returned: success
    type: list
    elements: dict
    sample: [
        {
            "address": "127.0.0.1",
            "name": "python",
            "pid": 5332,
            "port": 82,
            "protocol": "udp",
            "stime": "Thu Nov 18 15:27:42 2021",
            "user": "SERVER\\Administrator"
        }
    ]
'''
