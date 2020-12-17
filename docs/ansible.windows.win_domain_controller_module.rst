.. _ansible.windows.win_domain_controller_module:


*************************************
ansible.windows.win_domain_controller
*************************************

**Manage domain controller/member server state for a Windows host**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Ensure that a Windows Server 2012+ host is configured as a domain controller or demoted to member server.
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
                    <b>database_path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The path to a directory on a fixed disk of the Windows host where the domain database will be created..</div>
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
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>When <code>state</code> is <code>domain_controller</code>, the DNS name of the domain for which the targeted Windows host should be a DC.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>domain_admin_password</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Password for the specified <code>domain_admin_user</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>domain_admin_user</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Username of a domain admin for the target domain (necessary to promote or demote a domain controller).</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>domain_log_path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Specified the fully qualified, non-UNC path to a directory on a fixed disk of the local computer that will contain the domain log files.</div>
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
                                    <li>yes</li>
                        </ul>
                </td>
                <td>
                        <div>Whether to install the DNS service when creating the domain controller.</div>
                        <div>If not specified then the <code>-InstallDns</code> option is not supplied to <code>Install-ADDSDomainController</code> command, see <a href='https://docs.microsoft.com/en-us/powershell/module/addsdeployment/install-addsdomaincontroller'>https://docs.microsoft.com/en-us/powershell/module/addsdeployment/install-addsdomaincontroller</a>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>install_media_path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The path to a directory on a fixed disk of the Windows host where the Install From Media <code>IFC</code> data will be used.</div>
                        <div>See the <a href='https://social.technet.microsoft.com/wiki/contents/articles/8630.active-directory-step-by-step-guide-to-install-an-additional-domain-controller-using-ifm.aspx'>Install using IFM guide</a> for more information.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>local_admin_password</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Password to be assigned to the local <code>Administrator</code> user (required when <code>state</code> is <code>member_server</code>).</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>log_path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The path to log any debug information when running the module.</div>
                        <div>This option is deprecated and should not be used, it will be removed on the major release after <code>2022-07-01</code>.</div>
                        <div>This does not relate to the <code>-LogPath</code> paramter of the install controller cmdlet.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>read_only</b>
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
                        <div>Whether to install the domain controller as a read only replica for an existing domain.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>safe_mode_password</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Safe mode password for the domain controller (required when <code>state</code> is <code>domain_controller</code>).</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>site_name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Specifies the name of an existing site where you can place the new domain controller.</div>
                        <div>This option is required when <em>read_only</em> is <code>yes</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>state</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>domain_controller</li>
                                    <li>member_server</li>
                        </ul>
                </td>
                <td>
                        <div>Whether the target host should be a domain controller or a member server.</div>
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
                        <div>The path to a directory on a fixed disk of the Windows host where the Sysvol folder will be created.</div>
                        <div>If not set then the default path is <code>%SYSTEMROOT%\SYSVOL</code>.</div>
                </td>
            </tr>
    </table>
    <br/>



See Also
--------

.. seealso::

   :ref:`ansible.windows.win_domain_module`
      The official documentation on the **ansible.windows.win_domain** module.
   :ref:`ansible.windows.win_domain_computer_module`
      The official documentation on the **ansible.windows.win_domain_computer** module.
   :ref:`community.windows.win_domain_group_module`
      The official documentation on the **community.windows.win_domain_group** module.
   :ref:`ansible.windows.win_domain_membership_module`
      The official documentation on the **ansible.windows.win_domain_membership** module.
   :ref:`community.windows.win_domain_user_module`
      The official documentation on the **community.windows.win_domain_user** module.


Examples
--------

.. code-block:: yaml

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
        read_only: yes
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
