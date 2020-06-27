#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import absolute_import, division, print_function
__metaclass__ = type


DOCUMENTATION = r'''
---
module: setup
short_description: Gathers facts about remote Windows hosts
description:
- This module is automatically called by playbooks to gather useful variables about remote hosts that can be used in
  playbooks. It can also be executed directly by C(/usr/bin/ansible) to check what variables are available to a host.
- Ansible provides many I(facts) about the system, automatically.
options:
  fact_path:
    description:
    - Path used for local ansible facts, files with the C(.ps1) extension will be run and their results added to
      C(ansible_local) facts. 
    type: path
  gather_subset:
    description:
    - If supplied, restrict the additional facts collected to the given subset. Possible values are C(all), C(min),
      C(hardware), C(network), C(virtual), and C(facter).
    - Can specify a list of values to specify a larger subset.
    - Values can be used with an initial C(!) to specify that the specific subset should not be collected. For instance
      C(!hardware,!network,!virtual,!facter1).
    - If C(!all) is specified then only the C(min) subset is collected.
    - To avoid collecting even the min subset, specify C(!all,!min).
    - To collect only specific facts, use C(!all,!min) then specify the particular facts subset.
    type: list
    elements: str
    default: all
  gather_timeout:
    description:
    - Set the timeout in seconds for individual fact gathering subsets.
    type: int
    default: 10
notes:
- More ansible facts will be added with successive releases. If I(facter) is installed, variables from these programs
  will also be snapshotted into the JSON file for usage in templating. These variables are prefixed with C(facter_)
- Some facts will be blank when running as a non-administrator user.
author:
- Jordan Borean (@jborean93)
'''

EXAMPLES = r'''
# Display facts from all hosts and store them indexed by I(hostname) at C(/tmp/facts).
# ansible all -m setup --tree /tmp/facts

# Collect only facts returned by facter.
# ansible all -m setup -a 'gather_subset=!all,!any,facter'

- name: Collect only facts returned by facter
  setup:
    gather_subset:
      - '!all'
      - '!any'
      - facter

# Restrict additional gathered facts to network and virtual (includes default minimum facts)
# ansible all -m setup -a 'gather_subset=network,virtual'

# Collect only network and virtual (excludes default minimum facts)
# ansible all -m setup -a 'gather_subset=!all,!any,network,virtual'

# Do not call puppet facter even if present.
# ansible all -m setup -a 'gather_subset=!facter'

# Only collect the default minimum amount of facts:
# ansible all -m setup -a 'gather_subset=!all'

# Collect no facts, even the default minimum subset of facts:
# ansible all -m setup -a 'gather_subset=!all,!min'

# Display facts from Windows hosts with custom facts stored in C(C:\\custom_facts).
# ansible windows -m setup -a "fact_path='c:\\custom_facts'"
'''

RETURN = r'''
#
'''
