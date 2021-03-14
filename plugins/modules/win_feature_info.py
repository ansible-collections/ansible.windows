#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2020, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_feature_info
version_added: '1.4.0'
short_description: Gather information about Windows features
description:
- Gather information about all or a specific installed Windows feature(s).
options:
  name:
    description:
    - If specified, this is used to match the C(name) of the Windows feature to get the info for.
    - Can be a wildcard to match multiple features but the wildcard will only be matched on the C(name) of the feature.
    - If omitted then all features will returned.
    type: str
    default: '*'
seealso:
- module: ansible.windows.win_feature
author:
- Larry Lane (@gamethis)
'''

EXAMPLES = r'''
- name: Get info for all installed features
  community.windows.win_feature_info:
  register: feature_info
- name: Get info for a single feature
  community.windows.win_feature_info:
    name: DNS
  register: feature_info
- name: Find all features that start with 'FS'
  ansible.windows.win_feature_info:
    name: FS*
'''

RETURN = r'''
exists:
  description: Whether any features were found based on the criteria specified.
  returned: always
  type: bool
  sample: true
features:
  description:
  - A list of feature(s) that were found based on the criteria.
  - Will be an empty list if no features were found.
  returned: always
  type: list
  elements: dict
  contains:
    name:
      description:
      - Name of feature found.
      type: str
      sample: AD-Certificate
    display_name:
      description:
      - The Display name of feature found.
      type: str
      sample: Active Directory Certificate Services
    description:
      description:
      - The description of the feature.
      type: str
      sample: Example description of the Windows feature.
    installed:
      description:
      - Whether the feature by C(name) is installed.
      type: bool
      sample: false
    install_state:
      description:
      - The Install State of C(name).
      - Values will be one of C(Available), C(Removed), C(Installed).
      type: str
      sample: Installed
    feature_type:
      description:
      - The Feature Type of C(name).
      - Values will be one of C(Role), C(Role Service), C(Feature).
      type: str
      sample: Feature
    path:
      description:
      - The Path of C(name) feature.
      type: str
      sample: WoW64 Support
    depth:
      description:
      - Depth of C(name) feature.
      type: int
      sample: 1
    depends_on:
      description:
      - The command line that will be run when a C(run_command) failure action is fired.
      type: list
      elements: str
      sample: ['Web-Static-Content', 'Web-Default-Doc']
    parent:
      description:
      - The parent of feature C(name) if present.
      type: str
      sample: PowerShellRoot
    server_component_descriptor:
      description:
      - Descriptor of C(name) feature.
      type: str
      sample: ServerComponent_AD_Certificate
    sub_features:
      description:
      - List of sub features names of feature C(name).
      type: list
      elements: str
      sample: ['WAS-Process-Model', 'WAS-NET-Environment', 'WAS-Config-APIs']
    system_service:
      description:
      - The name of the service installed by feature C(name).
      type: list
      elements: str
      sample: ['iisadmin', 'w3svc']
    best_practices_model_id:
      description:
      - BestPracticesModelId for feature C(name).
      type: str
      sample: Microsoft/Windows/UpdateServices
    event_query:
      description:
      - The EventQuery for feature C(name).
      - This will be C(null) if None Present
      type: str
      sample: IPAMServer.Events.xml
    post_configuration_needed:
      description:
      - Tells if Post Configuration is needed for feature C(name).
      type: bool
      sample: False
    additional_info:
      description:
      - A list of privileges that the feature requires and will run with
      type: dict
      contains:
        major_version:
          description:
          - Major Version of feature C(name).
          type: int
          sample: 8
        minor_version:
          description:
          - Minor Version of feature C(name).
          type: int
          sample: 0
        number_id_version:
          description:
          - Numberic Id of feature C(name).
          type: int
          sample: 16
        install_name:
          description:
          - The action to perform once triggered, can be C(start_feature) or C(stop_feature).
          type: str
          sample: ADCertificateServicesRole
'''
