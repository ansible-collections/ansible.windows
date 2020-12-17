.. _ansible.windows.win_acl_inheritance_module:


***********************************
ansible.windows.win_acl_inheritance
***********************************

**Change ACL inheritance**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Change ACL (Access Control List) inheritance and optionally copy inherited ACE's (Access Control Entry) to dedicated ACE's or vice versa.




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
                    <b>path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Path to be used for changing inheritance</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>reorganize</b>
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
                        <div>For P(state) = <em>absent</em>, indicates if the inherited ACE&#x27;s should be copied from the parent directory. This is necessary (in combination with removal) for a simple ACL instead of using multiple ACE deny entries.</div>
                        <div>For P(state) = <em>present</em>, indicates if the inherited ACE&#x27;s should be deduplicated compared to the parent directory. This removes complexity of the ACL structure.</div>
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
                                    <li><div style="color: blue"><b>absent</b>&nbsp;&larr;</div></li>
                                    <li>present</li>
                        </ul>
                </td>
                <td>
                        <div>Specify whether to enable <em>present</em> or disable <em>absent</em> ACL inheritance.</div>
                </td>
            </tr>
    </table>
    <br/>



See Also
--------

.. seealso::

   :ref:`ansible.windows.win_acl_module`
      The official documentation on the **ansible.windows.win_acl** module.
   :ref:`ansible.windows.win_file_module`
      The official documentation on the **ansible.windows.win_file** module.
   :ref:`ansible.windows.win_stat_module`
      The official documentation on the **ansible.windows.win_stat** module.


Examples
--------

.. code-block:: yaml

    - name: Disable inherited ACE's
      ansible.windows.win_acl_inheritance:
        path: C:\apache
        state: absent

    - name: Disable and copy inherited ACE's
      ansible.windows.win_acl_inheritance:
        path: C:\apache
        state: absent
        reorganize: yes

    - name: Enable and remove dedicated ACE's
      ansible.windows.win_acl_inheritance:
        path: C:\apache
        state: present
        reorganize: yes




Status
------


Authors
~~~~~~~

- Hans-Joachim Kliemeck (@h0nIg)
