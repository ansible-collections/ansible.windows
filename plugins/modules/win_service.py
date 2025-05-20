#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2014, Chris Hoffman <choffman@chathamfinancial.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_service
short_description: Manage Windows services
description:
- Manage Windows services.
- For non-Windows targets, use the M(ansible.builtin.service) module instead.
options:
  dependencies:
    description:
    - A list of service dependencies to set for this particular service.
    - This should be a list of service names and not the display name of the
      service.
    - This works by C(dependency_action) to either add/remove or set the
      services in this list.
    type: list
    elements: str
  dependency_action:
    description:
    - Used in conjunction with C(dependency) to either add the dependencies to
      the existing service dependencies.
    - Remove the dependencies to the existing dependencies.
    - Set the dependencies to only the values in the list replacing the
      existing dependencies.
    type: str
    choices: [ add, remove, set ]
    default: set
  desktop_interact:
    description:
    - Whether to allow the service user to interact with the desktop.
    - This can only be set to C(true) when using the C(LocalSystem) username.
    - This can only be set to C(true) when the I(service_type) is
      C(win32_own_process) or C(win32_share_process).
    type: bool
    default: no
  description:
    description:
      - The description to set for the service.
    type: str
  display_name:
    description:
      - The display name to set for the service.
    type: str
  error_control:
    description:
    - The severity of the error and action token if the service fails to start.
    - A new service defaults to C(normal).
    - C(critical) will log the error and restart the system with the last-known
      good configuration. If the startup fails on reboot then the system will
      fail to operate.
    - C(ignore) ignores the error.
    - C(normal) logs the error in the event log but continues.
    - C(severe) is like C(critical) but a failure on the last-known good
      configuration reboot startup will be ignored.
    choices:
    - critical
    - ignore
    - normal
    - severe
    type: str
  failure_actions:
    description:
    - A list of failure actions the service controller should take on each
      failure of a service.
    - The service manager will run the actions from first to last defined until
      the service starts. If I(failure_reset_period_sec) has been exceeded then
      the failure actions will restart from the beginning.
    - If all actions have been performed the the service manager will repeat
      the last service defined.
    - The existing actions will be replaced with the list defined in the task
      if there is a mismatch with any of them.
    - Set to an empty list to delete all failure actions on a service
      otherwise an omitted or null value preserves the existing actions on the
      service.
    type: list
    elements: dict
    suboptions:
      delay_ms:
        description:
        - The time to wait, in milliseconds, before performing the specified action.
        default: 0
        type: raw
        aliases:
        - delay
      type:
        description:
        - The action to be performed.
        - C(none) will perform no action, when used this should only be set as
          the last action.
        - C(reboot) will reboot the host, when used this should only be set as
          the last action as the reboot will reset the action list back to the
          beginning.
        - C(restart) will restart the service.
        - C(run_command) will run the command specified by I(failure_command).
        required: yes
        type: str
        choices:
        - none
        - reboot
        - restart
        - run_command
  failure_actions_on_non_crash_failure:
    description:
    - Controls whether failure actions will be performed on non crash failures
      or not.
    type: bool
  failure_command:
    description:
    - The command to run for a C(run_command) failure action.
    - Set to an empty string to remove the command.
    type: str
  failure_reboot_msg:
    description:
    - The message to be broadcast to users logged on the host for a C(reboot)
      failure action.
    - Set to an empty string to remove the message.
    type: str
  failure_reset_period_sec:
    description:
    - The time in seconds after which the failure action list resets back to
      the start of the list if there are no failures.
    - To set this value, I(failure_actions) must have at least 1 action
      present.
    - Specify C('0xFFFFFFFF') to set an infinite reset period.
    type: raw
    aliases:
    - failure_reset_period
  force_dependent_services:
    description:
    - If C(true), stopping or restarting a service with dependent services will
      force the dependent services to stop or restart also.
    - If C(false), stopping or restarting a service with dependent services may
      fail.
    type: bool
    default: no
  load_order_group:
    description:
    - The name of the load ordering group of which this service is a member.
    - Specify an empty string to remove the existing load order group of a
      service.
    type: str
  name:
    description:
    - Name of the service.
    - If only the name parameter is specified, the module will report
      on whether the service exists or not without making any changes.
    required: yes
    type: str
  path:
    description:
    - The path to the executable to set for the service.
    type: str
  password:
    description:
    - The password to set the service to start as.
    - This and the C(username) argument should be supplied together when using a local or domain account.
    - If omitted then the password will continue to use the existing value password set.
    - If specifying C(LocalSystem), C(NetworkService), C(LocalService), the C(NT SERVICE), or a gMSA this field can be
      omitted as those accounts have no password.
    type: str
  pre_shutdown_timeout_ms:
    description:
    - The time in which the service manager waits after sending a preshutdown
      notification to the service until it proceeds to continue with the other
      shutdown actions.
    aliases:
    - pre_shutdown_timeout
    type: raw
  required_privileges:
    description:
    - A list of privileges the service must have when starting up.
    - When set the service will only have the privileges specified on its
      access token.
    - The I(username) of the service must already have the privileges assigned.
    - The existing privileges will be replace with the list defined in the task
      if there is a mismatch with any of them.
    - Set to an empty list to remove all required privileges, otherwise an
      omitted or null value will keep the existing privileges.
    - See L(privilege text constants,https://docs.microsoft.com/en-us/windows/win32/secauthz/privilege-constants)
      for a list of privilege constants that can be used.
    type: list
    elements: str
  service_type:
    description:
    - The type of service.
    - The default type of a new service is C(win32_own_process).
    - I(desktop_interact) can only be set if the service type is
      C(win32_own_process) or C(win32_share_process).
    choices:
    - user_own_process
    - user_share_process
    - win32_own_process
    - win32_share_process
    type: str
  sid_info:
    description:
    - Used to define the behaviour of the service's access token groups.
    - C(none) will not add any groups to the token.
    - C(restricted) will add the C(NT SERVICE\<service name>) SID to the access
      token's groups and restricted groups.
    - C(unrestricted) will add the C(NT SERVICE\<service name>) SID to the
      access token's groups.
    choices:
    - none
    - restricted
    - unrestricted
    type: str
  start_mode:
    description:
    - Set the startup type for the service.
    - A newly created service will default to C(auto).
    type: str
    choices: [ auto, delayed, disabled, manual ]
  state:
    description:
    - The desired state of the service.
    - C(started)/C(stopped)/C(absent)/C(paused) are idempotent actions that will not run
      commands unless necessary.
    - C(restarted) will always bounce the service.
    - Only services that support the paused state can be paused, you can
      check the return value C(can_pause_and_continue).
    - You can only pause a service that is already started.
    - A newly created service will default to C(stopped).
    type: str
    choices: [ absent, paused, started, stopped, restarted ]
  update_password:
    description:
    - When set to C(always) and I(password) is set, the module will always report a change and set the password.
    - Set to C(on_create) to only set the password if the module needs to create the service.
    - If I(username) was specified and the service changed to that username then I(password) will also be changed if
      specified.
    - The current default is C(on_create) but this behaviour may change in the future, it is best to be explicit here.
    choices:
    - always
    - on_create
    type: str
  username:
    description:
    - The username to set the service to start as.
    - Can also be set to C(LocalSystem) or C(SYSTEM) to use the SYSTEM account.
    - A newly created service will default to C(LocalSystem).
    - If using a custom user account, it must have the C(SeServiceLogonRight)
      granted to be able to start up. You can use the M(ansible.windows.win_user_right) module
      to grant this user right for you.
    - Set to C(NT SERVICE\service name) to run as the NT SERVICE account for that service.
    - This can also be a gMSA in the form C(DOMAIN\gMSA$).
    type: str
notes:
- This module historically returning information about the service in its return values. These should be avoided in
  favour of the M(ansible.windows.win_service_info) module.
- Most of the options in this module are non-driver services that you can view in SCManager. While you can edit driver
  services, not all functionality may be available.
- The user running the module must have the following access rights on the service to be able to use it with this
  module - C(SERVICE_CHANGE_CONFIG), C(SERVICE_ENUMERATE_DEPENDENTS), C(SERVICE_QUERY_CONFIG), C(SERVICE_QUERY_STATUS).
- Changing the state or removing the service will also require futher rights depending on what needs to be done.
seealso:
- module: ansible.builtin.service
- module: community.windows.win_nssm
- module: ansible.windows.win_service_info
- module: ansible.windows.win_user_right
author:
- Chris Hoffman (@chrishoffman)
'''

EXAMPLES = r'''
- name: Restart a service
  ansible.windows.win_service:
    name: spooler
    state: restarted

- name: Set service startup mode to auto and ensure it is started
  ansible.windows.win_service:
    name: spooler
    start_mode: auto
    state: started

- name: Pause a service
  ansible.windows.win_service:
    name: Netlogon
    state: paused

- name: Ensure that WinRM is started when the system has settled
  ansible.windows.win_service:
    name: WinRM
    start_mode: delayed

# A new service will also default to the following values:
# - username: LocalSystem
# - state: stopped
# - start_mode: auto
- name: Create a new service
  ansible.windows.win_service:
    name: service name
    path: C:\temp\test.exe

- name: Create a new service with extra details
  ansible.windows.win_service:
    name: service name
    path: C:\temp\test.exe
    display_name: Service Name
    description: A test service description

- name: Remove a service
  ansible.windows.win_service:
    name: service name
    state: absent

# This is required to be set for non-service accounts that need to run as a service
- name: Grant domain account the SeServiceLogonRight user right
  ansible.windows.win_user_right:
    name: SeServiceLogonRight
    users:
      - DOMAIN\User
    action: add

- name: Set the log on user to a domain account
  ansible.windows.win_service:
    name: service name
    state: restarted
    username: DOMAIN\User
    password: Password

- name: Set the log on user to a local account
  ansible.windows.win_service:
    name: service name
    state: restarted
    username: .\Administrator
    password: Password

- name: Set the log on user to Local System
  ansible.windows.win_service:
    name: service name
    state: restarted
    username: SYSTEM

- name: Set the log on user to Local System and allow it to interact with the desktop
  ansible.windows.win_service:
    name: service name
    state: restarted
    username: SYSTEM
    desktop_interact: true

- name: Set the log on user to Network Service
  ansible.windows.win_service:
    name: service name
    state: restarted
    username: NT AUTHORITY\NetworkService

- name: Set the log on user to Local Service
  ansible.windows.win_service:
    name: service name
    state: restarted
    username: NT AUTHORITY\LocalService

- name: Set the log on user as the services' virtual account
  ansible.windows.win_service:
    name: service name
    username: NT SERVICE\service name

- name: Set the log on user as a gMSA
  ansible.windows.win_service:
    name: service name
    username: DOMAIN\gMSA$  # The end $ is important and should be set for all gMSA

- name: Set dependencies to ones only in the list
  ansible.windows.win_service:
    name: service name
    dependencies: [service1, service2]

- name: Add dependencies to existing dependencies
  ansible.windows.win_service:
    name: service name
    dependencies: [service1, service2]
    dependency_action: add

- name: Remove dependencies from existing dependencies
  ansible.windows.win_service:
    name: service name
    dependencies:
      - service1
      - service2
    dependency_action: remove

- name: Set required privileges for a service
  ansible.windows.win_service:
    name: service name
    username: NT SERVICE\LocalService
    required_privileges:
      - SeBackupPrivilege
      - SeRestorePrivilege

- name: Remove all required privileges for a service
  ansible.windows.win_service:
    name: service name
    username: NT SERVICE\LocalService
    required_privileges: []

- name: Set failure actions for a service with no reset period
  ansible.windows.win_service:
    name: service name
    failure_actions:
      - type: restart
      - type: run_command
        delay_ms: 1000
      - type: restart
        delay_ms: 5000
      - type: reboot
    failure_command: C:\Windows\System32\cmd.exe /c mkdir C:\temp
    failure_reboot_msg: Restarting host because service name has failed
    failure_reset_period_sec: '0xFFFFFFFF'

- name: Set only 1 failure action without a repeat of the last action
  ansible.windows.win_service:
    name: service name
    failure_actions:
      - type: restart
        delay_ms: 5000
      - type: none

- name: Remove failure action information
  ansible.windows.win_service:
    name: service name
    failure_actions: []
    failure_command: ''  # removes the existing command
    failure_reboot_msg: ''  # removes the existing reboot msg
'''

RETURN = r'''
exists:
    description: Whether the service exists or not.
    returned: success
    type: bool
    sample: true
name:
    description: The service name or id of the service.
    returned: success and service exists
    type: str
    sample: CoreMessagingRegistrar
display_name:
    description: The display name of the installed service.
    returned: success and service exists
    type: str
    sample: CoreMessaging
state:
    description: The current running status of the service.
    returned: success and service exists
    type: str
    sample: stopped
start_mode:
    description: The startup type of the service.
    returned: success and service exists
    type: str
    sample: manual
path:
    description: The path to the service executable.
    returned: success and service exists
    type: str
    sample: C:\Windows\system32\svchost.exe -k LocalServiceNoNetwork
can_pause_and_continue:
    description: Whether the service can be paused and unpaused.
    returned: success and service exists
    type: bool
    sample: true
description:
    description: The description of the service.
    returned: success and service exists
    type: str
    sample: Manages communication between system components.
username:
    description: The username that runs the service.
    returned: success and service exists
    type: str
    sample: LocalSystem
desktop_interact:
    description: Whether the current user is allowed to interact with the desktop.
    returned: success and service exists
    type: bool
    sample: false
dependencies:
    description: A list of services that is depended by this service.
    returned: success and service exists
    type: list
    sample: false
depended_by:
    description: A list of services that depend on this service.
    returned: success and service exists
    type: list
    sample: false
'''
