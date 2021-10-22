#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2015, Matt Davis <mdavis_ansible@rolpdog.com>
# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_updates
short_description: Download and install Windows updates
description:
    - Searches, downloads, and installs Windows updates synchronously by automating the Windows Update client.
options:
    accept_list:
        description:
        - A list of update titles or KB numbers that can be used to specify
          which updates are to be searched or installed.
        - If an available update does not match one of the entries, then it
          is skipped and not installed.
        - Each entry can either be the KB article or Update title as a regex
          according to the PowerShell regex rules.
        - The accept list is only validated on updates that were found based on
          I(category_names). It will not force the module to install an update
          if it was not in the category specified.
        - The alias C(whitelist) is deprecated and will be removed in a release after C(2023-06-01).
        type: list
        elements: str
        aliases:
        - whitelist
    category_names:
        description:
        - A scalar or list of categories to install updates from. To get the list
          of categories, run the module with C(state=searched). The category must
          be the full category string, but is case insensitive.
        - Some possible categories are Application, Connectors, Critical Updates,
          Definition Updates, Developer Kits, Feature Packs, Guidance, Security
          Updates, Service Packs, Tools, Update Rollups, Updates, and Upgrades.
        - Since C(v1.7.0) the value C(*) will match all categories.
        type: list
        elements: str
        default: [ CriticalUpdates, SecurityUpdates, UpdateRollups ]
    skip_optional:
        description:
        - Skip optional updates where the update has BrowseOnly set by Microsoft.
        - Microsoft documents show that BrowseOnly means that the update
          should not be installed automatically and appear as optional updates.
        type: bool
        default: no
        version_added: 1.8.0
    reboot:
        description:
        - Ansible will automatically reboot the remote host if it is required
          and continue to install updates after the reboot.
        - This can be used instead of using a M(ansible.windows.win_reboot) task after this one
          and ensures all updates for that category is installed in one go.
        - Async does not work when C(reboot=yes).
        type: bool
        default: no
    reboot_timeout:
        description:
        - The time in seconds to wait until the host is back online from a
          reboot.
        - This is only used if C(reboot=yes) and a reboot is required.
        default: 1200
        type: int
    server_selection:
        description:
        - Defines the Windows Update source catalog.
        - C(default) Use the default search source. For many systems default is
          set to the Microsoft Windows Update catalog. Systems participating in
          Windows Server Update Services (WSUS) or similar corporate update server environments may
          default to those managed update sources instead of the Windows Update
          catalog.
        - C(managed_server) Use a managed server catalog. For environments
          utilizing Windows Server Update Services (WSUS) or similar corporate update servers, this
          option selects the defined corporate update source.
        - C(windows_update) Use the Microsoft Windows Update catalog.
        type: str
        choices: [ default, managed_server, windows_update ]
        default: default
    state:
        description:
        - Controls whether found updates are downloaded or installed or listed
        - This module also supports Ansible check mode, which has the same effect as setting state=searched
        type: str
        choices: [ installed, searched, downloaded ]
        default: installed
    log_path:
        description:
        - If set, C(win_updates) will append update progress to the specified file. The directory must already exist.
        type: path
    reject_list:
        description:
        - A list of update titles or KB numbers that can be used to specify
          which updates are to be excluded from installation.
        - If an available update does match one of the entries, then it is
          skipped and not installed.
        - Each entry can either be the KB article or Update title as a regex
          according to the PowerShell regex rules.
        - The alias C(blacklist) is deprecated and will be removed in a release after C(2023-06-01).
        type: list
        elements: str
        aliases:
        - blacklist
    use_scheduled_task:
        description:
        - This option is deprecated and no longer does anything since C(v1.7.0) of this collection.
        - The option will be removed in a release after C(2023-06-01).
        type: bool
        default: no
    _output_path:
        description:
        - Internal use only.
        type: str
    _wait:
        description:
        - Internal use only.
        type: bool
        default: no
notes:
- M(ansible.windows.win_updates) must be run by a user with membership in the local Administrators group.
- M(ansible.windows.win_updates) will use the default update service configured for the machine (Windows Update, Microsoft Update, WSUS, etc).
- By default M(ansible.windows.win_updates) does not manage reboots, but will signal when a
  reboot is required with the I(reboot_required) return value.
  I(reboot) can be used to reboot the host if required in the one task.
- M(ansible.windows.win_updates) can take a significant amount of time to complete (hours, in some cases).
  Performance depends on many factors, including OS version, number of updates, system load, and update server load.
- Beware that just after M(ansible.windows.win_updates) reboots the system, the Windows system may not have settled yet
  and some base services could be in limbo. This can result in unexpected behavior.
  Check the examples for ways to mitigate this.
