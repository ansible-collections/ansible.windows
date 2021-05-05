#!/usr/bin/python
# -*- coding: utf-8 -*-

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_reboot
short_description: Reboot a windows machine
description:
- Reboot a Windows machine, wait for it to go down, come back up, and respond to commands.
- For non-Windows targets, use the M(ansible.builtin.reboot) module instead.
options:
  pre_reboot_delay:
    description:
    - Seconds to wait before reboot. Passed as a parameter to the reboot command.
    type: float
    default: 2
    aliases: [ pre_reboot_delay_sec ]
  post_reboot_delay:
    description:
    - Seconds to wait after the reboot command was successful before attempting to validate the system rebooted successfully.
    - This is useful if you want wait for something to settle despite your connection already working.
    type: float
    default: 0
    aliases: [ post_reboot_delay_sec ]
  reboot_timeout:
    description:
    - Maximum seconds to wait for machine to re-appear on the network and respond to a test command.
    - This timeout is evaluated separately for both reboot verification and test command success so maximum clock time is actually twice this value.
    type: float
    default: 600
    aliases: [ reboot_timeout_sec ]
  connect_timeout:
    description:
    - Maximum seconds to wait for a single successful TCP connection to the WinRM endpoint before trying again.
    type: float
    default: 5
    aliases: [ connect_timeout_sec ]
  test_command:
    description:
    - Command to expect success for to determine the machine is ready for management.
    - By default this test command is a custom one to detect when the Windows Logon screen is up and ready to accept
      credentials. Using a custom command will replace this behaviour and just run the command specified.
    type: str
  msg:
    description:
    - Message to display to users.
    type: str
    default: Reboot initiated by Ansible
  boot_time_command:
    description:
      - Command to run that returns a unique string indicating the last time the system was booted.
      - Setting this to a command that has different output each time it is run will cause the task to fail.
    type: str
    default: '(Get-CimInstance -ClassName Win32_OperatingSystem -Property LastBootUpTime).LastBootUpTime.ToFileTime()'
notes:
- If a shutdown was already scheduled on the system, M(ansible.windows.win_reboot) will abort the scheduled shutdown and enforce its own shutdown.
- Beware that when M(ansible.windows.win_reboot) returns, the Windows system may not have settled yet and some base services could be in limbo.
  This can result in unexpected behavior. Check the examples for ways to mitigate this. This has been slightly mitigated
  in the C(1.6.0) release of C(ansible.windows) but it is not guranteed to always wait until the logon prompt is shown.
- The connection user must have the C(SeRemoteShutdownPrivilege) privilege enabled, see
  U(https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/force-shutdown-from-a-remote-system)
  for more information.
seealso:
- module: ansible.builtin.reboot
author:
- Matt Davis (@nitzmahone)
'''

EXAMPLES = r'''
- name: Reboot the machine with all defaults
  ansible.windows.win_reboot:

- name: Reboot a slow machine that might have lots of updates to apply
  ansible.windows.win_reboot:
    reboot_timeout: 3600

# Install a Windows feature and reboot if necessary
- name: Install IIS Web-Server
  ansible.windows.win_feature:
    name: Web-Server
  register: iis_install

- name: Reboot when Web-Server feature requires it
  ansible.windows.win_reboot:
  when: iis_install.reboot_required

# One way to ensure the system is reliable, is to set WinRM to a delayed startup
- name: Ensure WinRM starts when the system has settled and is ready to work reliably
  ansible.windows.win_service:
    name: WinRM
    start_mode: delayed

# Additionally, you can add a delay before running the next task
- name: Reboot a machine that takes time to settle after being booted
  ansible.windows.win_reboot:
    post_reboot_delay: 120

# Or you can make win_reboot validate exactly what you need to work before running the next task
- name: Validate that the netlogon service has started, before running the next task
  ansible.windows.win_reboot:
    test_command: 'exit (Get-Service -Name Netlogon).Status -ne "Running"'
'''

RETURN = r'''
rebooted:
  description: True if the machine was rebooted.
  returned: always
  type: bool
  sample: true
elapsed:
  description: The number of seconds that elapsed waiting for the system to be rebooted.
  returned: always
  type: float
  sample: 23.2
'''
