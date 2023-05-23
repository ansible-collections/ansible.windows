#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2017, Red Hat, Inc.
# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
module: win_domain_controller
short_description: Manage domain controller/member server state for a Windows host
description:
    - Ensure that a Windows Server 2012+ host is configured as a domain controller or demoted to member server.
    - This module may require subsequent use of the M(ansible.windows.win_reboot) action if changes are made.
deprecated:
  removed_in: 3.0.0
  why: This module has been moved into the C(microsoft.ad) collection.
  alternative: Use the M(microsoft.ad.domain_controller) module instead.
options:
  dns_domain_name:
    description:
      - When C(state) is C(domain_controller), the DNS name of the domain for which the targeted Windows host should be a DC.
    type: str
  domain_admin_user:
    description:
      - Username of a domain admin for the target domain (necessary to promote or demote a domain controller).
    type: str
    required: true
  domain_admin_password:
    description:
      - Password for the specified C(domain_admin_user).
    type: str
    required: true
  safe_mode_password:
    description:
      - Safe mode password for the domain controller (required when C(state) is C(domain_controller)).
    type: str
  local_admin_password:
    description:
      - Password to be assigned to the local C(Administrator) user (required when C(state) is C(member_server)).
    type: str
  read_only:
    description:
      - Whether to install the domain controller as a read only replica for an existing domain.
    type: bool
    default: no
  site_name:
    description:
      - Specifies the name of an existing site where you can place the new domain controller.
      - This option is required when I(read_only) is C(true).
    type: str
  state:
    description:
      - Whether the target host should be a domain controller or a member server.
    type: str
    choices: [ domain_controller, member_server ]
    required: yes
  database_path:
    description:
    - The path to a directory on a fixed disk of the Windows host where the
      domain database will be created..
    - If not set then the default path is C(%SYSTEMROOT%\NTDS).
    type: path
  domain_log_path:
    description:
    - Specified the fully qualified, non-UNC path to a directory on a fixed disk of the local computer that will
      contain the domain log files.
    type: path
  sysvol_path:
    description:
    - The path to a directory on a fixed disk of the Windows host where the
      Sysvol folder will be created.
    - If not set then the default path is C(%SYSTEMROOT%\SYSVOL).
    type: path
  install_media_path:
    description:
    - The path to a directory on a fixed disk of the Windows host where the Install From Media C(IFC) data will be used.
    - See the L(Install using IFM guide,https://social.technet.microsoft.com/wiki/contents/articles/8630.active-directory-step-by-step-guide-to-install-an-additional-domain-controller-using-ifm.aspx) for more information. # noqa
    type: path
  install_dns:
    description:
    - Whether to install the DNS service when creating the domain controller.
    - If not specified then the C(-InstallDns) option is not supplied to C(Install-ADDSDomainController) command,
      see U(https://docs.microsoft.com/en-us/powershell/module/addsdeployment/install-addsdomaincontroller).
    type: bool
  log_path:
    description:
    - The path to log any debug information when running the module.
    - This option is deprecated and should not be used, it will be removed on the major release after C(2022-07-01).
    - This does not relate to the C(-LogPath) paramter of the install controller cmdlet.
    type: str
seealso:
- module: ansible.windows.win_domain
- module: community.windows.win_domain_computer
- module: community.windows.win_domain_group
- module: ansible.windows.win_domain_membership
- module: community.windows.win_domain_user
author:
    - Matt Davis (@nitzmahone)
'''

RETURN = r'''
reboot_required:
    description: True if changes were made that require a reboot.
    returned: always
    type: bool
    sample: true
'''

EXAMPLES = r'''
- name: Ensure a server is a domain controller
  ansible.windows.win_domain_controller:
    dns_domain_name: ansible.vagrant
    domain_admin_user: testguy@ansible.vagrant
    domain_admin_password: password123!
    safe_mode_password: password123!
    state: domain_controller

# note that without an action wrapper, in the case where a DC is demoted,
# the task will fail with a 401 Unauthorized, because the domain credential
# becomes invalid to fetch the final output over WinRM. This requires win_async
# with credential switching (or other clever credential-switching
# mechanism to get the output and trigger the required reboot)
- name: Ensure a server is not a domain controller
  ansible.windows.win_domain_controller:
    domain_admin_user: testguy@ansible.vagrant
    domain_admin_password: password123!
    local_admin_password: password123!
    state: member_server

- name: Promote server as a read only domain controller
  ansible.windows.win_domain_controller:
    dns_domain_name: ansible.vagrant
    domain_admin_user: testguy@ansible.vagrant
    domain_admin_password: password123!
    safe_mode_password: password123!
    state: domain_controller
    read_only: true
    site_name: London

- name: Promote server with custom paths
  ansible.windows.win_domain_controller:
    dns_domain_name: ansible.vagrant
    domain_admin_user: testguy@ansible.vagrant
    domain_admin_password: password123!
    safe_mode_password: password123!
    state: domain_controller
    sysvol_path: D:\SYSVOL
    database_path: D:\NTDS
    domain_log_path: D:\NTDS
  register: dc_promotion

- name: Reboot after promotion
  ansible.windows.win_reboot:
  when: dc_promotion.reboot_required
'''