- More information about PowerShell and how it handles RegEx strings can be
  found at U(https://technet.microsoft.com/en-us/library/2007.11.powershell.aspx).
- The current module doesn't support Systems Center Configuration Manager (SCCM).
  See L(https://github.com/ansible-collections/ansible.windows/issues/194)
seealso:
- module: chocolatey.chocolatey.win_chocolatey
- module: ansible.windows.win_feature
- module: community.windows.win_hotfix
- module: ansible.windows.win_package
author:
- Matt Davis (@nitzmahone)
'''

EXAMPLES = r'''
- name: Install all updates and reboot as many times as needed
  ansible.windows.win_updates:
    category_names: '*'
    reboot: yes

- name: Install all security, critical, and rollup updates without a scheduled task
  ansible.windows.win_updates:
    category_names:
      - SecurityUpdates
      - CriticalUpdates
      - UpdateRollups

- name: Search-only, return list of found updates (if any), log to C:\ansible_wu.txt
  ansible.windows.win_updates:
    category_names: SecurityUpdates
    state: searched
    log_path: C:\ansible_wu.txt

- name: Install all security updates with automatic reboots
  ansible.windows.win_updates:
    category_names:
    - SecurityUpdates
    reboot: yes

- name: Install only particular updates based on the KB numbers
  ansible.windows.win_updates:
    category_name:
    - SecurityUpdates
    accept_list:
    - KB4056892
    - KB4073117

- name: Exclude updates based on the update title
  ansible.windows.win_updates:
    category_name:
    - SecurityUpdates
    - CriticalUpdates
    reject_list:
    - Windows Malicious Software Removal Tool for Windows
    - \d{4}-\d{2} Cumulative Update for Windows Server 2016

# Optionally, you can increase the reboot_timeout to survive long updates during reboot
- name: Ensure we wait long enough for the updates to be applied during reboot
  ansible.windows.win_updates:
    reboot: yes
    reboot_timeout: 3600

# Search and download Windows updates
- name: Search and download Windows updates without installing them
  ansible.windows.win_updates:
    state: downloaded
'''

RETURN = r'''
reboot_required:
    description: True when the target server requires a reboot to complete updates (no further updates can be installed until after a reboot).
    returned: success
    type: bool
    sample: true

updates:
    description: List of updates that were found/installed.
    returned: success
    type: complex
    sample:
    contains:
        title:
            description: Display name.
            returned: always
            type: str
            sample: "Security Update for Windows Server 2012 R2 (KB3004365)"
        kb:
            description: A list of KB article IDs that apply to the update.
            returned: always
            type: list
            elements: str
            sample: [ '3004365' ]
        id:
            description: Internal Windows Update GUID.
            returned: always
            type: str
            sample: "fb95c1c8-de23-4089-ae29-fd3351d55421"
        downloaded:
            description: Was the update downloaded.
            returned: always
            type: bool
            sample: true
            version_added: 1.7.0
        installed:
            description: Was the update successfully installed.
            returned: always
            type: bool
            sample: true
        categories:
            description: A list of category strings for this update.
            returned: always
            type: list
            elements: str
            sample: [ 'Critical Updates', 'Windows Server 2012 R2' ]
        failure_hresult_code:
            description: The HRESULT code from a failed update.
            returned: on install or download failure
            type: bool
            sample: 2147942402
        failure_msg:
            description: The error message with more details on the failure.
            returned: on install or download failure and not running with async
            type: str
            sample: Operation did not complete because there is no logged-on interactive user (WU_E_NO_INTERACTIVE_USER 0x80240020)
            version_added: 1.7.0

filtered_updates:
    description: List of updates that were found but were filtered based on
      I(blacklist), I(whitelist) or I(category_names). The return value is in
      the same form as I(updates), along with I(filtered_reason).
    returned: success
    type: complex
    sample: see the updates return value
    contains:
        filtered_reason:
            description:
            - The reason why this update was filtered.
            - This value has been deprecated since C(1.7.0), use C(filtered_reasons) which contain a list of all the
              reasons why the update is filtered.
            returned: always
            type: str
            sample: 'skip_hidden'
        filtered_reasons:
            description:
            - A list of reasons why the update has been filtered.
            - Can be C(accept_list), C(reject_list), C(hidden), C(category_names), or C(skip_optional).
            type: list
            elements: str
            sample:
            - category_names
            - accept_list
            version_added: 1.7.0

found_update_count:
    description: The number of updates found needing to be applied.
    returned: success
    type: int
    sample: 3
installed_update_count:
    description: The number of updates successfully installed or downloaded.
    returned: success
    type: int
    sample: 2
failed_update_count:
    description: The number of updates that failed to install.
    returned: always
    type: int
    sample: 0
'''
