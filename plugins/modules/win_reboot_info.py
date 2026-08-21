#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_reboot_info
version_added: 3.8.0
short_description: Get reboot status information for a Windows host
description:
- Returns information about the last boot time and whether a reboot is pending on the target Windows host.
- A pending reboot can be caused by Windows Update, Component Based Servicing, pending file rename operations,
  domain join operations, or Server Manager component changes.
options: {}
seealso:
- module: ansible.windows.win_reboot
author:
- Mike Morency (@mikemorency)
'''

EXAMPLES = r'''
- name: Get reboot info
  ansible.windows.win_reboot_info:
  register: reboot_info

- name: Reboot if required
  ansible.windows.win_reboot:
  when: reboot_info.reboot_required

- name: Display last boot time
  ansible.builtin.debug:
    msg: "Last boot: {{ reboot_info.last_reboot.time }}"

- name: Show who initiated the last reboot
  ansible.builtin.debug:
    msg: >-
      Last reboot was initiated by {{ reboot_info.last_reboot.details.initiated_by }}
      via {{ reboot_info.last_reboot.details.process }}
      with comment: {{ reboot_info.last_reboot.details.comment }}
  when: reboot_info.last_reboot.details is not none

- name: Show pending reboot sources
  ansible.builtin.debug:
    msg: "Pending reboot due to: {{ reboot_info.reboot_required_reasons | map(attribute='source') | list }}"
  when: reboot_info.reboot_required
'''

RETURN = r'''
last_reboot:
  description: Information about the last system boot.
  returned: always
  type: dict
  contains:
    time:
      description: The last boot time of the system as an ISO 8601 UTC timestamp.
      type: str
      sample: "2024-01-15T08:30:00Z"
    time_epoch:
      description: The last boot time as a Unix epoch timestamp in seconds.
      type: float
      sample: 1705305000.0
    details:
      description:
      - Details about the most recent shutdown or restart event from the Windows Event Log.
      - This is gathered from Event ID 1074 in the System log.
      - Will be C(null) if no shutdown event was found in the event log.
      type: dict
      contains:
        initiated_by:
          description: The user account that initiated the reboot.
          type: str
          sample: "DOMAIN\\admin"
        process:
          description: The process that triggered the reboot.
          type: str
          sample: "C:\\Windows\\system32\\shutdown.exe"
        reason:
          description: The reason category for the reboot.
          type: str
          sample: "Operating System: Recovery (Planned)"
        reason_code:
          description:
          - The shutdown reason code associated with the reboot, as recorded in the event log.
          - This is a 32-bit value combining the major reason, minor reason, and flag bits
            (for example the high bit indicates a planned shutdown).
          - This is normally returned as an integer, but may fall back to the raw value from
            the event log if it could not be parsed as an integer.
          - The Windows event viewer displays this value as a hexadecimal string (for example
            C(0x80040002)); this is equivalent to the integer returned here.
          type: raw
          sample: 2147745794
        comment:
          description: The comment or message provided when the reboot was initiated.
          type: str
          sample: "Reboot initiated by Ansible"
        type:
          description: The type of action, such as C(restart), C(shutdown), or C(power off).
          type: str
          sample: "restart"
        event_time:
          description: The time the shutdown event was logged as an ISO 8601 UTC timestamp.
          type: str
          sample: "2024-01-15T08:29:45Z"
reboot_required:
  description: Whether the system has a pending reboot from any source.
  returned: always
  type: bool
  sample: true
reboot_required_reasons:
  description:
  - A list of sources that require a reboot.
  - Will be an empty list if no reboot is pending.
  returned: always
  type: list
  elements: dict
  contains:
    source:
      description:
      - The source that requires a reboot.
      - Known sources are C(component_based_servicing), C(windows_update), C(pending_file_rename),
        C(pending_computer_rename), C(domain_join), C(server_manager).
      type: str
      sample: windows_update
    description:
      description: A human-readable description of why a reboot is pending.
      type: str
      sample: Windows Update has installed updates that require a reboot.
'''
