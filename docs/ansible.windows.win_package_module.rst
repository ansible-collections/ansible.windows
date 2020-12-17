.. _ansible.windows.win_package_module:


***************************
ansible.windows.win_package
***************************

**Installs/uninstalls an installable package**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- Installs or uninstalls software packages for Windows.
- Supports ``.exe``, ``.msi``, ``.msp``, ``.appx``, ``.appxbundle``, ``.msix``, and ``.msixbundle``.
- These packages can be sourced from the local file system, network file share or a url.
- See *provider* for more info on each package type that is supported.




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
                    <b>arguments</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">raw</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Any arguments the installer needs to either install or uninstall the package.</div>
                        <div>If the package is an MSI do not supply the <code>/qn</code>, <code>/log</code> or <code>/norestart</code> arguments.</div>
                        <div>This is only used for the <code>msi</code>, <code>msp</code>, and <code>registry</code> providers.</div>
                        <div>Can be a list of arguments and the module will escape the arguments as necessary, it is recommended to use a string when dealing with MSI packages due to the unique escaping issues with msiexec.</div>
                </td>
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
                        <div>Set the specified path as the current working directory before installing or uninstalling a package.</div>
                        <div>This is only used for the <code>msi</code>, <code>msp</code>, and <code>registry</code> providers.</div>
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
                    <b>creates_path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Will check the existence of the path specified and use the result to determine whether the package is already installed.</div>
                        <div>You can use this in conjunction with <code>product_id</code> and other <code>creates_*</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>creates_service</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Will check the existing of the service specified and use the result to determine whether the package is already installed.</div>
                        <div>You can use this in conjunction with <code>product_id</code> and other <code>creates_*</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>creates_version</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Will check the file version property of the file at <code>creates_path</code> and use the result to determine whether the package is already installed.</div>
                        <div><code>creates_path</code> MUST be set and is a file.</div>
                        <div>You can use this in conjunction with <code>product_id</code> and other <code>creates_*</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>expected_return_code</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">list</span>
                         / <span style="color: purple">elements=integer</span>
                    </div>
                </td>
                <td>
                        <b>Default:</b><br/><div style="color: blue">[0, 3010]</div>
                </td>
                <td>
                        <div>One or more return codes from the package installation that indicates success.</div>
                        <div>The return codes are read as a signed integer, any values greater than 2147483647 need to be represented as the signed equivalent, i.e. <code>4294967295</code> is <code>-1</code>.</div>
                        <div>To convert a unsigned number to the signed equivalent you can run &quot;[Int32](&quot;0x{0:X}&quot; -f ([UInt32]3221225477))&quot;.</div>
                        <div>A return code of <code>3010</code> usually means that a reboot is required, the <code>reboot_required</code> return value is set if the return code is <code>3010</code>.</div>
                        <div>This is only used for the <code>msi</code>, <code>msp</code>, and <code>registry</code> providers.</div>
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
                    <b>log_path</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">path</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Specifies the path to a log file that is persisted after a package is installed or uninstalled.</div>
                        <div>This is only used for the <code>msi</code> or <code>msp</code> provider.</div>
                        <div>When omitted, a temporary log file is used instead for those providers.</div>
                        <div>This is only valid for MSI files, use <code>arguments</code> for the <code>registry</code> provider.</div>
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
                    <b>password</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The password for <code>user_name</code>, must be set when <code>user_name</code> is.</div>
                        <div>This option is deprecated in favour of using become, see examples for more information. Will be removed on the major release after <code>2022-07-01</code>.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: user_password</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
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
                        <div>Location of the package to be installed or uninstalled.</div>
                        <div>This package can either be on the local file system, network share or a url.</div>
                        <div>When <code>state=present</code>, <code>product_id</code> is not set and the path is a URL, this file will always be downloaded to a temporary directory for idempotency checks, otherwise the file will only be downloaded if the package has not been installed based on the <code>product_id</code> checks.</div>
                        <div>If <code>state=present</code> then this value MUST be set.</div>
                        <div>If <code>state=absent</code> then this value does not need to be set if <code>product_id</code> is.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>product_id</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>The product id of the installed packaged.</div>
                        <div>This is used for checking whether the product is already installed and getting the uninstall information if <code>state=absent</code>.</div>
                        <div>For msi packages, this is the <code>ProductCode</code> (GUID) of the package. This can be found under the same registry paths as the <code>registry</code> provider.</div>
                        <div>For msp packages, this is the <code>PatchCode</code> (GUID) of the package which can found under the <code>Details -&gt; Revision number</code> of the file&#x27;s properties.</div>
                        <div>For msix packages, this is the <code>Name</code> or <code>PackageFullName</code> of the package found under the <code>Get-AppxPackage</code> cmdlet.</div>
                        <div>For registry (exe) packages, this is the registry key name under the registry paths specified in <em>provider</em>.</div>
                        <div>This value is ignored if <code>path</code> is set to a local accesible file path and the package is not an <code>exe</code>.</div>
                        <div>This SHOULD be set when the package is an <code>exe</code>, or the path is a url or a network share and credential delegation is not being used. The <code>creates_*</code> options can be used instead but is not recommended.</div>
                        <div>The alias <em>productid</em> is deprecated and will be removed on the major release after <code>2022-07-01</code>.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: productid</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>provider</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li><div style="color: blue"><b>auto</b>&nbsp;&larr;</div></li>
                                    <li>msi</li>
                                    <li>msix</li>
                                    <li>msp</li>
                                    <li>registry</li>
                        </ul>
                </td>
                <td>
                        <div>Set the package provider to use when searching for a package.</div>
                        <div>The <code>auto</code> provider will select the proper provider if <em>path</em> otherwise it scans all the other providers based on the <em>product_id</em>.</div>
                        <div>The <code>msi</code> provider scans for MSI packages installed on a machine wide and current user context based on the <code>ProductCode</code> of the MSI.</div>
                        <div>The <code>msix</code> provider is used to install <code>.appx</code>, <code>.msix</code>, <code>.appxbundle</code>, or <code>.msixbundle</code> packages. These packages are only installed or removed on the current use. The host must be set to allow sideloaded apps or in developer mode. See the examples for how to enable this. If a package is already installed but <code>path</code> points to an updated package, this will be installed over the top of the existing one.</div>
                        <div>The <code>msp</code> provider scans for all MSP patches installed on a machine wide and current user context based on the <code>PatchCode</code> of the MSP. A <code>msp</code> will be applied or removed on all <code>msi</code> products that it applies to and is installed. If the patch is obsoleted or superseded then no action will be taken.</div>
                        <div>The <code>registry</code> provider is used for traditional <code>exe</code> installers and uses the following registry path to determine if a product was installed; <code>HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall</code>, <code>HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall</code>, <code>HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall</code>, and <code>HKCU:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall</code>.</div>
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
                        <div>Whether to install or uninstall the package.</div>
                        <div>The module uses <em>product_id</em> to determine whether the package is installed or not.</div>
                        <div>For all providers but <code>auto</code>, the <em>path</em> can be used for idempotency checks if it is locally accesible filesystem path.</div>
                        <div>The alias <em>ensure</em> is deprecated and will be removed on the major release after <code>2022-07-01</code>.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: ensure</div>
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
                    <b>username</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">string</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Username of an account with access to the package if it is located on a file share.</div>
                        <div>This is only needed if the WinRM transport is over an auth method that does not support credential delegation like Basic or NTLM or become is not used.</div>
                        <div>This option is deprecated in favour of using become, see examples for more information. Will be removed on the major release after <code>2022-07-01</code>.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: user_name</div>
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
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>wait_for_children</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">boolean</span>
                    </div>
                    <div style="font-style: italic; font-size: small; color: darkgreen">added in 1.3.0</div>
                </td>
                <td>
                        <ul style="margin: 0; padding: 0"><b>Choices:</b>
                                    <li><div style="color: blue"><b>no</b>&nbsp;&larr;</div></li>
                                    <li>yes</li>
                        </ul>
                </td>
                <td>
                        <div>The module will wait for the process it spawns to finish but any processes spawned in that child process as ignored.</div>
                        <div>Set to <code>yes</code> to wait for all descendent processes to finish before the module returns.</div>
                        <div>This is useful if the install/uninstaller is just a wrapper which then calls the actual installer as its own child process. When this option is <code>yes</code> then the module will wait for both processes to finish before returning.</div>
                        <div>This should not be required for most installers and setting to <code>yes</code> could result in the module not returning until the process it is waiting for has been stopped manually.</div>
                        <div>Requires Windows Server 2012 or Windows 8 or newer to use.</div>
                </td>
            </tr>
    </table>
    <br/>


