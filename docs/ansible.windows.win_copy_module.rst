.. _ansible.windows.win_copy_module:


************************
ansible.windows.win_copy
************************

**Copies files to remote locations on windows hosts**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- The ``win_copy`` module copies a file on the local box to remote windows locations.
- For non-Windows targets, use the :ref:`ansible.builtin.copy <ansible.builtin.copy_module>` module instead.




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
                    <b>backup</b>
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
                        <div>Determine whether a backup should be created.</div>
                        <div>When set to <code>yes</code>, create a backup file including the timestamp information so you can get the original file back if you somehow clobbered it incorrectly.</div>
                        <div>No backup is taken when <code>remote_src=False</code> and multiple files are being copied.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>content</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>When used instead of <code>src</code>, sets the contents of a file directly to the specified value.</div>
                        <div>This is for simple values, for anything complex or with formatting please switch to the <span class='module'>ansible.windows.win_template</span> module.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>decrypt</b>
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
                        <div>This option controls the autodecryption of source files using vault.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>dest</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Remote absolute path where the file should be copied to.</div>
                        <div>If <code>src</code> is a directory, this must be a directory too.</div>
                        <div>Use \ for path separators or \\ when in &quot;double quotes&quot;.</div>
                        <div>If <code>dest</code> ends with \ then source or the contents of source will be copied to the directory without renaming.</div>
                        <div>If <code>dest</code> is a nonexistent path, it will only be created if <code>dest</code> ends with &quot;/&quot; or &quot;\&quot;, or <code>src</code> is a directory.</div>
                        <div>If <code>src</code> and <code>dest</code> are files and if the parent directory of <code>dest</code> doesn&#x27;t exist, then the task will fail.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>force</b>
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
                        <div>If set to <code>yes</code>, the file will only be transferred if the content is different than destination.</div>
                        <div>If set to <code>no</code>, the file will only be transferred if the destination does not exist.</div>
                        <div>If set to <code>no</code>, no checksuming of the content is performed which can help improve performance on larger files.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>local_follow</b>
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
                        <div>This flag indicates that filesystem links in the source tree, if they exist, should be followed.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>remote_src</b>
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
                        <div>If <code>no</code>, it will search for src at originating/controller machine.</div>
                        <div>If <code>yes</code>, it will go to the remote/target machine for the src.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>src</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Local path to a file to copy to the remote server; can be absolute or relative.</div>
                        <div>If path is a directory, it is copied (including the source folder name) recursively to <code>dest</code>.</div>
                        <div>If path is a directory and ends with &quot;/&quot;, only the inside contents of that directory are copied to the destination. Otherwise, if it does not end with &quot;/&quot;, the directory itself with all contents is copied.</div>
                        <div>If path is a file and dest ends with &quot;\&quot;, the file is copied to the folder with the same filename.</div>
                        <div>Required unless using <code>content</code>.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - Currently win_copy does not support copying symbolic links from both local to remote and remote to remote.
   - It is recommended that backslashes ``\`` are used instead of ``/`` when dealing with remote paths.
   - Because win_copy runs over WinRM, it is not a very efficient transfer mechanism. If sending large files consider hosting them on a web service and using :ref:`ansible.windows.win_get_url <ansible.windows.win_get_url_module>` instead.


See Also
--------

.. seealso::

   :ref:`community.general.assemble_module`
      The official documentation on the **community.general.assemble** module.
   :ref:`ansible.builtin.copy_module`
      The official documentation on the **ansible.builtin.copy** module.
   :ref:`ansible.windows.win_get_url_module`
      The official documentation on the **ansible.windows.win_get_url** module.
   :ref:`community.windows.win_robocopy_module`
      The official documentation on the **community.windows.win_robocopy** module.


Examples
--------

.. code-block:: yaml

    - name: Copy a single file
      ansible.windows.win_copy:
        src: /srv/myfiles/foo.conf
        dest: C:\Temp\renamed-foo.conf

    - name: Copy a single file, but keep a backup
      ansible.windows.win_copy:
        src: /srv/myfiles/foo.conf
        dest: C:\Temp\renamed-foo.conf
        backup: yes

    - name: Copy a single file keeping the filename
      ansible.windows.win_copy:
        src: /src/myfiles/foo.conf
        dest: C:\Temp\

    - name: Copy folder to C:\Temp (results in C:\Temp\temp_files)
      ansible.windows.win_copy:
        src: files/temp_files
        dest: C:\Temp

    - name: Copy folder contents recursively
      ansible.windows.win_copy:
        src: files/temp_files/
        dest: C:\Temp

    - name: Copy a single file where the source is on the remote host
      ansible.windows.win_copy:
        src: C:\Temp\foo.txt
        dest: C:\ansible\foo.txt
        remote_src: yes

    - name: Copy a folder recursively where the source is on the remote host
      ansible.windows.win_copy:
        src: C:\Temp
        dest: C:\ansible
        remote_src: yes

    - name: Set the contents of a file
      ansible.windows.win_copy:
        content: abc123
        dest: C:\Temp\foo.txt

    - name: Copy a single file as another user
      ansible.windows.win_copy:
        src: NuGet.config
        dest: '%AppData%\NuGet\NuGet.config'
      vars:
        ansible_become_user: user
        ansible_become_password: pass
        # The tmp dir must be set when using win_copy as another user
        # This ensures the become user will have permissions for the operation
        # Make sure to specify a folder both the ansible_user and the become_user have access to (i.e not %TEMP% which is user specific and requires Admin)
        ansible_remote_tmp: 'c:\tmp'



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
                    <b>backup_file</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>if backup=yes</td>
                <td>
                            <div>Name of the backup file that was created.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">C:\Path\To\File.txt.11540.20150212-220915.bak</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>checksum</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success, src is a file</td>
                <td>
                            <div>SHA1 checksum of the file after running copy.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">6e642bb8dd5c2e027bf21dd923337cbb4214f827</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>dest</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>changed</td>
                <td>
                            <div>Destination file/path.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">C:\Temp\</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>operation</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>Whether a single file copy took place or a folder copy.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">file_copy</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>original_basename</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>changed, src is a file</td>
                <td>
                            <div>Basename of the copied file.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">foo.txt</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>size</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>changed, src is a file</td>
                <td>
                            <div>Size of the target, after execution.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">1220</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>src</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>changed</td>
                <td>
                            <div>Source file used for the copy on the target machine.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">/home/httpd/.ansible/tmp/ansible-tmp-1423796390.97-147729857856000/source</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Jon Hawkesworth (@jhawkesworth)
- Jordan Borean (@jborean93)
