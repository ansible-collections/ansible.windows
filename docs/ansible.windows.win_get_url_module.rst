.. _ansible.windows.win_get_url_module:


***************************
ansible.windows.win_get_url
***************************

**Downloads file from HTTP, HTTPS, or FTP to node**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Downloads files from HTTP, HTTPS, or FTP to the remote server.
- The remote server *must* have direct access to the remote resource.
- For non-Windows targets, use the :ref:`ansible.builtin.get_url <ansible.builtin.get_url_module>` module instead.




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
                    <b>checksum</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>If a <em>checksum</em> is passed to this parameter, the digest of the destination file will be calculated after it is downloaded to ensure its integrity and verify that the transfer completed successfully.</div>
                        <div>This option cannot be set with <em>checksum_url</em>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>checksum_algorithm</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>md5</li>
                                    <li><div style="color: blue"><b>sha1</b>&nbsp;&larr;</div></li>
                                    <li>sha256</li>
                                    <li>sha384</li>
                                    <li>sha512</li>
                        </ul>
                </td>
                <td>
                        <div>Specifies the hashing algorithm used when calculating the checksum of the remote and destination file.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>checksum_url</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Specifies a URL that contains the checksum values for the resource at <em>url</em>.</div>
                        <div>Like <code>checksum</code>, this is used to verify the integrity of the remote transfer.</div>
                        <div>This option cannot be set with <em>checksum</em>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>client_cert</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The path to the client certificate (.pfx) that is used for X509 authentication. This path can either be the path to the <code>pfx</code> on the filesystem or the PowerShell certificate path <code>Cert:\CurrentUser\My\&lt;thumbprint&gt;</code>.</div>
                        <div>The WinRM connection must be authenticated with <code>CredSSP</code> or <code>become</code> is used on the task if the certificate file is not password protected.</div>
                        <div>Other authentication types can set <em>client_cert_password</em> when the cert is password protected.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>client_cert_password</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The password for <em>client_cert</em> if the cert is password protected.</div>
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
                        <div>The location to save the file at the URL.</div>
                        <div>Be sure to include a filename and extension as appropriate.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>follow_redirects</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li>all</li>
                                    <li>none</li>
                                    <li><div style="color: blue"><b>safe</b>&nbsp;&larr;</div></li>
                        </ul>
                </td>
                <td>
                        <div>Whether or the module should follow redirects.</div>
                        <div><code>all</code> will follow all redirect.</div>
                        <div><code>none</code> will not follow any redirect.</div>
                        <div><code>safe</code> will follow only &quot;safe&quot; redirects, where &quot;safe&quot; means that the client is only doing a <code>GET</code> or <code>HEAD</code> on the URI to which it is being redirected.</div>
                        <div>When following a redirected URL, the <code>Authorization</code> header and any credentials set will be dropped and not redirected.</div>
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
                        <div>If <code>yes</code>, will download the file every time and replace the file if the contents change. If <code>no</code>, will only download the file if it does not exist or the remote file has been modified more recently than the local file.</div>
                        <div>This works by sending an http HEAD request to retrieve last modified time of the requested resource, so for this to work, the remote web server must support HEAD requests.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>force_basic_auth</b>
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
                        <div>By default the authentication header is only sent when a webservice responses to an initial request with a 401 status. Since some basic auth services do not properly send a 401, logins will fail.</div>
                        <div>This option forces the sending of the Basic authentication header upon the original request.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>headers</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">dictionary</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Extra headers to set on the request.</div>
                        <div>This should be a dictionary where the key is the header name and the value is the value for that header.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>http_agent</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">"ansible-httpget"</div>
                </td>
                <td>
                        <div>Header to identify as, generally appears in web server logs.</div>
                        <div>This is set to the <code>User-Agent</code> header on a HTTP request.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>maximum_redirection</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">50</div>
                </td>
                <td>
                        <div>Specify how many times the module will redirect a connection to an alternative URI before the connection fails.</div>
                        <div>If set to <code>0</code> or <em>follow_redirects</em> is set to <code>none</code>, or <code>safe</code> when not doing a <code>GET</code> or <code>HEAD</code> it prevents all redirection.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>proxy_password</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The password for <em>proxy_username</em>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>proxy_url</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>An explicit proxy to use for the request.</div>
                        <div>By default, the request will use the IE defined proxy unless <em>use_proxy</em> is set to <code>no</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>proxy_use_default_credential</b>
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
                        <div>Uses the current user&#x27;s credentials when authenticating with a proxy host protected with <code>NTLM</code>, <code>Kerberos</code>, or <code>Negotiate</code> authentication.</div>
                        <div>Proxies that use <code>Basic</code> auth will still require explicit credentials through the <em>proxy_username</em> and <em>proxy_password</em> options.</div>
                        <div>The module will only have access to the user&#x27;s credentials if using <code>become</code> with a password, you are connecting with SSH using a password, or connecting with WinRM using <code>CredSSP</code> or <code>Kerberos with delegation</code>.</div>
                        <div>If not using <code>become</code> or a different auth method to the ones stated above, there will be no default credentials available and no proxy authentication will occur.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>proxy_username</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The username to use for proxy authentication.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>url</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The full URL of a file to download.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>url_method</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The HTTP Method of the request.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: method</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>url_password</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The password for <em>url_username</em>.</div>
                        <div>The alias <em>password</em> is deprecated and will be removed on the major release after <code>2022-07-01</code>.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: password</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>url_timeout</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">30</div>
                </td>
                <td>
                        <div>Specifies how long the request can be pending before it times out (in seconds).</div>
                        <div>Set to <code>0</code> to specify an infinite timeout.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: timeout</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>url_username</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The username to use for authentication.</div>
                        <div>The alias <em>user</em> and <em>username</em> is deprecated and will be removed on the major release after <code>2022-07-01</code>.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: user, username</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>use_default_credential</b>
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
                        <div>Uses the current user&#x27;s credentials when authenticating with a server protected with <code>NTLM</code>, <code>Kerberos</code>, or <code>Negotiate</code> authentication.</div>
                        <div>Sites that use <code>Basic</code> auth will still require explicit credentials through the <em>url_username</em> and <em>url_password</em> options.</div>
                        <div>The module will only have access to the user&#x27;s credentials if using <code>become</code> with a password, you are connecting with SSH using a password, or connecting with WinRM using <code>CredSSP</code> or <code>Kerberos with delegation</code>.</div>
                        <div>If not using <code>become</code> or a different auth method to the ones stated above, there will be no default credentials available and no authentication will occur.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>use_proxy</b>
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
                        <div>If <code>no</code>, it will not use the proxy defined in IE for the current user.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>validate_certs</b>
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
                        <div>If <code>no</code>, SSL certificates will not be validated.</div>
                        <div>This should only be used on personally controlled sites using self-signed certificates.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - If your URL includes an escaped slash character (%2F) this module will convert it to a real slash. This is a result of the behaviour of the System.Uri class as described in `the documentation <https://docs.microsoft.com/en-us/dotnet/framework/configure-apps/file-schema/network/schemesettings-element-uri-settings#remarks>`_.


