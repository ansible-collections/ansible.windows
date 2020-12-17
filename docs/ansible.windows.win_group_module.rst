.. _ansible.windows.win_group_module:


*************************
ansible.windows.win_group
*************************

**Add and remove local groups**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Add and remove local groups.
- For non-Windows targets, please use the :ref:`ansible.builtin.group <ansible.builtin.group_module>` module instead.




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
                    <b>description</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Description of the group.</div>
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
                        <div>Name of the group.</div>
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
                        <div>Create or remove the group.</div>
                </td>
            </tr>
    </table>
    <br/>



See Also
--------

.. seealso::

   :ref:`ansible.builtin.group_module`
      The official documentation on the **ansible.builtin.group** module.
   :ref:`community.windows.win_domain_group_module`
      The official documentation on the **community.windows.win_domain_group** module.
   :ref:`ansible.windows.win_group_membership_module`
      The official documentation on the **ansible.windows.win_group_membership** module.


Examples
--------

.. code-block:: yaml

    - name: Create a new group
      ansible.windows.win_group:
        name: deploy
        description: Deploy Group
        state: present

    - name: Remove a group
      ansible.windows.win_group:
        name: deploy
        state: absent




Status
------


Authors
~~~~~~~

- Chris Hoffman (@chrishoffman)
