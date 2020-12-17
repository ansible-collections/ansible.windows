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
                         / <span style="color: red">required</span>
                    </div>
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
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The name of the environment variable. Required when <em>state=absent</em>.</div>
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
                                    <li>present</li>
                        </ul>
                </td>
                <td>
                        <div>Set to <code>present</code> to ensure environment variable is set.</div>
                        <div>Set to <code>absent</code> to ensure it is removed.</div>
                        <div>When using <em>variables</em>, do not set this option.</div>
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
                        <div>Must be set when <em>state=present</em> and cannot be an empty string.</div>
                        <div>Should be omitted for <em>state=absent</em> and <em>variables</em>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>variables</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">dictionary</span>
                    </div>
                    <div style="font-style: italic; font-size: small; color: darkgreen">added in 1.3.0</div>
                </td>
                <td>
                </td>
                <td>
                        <div>A dictionary where multiple environment variables can be defined at once.</div>
                        <div>Not valid when <em>state</em> is set. Variables with a value will be set (<code>present</code>) and variables with an empty value will be unset (<code>absent</code>).</div>
                        <div><em>level</em> applies to all vars defined this way.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - This module is best-suited for setting the entire value of an environment variable. For safe element-based management of path-like environment vars, use the :ref:`ansible.windows.win_path <ansible.windows.win_path_module>` module.
   - This module does not broadcast change events. This means that the minority of windows applications which can have their environment changed without restarting will not be notified and therefore will need restarting to pick up new environment settings. User level environment variables will require the user to log out and in again before they become available.
   - In the return, ``before_value`` and ``value`` will be set to the last values when using *variables*. It's best to use ``values`` in that case if you need to find a specific variable's before and after values.


See Also
--------

.. seealso::

   :ref:`ansible.windows.win_path_module`
      The official documentation on the **ansible.windows.win_path** module.


Examples
--------

.. code-block:: yaml

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

    - name: Set several variables at once
      ansible.windows.win_environment:
        level: machine
        variables:
          TestVariable: Test value
          CUSTOM_APP_VAR: 'Very important value'
          ANOTHER_VAR: '{{ my_ansible_var }}'

    - name: Set and remove multiple variables at once
      ansible.windows.win_environment:
        level: user
        variables:
          TestVariable: Test value
          CUSTOM_APP_VAR: 'Very important value'
          ANOTHER_VAR: '{{ my_ansible_var }}'
          UNWANTED_VAR: ''  # < this will be removed



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
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>values</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">dictionary</span>
                    </div>
    <div style="font-style: italic; font-size: small; color: darkgreen">added in 1.3.0</div></td>
                <td>always</td>
                <td>
                            <div>dictionary of before and after values; each key is a variable name, each value is another dict with <code>before</code>, <code>after</code>, and <code>changed</code> keys</div>
                    <br/>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Jon Hawkesworth (@jhawkesworth)
- Brian Scholer (@briantist)
