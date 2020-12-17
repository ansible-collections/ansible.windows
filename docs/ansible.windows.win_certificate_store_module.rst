.. _ansible.windows.win_certificate_store_module:


*************************************
ansible.windows.win_certificate_store
*************************************

**Manages the certificate store**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Used to import/export and remove certificates and keys from the local certificate store.
- This module is not used to create certificates and will only manage existing certs as a file or in the store.
- It can be used to import PEM, DER, P7B, PKCS12 (PFX) certificates and export PEM, DER and PKCS12 certificates.




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
                    <b>file_type</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li><div style="color: blue"><b>der</b>&nbsp;&larr;</div></li>
                                    <li>pem</li>
                                    <li>pkcs12</li>
                        </ul>
                </td>
                <td>
                        <div>The file type to export the certificate as when <code>state=exported</code>.</div>
                        <div><code>der</code> is a binary ASN.1 encoded file.</div>
                        <div><code>pem</code> is a base64 encoded file of a der file in the OpenSSL form.</div>
                        <div><code>pkcs12</code> (also known as pfx) is a binary container that contains both the certificate and private key unlike the other options.</div>
                        <div>When <code>pkcs12</code> is set and the private key is not exportable or accessible by the current user, it will throw an exception.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>key_exportable</b>
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
                        <div>Whether to allow the private key to be exported.</div>
                        <div>If <code>no</code>, then this module and other process will only be able to export the certificate and the private key cannot be exported.</div>
                        <div>Used when <code>state=present</code> only.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>key_storage</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li><div style="color: blue"><b>default</b>&nbsp;&larr;</div></li>
                                    <li>machine</li>
                                    <li>user</li>
                        </ul>
                </td>
                <td>
                        <div>Specifies where Windows will store the private key when it is imported.</div>
                        <div>When set to <code>default</code>, the default option as set by Windows is used, typically <code>user</code>.</div>
                        <div>When set to <code>machine</code>, the key is stored in a path accessible by various users.</div>
                        <div>When set to <code>user</code>, the key is stored in a path only accessible by the current user.</div>
                        <div>Used when <code>state=present</code> only and cannot be changed once imported.</div>
                        <div>See <a href='https://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509keystorageflags.aspx'>https://msdn.microsoft.com/en-us/library/system.security.cryptography.x509certificates.x509keystorageflags.aspx</a> for more details.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
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
                        <div>The password of the pkcs12 certificate key.</div>
                        <div>This is used when reading a pkcs12 certificate file or the password to set when <code>state=exported</code> and <code>file_type=pkcs12</code>.</div>
                        <div>If the pkcs12 file has no password set or no password should be set on the exported file, do not set this option.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The path to a certificate file.</div>
                        <div>This is required when <em>state</em> is <code>present</code> or <code>exported</code>.</div>
                        <div>When <em>state</em> is <code>absent</code> and <em>thumbprint</em> is not specified, the thumbprint is derived from the certificate at this path.</div>
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
                                    <li>exported</li>
                                    <li><div style="color: blue"><b>present</b>&nbsp;&larr;</div></li>
                        </ul>
                </td>
                <td>
                        <div>If <code>present</code>, will ensure that the certificate at <em>path</em> is imported into the certificate store specified.</div>
                        <div>If <code>absent</code>, will ensure that the certificate specified by <em>thumbprint</em> or the thumbprint of the cert at <em>path</em> is removed from the store specified.</div>
                        <div>If <code>exported</code>, will ensure the file at <em>path</em> is a certificate specified by <em>thumbprint</em>.</div>
                        <div>When exporting a certificate, if <em>path</em> is a directory then the module will fail, otherwise the file will be replaced if needed.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>store_location</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>CurrentUser</li>
                                    <li><div style="color: blue"><b>LocalMachine</b>&nbsp;&larr;</div></li>
                        </ul>
                </td>
                <td>
                        <div>The store location to use when importing a certificate or searching for a certificate.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>store_name</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>AddressBook</li>
                                    <li>AuthRoot</li>
                                    <li>CertificateAuthority</li>
                                    <li>Disallowed</li>
                                    <li><div style="color: blue"><b>My</b>&nbsp;&larr;</div></li>
                                    <li>Root</li>
                                    <li>TrustedPeople</li>
                                    <li>TrustedPublisher</li>
                        </ul>
                </td>
                <td>
                        <div>The store name to use when importing a certificate or searching for a certificate.</div>
                        <div><code>AddressBook</code>: The X.509 certificate store for other users</div>
                        <div><code>AuthRoot</code>: The X.509 certificate store for third-party certificate authorities (CAs)</div>
                        <div><code>CertificateAuthority</code>: The X.509 certificate store for intermediate certificate authorities (CAs)</div>
                        <div><code>Disallowed</code>: The X.509 certificate store for revoked certificates</div>
                        <div><code>My</code>: The X.509 certificate store for personal certificates</div>
                        <div><code>Root</code>: The X.509 certificate store for trusted root certificate authorities (CAs)</div>
                        <div><code>TrustedPeople</code>: The X.509 certificate store for directly trusted people and resources</div>
                        <div><code>TrustedPublisher</code>: The X.509 certificate store for directly trusted publishers</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>thumbprint</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The thumbprint as a hex string to either export or remove.</div>
                        <div>See the examples for how to specify the thumbprint.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - Some actions on PKCS12 certificates and keys may fail with the error ``the specified network password is not correct``, either use CredSSP or Kerberos with credential delegation, or use ``become`` to bypass these restrictions.
   - The certificates must be located on the Windows host to be set with *path*.
   - When importing a certificate for usage in IIS, it is generally required to use the ``machine`` key_storage option, as both ``default`` and ``user`` will make the private key unreadable to IIS APPPOOL identities and prevent binding the certificate to the https endpoint.



