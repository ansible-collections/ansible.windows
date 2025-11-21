#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: Contributors to the Ansible project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r"""
---
module: win_dsc3
short_description: Applies or get DSC v3 configuration state
description:
    - Calls C(dsc config set), C(dsc config test), or C(dsc config get) using the task definition
      as the configuration document.
    - This task expects the same schema for a DSC configuration document, but specific required
      properties are assigned appropriate default values when omitted. See
      U(https://learn.microsoft.com/en-us/powershell/dsc/reference/schemas/config/document) for the
      full specification.
author:
    - Yang Zhao (@yangskyboxlabs)
options:
    resources:
        description:
            - DSC resource state definitions to apply.
            - This corresponds to the C(resources) property of a DSC Configuration document.
        type: list
        elements: dict
        required: true
        suboptions:
            name:
                description:
                    - Name to assign to this resource state.
                    - Must be unique across resources in the same task.
                required: true
                type: str
            type:
                description: DSC resource type
                required: true
                type: str
            properties:
                description:
                    - The desired state of this resource instance.
                    - Can be an empty object.
                required: true
                type: dict
            dependsOn:
                description:
                    - Declare that this resource instance is dependent on other instances in the
                      same configuration.
                type: list
                elements: str
    schema:
        description:
            - The schema used to validate this configuration specification.
            - This corresponds to the C($schema) property of a DSC Configuration document.
            - See U(https://learn.microsoft.com/en-us/powershell/dsc/reference/schemas/config/document#schema)
              for accepted values.
        type: str
        default: https://aka.ms/dsc/schemas/v3/bundled/config/document.json
    parameters:
        description:
            - Runtime options for the configuration.
            - This corresponds to the C(parameters) property of a DSC Configuration document.
            - See U(https://learn.microsoft.com/en-us/powershell/dsc/reference/schemas/config/parameter)
              for the full schema definition.
        type: dict
    variables:
        description:
            - Reusable values for the resources in the configuration.
            - This corresponds to the C(variables) property of a DSC Configuration document.
        type: dict

    command:
        description:
          - DSC config command to use.
          - When O(command=set) and C(check_mode=True), C(test) is used for final invocation.
        type: str
        choices: [ set, get ]
        default: set
    raw_results:
        description: If set to True, include the complete RV(config_results[].result) property for each resource.
        type: bool
        default: False
    extra_paths:
        description:
            - Additional paths to append to E(PATH) when invocking C(dsc).
            - Use this if C(dsc) cannot be found using E(PATH), or to expand the searched paths for
              resources.
        type: list
        elements: path
    resource_paths:
        description:
            - Sets the E(DSC_RESOURCE_PATH) environment variable.
            - This will disable resource discovery using E(PATH) environment variable.
        type: list
        elements: path
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

- name: Install .NET Framework SDK form winget
  ansible.windows.win_dsc3:
    resources:
      - name: Install .NET Framework
        type: Microsoft.WinGet/Package
        properties:
          id: Microsoft.DotNet.Framework.DeveloperPack_4
          source: winget

# Manage VisualStudio BuildTools using its DSC2 resource
- name: Install VisualStudio DSC
  community.windows.win_psmodule:
    name: Microsoft.VisualStudio.DSC
  vars:
    # This is a class-based DSC resource must be executed using powershell 7 or later
    ansible_psrp_configuration_name: PowerShell.7

- name: Install Visual Studio Build Tools
  win_dsc3:
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
config_results:
    description:
        - Result of resource operations, in the same specfication order.
    type: list
    elements: dict
    returned: success
    contains:
        state:
            description: The current resource state.
            type: dict
        result:
            description: The complete, raw result information from DSC for this resource
            type: dict
            returned: success and O(raw_results=True)

metadata:
    description:
        - Application and execution metadata.
        - See U(https://learn.microsoft.com/en-us/powershell/dsc/reference/schemas/outputs/config/set#metadata)
          for more details.
    type: dict
    returned: success

rc:
    description: Exit code of dsc
    type: int
    returned: always
"""
