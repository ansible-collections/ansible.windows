.. _ansible.windows.win_path_module:


************************
ansible.windows.win_path
************************

**Manage Windows path environment variables**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Allows element-based ordering, addition, and removal of Windows path environment variables.




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
                    <b>elements</b>
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
                        <div>A single path element, or a list of path elements (ie, directories) to add or remove.</div>
                        <div>When multiple elements are included in the list (and <code>state</code> is <code>present</code>), the elements are guaranteed to appear in the same relative order in the resultant path value.</div>
                        <div>Variable expansions (eg, <code>%VARNAME%</code>) are allowed, and are stored unexpanded in the target path element.</div>
                        <div>Any existing path elements not mentioned in <code>elements</code> are always preserved in their current order.</div>
                        <div>New path elements are appended to the path, and existing path elements may be moved closer to the end to satisfy the requested ordering.</div>
                        <div>Paths are compared in a case-insensitive fashion, and trailing backslashes are ignored for comparison purposes. However, note that trailing backslashes in YAML require quotes.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">"PATH"</div>
                </td>
                <td>
                        <div>Target path environment variable name.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>scope</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li><div style="color: blue"><b>machine</b>&nbsp;&larr;</div></li>
                                    <li>user</li>
                        </ul>
                </td>
                <td>
                        <div>The level at which the environment variable specified by <code>name</code> should be managed (either for the current user or global machine scope).</div>
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
                        <div>Whether the path elements specified in <code>elements</code> should be present or absent.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - This module is for modifying individual elements of path-like environment variables. For general-purpose management of other environment vars, use the :ref:`ansible.windows.win_environment <ansible.windows.win_environment_module>` module.
   - This module does not broadcast change events. This means that the minority of windows applications which can have their environment changed without restarting will not be notified and therefore will need restarting to pick up new environment settings.
   - User level environment variables will require an interactive user to log out and in again before they become available.


See Also
--------

.. seealso::

   :ref:`ansible.windows.win_environment_module`
      The official documentation on the **ansible.windows.win_environment** module.


Examples
--------

.. code-block:: yaml

    - name: Ensure that system32 and Powershell are present on the global system path, and in the specified order
      ansible.windows.win_path:
        elements:
        - '%SystemRoot%\system32'
        - '%SystemRoot%\system32\WindowsPowerShell\v1.0'

    - name: Ensure that C:\Program Files\MyJavaThing is not on the current user's CLASSPATH
      ansible.windows.win_path:
        name: CLASSPATH
        elements: C:\Program Files\MyJavaThing
        scope: user
        state: absent




Status
------


Authors
~~~~~~~

- Matt Davis (@nitzmahone)
