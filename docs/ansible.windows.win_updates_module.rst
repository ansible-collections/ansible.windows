.. _ansible.windows.win_updates_module:


***************************
ansible.windows.win_updates
***************************

**Download and install Windows updates**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Searches, downloads, and installs Windows updates synchronously by automating the Windows Update client.




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
                    <b>blacklist</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">list</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>A list of update titles or KB numbers that can be used to specify which updates are to be excluded from installation.</div>
                        <div>If an available update does match one of the entries, then it is skipped and not installed.</div>
                        <div>Each entry can either be the KB article or Update title as a regex according to the PowerShell regex rules.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>category_names</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">list</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">["CriticalUpdates", "SecurityUpdates", "UpdateRollups"]</div>
                </td>
                <td>
                        <div>A scalar or list of categories to install updates from. To get the list of categories, run the module with <code>state=searched</code>. The category must be the full category string, but is case insensitive.</div>
                        <div>Some possible categories are Application, Connectors, Critical Updates, Definition Updates, Developer Kits, Feature Packs, Guidance, Security Updates, Service Packs, Tools, Update Rollups and Updates.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>log_path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>If set, <code>win_updates</code> will append update progress to the specified file. The directory must already exist.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>reboot</b>
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
                        <div>Ansible will automatically reboot the remote host if it is required and continue to install updates after the reboot.</div>
                        <div>This can be used instead of using a <span class='module'>ansible.windows.win_reboot</span> task after this one and ensures all updates for that category is installed in one go.</div>
                        <div>Async does not work when <code>reboot=yes</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>reboot_timeout</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">-</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">1200</div>
                </td>
                <td>
                        <div>The time in seconds to wait until the host is back online from a reboot.</div>
                        <div>This is only used if <code>reboot=yes</code> and a reboot is required.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>server_selection</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li><div style="color: blue"><b>default</b>&nbsp;&larr;</div></li>
                                    <li>managed_server</li>
                                    <li>windows_update</li>
                        </ul>
                </td>
                <td>
                        <div>Defines the Windows Update source catalog.</div>
                        <div><code>default</code> Use the default search source. For many systems default is set to the Microsoft Windows Update catalog. Systems participating in Windows Server Update Services (WSUS), Systems Center Configuration Manager (SCCM), or similar corporate update server environments may default to those managed update sources instead of the Windows Update catalog.</div>
                        <div><code>managed_server</code> Use a managed server catalog. For environments utilizing Windows Server Update Services (WSUS), Systems Center Configuration Manager (SCCM), or similar corporate update servers, this option selects the defined corporate update source.</div>
                        <div><code>windows_update</code> Use the Microsoft Windows Update catalog.</div>
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
                                    <li><div style="color: blue"><b>installed</b>&nbsp;&larr;</div></li>
                                    <li>searched</li>
                                    <li>downloaded</li>
                        </ul>
                </td>
                <td>
                        <div>Controls whether found updates are downloaded or installed or listed</div>
                        <div>This module also supports Ansible check mode, which has the same effect as setting state=searched</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>use_scheduled_task</b>
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
                        <div>Will not auto elevate the remote process with <em>become</em> and use a scheduled task instead.</div>
                        <div>Set this to <code>yes</code> when using this module with async on Server 2008, 2008 R2, or Windows 7, or on Server 2008 that is not authenticated with basic or credssp.</div>
                        <div>Can also be set to <code>yes</code> on newer hosts where become does not work due to further privilege restrictions from the OS defaults.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>whitelist</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">list</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>A list of update titles or KB numbers that can be used to specify which updates are to be searched or installed.</div>
                        <div>If an available update does not match one of the entries, then it is skipped and not installed.</div>
                        <div>Each entry can either be the KB article or Update title as a regex according to the PowerShell regex rules.</div>
                        <div>The whitelist is only validated on updates that were found based on <em>category_names</em>. It will not force the module to install an update if it was not in the category specified.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - :ref:`ansible.windows.win_updates <ansible.windows.win_updates_module>` must be run by a user with membership in the local Administrators group.
   - :ref:`ansible.windows.win_updates <ansible.windows.win_updates_module>` will use the default update service configured for the machine (Windows Update, Microsoft Update, WSUS, etc).
   - :ref:`ansible.windows.win_updates <ansible.windows.win_updates_module>` will *become* SYSTEM using *runas* unless ``use_scheduled_task`` is ``yes``
   - By default :ref:`ansible.windows.win_updates <ansible.windows.win_updates_module>` does not manage reboots, but will signal when a reboot is required with the *reboot_required* return value. *reboot* can be used to reboot the host if required in the one task.
   - :ref:`ansible.windows.win_updates <ansible.windows.win_updates_module>` can take a significant amount of time to complete (hours, in some cases). Performance depends on many factors, including OS version, number of updates, system load, and update server load.
   - Beware that just after :ref:`ansible.windows.win_updates <ansible.windows.win_updates_module>` reboots the system, the Windows system may not have settled yet and some base services could be in limbo. This can result in unexpected behavior. Check the examples for ways to mitigate this.
   - More information about PowerShell and how it handles RegEx strings can be found at https://technet.microsoft.com/en-us/library/2007.11.powershell.aspx.


