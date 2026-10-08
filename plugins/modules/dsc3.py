#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: Contributors to the Ansible project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r"""
---
module: dsc3
short_description: Sets or checks DSC v3 configuration state
version_added: '3.4.0'
description:
    - Calls C(dsc config set) using O(config) or O(config_file) as the configuration document.
    - The module is tested against Microsoft DSC 3.3. Older 3.x releases work as long as the options that map to
      newer DSC features, such as O(ignore_settings_file), are not used.
    - By default C(dsc) must be discoverable through the E(PATH) environment variable, which C(dsc) itself also
      uses to discover resources. Use O(executable) to run a specific C(dsc.exe) and O(resource_path) to control
      where resources are discovered.
author:
    - Yang Zhao (@yangskyboxlabs)
options:
    chdir:
        description:
            - Set the specified path as the working directory of the C(dsc) process.
            - When O(config) is used, C(dsc) reads the document from stdin and sets E(DSC_CONFIG_ROOT) to this
              directory, so relative paths of C(Microsoft.DSC/Include) resources are resolved from here. When
              O(config_file) is used, they are resolved from the directory containing the file instead.
        type: path
        version_added: '3.9.0'
    config:
        description:
            - The DSC configuration document to set or test.
            - See U(https://learn.microsoft.com/en-us/powershell/dsc/concepts/configuration-documents/overview?view=dsc-3.0)
              for an overview of how to author a configuration document.
            - The C($schema) top-level property may be omitted. If so, it will default to
              C(https://aka.ms/dsc/schemas/v3/bundled/config/document.json). Nested configuration documents, for
              example the properties of a C(Microsoft.DSC/Group) resource, must include their own C($schema).
            - One of O(config) or O(config_file) must be specified.
        type: dict
    config_file:
        description:
            - Path to DSC configuration document either on the control node or the target host.
            - The O(remote_config_file) parameter controls whether the file is located on the control node
              (V(false)) or the target host (V(true)).
            - This corresponds to the C(--file) DSC commandline option.
            - One of O(config) or O(config_file) must be specified.
        type: path
    executable:
        description:
            - Path to the C(dsc) executable to run.
            - By default C(dsc.exe) is searched for through the E(PATH) environment variable. Installations through
              WinGet place it in C(%LOCALAPPDATA%\Microsoft\WinGet\Links), which may not be part of E(PATH) for
              a remote session.
        type: path
        default: dsc.exe
        version_added: '3.9.0'
    ignore_settings_file:
        description:
            - Ignore the DSC settings and policy files when running the command.
            - This corresponds to the C(--ignore-settings-file) DSC commandline option and requires DSC 3.3.0 or
              later, older releases fail with exit code 2 when this is set.
        type: bool
        default: false
        version_added: '3.9.0'
    parameters:
        description:
            - Runtime parameter values.
            - This corresponds to the C(--parameters) commandline option.
            - Can be combined with O(parameters_file) on DSC 3.2.0 or later, the values set here take precedence
              for parameters that are defined in both.
        type: dict
    parameters_file:
        description:
            - Path on the target host to a JSON or YAML file with runtime parameter values.
            - The file must contain a top-level C(parameters) object with the values.
            - This corresponds to the C(--parameters-file) DSC commandline option.
        type: path
        version_added: '3.9.0'
    remote_config_file:
        description:
            - Whether the provided O(config_file) is already on the target host.
            - If V(false), the file will be transferred from the control node to the target host
              and removed after the module is done.
            - A local O(config_file) cannot be used with async tasks, the file will need to be
              pre-transferred to the target host.
        type: bool
        default: false
    resource_path:
        description:
            - List of directories C(dsc) searches for resource manifests, set as the E(DSC_RESOURCE_PATH)
              environment variable of the C(dsc) process.
            - When set, C(dsc) only discovers resource manifests in these directories, include the DSC installation
              directory if the built-in resources are needed. The executables of resources are still located
              through E(PATH) on DSC 3.3.0 or later, older releases only look for them in these directories.
        type: list
        elements: path
        version_added: '3.9.0'
    system_root:
        description:
            - Path to the root of the operating system to target when it is not the running one, for example an
              offline image.
            - This corresponds to the C(--system-root) DSC commandline option.
        type: path
        version_added: '3.9.0'
    trace_level:
        description:
            - Specify level of tracing output, which is returned in RV(stderr_lines).
            - Messages of level C(WARN) are also reported as Ansible warnings.
            - This corresponds to the C(--trace-level) DSC commandline option.
        type: str
        choices: [ error, warn, info, debug, trace ]
        default: warn
notes:
    - The C(dsc) process runs as the user Ansible connects with. If that user does not have the rights a resource
      needs, C(become) may be able to help.
    - A configuration document can require a security context through the C(securityContext) key of its top-level
      C(directives) property, with the value V(elevated) or V(restricted). C(dsc) checks this before it invokes
      any resource and the task fails with exit code 2 when the C(dsc) process does not run in that context.
    - In check mode the module runs C(dsc config set --what-if), which reports the changes that would be made
      without changing the system. This requires DSC 3.1.0 or later. Resources without native what-if support are
      simulated from their test operation, but group resources such as C(Microsoft.DSC/Group) and
      C(Microsoft.DSC/Include) and resources that declare C(implementsPretest) do not support what-if and fail
      the task with exit code 2.
    - The changed status is derived from the C(changedProperties) of each resource. The nested results of group
      resources such as C(Microsoft.DSC/Group) and C(Microsoft.DSC/Include) are walked recursively so a group is
      only reported as changed when one of its resources changed.
    - When run with diff mode, the diff lists every resource with its name and type. Resources that changed also
      include the properties that changed and group resources contain a nested C(resources) list.
    - Warnings emitted by C(dsc) are reported as Ansible warnings and the last error emitted by C(dsc) is included
      in RV(msg) when the command fails.
seealso:
    - module: ansible.windows.win_dsc
    - name: DSC configuration document schema
      description: Reference documentation for configuration documents, including the C(directives) property.
      link: https://learn.microsoft.com/en-us/powershell/dsc/reference/schemas/config/document?view=dsc-3.0
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

- name: Require an elevated session and DSC 3.3 or later before configuring the registry
  ansible.windows.dsc3:
    config:
      directives:
        securityContext: elevated
        version: '>=3.3.0'
      resources:
        - name: Example key
          type: Microsoft.Windows/Registry
          properties:
            keyPath: HKLM\Software\Example
            _exist: true
  register: dsc_result

- name: Reboot when a resource requires it
  ansible.windows.win_reboot:
  when: dsc_result.reboot_required

- name: Run a specific dsc executable with additional resource directories
  ansible.windows.dsc3:
    executable: '{{ ansible_env.ProgramFiles }}\WinGet\Links\dsc.exe'
    resource_path:
      - '{{ ansible_env.ProgramFiles }}\DSC'
      - C:\DscResources
    config:
      resources:
        - name: Custom resource
          type: Contoso/Example
          properties:
            enabled: true

- name: Include a configuration document from a directory on the target
  ansible.windows.dsc3:
    chdir: C:\dsc\configs
    config:
      resources:
        - name: Base configuration
          type: Microsoft.DSC/Include
          properties:
            configurationFile: base.dsc.config.yaml
            parametersFile: base.parameters.yaml

- name: Apply a configuration with parameters from a file and the playbook
  ansible.windows.dsc3:
    config_file: C:\dsc\configs\web.dsc.config.yaml
    remote_config_file: true
    parameters_file: C:\dsc\configs\web.parameters.yaml
    parameters:
      siteName: '{{ inventory_hostname }}'

- name: Preview the changes DSC would make without applying them
  ansible.windows.dsc3:
    config_file: files/baseline.dsc.config.yaml
  check_mode: true
  diff: true
  register: dsc_preview
"""

RETURN = r"""
result:
    description:
        - Result object returned by C(dsc).
        - See U(https://learn.microsoft.com/en-us/powershell/dsc/reference/schemas/outputs/config/set?view=dsc-3.0)
          for the schema of this object.
    type: dict
    returned: success
    contains:
        executionInformation:
            description:
                - Details regarding the DSC execution such as the operation, the execution type, the timings, the
                  security context and the restart requirements reported by resources.
                - Returned by DSC 3.2.0 and later, older releases only return RV(result.metadata).
            type: dict
        metadata:
            description:
                - Details regarding the DSC execution under the C(Microsoft.DSC) key.
                - See U(https://learn.microsoft.com/en-us/powershell/dsc/reference/schemas/metadata/microsoft.dsc/properties?view=dsc-3.0).
                - Since DSC 3.2.0 this is a deprecated copy of RV(result.executionInformation) that DSC will stop
                  returning in a future major version.
            type: dict
        results:
            description:
                - List of results from each resource that were configured.
                - The schema of each item depends on the resource's type.
            type: list

rc:
    description: Exit code of C(dsc)
    type: int
    returned: always

msg:
    description:
        - Error message when C(dsc) fails.
        - Contains the exit code with its meaning and the last error message emitted by C(dsc).
    type: str
    returned: failure
    sample: "dsc config set failed with exit code 2 (DSC error): Security context: Elevated security context required"

stderr:
    description:
        - Raw output of C(dsc) on stderr, which contains the logging and tracing messages.
    type: str
    returned: always

stderr_lines:
    description:
        - Logging and tracing messages from C(dsc).
        - May be empty if no messages were emitted at the levels allowed by O(trace_level).
    type: list
    elements: str
    returned: always

reboot_required:
    description:
        - Whether a resource reported that the system needs to be restarted to complete the configuration.
    type: bool
    returned: success
    sample: false
    version_added: '3.9.0'

restart_requirements:
    description:
        - The restart requirements reported by the resources, aggregated from C(executionInformation.restartRequired).
        - Each entry contains a C(system), C(service) or C(process) key.
    type: list
    elements: dict
    returned: success
    sample: [{"system": "Windows"}, {"service": "Spooler"}]
    version_added: '3.9.0'

security_context:
    description:
        - The security context C(dsc) ran in, either V(elevated) or V(restricted).
    type: str
    returned: success
    sample: elevated
    version_added: '3.9.0'

execution_type:
    description:
        - V(actual) when the configuration was set and V(whatIf) when the module ran in check mode.
        - Not returned by DSC releases before 3.2.0.
    type: str
    returned: success
    sample: actual
    version_added: '3.9.0'
"""
