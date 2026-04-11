#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2026, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_credential_info
short_description: Get information on credentials stored in the Windows Credential Manager
description:
- Returns information about credentials stored in the Windows Credential Manager.
- Credentials are stored per-user. When run with C(become) and C(become_user),
  this module queries the credential store of that user. When run as SYSTEM,
  it queries the SYSTEM account's credential store, which is separate from any
  interactive user's store and not visible in the Credential Manager UI.
options:
  name:
    description:
    - The target name of the credential to retrieve.
    - Supports wildcard matching using C(*) to filter credentials.
    - When not specified, all credentials in the user's store are returned.
    type: str
  type:
    description:
    - The type of credential to filter by.
    - When specified with I(name), returns a single credential matching both
      the name and type.
    - When omitted, credentials of all types are returned.
    type: str
    choices: [ domain_certificate, domain_password, generic_certificate, generic_password ]
notes:
- This module requires to be run with C(become) so it can access the
  user's credential store.
- Credentials are stored per-user in Windows. The SYSTEM account has its own
  isolated credential store that is not visible through the Credential Manager
  UI (C(control keymgr.dll)). To verify credentials stored under SYSTEM, use
  this module with C(become_user=System) or run C(cmdkey /list) in a SYSTEM
  context (e.g. via PsExec).
seealso:
- module: ansible.windows.win_credential
author:
- Ansible Project
'''

EXAMPLES = r'''
- name: Get all credentials in the current user's store
  ansible.windows.win_credential_info:
  become: true
  register: all_creds

- name: Get a specific credential by name and type
  ansible.windows.win_credential_info:
    name: server.domain.com
    type: domain_password
  become: true
  register: cred_info

- name: Get credentials matching a wildcard pattern
  ansible.windows.win_credential_info:
    name: "*.domain.com"
  become: true
  register: domain_creds

- name: Verify a credential stored under the SYSTEM account
  ansible.windows.win_credential_info:
    name: my_target
    type: generic_password
  become: true
  become_method: runas
  become_user: System
  register: system_cred
'''

RETURN = r'''
exists:
  description: Whether any credentials were found based on the criteria specified.
  returned: always
  type: bool
  sample: true
credentials:
  description:
  - A list of credentials found in the store matching the filter criteria.
  - Will be an empty list if no credentials were found.
  returned: always
  type: list
  elements: dict
  contains:
    name:
      description: The target name that identifies the server or resource.
      type: str
      sample: server.domain.com
    type:
      description: The type of credential.
      type: str
      sample: DomainPassword
    username:
      description:
      - The username associated with the credential.
      - For certificate credentials, this is the certificate thumbprint.
      type: str
      sample: DOMAIN\username
    alias:
      description: An alias for the credential, typically a NetBIOS name.
      type: str
      sample: server
    comment:
      description: A user-defined comment for the credential.
      type: str
      sample: Credential for server.domain.com
    persistence:
      description: The persistence level of the credential.
      type: str
      sample: LocalMachine
    attributes:
      description:
      - A list of application-specific attributes on the credential.
      type: list
      elements: dict
      contains:
        name:
          description: The attribute key.
          type: str
          sample: Source
        data:
          description: The attribute value as a base64 encoded string.
          type: str
          sample: QW5zaWJsZQ==
'''
