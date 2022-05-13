.. _ansible.windows.win_group_membership_module:


************************************
ansible.windows.win_group_membership
************************************

**Manage Windows local group membership**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Allows the addition and removal of local, service and domain users, and domain groups from a local group.




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
                    <b>members</b>
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
                        <div>A list of members to ensure are present/absent from the group.</div>
                        <div>Accepts local users as .\username, and SERVERNAME\username.</div>
                        <div>Accepts domain users and groups as DOMAIN\username and username@DOMAIN.</div>
                        <div>Accepts service users as NT AUTHORITY\username.</div>
                        <div>Accepts all local, domain and service user types as username, favoring domain lookups when in a domain.</div>
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
                        <div>Name of the local group to manage membership on.</div>
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
                                    <li>pure</li>
                        </ul>
                </td>
                <td>
                        <div>Desired state of the members in the group.</div>
                        <div>When <code>state</code> is <code>pure</code>, only the members specified will exist, and all other existing members not specified are removed.</div>
                </td>
            </tr>
    </table>
    <br/>



See Also
--------

.. seealso::

   :ref:`community.windows.win_domain_group_module`
      The official documentation on the **community.windows.win_domain_group** module.
   :ref:`ansible.windows.win_domain_membership_module`
      The official documentation on the **ansible.windows.win_domain_membership** module.
   :ref:`ansible.windows.win_group_module`
      The official documentation on the **ansible.windows.win_group** module.


Examples
--------

.. code-block:: yaml

    - name: Add a local and domain user to a local group
      ansible.windows.win_group_membership:
        name: Remote Desktop Users
        members:
          - NewLocalAdmin
          - DOMAIN\TestUser
        state: present

    - name: Remove a domain group and service user from a local group
      ansible.windows.win_group_membership:
        name: Backup Operators
        members:
          - DOMAIN\TestGroup
          - NT AUTHORITY\SYSTEM
        state: absent

    - name: Ensure only a domain user exists in a local group
      ansible.windows.win_group_membership:
        name: Remote Desktop Users
        members:
          - DOMAIN\TestUser
        state: pure



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
                <td>success and <code>state</code> is <code>present</code></td>
                <td>
                            <div>A list of members added when <code>state</code> is <code>present</code> or <code>pure</code>; this is empty if no members are added.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">[&#x27;SERVERNAME\\NewLocalAdmin&#x27;, &#x27;DOMAIN\\TestUser&#x27;]</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>members</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">list</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>A list of all local group members at completion; this is empty if the group contains no members.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">[&#x27;DOMAIN\\TestUser&#x27;, &#x27;SERVERNAME\\NewLocalAdmin&#x27;]</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>name</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The name of the target local group.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">Administrators</div>
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
                <td>success and <code>state</code> is <code>absent</code></td>
                <td>
                            <div>A list of members removed when <code>state</code> is <code>absent</code> or <code>pure</code>; this is empty if no members are removed.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">[&#x27;DOMAIN\\TestGroup&#x27;, &#x27;NT AUTHORITY\\SYSTEM&#x27;]</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Andrew Saraceni (@andrewsaraceni)
