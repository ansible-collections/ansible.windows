#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2019, Varun Chopra (@chopraaa) <v@chopraaa.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_format
version_added: 3.10.0
short_description: Formats an existing volume or a new volume on an existing partition on Windows
description:
  - The M(ansible.windows.win_format) module formats an existing volume or a new volume on an existing partition on Windows.
  - Use M(ansible.windows.win_format_info) to gather information about volumes.
options:
  drive_letter:
    description:
      - Used to specify the drive letter of the volume to be formatted.
    type: str
  path:
    description:
      - Used to specify the path to the volume to be formatted.
    type: str
  label:
    description:
      - Used to specify the label of the volume to be formatted.
      - If multiple volumes have this label, the module fails without formatting. Use I(drive_letter) or I(path) to select a single volume.
    type: str
  new_label:
    description:
      - Used to specify the new file system label of the formatted volume.
      - For an already formatted volume, the label can be changed without formatting the volume unless I(force) is specified.
    type: str
  file_system:
    description:
      - Used to specify the file system to be used when formatting the target volume.
    type: str
    choices: [ ntfs, refs, exfat, fat32, fat ]
  allocation_unit_size:
    description:
      - Specifies the cluster size to use when formatting the volume.
      - If no cluster size is specified when you format a partition, defaults are selected based on
        the size of the partition.
      - This value must be a multiple of the physical sector size of the disk.
      - If the current allocation unit size of an already formatted volume cannot be determined, I(force) is required.
    type: int
  large_frs:
    description:
      - Specifies that large File Record Segments (FRS) should be used.
    type: bool
  compress:
    description:
      - Enable compression on the resulting NTFS volume.
      - NTFS compression is not supported where I(allocation_unit_size) is more than 4096.
    type: bool
  integrity_streams:
    description:
      - Enable integrity streams on the resulting ReFS volume.
    type: bool
  full:
    description:
      - A full format writes to every sector of the disk, takes much longer to perform than the
        default (quick) format, and is not recommended on storage that is thinly provisioned.
      - Specify C(true) for full format.
    type: bool
    default: no
  force:
    description:
      - Required to change the file system or allocation unit size of an already formatted volume, even when the volume contains no files.
      - When specified, the volume is formatted even if its current settings already match. Formatting removes existing data.
    type: bool
    default: no
notes:
  - Microsoft Windows Server 2012 or Microsoft Windows 8 or newer is required to use this module. To check if your system is compatible, see
    U(https://docs.microsoft.com/en-us/windows/desktop/sysinfo/operating-system-version).
  - One of three parameters (I(drive_letter), I(path) and I(label)) are mandatory to identify the target
    volume but more than one cannot be specified at the same time.
  - Changing only I(new_label) does not remove existing data. Repeating the same label update is idempotent.
  - Options that affect formatting (I(full), I(compress), I(integrity_streams), and I(large_frs)) require I(force)
    when the target volume is already formatted.
  - For more information, see U(https://learn.microsoft.com/en-us/windows-hardware/drivers/storage/format-msft-volume)
seealso:
  - module: ansible.windows.win_format_info
  - module: community.windows.win_disk_facts
  - module: community.windows.win_partition
author:
  - Varun Chopra (@chopraaa) <v@chopraaa.com>
'''

EXAMPLES = r'''
- name: Create a partition with drive letter D and size 5 GiB
  community.windows.win_partition:
    drive_letter: D
    partition_size: 5 GiB
    disk_number: 1

- name: Full format the newly created partition as NTFS and label it
  ansible.windows.win_format:
    drive_letter: D
    file_system: NTFS
    new_label: Formatted
    full: true
'''

RETURN = r'''
#
'''