See Also
--------

.. seealso::

   :ref:`ansible.builtin.get_url_module`
      The official documentation on the **ansible.builtin.get_url** module.
   :ref:`ansible.builtin.uri_module`
      The official documentation on the **ansible.builtin.uri** module.
   :ref:`ansible.windows.win_uri_module`
      The official documentation on the **ansible.windows.win_uri** module.
   :ref:`community.windows.win_inet_proxy_module`
      The official documentation on the **community.windows.win_inet_proxy** module.


Examples
--------

.. code-block:: yaml

    - name: Download earthrise.jpg to specified path
      ansible.windows.win_get_url:
        url: http://www.example.com/earthrise.jpg
        dest: C:\Users\RandomUser\earthrise.jpg

    - name: Download earthrise.jpg to specified path only if modified
      ansible.windows.win_get_url:
        url: http://www.example.com/earthrise.jpg
        dest: C:\Users\RandomUser\earthrise.jpg
        force: no

    - name: Download earthrise.jpg to specified path through a proxy server.
      ansible.windows.win_get_url:
        url: http://www.example.com/earthrise.jpg
        dest: C:\Users\RandomUser\earthrise.jpg
        proxy_url: http://10.0.0.1:8080
        proxy_username: username
        proxy_password: password

    - name: Download file from FTP with authentication
      ansible.windows.win_get_url:
        url: ftp://server/file.txt
        dest: '%TEMP%\ftp-file.txt'
        url_username: ftp-user
        url_password: ftp-password

    - name: Download src with sha256 checksum url
      ansible.windows.win_get_url:
        url: http://www.example.com/earthrise.jpg
        dest: C:\temp\earthrise.jpg
        checksum_url: http://www.example.com/sha256sum.txt
        checksum_algorithm: sha256
        force: True

    - name: Download src with sha256 checksum url
      ansible.windows.win_get_url:
        url: http://www.example.com/earthrise.jpg
        dest: C:\temp\earthrise.jpg
        checksum: a97e6837f60cec6da4491bab387296bbcd72bdba
        checksum_algorithm: sha1
        force: True



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
                    <b>checksum_dest</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>success and dest has been downloaded</td>
                <td>
                            <div>&lt;algorithm&gt; checksum of the file after the download</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">6e642bb8dd5c2e027bf21dd923337cbb4214f827</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>checksum_src</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>force=yes or dest did not exist</td>
                <td>
                            <div>&lt;algorithm&gt; checksum of the remote resource</div>
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
                <td>always</td>
                <td>
                            <div>destination file/path</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">C:\Users\RandomUser\earthrise.jpg</div>
                </td>
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
                            <div>The elapsed seconds between the start of poll and the end of the module.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">2.1406487</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>msg</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>Error message, or HTTP status message from web-server</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">OK</div>
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
                <td>success</td>
                <td>
                            <div>size of the dest file</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">1220</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>status_code</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">integer</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>HTTP status code</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">200</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>url</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>requested url</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">http://www.example.com/earthrise.jpg</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Paul Durivage (@angstwad)
- Takeshi Kuramochi (@tksarah)
