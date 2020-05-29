#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2015, Trond Hindenes <trond@hindenes.com>, and others
# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_dsc
short_description: Invokes a PowerShell DSC configuration
description:
- Configures a resource using PowerShell DSC.
- Requires PowerShell version 5.0 or newer.
- Most of the options for this module are dynamic and will vary depending on
  the DSC Resource specified in I(resource_name).
options:
  resource_name:
    description:
    - The name of the DSC Resource to use.
    - Must be accessible to PowerShell using any of the default paths.
    type: str
    required: yes
  module_version:
    description:
    - Can be used to configure the exact version of the DSC resource to be
      invoked.
    - Useful if the target node has multiple versions installed of the module
      containing the DSC resource.
    - If not specified, the module will follow standard PowerShell convention
      and use the highest version available.
    type: str
    default: latest
  free_form:
    description:
    - The M(ansible.windows.win_dsc) module takes in multiple free form options based on the
      DSC resource being invoked by I(resource_name).
    - There is no option actually named C(free_form) so see the examples.
    - This module will try and convert the option to the correct type required
      by the DSC resource and throw a warning if it fails.
    - If the type of the DSC resource option is a C(CimInstance) or
      C(CimInstance[]), this means the value should be a dictionary or list
      of dictionaries based on the values required by that option.
    - If the type of the DSC resource option is a C(PSCredential) then there
      needs to be 2 options set in the Ansible task definition suffixed with
      C(_username) and C(_password).
    - If the type of the DSC resource option is an array, then a list should be
      provided but a comma separated string also work. Use a list where
      possible as no escaping is required and it works with more complex types
      list C(CimInstance[]).
    - If the type of the DSC resource option is a C(DateTime), you should use
      a string in the form of an ISO 8901 string to ensure the exact date is
      used.
    type: str
    required: true
notes:
- By default there are a few builtin resources that come with PowerShell 5.0,
  see U(https://docs.microsoft.com/en-us/powershell/scripting/dsc/resources/resources) for
  more information on these resources.
- Custom DSC resources can be installed with M(community.windows.win_psmodule) using the I(name)
  option.
- The DSC engine run's each task as the SYSTEM account, any resources that need
  to be accessed with a different account need to have C(PsDscRunAsCredential)
  set.
- To see the valid options for a DSC resource, run the module with C(-vvv) to
  show the possible module invocation. Default values are not shown in this
  output but are applied within the DSC engine.
- The DSC engine requires the HTTP WSMan listener to be online and its port
  configured as the default listener for HTTP. This is set up by default but if
  a custom HTTP port is used or only a HTTPS listener is present then the
  module will fail. See the examples for a way to check this out in PowerShell.
author:
- Trond Hindenes (@trondhindenes)
'''

EXAMPLES = r'''
- name: Verify the WSMan HTTP listener is active and configured correctly
  ansible.windows.win_shell: |
    $port = (Get-Item -LiteralPath WSMan:\localhost\Client\DefaultPorts\HTTP).Value
    $onlinePorts = @(Get-ChildItem -LiteralPath WSMan:\localhost\Listener |
        Where-Object { 'Transport=HTTP' -in $_.Keys } |
        Get-ChildItem |
        Where-Object Name -eq Port |
        Select-Object -ExpandProperty Value)

    if ($port -notin $onlinePorts) {
        "The default client port $port is not set up as a WSMan HTTP listener, win_dsc will not work."
    }

- name: Extract zip file
  ansible.windows.win_dsc:
    resource_name: Archive
    Ensure: Present
    Path: C:\Temp\zipfile.zip
    Destination: C:\Temp\Temp2

- name: Install a Windows feature with the WindowsFeature resource
  ansible.windows.win_dsc:
    resource_name: WindowsFeature
    Name: telnet-client

- name: Edit HKCU reg key under specific user
  ansible.windows.win_dsc:
    resource_name: Registry
    Ensure: Present
    Key: HKEY_CURRENT_USER\ExampleKey
    ValueName: TestValue
    ValueData: TestData
    PsDscRunAsCredential_username: '{{ansible_user}}'
    PsDscRunAsCredential_password: '{{ansible_password}}'
  no_log: true

- name: Create file with multiple attributes
  ansible.windows.win_dsc:
    resource_name: File
    DestinationPath: C:\ansible\dsc
    Attributes: # can also be a comma separated string, e.g. 'Hidden, System'
    - Hidden
    - System
    Ensure: Present
    Type: Directory

- name: Call DSC resource with DateTime option
  ansible.windows.win_dsc:
    resource_name: DateTimeResource
    DateTimeOption: '2019-02-22T13:57:31.2311892+00:00'

# more complex example using custom DSC resource and dict values
- name: Setup the xWebAdministration module
  ansible.windows.win_psmodule:
    name: xWebAdministration
    state: present

- name: Create IIS Website with Binding and Authentication options
  ansible.windows.win_dsc:
    resource_name: xWebsite
    Ensure: Present
    Name: DSC Website
    State: Started
    PhysicalPath: C:\inetpub\wwwroot
    BindingInfo: # Example of a CimInstance[] DSC parameter (list of dicts)
    - Protocol: https
      Port: 1234
      CertificateStoreName: MY
      CertificateThumbprint: C676A89018C4D5902353545343634F35E6B3A659
      HostName: DSCTest
      IPAddress: '*'
      SSLFlags: '1'
    - Protocol: http
      Port: 4321
      IPAddress: '*'
    AuthenticationInfo: # Example of a CimInstance DSC parameter (dict)
      Anonymous: no
      Basic: true
      Digest: false
      Windows: yes
'''

RETURN = r'''
module_version:
    description: The version of the dsc resource/module used.
    returned: always
    type: str
    sample: "1.0.1"
reboot_required:
    description: Flag returned from the DSC engine indicating whether or not
      the machine requires a reboot for the invoked changes to take effect.
    returned: always
    type: bool
    sample: true
verbose_test:
    description: The verbose output as a list from executing the DSC test
      method.
    returned: Ansible verbosity is -vvv or greater
    type: list
    sample: [
      "Perform operation 'Invoke CimMethod' with the following parameters, ",
      "[SERVER]: LCM: [Start Test ] [[File]DirectResourceAccess]",
      "Operation 'Invoke CimMethod' complete."
    ]
verbose_set:
    description: The verbose output as a list from executing the DSC Set
      method.
    returned: Ansible verbosity is -vvv or greater and a change occurred
    type: list
    sample: [
      "Perform operation 'Invoke CimMethod' with the following parameters, ",
      "[SERVER]: LCM: [Start Set ] [[File]DirectResourceAccess]",
      "Operation 'Invoke CimMethod' complete."
    ]
'''
