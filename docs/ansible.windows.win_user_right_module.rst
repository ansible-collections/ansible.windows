.. _ansible.windows.win_user_right_module:


******************************
ansible.windows.win_user_right
******************************

**Manage Windows User Rights**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Add, remove or set User Rights for a group or users or groups.
- You can set user rights for both local and domain accounts.




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
                    <b>action</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>add</li>
                                    <li>remove</li>
                                    <li><div style="color: blue"><b>set</b>&nbsp;&larr;</div></li>
                        </ul>
                </td>
                <td>
                        <div><code>add</code> will add the users/groups to the existing right.</div>
                        <div><code>remove</code> will remove the users/groups from the existing right.</div>
                        <div><code>set</code> will replace the users/groups of the existing right.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The name of the User Right as shown by the <code>Constant Name</code> value from <a href='https://technet.microsoft.com/en-us/library/dd349804.aspx'>https://technet.microsoft.com/en-us/library/dd349804.aspx</a>.</div>
                        <div>The module will return an error if the right is invalid.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>users</b>
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
                        <div>A list of users or groups to add/remove on the User Right.</div>
                        <div>These can be in the form DOMAIN\user-group, user-group@DOMAIN.COM for domain users/groups.</div>
                        <div>For local users/groups it can be in the form user-group, .\user-group, SERVERNAME\user-group where SERVERNAME is the name of the remote server.</div>
                        <div>You can also add special local accounts like SYSTEM and others.</div>
                        <div>Can be set to an empty list with <em>action=set</em> to remove all accounts from the right.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - If the server is domain joined this module can change a right but if a GPO governs this right then the changes won't last.


See Also
--------

.. seealso::

   :ref:`ansible.windows.win_group_module`
      The official documentation on the **ansible.windows.win_group** module.
   :ref:`ansible.windows.win_group_membership_module`
      The official documentation on the **ansible.windows.win_group_membership** module.
   :ref:`ansible.windows.win_user_module`
      The official documentation on the **ansible.windows.win_user** module.


Examples
--------

.. code-block:: yaml

    ---
    - name: Replace the entries of Deny log on locally
      ansible.windows.win_user_right:
        name: SeDenyInteractiveLogonRight
        users:
        - Guest
        - Users
        action: set

    - name: Add account to Log on as a service
      ansible.windows.win_user_right:
        name: SeServiceLogonRight
        users:
        - .\Administrator
        - '{{ansible_hostname}}\local-user'
        action: add

    - name: Remove accounts who can create Symbolic links
      ansible.windows.win_user_right:
        name: SeCreateSymbolicLinkPrivilege
        users:
        - SYSTEM
        - Administrators
        - DOMAIN\User
        - group@DOMAIN.COM
        action: remove

    - name: Remove all accounts who cannot log on remote interactively
      ansible.windows.win_user_right:
        name: SeDenyRemoteInteractiveLogonRight
        users: []



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
                    <b>added</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">list</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>A list of accounts that were added to the right, this is empty if no accounts were added.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">[&#x27;NT AUTHORITY\\SYSTEM&#x27;, &#x27;DOMAIN\\User&#x27;]</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>removed</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">list</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>A list of accounts that were removed from the right, this is empty if no accounts were removed.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">[&#x27;SERVERNAME\\Administrator&#x27;, &#x27;BUILTIN\\Administrators&#x27;]</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Jordan Borean (@jborean93)
