.. _ansible.windows.win_service_module:


***************************
ansible.windows.win_service
***************************

**Manage and query Windows services**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Manage and query Windows services.
- For non-Windows targets, use the :ref:`ansible.builtin.service <ansible.builtin.service_module>` module instead.




Parameters
----------

.. raw:: html

    <table  border=0 cellpadding=0 class="documentation-table">
        <tr>
            <th colspan="2">Parameter</th>
            <th>Choices/<font color="blue">Defaults</font></th>
            <th width="100%">Comments</th>
        </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>dependencies</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">list</span>
                         / <span style="color: purple">elements=string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>A list of service dependencies to set for this particular service.</div>
                        <div>This should be a list of service names and not the display name of the service.</div>
                        <div>This works by <code>dependency_action</code> to either add/remove or set the services in this list.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>dependency_action</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>add</li>
                                    <li>remove</li>
                                    <li><div style="color: blue"><b>set</b>&nbsp;&larr;</div></li>
                        </ul>
                </td>
                <td>
                        <div>Used in conjunction with <code>dependency</code> to either add the dependencies to the existing service dependencies.</div>
                        <div>Remove the dependencies to the existing dependencies.</div>
                        <div>Set the dependencies to only the values in the list replacing the existing dependencies.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>description</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The description to set for the service.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>desktop_interact</b>
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
                        <div>Whether to allow the service user to interact with the desktop.</div>
                        <div>This can only be set to <code>yes</code> when using the <code>LocalSystem</code> username.</div>
                        <div>This can only be set to <code>yes</code> when the <em>service_type</em> is <code>win32_own_process</code> or <code>win32_share_process</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>display_name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The display name to set for the service.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>error_control</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>critical</li>
                                    <li>ignore</li>
                                    <li>normal</li>
                                    <li>severe</li>
                        </ul>
                </td>
                <td>
                        <div>The severity of the error and action token if the service fails to start.</div>
                        <div>A new service defaults to <code>normal</code>.</div>
                        <div><code>critical</code> will log the error and restart the system with the last-known good configuration. If the startup fails on reboot then the system will fail to operate.</div>
                        <div><code>ignore</code> ignores the error.</div>
                        <div><code>normal</code> logs the error in the event log but continues.</div>
                        <div><code>severe</code> is like <code>critical</code> but a failure on the last-known good configuration reboot startup will be ignored.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>failure_actions</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">list</span>
                         / <span style="color: purple">elements=dictionary</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>A list of failure actions the service controller should take on each failure of a service.</div>
                        <div>The service manager will run the actions from first to last defined until the service starts. If <em>failure_reset_period_sec</em> has been exceeded then the failure actions will restart from the beginning.</div>
                        <div>If all actions have been performed the the service manager will repeat the last service defined.</div>
                        <div>The existing actions will be replaced with the list defined in the task if there is a mismatch with any of them.</div>
                        <div>Set to an empty list to delete all failure actions on a service otherwise an omitted or null value preserves the existing actions on the service.</div>
                </td>
            </tr>
                                <tr>
                    <td class="elbow-placeholder"></td>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>delay_ms</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">raw</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">0</div>
                </td>
                <td>
                        <div>The time to wait, in milliseconds, before performing the specified action.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: delay</div>
                </td>
            </tr>
            <tr>
                    <td class="elbow-placeholder"></td>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>type</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>none</li>
                                    <li>reboot</li>
                                    <li>restart</li>
                                    <li>run_command</li>
                        </ul>
                </td>
                <td>
                        <div>The action to be performed.</div>
                        <div><code>none</code> will perform no action, when used this should only be set as the last action.</div>
                        <div><code>reboot</code> will reboot the host, when used this should only be set as the last action as the reboot will reset the action list back to the beginning.</div>
                        <div><code>restart</code> will restart the service.</div>
                        <div><code>run_command</code> will run the command specified by <em>failure_command</em>.</div>
                </td>
            </tr>

            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>failure_actions_on_non_crash_failure</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>no</li>
                                    <li>yes</li>
                        </ul>
                </td>
                <td>
                        <div>Controls whether failure actions will be performed on non crash failures or not.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>failure_command</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The command to run for a <code>run_command</code> failure action.</div>
                        <div>Set to an empty string to remove the command.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>failure_reboot_msg</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The message to be broadcast to users logged on the host for a <code>reboot</code> failure action.</div>
                        <div>Set to an empty string to remove the message.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>failure_reset_period_sec</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">raw</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The time in seconds after which the failure action list begings from the start if there are no failures.</div>
                        <div>To set this value, <em>failure_actions</em> must have at least 1 action present.</div>
                        <div>Specify <code>&#x27;0xFFFFFFFF&#x27;</code> to set an infinite reset period.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: failure_reset_period</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>force_dependent_services</b>
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
                        <div>If <code>yes</code>, stopping or restarting a service with dependent services will force the dependent services to stop or restart also.</div>
                        <div>If <code>no</code>, stopping or restarting a service with dependent services may fail.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>load_order_group</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The name of the load ordering group of which this service is a member.</div>
                        <div>Specify an empty string to remove the existing load order group of a service.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Name of the service.</div>
                        <div>If only the name parameter is specified, the module will report on whether the service exists or not without making any changes.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>password</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The password to set the service to start as.</div>
                        <div>This and the <code>username</code> argument should be supplied together when using a local or domain account.</div>
                        <div>If omitted then the password will continue to use the existing value password set.</div>
                        <div>If specifying <code>LocalSystem</code>, <code>NetworkService</code>, <code>LocalService</code>, the <code>NT SERVICE</code>, or a gMSA this field can be omitted as those accounts have no password.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The path to the executable to set for the service.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>pre_shutdown_timeout_ms</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">raw</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The time in which the service manager waits after sending a preshutdown notification to the service until it proceeds to continue with the other shutdown actions.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: pre_shutdown_timeout</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>required_privileges</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">list</span>
                         / <span style="color: purple">elements=string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>A list of privileges the service must have when starting up.</div>
                        <div>When set the service will only have the privileges specified on its access token.</div>
                        <div>The <em>username</em> of the service must already have the privileges assigned.</div>
                        <div>The existing privileges will be replace with the list defined in the task if there is a mismatch with any of them.</div>
                        <div>Set to an empty list to remove all required privileges, otherwise an omitted or null value will keep the existing privileges.</div>
                        <div>See <a href='https://docs.microsoft.com/en-us/windows/win32/secauthz/privilege-constants'>privilege text constants</a> for a list of privilege constants that can be used.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>service_type</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>user_own_process</li>
                                    <li>user_share_process</li>
                                    <li>win32_own_process</li>
                                    <li>win32_share_process</li>
                        </ul>
                </td>
                <td>
                        <div>The type of service.</div>
                        <div>The default type of a new service is <code>win32_own_process</code>.</div>
                        <div><em>desktop_interact</em> can only be set if the service type is <code>win32_own_process</code> or <code>win32_share_process</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>sid_info</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>none</li>
                                    <li>restricted</li>
                                    <li>unrestricted</li>
                        </ul>
                </td>
                <td>
                        <div>Used to define the behaviour of the service&#x27;s access token groups.</div>
                        <div><code>none</code> will not add any groups to the token.</div>
                        <div><code>restricted</code> will add the <code>NT SERVICE\&lt;service name&gt;</code> SID to the access token&#x27;s groups and restricted groups.</div>
                        <div><code>unrestricted</code> will add the <code>NT SERVICE\&lt;service name&gt;</code> SID to the access token&#x27;s groups.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>start_mode</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>auto</li>
                                    <li>delayed</li>
                                    <li>disabled</li>
                                    <li>manual</li>
                        </ul>
                </td>
                <td>
                        <div>Set the startup type for the service.</div>
                        <div>A newly created service will default to <code>auto</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
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
                                    <li>paused</li>
                                    <li>started</li>
                                    <li>stopped</li>
                                    <li>restarted</li>
                        </ul>
                </td>
                <td>
                        <div>The desired state of the service.</div>
                        <div><code>started</code>/<code>stopped</code>/<code>absent</code>/<code>paused</code> are idempotent actions that will not run commands unless necessary.</div>
                        <div><code>restarted</code> will always bounce the service.</div>
                        <div>Only services that support the paused state can be paused, you can check the return value <code>can_pause_and_continue</code>.</div>
                        <div>You can only pause a service that is already started.</div>
                        <div>A newly created service will default to <code>stopped</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>update_password</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>always</li>
                                    <li>on_create</li>
                        </ul>
                </td>
                <td>
                        <div>When set to <code>always</code> and <em>password</em> is set, the module will always report a change and set the password.</div>
                        <div>Set to <code>on_create</code> to only set the password if the module needs to create the service.</div>
                        <div>If <em>username</em> was specified and the service changed to that username then <em>password</em> will also be changed if specified.</div>
                        <div>The current default is <code>on_create</code> but this behaviour may change in the future, it is best to be explicit here.</div>
                </td>
            </tr>
            <tr>
                <td colspan="2">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>username</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The username to set the service to start as.</div>
                        <div>Can also be set to <code>LocalSystem</code> or <code>SYSTEM</code> to use the SYSTEM account.</div>
                        <div>A newly created service will default to <code>LocalSystem</code>.</div>
                        <div>If using a custom user account, it must have the <code>SeServiceLogonRight</code> granted to be able to start up. You can use the <span class='module'>ansible.windows.win_user_right</span> module to grant this user right for you.</div>
                        <div>Set to <code>NT SERVICE\service name</code> to run as the NT SERVICE account for that service.</div>
                        <div>This can also be a gMSA in the form <code>DOMAIN\gMSA$</code>.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - This module historically returning information about the service in its return values. These should be avoided in favour of the :ref:`ansible.windows.win_service_info <ansible.windows.win_service_info_module>` module.
   - Most of the options in this module are non-driver services that you can view in SCManager. While you can edit driver services, not all functionality may be available.
   - The user running the module must have the following access rights on the service to be able to use it with this module - ``SERVICE_CHANGE_CONFIG``, ``SERVICE_ENUMERATE_DEPENDENTS``, ``SERVICE_QUERY_CONFIG``, ``SERVICE_QUERY_STATUS``.
   - Changing the state or removing the service will also require futher rights depending on what needs to be done.


