.. _ansible.windows.win_dsc_module:


***********************
ansible.windows.win_dsc
***********************

**Invokes a PowerShell DSC configuration**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Configures a resource using PowerShell DSC.
- Requires PowerShell version 5.0 or newer.
- Most of the options for this module are dynamic and will vary depending on the DSC Resource specified in *resource_name*.




Parameters
----------

.. raw:: html

    <table  border=0 cellpadding=0 class="documentation-table">
        <tr>
            <th colspan="1">Parameter</th>
            <th>Choices/<font color="blue">Defaults</font></th>
            <th width="100%">Comments</th>
        </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>free_form</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The <span class='module'>ansible.windows.win_dsc</span> module takes in multiple free form options based on the DSC resource being invoked by <em>resource_name</em>.</div>
                        <div>There is no option actually named <code>free_form</code> so see the examples.</div>
                        <div>This module will try and convert the option to the correct type required by the DSC resource and throw a warning if it fails.</div>
                        <div>If the type of the DSC resource option is a <code>CimInstance</code> or <code>CimInstance[]</code>, this means the value should be a dictionary or list of dictionaries based on the values required by that option.</div>
                        <div>If the type of the DSC resource option is a <code>PSCredential</code> then there needs to be 2 options set in the Ansible task definition suffixed with <code>_username</code> and <code>_password</code>.</div>
                        <div>If the type of the DSC resource option is an array, then a list should be provided but a comma separated string also work. Use a list where possible as no escaping is required and it works with more complex types list <code>CimInstance[]</code>.</div>
                        <div>If the type of the DSC resource option is a <code>DateTime</code>, you should use a string in the form of an ISO 8901 string to ensure the exact date is used.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>module_version</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">"latest"</div>
                </td>
                <td>
                        <div>Can be used to configure the exact version of the DSC resource to be invoked.</div>
                        <div>Useful if the target node has multiple versions installed of the module containing the DSC resource.</div>
                        <div>If not specified, the module will follow standard PowerShell convention and use the highest version available.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>resource_name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The name of the DSC Resource to use.</div>
                        <div>Must be accessible to PowerShell using any of the default paths.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - By default there are a few builtin resources that come with PowerShell 5.0, See https://docs.microsoft.com/en-us/powershell/scripting/dsc/resources/resources for more information on these resources.
   - Custom DSC resources can be installed with :ref:`community.windows.win_psmodule <community.windows.win_psmodule_module>` using the *name* option.
   - The DSC engine run's each task as the SYSTEM account, any resources that need to be accessed with a different account need to have ``PsDscRunAsCredential`` set.
   - To see the valid options for a DSC resource, run the module with ``-vvv`` to show the possible module invocation. Default values are not shown in this output but are applied within the DSC engine.
   - The DSC engine requires the HTTP WSMan listener to be online and its port configured as the default listener for HTTP. This is set up by default but if a custom HTTP port is used or only a HTTPS listener is present then the module will fail. See the examples for a way to check this out in PowerShell.
   - The Local Configuration Manager ``LCM`` on the targeted host in question should be disabled to avoid any conflicts with resources being applied by this module. See https://devblogs.microsoft.com/powershell/invoking-powershell-dsc-resources-directly/ for more information on hwo to disable ``LCM``.



Examples
--------

.. code-block:: yaml

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



Return Values
-------------
Common return values are documented `here <https://docs.ansible.com/ansible/latest/reference_appendices/common_return_values.html#common-return-values>`_, the following are the fields unique to this module:

.. raw:: html

    <table border=0 cellpadding=0 class="documentation-table">
        <tr>
            <th colspan="1">Key</th>
            <th>Returned</th>
            <th width="100%">Description</th>
        </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>module_version</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The version of the dsc resource/module used.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">1.0.1</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>reboot_required</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>Flag returned from the DSC engine indicating whether or not the machine requires a reboot for the invoked changes to take effect.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">True</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>verbose_set</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">list</span>
                    </div>
                </td>
                <td>Ansible verbosity is -vvv or greater and a change occurred</td>
                <td>
                            <div>The verbose output as a list from executing the DSC Set method.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">[&quot;Perform operation &#x27;Invoke CimMethod&#x27; with the following parameters, &quot;, &#x27;[SERVER]: LCM: [Start Set ] [[File]DirectResourceAccess]&#x27;, &quot;Operation &#x27;Invoke CimMethod&#x27; complete.&quot;]</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>verbose_test</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">list</span>
                    </div>
                </td>
                <td>Ansible verbosity is -vvv or greater</td>
                <td>
                            <div>The verbose output as a list from executing the DSC test method.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">[&quot;Perform operation &#x27;Invoke CimMethod&#x27; with the following parameters, &quot;, &#x27;[SERVER]: LCM: [Start Test ] [[File]DirectResourceAccess]&#x27;, &quot;Operation &#x27;Invoke CimMethod&#x27; complete.&quot;]</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Trond Hindenes (@trondhindenes)
