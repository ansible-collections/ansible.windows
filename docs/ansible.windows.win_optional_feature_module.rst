.. _ansible.windows.win_optional_feature_module:


************************************
ansible.windows.win_optional_feature
************************************

**Manage optional Windows features**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Install or uninstall optional Windows features on non-Server Windows.
- This module uses the ``Enable-WindowsOptionalFeature`` and ``Disable-WindowsOptionalFeature`` cmdlets.




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
                    <b>include_parent</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li><div style="color: blue"><b>no</b>&nbsp;&larr;</div></li>
                                    <li>yes</li>
                        </ul>
                </td>
                <td>
                        <div>Whether to enable the parent feature and the parent&#x27;s dependencies.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">list</span>
                         / <span style="color: purple">elements=string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The name(s) of the feature to install.</div>
                        <div>This relates to <code>FeatureName</code> in the Powershell cmdlet.</div>
                        <div>To list all available features use the PowerShell command <code>Get-WindowsOptionalFeature</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>source</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Specify a source to install the feature from.</div>
                        <div>Can either be <code>{driveletter}:\sources\sxs</code> or <code>\\{IP}\share\sources\sxs</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>state</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>absent</li>
                                    <li><div style="color: blue"><b>present</b>&nbsp;&larr;</div></li>
                        </ul>
                </td>
                <td>
                        <div>Whether to ensure the feature is absent or present on the system.</div>
                </td>
            </tr>
    </table>
    <br/>



See Also
--------

.. seealso::

   :ref:`chocolatey.chocolatey.win_chocolatey_module`
      The official documentation on the **chocolatey.chocolatey.win_chocolatey** module.
   :ref:`ansible.windows.win_feature_module`
      The official documentation on the **ansible.windows.win_feature** module.
   :ref:`ansible.windows.win_package_module`
      The official documentation on the **ansible.windows.win_package** module.


Examples
--------

.. code-block:: yaml

    - name: Install .Net 3.5
      ansible.windows.win_optional_feature:
        name: NetFx3
        state: present

    - name: Install .Net 3.5 from source
      ansible.windows.win_optional_feature:
        name: NetFx3
        source: \\share01\win10\sources\sxs
        state: present

    - name: Install Microsoft Subsystem for Linux
      ansible.windows.win_optional_feature:
        name: Microsoft-Windows-Subsystem-Linux
        state: present
      register: wsl_status

    - name: Reboot if installing Linux Subsytem as feature requires it
      ansible.windows.win_reboot:
      when: wsl_status.reboot_required

    - name: Install multiple features in one task
      ansible.windows.win_optional_feature:
        name:
        - NetFx3
        - Microsoft-Windows-Subsystem-Linux
        state: present



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
                    <b>reboot_required</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>True when the target server requires a reboot to complete updates</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">True</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Carson Anderson (@rcanderson23)