See Also
--------

.. seealso::

   :ref:`ansible.builtin.service_module`
      The official documentation on the **ansible.builtin.service** module.
   :ref:`community.windows.win_nssm_module`
      The official documentation on the **community.windows.win_nssm** module.
   :ref:`ansible.windows.win_service_info_module`
      The official documentation on the **ansible.windows.win_service_info** module.
   :ref:`ansible.windows.win_user_right_module`
      The official documentation on the **ansible.windows.win_user_right** module.


Examples
--------

.. code-block:: yaml

    - name: Restart a service
      ansible.windows.win_service:
        name: spooler
        state: restarted

    - name: Set service startup mode to auto and ensure it is started
      ansible.windows.win_service:
        name: spooler
        start_mode: auto
        state: started

    - name: Pause a service
      ansible.windows.win_service:
        name: Netlogon
        state: paused

    - name: Ensure that WinRM is started when the system has settled
      ansible.windows.win_service:
        name: WinRM
        start_mode: delayed

    # A new service will also default to the following values:
    # - username: LocalSystem
    # - state: stopped
    # - start_mode: auto
    - name: Create a new service
      ansible.windows.win_service:
        name: service name
        path: C:\temp\test.exe

    - name: Create a new service with extra details
      ansible.windows.win_service:
        name: service name
        path: C:\temp\test.exe
        display_name: Service Name
        description: A test service description

    - name: Remove a service
      ansible.windows.win_service:
        name: service name
        state: absent

    # This is required to be set for non-service accounts that need to run as a service
    - name: Grant domain account the SeServiceLogonRight user right
      ansible.windows.win_user_right:
        name: SeServiceLogonRight
        users:
        - DOMAIN\User
        action: add

    - name: Set the log on user to a domain account
      ansible.windows.win_service:
        name: service name
        state: restarted
        username: DOMAIN\User
        password: Password

    - name: Set the log on user to a local account
      ansible.windows.win_service:
        name: service name
        state: restarted
        username: .\Administrator
        password: Password

    - name: Set the log on user to Local System
      ansible.windows.win_service:
        name: service name
        state: restarted
        username: SYSTEM

    - name: Set the log on user to Local System and allow it to interact with the desktop
      ansible.windows.win_service:
        name: service name
        state: restarted
        username: SYSTEM
        desktop_interact: yes

    - name: Set the log on user to Network Service
      ansible.windows.win_service:
        name: service name
        state: restarted
        username: NT AUTHORITY\NetworkService

    - name: Set the log on user to Local Service
      ansible.windows.win_service:
        name: service name
        state: restarted
        username: NT AUTHORITY\LocalService

    - name: Set the log on user as the services' virtual account
      ansible.windows.win_service:
        name: service name
        username: NT SERVICE\service name

    - name: Set the log on user as a gMSA
      ansible.windows.win_service:
        name: service name
        username: DOMAIN\gMSA$  # The end $ is important and should be set for all gMSA

    - name: Set dependencies to ones only in the list
      ansible.windows.win_service:
        name: service name
        dependencies: [ service1, service2 ]

    - name: Add dependencies to existing dependencies
      ansible.windows.win_service:
        name: service name
        dependencies: [ service1, service2 ]
        dependency_action: add

    - name: Remove dependencies from existing dependencies
      ansible.windows.win_service:
        name: service name
        dependencies:
        - service1
        - service2
        dependency_action: remove

    - name: Set required privileges for a service
      ansible.windows.win_service:
        name: service name
        username: NT SERVICE\LocalService
        required_privileges:
        - SeBackupPrivilege
        - SeRestorePrivilege

    - name: Remove all required privileges for a service
      ansible.windows.win_service:
        name: service name
        username: NT SERVICE\LocalService
        required_privileges: []

    - name: Set failure actions for a service with no reset period
      ansible.windows.win_service:
        name: service name
        failure_actions:
        - type: restart
        - type: run_command
          delay_ms: 1000
        - type: restart
          delay_ms: 5000
        - type: reboot
        failure_command: C:\Windows\System32\cmd.exe /c mkdir C:\temp
        failure_reboot_msg: Restarting host because service name has failed
        failure_reset_period_sec: '0xFFFFFFFF'

    - name: Set only 1 failure action without a repeat of the last action
      ansible.windows.win_service:
        name: service name
        failure_actions:
        - type: restart
          delay_ms: 5000
        - type: none

    - name: Remove failure action information
      ansible.windows.win_service:
        name: service name
        failure_actions: []
        failure_command: ''  # removes the existing command
        failure_reboot_msg: ''  # removes the existing reboot msg



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
                    <b>can_pause_and_continue</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>success and service exists</td>
                <td>
                            <div>Whether the service can be paused and unpaused.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">True</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>depended_by</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">list</span>
                    </div>
                </td>
                <td>success and service exists</td>
                <td>
                            <div>A list of services that depend on this service.</div>
                    <br/>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>dependencies</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">list</span>
                    </div>
                </td>
                <td>success and service exists</td>
                <td>
                            <div>A list of services that is depended by this service.</div>
                    <br/>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>description</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success and service exists</td>
                <td>
                            <div>The description of the service.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">Manages communication between system components.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>desktop_interact</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>success and service exists</td>
                <td>
                            <div>Whether the current user is allowed to interact with the desktop.</div>
                    <br/>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>display_name</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success and service exists</td>
                <td>
                            <div>The display name of the installed service.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">CoreMessaging</div>
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
                <td>success</td>
                <td>
                            <div>Whether the service exists or not.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">True</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>name</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success and service exists</td>
                <td>
                            <div>The service name or id of the service.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">CoreMessagingRegistrar</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>path</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success and service exists</td>
                <td>
                            <div>The path to the service executable.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">C:\Windows\system32\svchost.exe -k LocalServiceNoNetwork</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>start_mode</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success and service exists</td>
                <td>
                            <div>The startup type of the service.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">manual</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>state</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success and service exists</td>
                <td>
                            <div>The current running status of the service.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">stopped</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>username</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success and service exists</td>
                <td>
                            <div>The username that runs the service.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">LocalSystem</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Chris Hoffman (@chrishoffman)
