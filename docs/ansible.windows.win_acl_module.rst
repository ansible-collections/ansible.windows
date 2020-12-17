.. _ansible.windows.win_acl_module:


***********************
ansible.windows.win_acl
***********************

**Set file/directory/registry permissions for a system user or group**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Add or remove rights/permissions for a given user or group for the specified file, folder, registry key or AppPool identifies.




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
                    <b>inherit</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>ContainerInherit</li>
                                    <li>ObjectInherit</li>
                        </ul>
                </td>
                <td>
                        <div>Inherit flags on the ACL rules.</div>
                        <div>Can be specified as a comma separated list, e.g. <code>ContainerInherit</code>, <code>ObjectInherit</code>.</div>
                        <div>For more information on the choices see MSDN InheritanceFlags enumeration at <a href='https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.inheritanceflags.aspx'>https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.inheritanceflags.aspx</a>.</div>
                        <div>Defaults to <code>ContainerInherit, ObjectInherit</code> for Directories.</div>
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
                        <div>The path to the file or directory.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>propagation</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>InheritOnly</li>
                                    <li><div style="color: blue"><b>None</b>&nbsp;&larr;</div></li>
                                    <li>NoPropagateInherit</li>
                        </ul>
                </td>
                <td>
                        <div>Propagation flag on the ACL rules.</div>
                        <div>For more information on the choices see MSDN PropagationFlags enumeration at <a href='https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.propagationflags.aspx'>https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.propagationflags.aspx</a>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>rights</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The rights/permissions that are to be allowed/denied for the specified user or group for the item at <code>path</code>.</div>
                        <div>If <code>path</code> is a file or directory, rights can be any right under MSDN FileSystemRights <a href='https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemrights.aspx'>https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.filesystemrights.aspx</a>.</div>
                        <div>If <code>path</code> is a registry key, rights can be any right under MSDN RegistryRights <a href='https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.registryrights.aspx'>https://msdn.microsoft.com/en-us/library/system.security.accesscontrol.registryrights.aspx</a>.</div>
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
                        <div>Specify whether to add <code>present</code> or remove <code>absent</code> the specified access rule.</div>
                </td>
            </tr>
            <tr>
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
                                    <li>allow</li>
                                    <li>deny</li>
                        </ul>
                </td>
                <td>
                        <div>Specify whether to allow or deny the rights specified.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>user</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>User or Group to add specified rights to act on src file/folder or registry key.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - If adding ACL's for AppPool identities, the Windows Feature "Web-Scripting-Tools" must be enabled.


See Also
--------

.. seealso::

   :ref:`ansible.windows.win_acl_inheritance_module`
      The official documentation on the **ansible.windows.win_acl_inheritance** module.
   :ref:`ansible.windows.win_file_module`
      The official documentation on the **ansible.windows.win_file** module.
   :ref:`ansible.windows.win_owner_module`
      The official documentation on the **ansible.windows.win_owner** module.
   :ref:`ansible.windows.win_stat_module`
      The official documentation on the **ansible.windows.win_stat** module.


Examples
--------

.. code-block:: yaml

    - name: Restrict write and execute access to User Fed-Phil
      ansible.windows.win_acl:
        user: Fed-Phil
        path: C:\Important\Executable.exe
        type: deny
        rights: ExecuteFile,Write

    - name: Add IIS_IUSRS allow rights
      ansible.windows.win_acl:
        path: C:\inetpub\wwwroot\MySite
        user: IIS_IUSRS
        rights: FullControl
        type: allow
        state: present
        inherit: ContainerInherit, ObjectInherit
        propagation: 'None'

    - name: Set registry key right
      ansible.windows.win_acl:
        path: HKCU:\Bovine\Key
        user: BUILTIN\Users
        rights: EnumerateSubKeys
        type: allow
        state: present
        inherit: ContainerInherit, ObjectInherit
        propagation: 'None'

    - name: Remove FullControl AccessRule for IIS_IUSRS
      ansible.windows.win_acl:
        path: C:\inetpub\wwwroot\MySite
        user: IIS_IUSRS
        rights: FullControl
        type: allow
        state: absent
        inherit: ContainerInherit, ObjectInherit
        propagation: 'None'

    - name: Deny Intern
      ansible.windows.win_acl:
        path: C:\Administrator\Documents
        user: Intern
        rights: Read,Write,Modify,FullControl,Delete
        type: deny
        state: present




Status
------


Authors
~~~~~~~

- Phil Schwartz (@schwartzmx)
- Trond Hindenes (@trondhindenes)
- Hans-Joachim Kliemeck (@h0nIg)
