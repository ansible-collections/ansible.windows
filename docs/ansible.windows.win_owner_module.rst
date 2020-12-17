.. _ansible.windows.win_owner_module:


*************************
ansible.windows.win_owner
*************************

**Set owner**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Set owner of files or directories.




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
                        <div>Path to be used for changing owner.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>recurse</b>
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
                        <div>Indicates if the owner should be changed recursively.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>user</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Name to be used for changing owner.</div>
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

    - name: Change owner of path
      ansible.windows.win_owner:
        path: C:\apache
        user: apache
        recurse: yes

    - name: Set the owner of root directory
      ansible.windows.win_owner:
        path: C:\apache
        user: SYSTEM
        recurse: no




Status
------


Authors
~~~~~~~

- Hans-Joachim Kliemeck (@h0nIg)
