.. _ansible.windows.win_regedit_module:


***************************
ansible.windows.win_regedit
***************************

**Add, change, or remove registry keys and values**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Add, modify or remove registry keys and values.
- More information about the windows registry from Wikipedia https://en.wikipedia.org/wiki/Windows_Registry.




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
                        <span style="color: purple">raw</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Value of the registry entry <code>name</code> in <code>path</code>.</div>
                        <div>If not specified then the value for the property will be null for the corresponding <code>type</code>.</div>
                        <div>Binary and None data should be expressed in a yaml byte array or as comma separated hex values.</div>
                        <div>An easy way to generate this is to run <code>regedit.exe</code> and use the <em>export</em> option to save the registry values to a file.</div>
                        <div>In the exported file, binary value will look like <code>hex:be,ef,be,ef</code>, the <code>hex:</code> prefix is optional.</div>
                        <div>DWORD and QWORD values should either be represented as a decimal number or a hex value.</div>
                        <div>Multistring values should be passed in as a list.</div>
                        <div>See the examples for more details on how to format this data.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>delete_key</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>no</li>
                                    <li><div style="color: blue"><b>yes</b>&nbsp;&larr;</div></li>
                        </ul>
                </td>
                <td>
                        <div>When <code>state</code> is &#x27;absent&#x27; then this will delete the entire key.</div>
                        <div>If <code>no</code> then it will only clear out the &#x27;(Default)&#x27; property for that key.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>hive</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>A path to a hive key like C:\Users\Default\NTUSER.DAT to load in the registry.</div>
                        <div>This hive is loaded under the HKLM:\ANSIBLE key which can then be used in <em>name</em> like any other path.</div>
                        <div>This can be used to load the default user profile registry hive or any other hive saved as a file.</div>
                        <div>Using this function requires the user to have the <code>SeRestorePrivilege</code> and <code>SeBackupPrivilege</code> privileges enabled.</div>
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
                        <div>Name of the registry entry in the above <code>path</code> parameters.</div>
                        <div>If not provided, or empty then the &#x27;(Default)&#x27; property for the key will be used.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: entry, value</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Name of the registry path.</div>
                        <div>Should be in one of the following registry hives: HKCC, HKCR, HKCU, HKLM, HKU.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: key</div>
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
                        <div>The state of the registry entry.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>type</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>none</li>
                                    <li>binary</li>
                                    <li>dword</li>
                                    <li>expandstring</li>
                                    <li>multistring</li>
                                    <li><div style="color: blue"><b>string</b>&nbsp;&larr;</div></li>
                                    <li>qword</li>
                        </ul>
                </td>
                <td>
                        <div>The registry value data type.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: datatype</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - Check-mode ``-C/--check`` and diff output ``-D/--diff`` are supported, so that you can test every change against the active configuration before applying changes.
   - Beware that some registry hives (``HKEY_USERS`` in particular) do not allow to create new registry paths in the root folder.


See Also
--------

.. seealso::

   :ref:`ansible.windows.win_reg_stat_module`
      The official documentation on the **ansible.windows.win_reg_stat** module.
   :ref:`ansible.windows.win_regmerge_module`
      The official documentation on the **ansible.windows.win_regmerge** module.


Examples
--------

.. code-block:: yaml

    - name: Create registry path MyCompany
      ansible.windows.win_regedit:
        path: HKCU:\Software\MyCompany

    - name: Add or update registry path MyCompany, with entry 'hello', and containing 'world'
      ansible.windows.win_regedit:
        path: HKCU:\Software\MyCompany
        name: hello
        data: world

    - name: Add or update registry path MyCompany, with dword entry 'hello', and containing 1337 as the decimal value
      ansible.windows.win_regedit:
        path: HKCU:\Software\MyCompany
        name: hello
        data: 1337
        type: dword

    - name: Add or update registry path MyCompany, with dword entry 'hello', and containing 0xff2500ae as the hex value
      ansible.windows.win_regedit:
        path: HKCU:\Software\MyCompany
        name: hello
        data: 0xff2500ae
        type: dword

    - name: Add or update registry path MyCompany, with binary entry 'hello', and containing binary data in hex-string format
      ansible.windows.win_regedit:
        path: HKCU:\Software\MyCompany
        name: hello
        data: hex:be,ef,be,ef,be,ef,be,ef,be,ef
        type: binary

    - name: Add or update registry path MyCompany, with binary entry 'hello', and containing binary data in yaml format
      ansible.windows.win_regedit:
        path: HKCU:\Software\MyCompany
        name: hello
        data: [0xbe,0xef,0xbe,0xef,0xbe,0xef,0xbe,0xef,0xbe,0xef]
        type: binary

    - name: Add or update registry path MyCompany, with expand string entry 'hello'
      ansible.windows.win_regedit:
        path: HKCU:\Software\MyCompany
        name: hello
        data: '%appdata%\local'
        type: expandstring

    - name: Add or update registry path MyCompany, with multi string entry 'hello'
      ansible.windows.win_regedit:
        path: HKCU:\Software\MyCompany
        name: hello
        data: ['hello', 'world']
        type: multistring

    - name: Disable keyboard layout hotkey for all users (changes existing)
      ansible.windows.win_regedit:
        path: HKU:\.DEFAULT\Keyboard Layout\Toggle
        name: Layout Hotkey
        data: 3
        type: dword

    - name: Disable language hotkey for current users (adds new)
      ansible.windows.win_regedit:
        path: HKCU:\Keyboard Layout\Toggle
        name: Language Hotkey
        data: 3
        type: dword

    - name: Remove registry path MyCompany (including all entries it contains)
      ansible.windows.win_regedit:
        path: HKCU:\Software\MyCompany
        state: absent
        delete_key: yes

    - name: Clear the existing (Default) entry at path MyCompany
      ansible.windows.win_regedit:
        path: HKCU:\Software\MyCompany
        state: absent
        delete_key: no

    - name: Remove entry 'hello' from registry path MyCompany
      ansible.windows.win_regedit:
        path: HKCU:\Software\MyCompany
        name: hello
        state: absent

    - name: Change default mouse trailing settings for new users
      ansible.windows.win_regedit:
        path: HKLM:\ANSIBLE\Control Panel\Mouse
        name: MouseTrails
        data: 10
        type: str
        state: present
        hive: C:\Users\Default\NTUSER.dat



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
                    <b>data_changed</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>Whether this invocation changed the data in the registry value.</div>
                    <br/>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>data_type_changed</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>Whether this invocation changed the datatype of the registry value.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">True</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Adam Keech (@smadam813)
- Josh Ludwig (@joshludwig)
- Jordan Borean (@jborean93)
