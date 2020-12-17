.. _ansible.windows.win_reg_stat_module:


****************************
ansible.windows.win_reg_stat
****************************

**Get information about Windows registry keys**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Like :ref:`ansible.windows.win_file <ansible.windows.win_file_module>`, :ref:`ansible.windows.win_reg_stat <ansible.windows.win_reg_stat_module>` will return whether the key/property exists.
- It also returns the sub keys and properties of the key specified.
- If specifying a property name through *property*, it will return the information specific for that property.




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
                    <b>name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The registry property name to get information for, the return json will not include the sub_keys and properties entries for the <em>key</em> specified.</div>
                        <div>Set to an empty string to target the registry key&#x27;s <code>(Default</code>) property value.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: entry, value, property</div>
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
                        <div>The full registry key path including the hive to search for.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: key</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - The ``properties`` return value will contain an empty string key ``""`` that refers to the key's ``Default`` value. If the value has not been set then this key is not returned.


See Also
--------

.. seealso::

   :ref:`ansible.windows.win_regedit_module`
      The official documentation on the **ansible.windows.win_regedit** module.
   :ref:`ansible.windows.win_regmerge_module`
      The official documentation on the **ansible.windows.win_regmerge** module.


Examples
--------

.. code-block:: yaml

    - name: Obtain information about a registry key using short form
      ansible.windows.win_reg_stat:
        path: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion
      register: current_version

    - name: Obtain information about a registry key property
      ansible.windows.win_reg_stat:
        path: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion
        name: CommonFilesDir
      register: common_files_dir

    - name: Obtain the registry key's (Default) property
      ansible.windows.win_reg_stat:
        path: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion
        name: ''
      register: current_version_default



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
                    <b>changed</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>Whether anything was changed.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">True</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>exists</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>success and path/property exists</td>
                <td>
                            <div>States whether the registry key/property exists.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">True</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>properties</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">dictionary</span>
                    </div>
                </td>
                <td>success, path exists and property not specified</td>
                <td>
                            <div>A dictionary containing all the properties and their values in the registry key.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">{&#x27;&#x27;: {&#x27;raw_value&#x27;: &#x27;&#x27;, &#x27;type&#x27;: &#x27;REG_SZ&#x27;, &#x27;value&#x27;: &#x27;&#x27;}, &#x27;binary_property&#x27;: {&#x27;raw_value&#x27;: [&#x27;0x01&#x27;, &#x27;0x16&#x27;], &#x27;type&#x27;: &#x27;REG_BINARY&#x27;, &#x27;value&#x27;: [1, 22]}, &#x27;multi_string_property&#x27;: {&#x27;raw_value&#x27;: [&#x27;a&#x27;, &#x27;b&#x27;], &#x27;type&#x27;: &#x27;REG_MULTI_SZ&#x27;, &#x27;value&#x27;: [&#x27;a&#x27;, &#x27;b&#x27;]}}</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>raw_value</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success, path/property exists and property specified</td>
                <td>
                            <div>Returns the raw value of the registry property, REG_EXPAND_SZ has no string expansion, REG_BINARY or REG_NONE is in hex 0x format. REG_NONE, this value is a hex string in the 0x format.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">%ProgramDir%\\Common Files</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>sub_keys</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">list</span>
                    </div>
                </td>
                <td>success, path exists and property not specified</td>
                <td>
                            <div>A list of all the sub keys of the key specified.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">[&#x27;AppHost&#x27;, &#x27;Casting&#x27;, &#x27;DateTime&#x27;]</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>type</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success, path/property exists and property specified</td>
                <td>
                            <div>The property type.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">REG_EXPAND_SZ</div>
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
                <td>success, path/property exists and property specified</td>
                <td>
                            <div>The value of the property.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">C:\\Program Files\\Common Files</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Jordan Borean (@jborean93)
