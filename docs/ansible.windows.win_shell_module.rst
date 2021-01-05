.. _ansible.windows.win_shell_module:


*************************
ansible.windows.win_shell
*************************

**Execute shell commands on target hosts**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- The :ref:`ansible.windows.win_shell <ansible.windows.win_shell_module>` module takes the command name followed by a list of space-delimited arguments. It is similar to the :ref:`ansible.windows.win_command <ansible.windows.win_command_module>` module, but runs the command via a shell (defaults to PowerShell) on the target host.
- For non-Windows targets, use the :ref:`ansible.builtin.shell <ansible.builtin.shell_module>` module instead.




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
                    <b>chdir</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Set the specified path as the current working directory before executing a command</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>creates</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>A path or path filter pattern; when the referenced path exists on the target host, the task will be skipped.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>executable</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Change the shell used to execute the command (eg, <code>cmd</code>).</div>
                        <div>The target shell must accept a <code>/c</code> parameter followed by the raw command line to be executed.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>free_form</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The <span class='module'>ansible.windows.win_shell</span> module takes a free form command to run.</div>
                        <div>There is no parameter actually named &#x27;free form&#x27;. See the examples!</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>no_profile</b>
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
                        <div>Do not load the user profile before running a command. This is only valid when using PowerShell as the executable.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>output_encoding_override</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>This option overrides the encoding of stdout/stderr output.</div>
                        <div>You can use this option when you need to run a command which ignore the console&#x27;s codepage.</div>
                        <div>You should only need to use this option in very rare circumstances.</div>
                        <div>This value can be any valid encoding <code>Name</code> based on the output of <code>[System.Text.Encoding]::GetEncodings(</code>). See <a href='https://docs.microsoft.com/dotnet/api/system.text.encoding.getencodings'>https://docs.microsoft.com/dotnet/api/system.text.encoding.getencodings</a>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>removes</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>A path or path filter pattern; when the referenced path <b>does not</b> exist on the target host, the task will be skipped.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>stdin</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Set the stdin of the command directly to the specified value.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - If you want to run an executable securely and predictably, it may be better to use the :ref:`ansible.windows.win_command <ansible.windows.win_command_module>` module instead. Best practices when writing playbooks will follow the trend of using :ref:`ansible.windows.win_command <ansible.windows.win_command_module>` unless ``win_shell`` is explicitly required. When running ad-hoc commands, use your best judgement.
   - WinRM will not return from a command execution until all child processes created have exited. Thus, it is not possible to use :ref:`ansible.windows.win_shell <ansible.windows.win_shell_module>` to spawn long-running child or background processes. Consider creating a Windows service for managing background processes.


See Also
--------

.. seealso::

   :ref:`community.windows.psexec_module`
      The official documentation on the **community.windows.psexec** module.
   :ref:`ansible.builtin.raw_module`
      The official documentation on the **ansible.builtin.raw** module.
   :ref:`ansible.builtin.script_module`
      The official documentation on the **ansible.builtin.script** module.
   :ref:`ansible.builtin.shell_module`
      The official documentation on the **ansible.builtin.shell** module.
   :ref:`ansible.windows.win_command_module`
      The official documentation on the **ansible.windows.win_command** module.
   :ref:`community.windows.win_psexec_module`
      The official documentation on the **community.windows.win_psexec** module.


Examples
--------

.. code-block:: yaml

    - name: Execute a command in the remote shell, stdout goes to the specified file on the remote
      ansible.windows.win_shell: C:\somescript.ps1 >> C:\somelog.txt

    - name: Change the working directory to somedir/ before executing the command
      ansible.windows.win_shell: C:\somescript.ps1 >> C:\somelog.txt
      args:
        chdir: C:\somedir

    - name: Run a command with an idempotent check on what it creates, will only run when somedir/somelog.txt does not exist
      ansible.windows.win_shell: C:\somescript.ps1 >> C:\somelog.txt
      args:
        chdir: C:\somedir
        creates: C:\somelog.txt

    - name: Run a command under a non-Powershell interpreter (cmd in this case)
      ansible.windows.win_shell: echo %HOMEDIR%
      args:
        executable: cmd
      register: homedir_out

    - name: Run multi-lined shell commands
      ansible.windows.win_shell: |
        $value = Test-Path -Path C:\temp
        if ($value) {
            Remove-Item -Path C:\temp -Force
        }
        New-Item -Path C:\temp -ItemType Directory

    - name: Retrieve the input based on stdin
      ansible.windows.win_shell: '$string = [Console]::In.ReadToEnd(); Write-Output $string.Trim()'
      args:
        stdin: Input message



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
                    <b>cmd</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The command executed by the task.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">rabbitmqctl join_cluster rabbit@main</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>delta</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The command execution delta time.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">0:00:00.325771</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>end</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The command execution end time.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">2016-02-25 09:18:26.755339</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>msg</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>Changed.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">True</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>rc</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The command return code (0 means success).</div>
                    <br/>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>start</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The command execution start time.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">2016-02-25 09:18:26.429568</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>stderr</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The command standard error.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">ls: cannot access foo: No such file or directory</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>stdout</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The command standard output.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">Clustering node rabbit@slave1 with rabbit@main ...</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>stdout_lines</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">list</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The command standard output split in lines.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">[&quot;u&#x27;Clustering node rabbit@slave1 with rabbit@main ...&#x27;&quot;]</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Matt Davis (@nitzmahone)
