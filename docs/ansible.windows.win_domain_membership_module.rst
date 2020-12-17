.. _ansible.windows.win_domain_membership_module:


*************************************
ansible.windows.win_domain_membership
*************************************

**Manage domain/workgroup membership for a Windows host**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Manages domain membership or workgroup membership for a Windows host. Also supports hostname changes.
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
                    <b>dns_domain_name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>When <code>state</code> is <code>domain</code>, the DNS name of the domain to which the targeted Windows host should be joined.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>domain_admin_password</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
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
                        <div>Username of a domain admin for the target domain (required to join or leave the domain).</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>domain_ou_path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The desired OU path for adding the computer object.</div>
                        <div>This is only used when adding the target host to a domain, if it is already a member then it is ignored.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>hostname</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The desired hostname for the Windows host.</div>
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
                                    <li>domain</li>
                                    <li>workgroup</li>
                        </ul>
                </td>
                <td>
                        <div>Whether the target host should be a member of a domain or workgroup.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>workgroup_name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>When <code>state</code> is <code>workgroup</code>, the name of the workgroup that the Windows host should be in.</div>
                </td>
            </tr>
    </table>
    <br/>



See Also
--------

.. seealso::

   :ref:`ansible.windows.win_domain_module`
      The official documentation on the **ansible.windows.win_domain** module.
   :ref:`ansible.windows.win_domain_controller_module`
      The official documentation on the **ansible.windows.win_domain_controller** module.
   :ref:`community.windows.win_domain_computer_module`
      The official documentation on the **community.windows.win_domain_computer** module.
   :ref:`community.windows.win_domain_group_module`
      The official documentation on the **community.windows.win_domain_group** module.
   :ref:`community.windows.win_domain_user_module`
      The official documentation on the **community.windows.win_domain_user** module.
   :ref:`ansible.windows.win_group_module`
      The official documentation on the **ansible.windows.win_group** module.
   :ref:`ansible.windows.win_group_membership_module`
      The official documentation on the **ansible.windows.win_group_membership** module.
   :ref:`ansible.windows.win_user_module`
      The official documentation on the **ansible.windows.win_user** module.


Examples
--------

.. code-block:: yaml

    # host should be a member of domain ansible.vagrant; module will ensure the hostname is mydomainclient
    # and will use the passed credentials to join domain if necessary.
    # Ansible connection should use local credentials if possible.
    # If a reboot is required, the second task will trigger one and wait until the host is available.
    - hosts: winclient
      gather_facts: no
      tasks:
      - ansible.windows.win_domain_membership:
          dns_domain_name: ansible.vagrant
          hostname: mydomainclient
          domain_admin_user: testguy@ansible.vagrant
          domain_admin_password: password123!
          domain_ou_path: "OU=Windows,OU=Servers,DC=ansible,DC=vagrant"
          state: domain
        register: domain_state

      - ansible.windows.win_reboot:
        when: domain_state.reboot_required



    # Host should be in workgroup mywg- module will use the passed credentials to clean-unjoin domain if possible.
    # Ansible connection should use local credentials if possible.
    # The domain admin credentials can be sourced from a vault-encrypted variable
    - hosts: winclient
      gather_facts: no
      tasks:
      - ansible.windows.win_domain_membership:
          workgroup_name: mywg
          domain_admin_user: '{{ win_domain_admin_user }}'
          domain_admin_password: '{{ win_domain_admin_password }}'
          state: workgroup



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
