#!/usr/bin/python

# Copyright: (c) 2019, Brant Evans <bevans@redhat.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = '''
---
module: win_initialize_disk
short_description: Initializes disks on Windows Server
description:
    - "The M(community.windows.win_initialize_disk) module initializes disks"
options:
    disk_number:
        description:
            - Used to specify the disk number of the disk to be initialized.
        type: int
    uniqueid:
        description:
            - Used to specify the uniqueid of the disk to be initialized.
        type: str
    path:
        description:
            - Used to specify the path to the disk to be initialized.
        type: str
    style:
        description:
            - The partition style to use for the disk. Valid options are mbr or gpt.
        type: str
        choices: [ gpt, mbr ]
        default: gpt
    online:
        description:
            - If the disk is offline and/or readonly update the disk to be online and not readonly.
        type: bool
        default: true
    force:
        description:
            - Specify if initializing should be forced for disks that are already initialized.
        type: bool
        default: no

notes:
    - One of three parameters (I(disk_number), I(uniqueid), and I(path)) are mandatory to identify the target disk, but
      more than one cannot be specified at the same time.
    - A minimum Operating System Version of Server 2012 or Windows 8 is required to use this module.
    - This module is idempotent if I(force) is not specified.

seealso:
    - module: community.windows.win_disk_facts
    - module: community.windows.win_partition
    - module: community.windows.win_format

author:
    - Brant Evans (@branic)
'''

EXAMPLES = '''
- name: Initialize a disk
  community.windows.win_initialize_disk:
    disk_number: 1

- name: Initialize a disk with an MBR partition style
  community.windows.win_initialize_disk:
    disk_number: 1
    style: mbr

- name: Forcefully initiallize a disk
  community.windows.win_initialize_disk:
    disk_number: 2
    force: yes
'''

RETURN = '''
#
'''
