.. _ansible.windows.win_reboot_module:


**************************
ansible.windows.win_reboot
**************************

**Reboot a windows machine**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Reboot a Windows machine, wait for it to go down, come back up, and respond to commands.
- For non-Windows targets, use the :ref:`ansible.builtin.reboot <ansible.builtin.reboot_module>` module instead.




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
                    <b>boot_time_command</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">"(Get-CimInstance -ClassName Win32_OperatingSystem -Property LastBootUpTime).LastBootUpTime.ToFileTime()"</div>
                </td>
                <td>
                        <div>Command to run that returns a unique string indicating the last time the system was booted.</div>
                        <div>Setting this to a command that has different output each time it is run will cause the task to fail.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>connect_timeout</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">float</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">5</div>
                </td>
                <td>
                        <div>Maximum seconds to wait for a single successful TCP connection to the WinRM endpoint before trying again.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: connect_timeout_sec</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>msg</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">"Reboot initiated by Ansible"</div>
                </td>
                <td>
                        <div>Message to display to users.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>post_reboot_delay</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">float</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">0</div>
                </td>
                <td>
                        <div>Seconds to wait after the reboot command was successful before attempting to validate the system rebooted successfully.</div>
                        <div>This is useful if you want wait for something to settle despite your connection already working.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: post_reboot_delay_sec</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>pre_reboot_delay</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">float</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">2</div>
                </td>
                <td>
                        <div>Seconds to wait before reboot. Passed as a parameter to the reboot command.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: pre_reboot_delay_sec</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>reboot_timeout</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">float</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">600</div>
                </td>
                <td>
                        <div>Maximum seconds to wait for machine to re-appear on the network and respond to a test command.</div>
                        <div>This timeout is evaluated separately for both reboot verification and test command success so maximum clock time is actually twice this value.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: reboot_timeout_sec</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>test_command</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Command to expect success for to determine the machine is ready for management.</div>
                        <div>By default this test command is a custom one to detect when the Windows Logon screen is up and ready to accept credentials. Using a custom command will replace this behaviour and just run the command specified.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - If a shutdown was already scheduled on the system, :ref:`ansible.windows.win_reboot <ansible.windows.win_reboot_module>` will abort the scheduled shutdown and enforce its own shutdown.
   - Beware that when :ref:`ansible.windows.win_reboot <ansible.windows.win_reboot_module>` returns, the Windows system may not have settled yet and some base services could be in limbo. This can result in unexpected behavior. Check the examples for ways to mitigate this. This has been slightly mitigated in the ``1.6.0`` release of ``ansible.windows`` but it is not guranteed to always wait until the logon prompt is shown.
   - The connection user must have the ``SeRemoteShutdownPrivilege`` privilege enabled, see https://docs.microsoft.com/en-us/windows/security/threat-protection/security-policy-settings/force-shutdown-from-a-remote-system for more information.


See Also
--------

.. seealso::

   :ref:`ansible.builtin.reboot_module`
      The official documentation on the **ansible.builtin.reboot** module.


Examples
--------

.. code-block:: yaml

    - name: Reboot the machine with all defaults
      ansible.windows.win_reboot:

    - name: Reboot a slow machine that might have lots of updates to apply
      ansible.windows.win_reboot:
        reboot_timeout: 3600

    # Install a Windows feature and reboot if necessary
    - name: Install IIS Web-Server
      ansible.windows.win_feature:
        name: Web-Server
      register: iis_install

    - name: Reboot when Web-Server feature requires it
      ansible.windows.win_reboot:
      when: iis_install.reboot_required

    # One way to ensure the system is reliable, is to set WinRM to a delayed startup
    - name: Ensure WinRM starts when the system has settled and is ready to work reliably
      ansible.windows.win_service:
        name: WinRM
        start_mode: delayed

    # Additionally, you can add a delay before running the next task
    - name: Reboot a machine that takes time to settle after being booted
      ansible.windows.win_reboot:
        post_reboot_delay: 120

    # Or you can make win_reboot validate exactly what you need to work before running the next task
    - name: Validate that the netlogon service has started, before running the next task
      ansible.windows.win_reboot:
        test_command: 'exit (Get-Service -Name Netlogon).Status -ne "Running"'



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
                            <div>The number of seconds that elapsed waiting for the system to be rebooted.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">23.2</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>rebooted</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>True if the machine was rebooted.</div>
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

- Matt Davis (@nitzmahone)
