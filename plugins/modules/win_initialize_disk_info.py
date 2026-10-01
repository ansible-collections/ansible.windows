#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2026, Hen Yaish (hyaish@redhat.com)
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_initialize_disk_info
short_description: Gather information about disks on Windows Server
description:
  - Gathers detailed information about physical and virtual disks attached to a Windows host.
  - Allows querying a specific disk by disk number, unique ID, device path, or listing all available disks.
options:
  disk_number:
    description:
      - Used to specify the disk number of the target disk to query.
      - Mutually exclusive with I(uniqueid) and I(path).
    type: int
  uniqueid:
    description:
      - Used to specify the unique ID of the target disk to query.
      - Mutually exclusive with I(disk_number) and I(path).
    type: str
  path:
    description:
      - Used to specify the device path of the target disk to query.
      - Mutually exclusive with I(disk_number) and I(uniqueid).
    type: str
notes:
  - A minimum Operating System Version of Server 2012 or Windows 8 is required to use this module.
seealso:
  - module: ansible.windows.win_initialize_disk
author:
  - Hen Yaish (@yaish25491)
'''

EXAMPLES = r'''
- name: Gather information about all disks on the host
  ansible.windows.win_initialize_disk_info:
  register: all_disks

- name: Gather information about a specific disk by disk_number
  ansible.windows.win_initialize_disk_info:
    disk_number: 1
  register: disk_1_info

- name: Gather information about a disk by uniqueid
  ansible.windows.win_initialize_disk_info:
    uniqueid: "{60003979-3838-8288-1234-56789abcdef0}"
  register: unique_disk_info

- name: Gather information about a disk by path
  ansible.windows.win_initialize_disk_info:
    path: "\\\\?\\scsi#disk&ven_msft&prod_virtual_hd..."
  register: path_disk_info
'''

RETURN = r'''
disks:
  description: List of disks matching the specified criteria.
  returned: always
  type: list
  elements: dict
  contains:
    number:
      description: System-assigned disk number.
      returned: always
      type: int
      sample: 1
    friendly_name:
      description: Friendly name/model string of the disk device.
      returned: always
      type: str
      sample: "Virtual HD"
    unique_id:
      description: Unique identifier string of the disk.
      returned: always
      type: str
      sample: "{600A0B80006E1B7800000C123456789A}"
    path:
      description: Device path assigned by Windows.
      returned: always
      type: str
      sample: "\\\\?\\scsi#disk&ven_msft&prod_virtual_hd..."
    partition_style:
      description: Disk partition layout style (RAW, MBR, or GPT).
      returned: always
      type: str
      sample: "RAW"
    operational_status:
      description: Operational status of the disk (e.g., Online, Offline).
      returned: always
      type: str
      sample: "Online"
    health_status:
      description: Overall health status of the disk (e.g., Healthy, Warning, Unhealthy).
      returned: always
      type: str
      sample: "Healthy"
    bus_type:
      description: Bus architecture connecting the disk (e.g., NVMe, SAS, SATA, SCSI).
      returned: always
      type: str
      sample: "SCSI"
    size:
      description: Storage capacity of the disk in bytes.
      returned: always
      type: int
      sample: 107374182400
    allocated_size:
      description: Amount of disk space allocated to existing partitions in bytes.
      returned: always
      type: int
      sample: 0
    is_offline:
      description: Whether the disk is currently offline.
      returned: always
      type: bool
      sample: false
    is_read_only:
      description: Whether the disk attribute is set to read-only.
      returned: always
      type: bool
      sample: false
    is_system:
      description: Whether the disk contains the active system partition.
      returned: always
      type: bool
      sample: false
    is_boot:
      description: Whether the disk contains the active boot partition.
      returned: always
      type: bool
      sample: false
    number_of_partitions:
      description: Number of partitions created on the disk.
      returned: always
      type: int
      sample: 0
'''
