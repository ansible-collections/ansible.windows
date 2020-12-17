.. _ansible.windows.win_domain_module:


**************************
ansible.windows.win_domain
**************************

**Ensures the existence of a Windows domain**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Ensure that the domain named by ``dns_domain_name`` exists and is reachable.
- If the domain is not reachable, the domain is created in a new forest on the target Windows Server 2012R2+ host.
- This module may require subsequent use of the :ref:`ansible.windows.win_reboot <ansible.windows.win_reboot_module>` action if changes are made.




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
                    <b>create_dns_delegation</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>no</li>
                                    <li>yes</li>
                        </ul>
                </td>
                <td>
                        <div>Whether to create a DNS delegation that references the new DNS server that you install along with the domain controller.</div>
                        <div>Valid for Active Directory-integrated DNS only.</div>
                        <div>The default is computed automatically based on the environment.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>database_path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The path to a directory on a fixed disk of the Windows host where the domain database will be created.</div>
                        <div>If not set then the default path is <code>%SYSTEMROOT%\NTDS</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>dns_domain_name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The DNS name of the domain which should exist and be reachable or reside on the target Windows host.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>domain_mode</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>Win2003</li>
                                    <li>Win2008</li>
                                    <li>Win2008R2</li>
                                    <li>Win2012</li>
                                    <li>Win2012R2</li>
                                    <li>WinThreshold</li>
                        </ul>
                </td>
                <td>
                        <div>Specifies the domain functional level of the first domain in the creation of a new forest.</div>
                        <div>The domain functional level cannot be lower than the forest functional level, but it can be higher.</div>
                        <div>The default is automatically computed and set.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>domain_netbios_name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The NetBIOS name for the root domain in the new forest.</div>
                        <div>For NetBIOS names to be valid for use with this parameter they must be single label names of 15 characters or less, if not it will fail.</div>
                        <div>If this parameter is not set, then the default is automatically computed from the value of the <em>domain_name</em> parameter.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>forest_mode</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>Win2003</li>
                                    <li>Win2008</li>
                                    <li>Win2008R2</li>
                                    <li>Win2012</li>
                                    <li>Win2012R2</li>
                                    <li>WinThreshold</li>
                        </ul>
                </td>
                <td>
                        <div>Specifies the forest functional level for the new forest.</div>
                        <div>The default forest functional level in Windows Server is typically the same as the version you are running.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>install_dns</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>no</li>
                                    <li><div style="color: blue"><b>yes</b>&nbsp;&larr;</div></li>
                        </ul>
                </td>
                <td>
                        <div>Whether to install the DNS service when creating the domain controller.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>log_path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Specifies the fully qualified, non-UNC path to a directory on a fixed disk of the local computer where the log file for this operation is written.</div>
                        <div>If not set then the default path is <code>%SYSTEMROOT%\NTDS</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>safe_mode_password</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Safe mode password for the domain controller.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>sysvol_path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The path to a directory on a fixed disk of the Windows host where the Sysvol file will be created.</div>
                        <div>If not set then the default path is <code>%SYSTEMROOT%\SYSVOL</code>.</div>
                </td>
            </tr>
    </table>
    <br/>



See Also
--------

.. seealso::

   :ref:`ansible.windows.win_domain_controller_module`
      The official documentation on the **ansible.windows.win_domain_controller** module.
   :ref:`community.windows.win_domain_computer_module`
      The official documentation on the **community.windows.win_domain_computer** module.
   :ref:`community.windows.win_domain_group_module`
      The official documentation on the **community.windows.win_domain_group** module.
   :ref:`ansible.windows.win_domain_membership_module`
      The official documentation on the **ansible.windows.win_domain_membership** module.
   :ref:`community.windows.win_domain_user_module`
      The official documentation on the **community.windows.win_domain_user** module.


Examples
--------

.. code-block:: yaml

    - name: Create new domain in a new forest on the target host
      ansible.windows.win_domain:
        dns_domain_name: ansible.vagrant
        safe_mode_password: password123!

    - name: Create new Windows domain in a new forest with specific parameters
      ansible.windows.win_domain:
        create_dns_delegation: no
        database_path: C:\Windows\NTDS
        dns_domain_name: ansible.vagrant
        domain_mode: Win2012R2
        domain_netbios_name: ANSIBLE
        forest_mode: Win2012R2
        safe_mode_password: password123!
        sysvol_path: C:\Windows\SYSVOL
      register: domain_install



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
                <td>always</td>
                <td>
                            <div>True if changes were made that require a reboot.</div>
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

- Matt Davis (@nitzmahone)
