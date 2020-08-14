.. _ansible.windows.win_environment_module:


*******************************
ansible.windows.win_environment
*******************************

**Modify environment variables on windows hosts**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Uses .net Environment to set or remove environment variables and can set at User, Machine or Process level.
- User level environment variables will be set, but not available until the user has logged off and on again.




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
                    <b>level</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                                                 / <span style="color: red">required</span>                    </div>
                                    </td>
                                <td>
                                                                                                                            <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                                                                                                                                                <li>machine</li>
                                                                                                                                                                                                <li>process</li>
                                                                                                                                                                                                <li>user</li>
                                                                                    </ul>
                                                                            </td>
                                                                <td>
                                            <div>The level at which to set the environment variable.</div>
                                            <div>Use <code>machine</code> to set for all users.</div>
                                            <div>Use <code>user</code> to set for the current user that ansible is connected as.</div>
                                            <div>Use <code>process</code> to set for the current process.  Probably not that useful.</div>
                                                        </td>
            </tr>
                                <tr>
                                                                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                                                 / <span style="color: red">required</span>                    </div>
                                    </td>
                                <td>
                                                                                                                                                            </td>
                                                                <td>
                                            <div>The name of the environment variable.</div>
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
                                            <div>Set to <code>present</code> to ensure environment variable is set.</div>
                                            <div>Set to <code>absent</code> to ensure it is removed.</div>
                                                        </td>
            </tr>
                                <tr>
                                                                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>value</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                                                                    </div>
                                    </td>
                                <td>
                                                                                                                                                            </td>
                                                                <td>
                                            <div>The value to store in the environment variable.</div>
                                            <div>Must be set when <code>state=present</code> and cannot be an empty string.</div>
                                            <div>Can be omitted for <code>state=absent</code>.</div>
                                                        </td>
            </tr>
                        </table>
    <br/>


Notes
-----

.. note::
   - This module is best-suited for setting the entire value of an environment variable. For safe element-based management of path-like environment vars, use the :ref:`ansible.windows.win_path <ansible.windows.win_path_module>` module.
   - This module does not broadcast change events. This means that the minority of windows applications which can have their environment changed without restarting will not be notified and therefore will need restarting to pick up new environment settings. User level environment variables will require the user to log out and in again before they become available.


See Also
--------

.. seealso::

   :ref:`ansible.windows.win_path_module`
      The official documentation on the **ansible.windows.win_path** module.


Examples
--------

.. code-block:: yaml+jinja

    - name: Set an environment variable for all users
      ansible.windows.win_environment:
        state: present
        name: TestVariable
        value: Test value
        level: machine

    - name: Remove an environment variable for the current user
      ansible.windows.win_environment:
        state: absent
        name: TestVariable
        level: user



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
                    <b>before_value</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                                          </div>
                                    </td>
                <td>always</td>
                <td>
                                                                        <div>the value of the environment key before a change, this is null if it didn&#x27;t exist</div>
                                                                <br/>
                                            <div style="font-size: smaller"><b>Sample:</b></div>
                                                <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">C:\Windows\System32</div>
                                    </td>
            </tr>
                                <tr>
                                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>value</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                                          </div>
                                    </td>
                <td>always</td>
                <td>
                                                                        <div>the value the environment key has been set to, this is null if removed</div>
                                                                <br/>
                                            <div style="font-size: smaller"><b>Sample:</b></div>
                                                <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">C:\Program Files\jdk1.8</div>
                                    </td>
            </tr>
                        </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Jon Hawkesworth (@jhawkesworth)