See Also
--------

.. seealso::

   :ref:`chocolatey.chocolatey.win_chocolatey_module`
      The official documentation on the **chocolatey.chocolatey.win_chocolatey** module.
   :ref:`ansible.windows.win_feature_module`
      The official documentation on the **ansible.windows.win_feature** module.
   :ref:`community.windows.win_hotfix_module`
      The official documentation on the **community.windows.win_hotfix** module.
   :ref:`ansible.windows.win_package_module`
      The official documentation on the **ansible.windows.win_package** module.


Examples
--------

.. code-block:: yaml

    - name: Install all security, critical, and rollup updates without a scheduled task
      ansible.windows.win_updates:
        category_names:
          - SecurityUpdates
          - CriticalUpdates
          - UpdateRollups

    - name: Install only security updates as a scheduled task for Server 2008
      ansible.windows.win_updates:
        category_names: SecurityUpdates
        use_scheduled_task: yes

    - name: Search-only, return list of found updates (if any), log to C:\ansible_wu.txt
      ansible.windows.win_updates:
        category_names: SecurityUpdates
        state: searched
        log_path: C:\ansible_wu.txt

    - name: Install all security updates with automatic reboots
      ansible.windows.win_updates:
        category_names:
        - SecurityUpdates
        reboot: yes

    - name: Install only particular updates based on the KB numbers
      ansible.windows.win_updates:
        category_name:
        - SecurityUpdates
        whitelist:
        - KB4056892
        - KB4073117

    - name: Exclude updates based on the update title
      ansible.windows.win_updates:
        category_name:
        - SecurityUpdates
        - CriticalUpdates
        blacklist:
        - Windows Malicious Software Removal Tool for Windows
        - \d{4}-\d{2} Cumulative Update for Windows Server 2016

    # One way to ensure the system is reliable just after a reboot, is to set WinRM to a delayed startup
    - name: Ensure WinRM starts when the system has settled and is ready to work reliably
      ansible.windows.win_service:
        name: WinRM
        start_mode: delayed

    # Optionally, you can increase the reboot_timeout to survive long updates during reboot
    - name: Ensure we wait long enough for the updates to be applied during reboot
      ansible.windows.win_updates:
        reboot: yes
        reboot_timeout: 3600

    # Search and download Windows updates
    - name: Search and download Windows updates without installing them
      ansible.windows.win_updates:
        state: downloaded



Return Values
-------------
Common return values are documented `here <https://docs.ansible.com/ansible/latest/reference_appendices/common_return_values.html#common-return-values>`_, the following are the fields unique to this module:

.. raw:: html

    <table border=0 cellpadding=0 class="documentation-table">
        <tr>
            <th colspan="2">Key</th>
            <th>Returned</th>
            <th width="100%">Description</th>
        </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>failed_update_count</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The number of updates that failed to install.</div>
                    <br/>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>filtered_updates</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">complex</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>List of updates that were found but were filtered based on <em>blacklist</em>, <em>whitelist</em> or <em>category_names</em>. The return value is in the same form as <em>updates</em>, along with <em>filtered_reason</em>.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">see the updates return value</div>
                </td>
            </tr>
                                <tr>
                    <td class="elbow-placeholder">&nbsp;</td>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>filtered_reason</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>The reason why this update was filtered.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">skip_hidden</div>
                </td>
            </tr>

            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>found_update_count</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>The number of updates found needing to be applied.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">3</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>installed_update_count</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>The number of updates successfully installed or downloaded.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">2</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>reboot_required</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>True when the target server requires a reboot to complete updates (no further updates can be installed until after a reboot).</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">True</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>updates</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">complex</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>List of updates that were found/installed.</div>
                    <br/>
                </td>
            </tr>
                                <tr>
                    <td class="elbow-placeholder">&nbsp;</td>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>categories</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">list</span>
                       / <span style="color: purple">elements=string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>A list of category strings for this update.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">[&#x27;Critical Updates&#x27;, &#x27;Windows Server 2012 R2&#x27;]</div>
                </td>
            </tr>
            <tr>
                    <td class="elbow-placeholder">&nbsp;</td>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>failure_hresult_code</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>on install failure</td>
                <td>
                            <div>The HRESULT code from a failed update.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">2147942402</div>
                </td>
            </tr>
            <tr>
                    <td class="elbow-placeholder">&nbsp;</td>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>id</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>Internal Windows Update GUID.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">fb95c1c8-de23-4089-ae29-fd3351d55421</div>
                </td>
            </tr>
            <tr>
                    <td class="elbow-placeholder">&nbsp;</td>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>installed</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>Was the update successfully installed.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">True</div>
                </td>
            </tr>
            <tr>
                    <td class="elbow-placeholder">&nbsp;</td>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>kb</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">list</span>
                       / <span style="color: purple">elements=string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>A list of KB article IDs that apply to the update.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">[&#x27;3004365&#x27;]</div>
                </td>
            </tr>
            <tr>
                    <td class="elbow-placeholder">&nbsp;</td>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>title</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>Display name.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">Security Update for Windows Server 2012 R2 (KB3004365)</div>
                </td>
            </tr>

    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Matt Davis (@nitzmahone)
