.. _ansible.windows.win_file_module:


************************
ansible.windows.win_file
************************

**Creates, touches or removes files or directories**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Creates (empty) files, updates file modification stamps of existing files, and can create or remove directories.
- Unlike :ref:`ansible.builtin.file <ansible.builtin.file_module>`, does not modify ownership, permissions or manipulate links.
- For non-Windows targets, use the :ref:`ansible.builtin.file <ansible.builtin.file_module>` module instead.




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
                        <div>Path to the file being managed.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: dest, name</div>
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
                                    <li>directory</li>
                                    <li>file</li>
                                    <li>touch</li>
                        </ul>
                </td>
                <td>
                        <div>If <code>directory</code>, all immediate subdirectories will be created if they do not exist.</div>
                        <div>If <code>file</code>, the file will NOT be created if it does not exist, see the <span class='module'>ansible.windows.win_copy</span> or <span class='module'>ansible.windows.win_template</span> module if you want that behavior.</div>
                        <div>If <code>absent</code>, directories will be recursively deleted, and files will be removed.</div>
                        <div>If <code>touch</code>, an empty file will be created if the <code>path</code> does not exist, while an existing file or directory will receive updated file access and modification times (similar to the way <code>touch</code> works from the command line).</div>
                </td>
            </tr>
    </table>
    <br/>



See Also
--------

.. seealso::

   :ref:`ansible.builtin.file_module`
      The official documentation on the **ansible.builtin.file** module.
   :ref:`ansible.windows.win_acl_module`
      The official documentation on the **ansible.windows.win_acl** module.
   :ref:`ansible.windows.win_acl_inheritance_module`
      The official documentation on the **ansible.windows.win_acl_inheritance** module.
   :ref:`ansible.windows.win_owner_module`
      The official documentation on the **ansible.windows.win_owner** module.
   :ref:`ansible.windows.win_stat_module`
      The official documentation on the **ansible.windows.win_stat** module.


Examples
--------

.. code-block:: yaml

    - name: Touch a file (creates if not present, updates modification time if present)
      ansible.windows.win_file:
        path: C:\Temp\foo.conf
        state: touch

    - name: Remove a file, if present
      ansible.windows.win_file:
        path: C:\Temp\foo.conf
        state: absent

    - name: Create directory structure
      ansible.windows.win_file:
        path: C:\Temp\folder\subfolder
        state: directory

    - name: Remove directory structure
      ansible.windows.win_file:
        path: C:\Temp
        state: absent




Status
------


Authors
~~~~~~~

- Jon Hawkesworth (@jhawkesworth)
