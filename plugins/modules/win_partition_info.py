#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_partition_info
version_added: '3.10.0'
short_description: Gather information about Windows disk partitions
description:
- Gather information about all partitions or partitions matching the specified filters.
options:
  disk_number:
    description:
    - Return partitions on this disk.
    - Disk numbers start at C(0).
    type: int
  partition_number:
    description:
    - Return partitions with this partition number.
    - Can be used by itself to search all disks or together with I(disk_number) to identify a partition.
    - Partition numbers start at C(1).
    type: int
  drive_letter:
    description:
    - Return the partition with this drive letter.
    - This option is mutually exclusive with I(disk_number) and I(partition_number).
    type: str
notes:
- Requires Windows 8 or Windows Server 2012 (NT 6.2) or newer.
author:
- Hen Yaish (@Yaish25491)
seealso:
- module: ansible.windows.win_partition
'''

EXAMPLES = r'''
- name: Get information about all partitions
  ansible.windows.win_partition_info:
  register: partition_info

- name: Get information about a partition by disk and partition number
  ansible.windows.win_partition_info:
    disk_number: 1
    partition_number: 2
  register: partition_info

- name: Get information about the partition with drive letter D
  ansible.windows.win_partition_info:
    drive_letter: D
  register: partition_info
'''

RETURN = r'''
exists:
  description: Whether any partitions were found with the specified filters.
  returned: always
  type: bool
  sample: true
partitions:
  description:
  - Information about each matching partition.
  - This will be an empty list when no partitions match the specified filters.
  returned: always
  type: list
  elements: dict
  contains:
    access_paths:
      description: Access paths for the partition, including drive letters and mounted folders.
      type: list
      elements: str
    disk_number:
      description: Number of the disk containing the partition.
      type: int
      sample: 1
    drive_letter:
      description: Drive letter assigned to the partition, or C(null) if no letter is assigned.
      type: str
      sample: D
    gpt_type:
      description: GPT type GUID, or C(null) when the disk uses MBR partitioning.
      type: str
      sample: '{ebd0a0a2-b9e5-4433-87c0-68b6b72699c7}'
    guid:
      description: GUID of the partition, or C(null) when it is not available.
      type: str
      sample: '{302e475c-6e64-4674-a8e2-2f1c7018bf97}'
    is_active:
      description: Whether the partition is active. This property is only applicable to MBR disks.
      type: bool
      sample: false
    is_boot:
      description: Whether the partition is the current boot partition.
      type: bool
      sample: false
    is_hidden:
      description: Whether the partition is hidden from the mount manager.
      type: bool
      sample: false
    is_offline:
      description: Whether the partition is offline.
      type: bool
      sample: false
    is_read_only:
      description: Whether the partition is read-only.
      type: bool
      sample: false
    is_shadow_copy:
      description: Whether the partition is a shadow copy of another partition.
      type: bool
      sample: false
    is_system:
      description: Whether the partition is a system partition.
      type: bool
      sample: false
    mbr_type:
      description: MBR partition type code, or C(null) when the disk uses GPT partitioning.
      type: int
      sample: 7
    no_default_drive_letter:
      description: Whether Windows avoids assigning a drive letter automatically to this partition.
      type: bool
      sample: false
    offset:
      description: Starting offset of the partition in bytes.
      type: int
      sample: 1048576
    operational_status:
      description: Numeric operational status reported for the partition.
      type: int
      sample: 1
    partition_number:
      description: Number of the partition on its disk.
      type: int
      sample: 2
    size:
      description: Size of the partition in bytes.
      type: int
      sample: 1073741824
    transition_state:
      description: Numeric transition state reported for the partition.
      type: int
      sample: 1
    type:
      description: Partition type reported by the Windows Storage module.
      type: str
      sample: IFS
'''
