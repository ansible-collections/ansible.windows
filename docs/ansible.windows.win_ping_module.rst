.. _ansible.windows.win_ping_module:


************************
ansible.windows.win_ping
************************

**A windows version of the classic ping module**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Checks management connectivity of a windows host.
- This is NOT ICMP ping, this is just a trivial test module.
- For non-Windows targets, use the :ref:`ansible.builtin.ping <ansible.builtin.ping_module>` module instead.




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
                    <b>data</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">"pong"</div>
                </td>
                <td>
                        <div>Alternate data to return instead of &#x27;pong&#x27;.</div>
                        <div>If this parameter is set to <code>crash</code>, the module will cause an exception.</div>
                </td>
            </tr>
    </table>
    <br/>



See Also
--------

.. seealso::

   :ref:`ansible.builtin.ping_module`
      The official documentation on the **ansible.builtin.ping** module.


Examples
--------

.. code-block:: yaml

    # Test connectivity to a windows host
    # ansible winserver -m ansible.windows.win_ping

    - name: Example from an Ansible Playbook
      ansible.windows.win_ping:

    - name: Induce an exception to see what happens
      ansible.windows.win_ping:
        data: crash



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
                    <b>ping</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>Value provided with the data parameter.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">pong</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Chris Church (@cchurch)