Notes
-----

.. note::
   - When ``state=absent`` and the product is an exe, the path may be different from what was used to install the package originally. If path is not set then the path used will be what is set under ``QuietUninstallString`` or ``UninstallString`` in the registry for that *product_id*.
   - By default all msi installs and uninstalls will be run with the arguments ``/log, /qn, /norestart``.
   - All the installation checks under ``product_id`` and ``creates_*`` add together, if one fails then the program is considered to be absent.


See Also
--------

.. seealso::

   :ref:`chocolatey.chocolatey.win_chocolatey_module`
      The official documentation on the **chocolatey.chocolatey.win_chocolatey** module.
   :ref:`community.windows.win_hotfix_module`
      The official documentation on the **community.windows.win_hotfix** module.
   :ref:`ansible.windows.win_updates_module`
      The official documentation on the **ansible.windows.win_updates** module.
   :ref:`community.windows.win_inet_proxy_module`
      The official documentation on the **community.windows.win_inet_proxy** module.


Examples
--------

.. code-block:: yaml

    - name: Install the Visual C thingy
      ansible.windows.win_package:
        path: http://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe
        product_id: '{CF2BEA3C-26EA-32F8-AA9B-331F7E34BA97}'
        arguments: /install /passive /norestart

    - name: Install Visual C thingy with list of arguments instead of a string
      ansible.windows.win_package:
        path: http://download.microsoft.com/download/1/6/B/16B06F60-3B20-4FF2-B699-5E9B7962F9AE/VSU_4/vcredist_x64.exe
        product_id: '{CF2BEA3C-26EA-32F8-AA9B-331F7E34BA97}'
        arguments:
        - /install
        - /passive
        - /norestart

    - name: Install Remote Desktop Connection Manager from msi with a permanent log
      ansible.windows.win_package:
        path: https://download.microsoft.com/download/A/F/0/AF0071F3-B198-4A35-AA90-C68D103BDCCF/rdcman.msi
        product_id: '{0240359E-6A4C-4884-9E94-B397A02D893C}'
        state: present
        log_path: D:\logs\vcredist_x64-exe-{{lookup('pipe', 'date +%Y%m%dT%H%M%S')}}.log

    - name: Uninstall Remote Desktop Connection Manager
      ansible.windows.win_package:
        product_id: '{0240359E-6A4C-4884-9E94-B397A02D893C}'
        state: absent

    - name: Install Remote Desktop Connection Manager locally omitting the product_id
      ansible.windows.win_package:
        path: C:\temp\rdcman.msi
        state: present

    - name: Uninstall Remote Desktop Connection Manager from local MSI omitting the product_id
      ansible.windows.win_package:
        path: C:\temp\rdcman.msi
        state: absent

    # 7-Zip exe doesn't use a guid for the Product ID
    - name: Install 7zip from a network share with specific credentials
      ansible.windows.win_package:
        path: \\domain\programs\7z.exe
        product_id: 7-Zip
        arguments: /S
        state: present
      become: yes
      become_method: runas
      become_flags: logon_type=new_credential logon_flags=netcredentials_only
      vars:
        ansible_become_user: DOMAIN\User
        ansible_become_password: Password

    - name: Install 7zip and use a file version for the installation check
      ansible.windows.win_package:
        path: C:\temp\7z.exe
        creates_path: C:\Program Files\7-Zip\7z.exe
        creates_version: 16.04
        state: present

    - name: Uninstall 7zip from the exe
      ansible.windows.win_package:
        path: C:\Program Files\7-Zip\Uninstall.exe
        product_id: 7-Zip
        arguments: /S
        state: absent

    - name: Uninstall 7zip without specifying the path
      ansible.windows.win_package:
        product_id: 7-Zip
        arguments: /S
        state: absent

    - name: Install application and override expected return codes
      ansible.windows.win_package:
        path: https://download.microsoft.com/download/1/6/7/167F0D79-9317-48AE-AEDB-17120579F8E2/NDP451-KB2858728-x86-x64-AllOS-ENU.exe
        product_id: '{7DEBE4EB-6B40-3766-BB35-5CBBC385DA37}'
        arguments: '/q /norestart'
        state: present
        expected_return_code: [0, 666, 3010]

    - name: Install a .msp patch
      ansible.windows.win_package:
        path: C:\Patches\Product.msp
        state: present

    - name: Remove a .msp patch
      ansible.windows.win_package:
        product_id: '{AC76BA86-A440-FFFF-A440-0C13154E5D00}'
        state: absent

    - name: Enable installation of 3rd party MSIX packages
      ansible.windows.win_regedit:
        path: HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock
        name: AllowAllTrustedApps
        data: 1
        type: dword
        state: present

    - name: Install an MSIX package for the current user
      ansible.windows.win_package:
        path: C:\Installers\Calculator.msix  # Can be .appx, .msixbundle, or .appxbundle
        state: present

    - name: Uninstall an MSIX package using the product_id
      ansible.windows.win_package:
        product_id: InputApp
        state: absent



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
                    <b>log</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">string</span>
                    </div>
                </td>
                <td>installation/uninstallation failure for MSI or MSP packages</td>
                <td>
                            <div>The contents of the MSI or MSP log.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">Installation completed successfully</div>
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
                <td>change occurred</td>
                <td>
                            <div>The return code of the package process.</div>
                    <br/>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="return-"></div>
                    <b>reboot_required</b>
                    <a class="ansibleOptionLink" href="#return-" title="Permalink to this return value"></a>
                    <div style="font-size: small">
                      <span style="color: purple">boolean</span>
                    </div>
                </td>
                <td>always</td>
                <td>
                            <div>Whether a reboot is required to finalise package. This is set to true if the executable return code is 3010.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">True</div>
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
                <td>failure during install or uninstall</td>
                <td>
                            <div>The stderr stream of the package process.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">Failed to install program</div>
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
                <td>failure during install or uninstall</td>
                <td>
                            <div>The stdout stream of the package process.</div>
                    <br/>
                        <div style="font-size: smaller"><b>Sample:</b></div>
                        <div style="font-size: smaller; color: blue; word-wrap: break-word; word-break: break-all;">Installing program</div>
                </td>
            </tr>
    </table>
    <br/><br/>


Status
------


Authors
~~~~~~~

- Trond Hindenes (@trondhindenes)
- Jordan Borean (@jborean93)
