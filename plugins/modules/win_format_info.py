#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_format_info
version_added: 3.10.0
short_description: Gather information about Windows volumes
description:
  - Gathers information about existing volumes on Windows.
  - A volume can be selected by drive letter, path, or file system label.
  - If no selector is specified, information about all volumes is returned.
options:
  drive_letter:
    description:
      - The drive letter of the volume to query.
      - Mutually exclusive with I(path) and I(label).
    type: str
  path:
    description:
      - The path of the volume to query.
      - Mutually exclusive with I(drive_letter) and I(label).
    type: str
  label:
    description:
      - The file system label of the volume or volumes to query.
      - Mutually exclusive with I(drive_letter) and I(path).
    type: str
notes:
  - If no volumes match the selector, C(exists) is C(false) and C(volumes) is an empty list.
seealso:
  - module: ansible.windows.win_format
author:
  - Hen Yaish (@yaish25491)
'''

EXAMPLES = r'''
- name: Gather information about all volumes
  ansible.windows.win_format_info:
  register: all_volumes

- name: Gather information about a volume by drive letter
  ansible.windows.win_format_info:
    drive_letter: D
  register: d_volume

- name: Gather information about a volume by path
  ansible.windows.win_format_info:
    path: "\\\\?\\Volume{00000000-0000-0000-0000-000000000000}\\"
  register: selected_volume

- name: Gather information about all volumes with a file system label
  ansible.windows.win_format_info:
    label: Data
  register: data_volumes
'''

RETURN = r'''
exists:
  description: Whether any matching volumes were found.
  returned: always
  type: bool
  sample: true
volumes:
  description: Volumes matching the specified criteria, or all volumes when no selector is provided.
  returned: always
  type: list
  elements: dict
  contains:
    allocation_unit_size:
      description: Allocation unit size of the volume in bytes, or null when it is unavailable.
      returned: always
      type: int
      sample: 4096
    drive_letter:
      description: Drive letter assigned to the volume, or null if it has no drive letter.
      returned: always
      type: str
      sample: D
    drive_type:
      description: Type of the volume drive.
      returned: always
      type: str
      sample: Fixed
    file_system:
      description: File system of the volume, or an empty string if it is not formatted.
      returned: always
      type: str
      sample: NTFS
    file_system_label:
      description: File system label of the volume, or an empty string if no label is set.
      returned: always
      type: str
      sample: Data
    health_status:
      description: Health status reported for the volume.
      returned: always
      type: str
      sample: Healthy
    operational_status:
      description: Operational status values reported for the volume.
      returned: always
      type: list
      elements: str
      sample: [OK]
    path:
      description: Path used to identify the volume.
      returned: always
      type: str
      sample: "\\\\?\\Volume{00000000-0000-0000-0000-000000000000}\\"
    size:
      description: Total size of the volume in bytes.
      returned: always
      type: int
      sample: 1073741824
    size_remaining:
      description: Remaining capacity of the volume in bytes.
      returned: always
      type: int
      sample: 536870912
'''
