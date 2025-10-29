#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: Contributors to the Ansible project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r"""
---
module: dsc3
short_description: Sets or checks DSC v3 configuration state
description:
    - Calls C(dsc config set) or C(dsc config test) using O(config) as the configuration document.
    - This module assumes that C(dsc) can be found using E(PATH) environment variable, and C(dsc)
      itself relies on E(PATH) for resource discovery. Manipulate the environment variable directly
      if C(dsc) is not already discoverable using E(PATH).
author:
    - Yang Zhao (@yangskyboxlabs)
options:
    config:
        description:
            - The DSC configuration document to set or test.
            - See U(https://learn.microsoft.com/en-us/powershell/dsc/concepts/configuration-documents/overview?view=dsc-3.0)
              for an overview of how to author a configuration document.
            - The C($schema) top-level property may be omitted. If so, it will default to
              C(https://aka.ms/dsc/schemas/v3/bundled/config/document.json)
            - One of O(config) or O(config_file) must be specified.
        type: dict
    config_file:
        description:
            - Path to DSC configuration document on the target host.
            - This corresponds to the C(--file) commandline option.
            - One of O(config) or O(config_file) must be specified.
        type: path

    parameters:
        description:
            - Runtime parameter values.
            - This corresponds to the C(--parameters) commandline option.
        type: dict

    trace_level:
        description:
            - Specify level of tracing output, which are returned in RV(stderr_lines).
            - This corresponds to the C(--trave-level) commandline option.
        type: str
        choices: [ error, warn, info, debug, trace ]
        default: warn
"""

EXAMPLES = r"""
- name: Install DSC3 using WinGet
  ansible.windows.win_command:
    argv:
      - winget
      - install
      - --id=Microsoft.DSC
      - --exact
      - --source=winget
      - --scope=machine
      - --accept-package-agreements
      - --accept-source-agreements
      - --disable-interactivity
    creates: '{{ ansible_env.ProgramFiles }}\WinGet\Links\dsc.exe'

- name: Install .NET Framework SDK from winget
  ansible.windows.dsc3:
    config:
      resources:
        - name: Install .NET Framework
          type: Microsoft.WinGet/Package
          properties:
            id: Microsoft.DotNet.Framework.DeveloperPack_4
            source: winget

- name: Install Visual Studio Build Tools
  ansible.windows.dsc3:
    config:
      resources:
        - name: Install Visual Studio
          type: Microsoft.WinGet/Package
          properties:
            id: Microsoft.VisualStudio.2022.{{ vs_product }}
            source: winget

        - name: Install Visual Studio components
          type: Microsoft.VisualStudio.DSC/VSComponents
          properties:
            productId: Microsoft.VisualStudio.Product.{{ vs_product }}
            channelId: VisualStudio.17.Release
            components:
              - Microsoft.VisualStudio.Component.VC.14.44.17.14.x86.x64
              - Microsoft.VisualStudio.Component.Windows11SDK.22621
  vars:
    vs_product: BuildTools
"""

RETURN = r"""
result:
    description:
        - Result object returned by C(dsc).
        - The exact schema of this object depends on the command used to invoke C(dsc).
          For example, U(https://learn.microsoft.com/en-us/powershell/dsc/reference/schemas/outputs/config/set?view=dsc-3.0)
          or U(https://learn.microsoft.com/en-us/powershell/dsc/reference/schemas/outputs/config/test?view=dsc-3.0).
    type: dict
    returned: success
    contains:
        metadata:
            description:
                - Details regarding the DSC execution.
                - See U(https://learn.microsoft.com/en-us/powershell/dsc/reference/schemas/metadata/microsoft.dsc/properties?view=dsc-3.0).
            type: dict
        results:
            description:
                - List of results from each resource that were configured.
                - The schema of each item depends on the DSC operation used, and the resource's type.
            type: list

rc:
    description: Exit code of C(dsc)
    type: int
    returned: always

stderr_lines:
    description:
        - Logging and tracing messages from C(dsc).
        - May be empty if no messages were emitted at the levels allowed by O(trace_level).
    type: list
    elements: str
    returned: always
"""