Examples
--------

.. code-block:: yaml

    - name: Import a certificate
      ansible.windows.win_certificate_store:
        path: C:\Temp\cert.pem
        state: present

    - name: Import pfx certificate that is password protected
      ansible.windows.win_certificate_store:
        path: C:\Temp\cert.pfx
        state: present
        password: VeryStrongPasswordHere!
      become: yes
      become_method: runas

    - name: Import pfx certificate without password and set private key as un-exportable
      ansible.windows.win_certificate_store:
        path: C:\Temp\cert.pfx
        state: present
        key_exportable: no
      # usually you don't set this here but it is for illustrative purposes
      vars:
        ansible_winrm_transport: credssp

    - name: Remove a certificate based on file thumbprint
      ansible.windows.win_certificate_store:
        path: C:\Temp\cert.pem
        state: absent

    - name: Remove a certificate based on thumbprint
      ansible.windows.win_certificate_store:
        thumbprint: BD7AF104CF1872BDB518D95C9534EA941665FD27
        state: absent

    - name: Remove certificate based on thumbprint is CurrentUser/TrustedPublishers store
      ansible.windows.win_certificate_store:
        thumbprint: BD7AF104CF1872BDB518D95C9534EA941665FD27
        state: absent
        store_location: CurrentUser
        store_name: TrustedPublisher

    - name: Export certificate as der encoded file
      ansible.windows.win_certificate_store:
        path: C:\Temp\cert.cer
        state: exported
        file_type: der

    - name: Export certificate and key as pfx encoded file
      ansible.windows.win_certificate_store:
        path: C:\Temp\cert.pfx
        state: exported
        file_type: pkcs12
        password: AnotherStrongPass!
      become: yes
      become_method: runas
      become_user: SYSTEM

    - name: Import certificate be used by IIS
      ansible.windows.win_certificate_store:
        path: C:\Temp\cert.pfx
        file_type: pkcs12
        password: StrongPassword!
        store_location: LocalMachine
        key_storage: machine
        state: present
      become: yes
      become_method: runas
      become_user: SYSTEM



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
                    <b>thumbprints</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">list</span>
                    </div>
                </td>
                <td>success</td>
                <td>
                            <div>A list of certificate thumbprints that were touched by the module.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">[&#x27;BC05633694E675449136679A658281F17A191087&#x27;]</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Jordan Borean (@jborean93)
