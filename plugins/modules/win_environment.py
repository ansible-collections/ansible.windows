#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020, Brian Scholer (@briantist)
# Copyright: (c) 2015, Jon Hawkesworth (@jhawkesworth) <figs@unity.demon.co.uk>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_environment
short_description: Modify environment variables on windows hosts
description:
- Uses .net Environment to set or remove environment variables and can set at User, Machine or Process level.
- User level environment variables will be set, but not available until the user has logged off and on again.
options:
  state:
    description:
    - Set to C(present) to ensure environment variable is set.
    - Set to C(absent) to ensure it is removed.
    - When using I(variables), do not set this option.
    type: str
    choices: [ absent, present ]
  name:
    description:
    - The name of the environment variable. Required when I(state=absent).
    type: str
  value:
    description:
    - The value to store in the environment variable.
    - Must be set when I(state=present) and cannot be an empty string.
    - Should be omitted for I(state=absent) and I(variables).
    type: str
  variables:
    description:
    - A dictionary where multiple environment variables can be defined at once.
    - Not valid when I(state) is set. Variables with a value will be set (C(present)) and variables with an empty value will be unset (C(absent)).
    - I(level) applies to all vars defined this way.
    type: dict
    version_added: '1.3.0'
  level:
    description:
    - The level at which to set the environment variable.
    - Use C(machine) to set for all users.
    - Use C(user) to set for the current user that ansible is connected as.
    - Use C(process) to set for the current process.  Probably not that useful.
    type: str
    required: yes
    choices: [ machine, process, user ]
notes:
- This module is best-suited for setting the entire value of an
  environment variable. For safe element-based management of
  path-like environment vars, use the M(ansible.windows.win_path) module.
- This module does not broadcast change events.
  This means that the minority of windows applications which can have
  their environment changed without restarting will not be notified and
  therefore will need restarting to pick up new environment settings.
  User level environment variables will require the user to log out
  and in again before they become available.
- In the return, C(before_value) and C(value) will be set to the last values
  when using I(variables). It's best to use C(values) in that case if you need
  to find a specific variable's before and after values.
seealso:
- module: ansible.windows.win_path
author:
- Jon Hawkesworth (@jhawkesworth)
- Brian Scholer (@briantist)
'''

EXAMPLES = r'''
- name: Set an environment variable for all users
  ansible.windows.win_environment:
    state: present
    name: TestVariable
    value: Test value
    level: machine

- name: Remove an environment variable for the current user
  ansible.windows.win_environment:
    state: absent
    name: TestVariable
    level: user

- name: Set several variables at once
  ansible.windows.win_environment:
    level: machine
    variables:
      TestVariable: Test value
      CUSTOM_APP_VAR: 'Very important value'
      ANOTHER_VAR: '{{ my_ansible_var }}'

- name: Set and remove multiple variables at once
  ansible.windows.win_environment:
    level: user
    variables:
      TestVariable: Test value
      CUSTOM_APP_VAR: 'Very important value'
      ANOTHER_VAR: '{{ my_ansible_var }}'
      UNWANTED_VAR: ''  # < this will be removed
'''

RETURN = r'''
before_value:
  description: the value of the environment key before a change, this is null if it didn't exist
  returned: always
  type: str
  sample: C:\Windows\System32
value:
  description: the value the environment key has been set to, this is null if removed
  returned: always
  type: str
  sample: C:\Program Files\jdk1.8
values:
  description: "dictionary of before and after values; each key is a variable name, each value is
  another dict with C(before), C(after), and C(changed) keys"
  returned: always
  type: dict
  version_added: '1.3.0'
'''
