.. _ansible.windows.win_wait_for_module:


****************************
ansible.windows.win_wait_for
****************************

**Waits for a condition before continuing**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- You can wait for a set amount of time ``timeout``, this is the default if nothing is specified.
- Waiting for a port to become available is useful for when services are not immediately available after their init scripts return which is true of certain Java application servers.
- You can wait for a file to exist or not exist on the filesystem.
- This module can also be used to wait for a regex match string to be present in a file.
- You can wait for active connections to be closed before continuing on a local port.




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
                    <b>connect_timeout</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">5</div>
                </td>
                <td>
                        <div>The maximum number of seconds to wait for a connection to happen before closing and retrying.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>delay</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The number of seconds to wait before starting to poll.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>exclude_hosts</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">list</span>
                         / <span style="color: purple">elements=string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The list of hosts or IPs to ignore when looking for active TCP connections when <code>state=drained</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>host</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">"127.0.0.1"</div>
                </td>
                <td>
                        <div>A resolvable hostname or IP address to wait for.</div>
                        <div>If <code>state=drained</code> then it will only check for connections on the IP specified, you can use &#x27;0.0.0.0&#x27; to use all host IPs.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The path to a file on the filesystem to check.</div>
                        <div>If <code>state</code> is present or started then it will wait until the file exists.</div>
                        <div>If <code>state</code> is absent then it will wait until the file does not exist.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>port</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The port number to poll on <code>host</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>regex</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Can be used to match a string in a file.</div>
                        <div>If <code>state</code> is present or started then it will wait until the regex matches.</div>
                        <div>If <code>state</code> is absent then it will wait until the regex does not match.</div>
                        <div>Defaults to a multiline regex.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: search_regex, regexp</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>sleep</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">1</div>
                </td>
                <td>
                        <div>Number of seconds to sleep between checks.</div>
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
                                    <li>drained</li>
                                    <li>present</li>
                                    <li><div style="color: blue"><b>started</b>&nbsp;&larr;</div></li>
                                    <li>stopped</li>
                        </ul>
                </td>
                <td>
                        <div>When checking a port, <code>started</code> will ensure the port is open, <code>stopped</code> will check that is it closed and <code>drained</code> will check for active connections.</div>
                        <div>When checking for a file or a search string <code>present</code> or <code>started</code> will ensure that the file or string is present, <code>absent</code> will check that the file or search string is absent or removed.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>timeout</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">300</div>
                </td>
                <td>
                        <div>The maximum number of seconds to wait for.</div>
                </td>
            </tr>
    </table>
    <br/>



See Also
--------

.. seealso::

   :ref:`ansible.builtin.wait_for_module`
      The official documentation on the **ansible.builtin.wait_for** module.
   :ref:`community.windows.win_wait_for_process_module`
      The official documentation on the **community.windows.win_wait_for_process** module.


Examples
--------

.. code-block:: yaml

    - name: Wait 300 seconds for port 8000 to become open on the host, don't start checking for 10 seconds
      ansible.windows.win_wait_for:
        port: 8000
        delay: 10

    - name: Wait 150 seconds for port 8000 of any IP to close active connections
      ansible.windows.win_wait_for:
        host: 0.0.0.0
        port: 8000
        state: drained
        timeout: 150

    - name: Wait for port 8000 of any IP to close active connection, ignoring certain hosts
      ansible.windows.win_wait_for:
        host: 0.0.0.0
        port: 8000
        state: drained
        exclude_hosts: ['10.2.1.2', '10.2.1.3']

    - name: Wait for file C:\temp\log.txt to exist before continuing
      ansible.windows.win_wait_for:
        path: C:\temp\log.txt

    - name: Wait until process complete is in the file before continuing
      ansible.windows.win_wait_for:
        path: C:\temp\log.txt
        regex: process complete

    - name: Wait until file is removed
      ansible.windows.win_wait_for:
        path: C:\temp\log.txt
        state: absent

    - name: Wait until port 1234 is offline but try every 10 seconds
      ansible.windows.win_wait_for:
        port: 1234
        state: absent
        sleep: 10



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
                    <b>elapsed</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">float</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The elapsed seconds between the start of poll and the end of the module. This includes the delay if the option is set.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">2.1406487</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>wait_attempts</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The number of attempts to poll the file or port before module finishes.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">1</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Jordan Borean (@jborean93)
