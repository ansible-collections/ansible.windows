.. _ansible.windows.win_dns_client_module:


******************************
ansible.windows.win_dns_client
******************************

**Configures DNS lookup on Windows hosts**



.. contents::
   :local:
   :depth: 1


Synopsis
--------
- The :ref:`ansible.windows.win_dns_client <ansible.windows.win_dns_client_module>` module configures the DNS client on Windows network adapters.




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
                    <b>adapter_names</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">list</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Adapter name or list of adapter names for which to manage DNS settings (&#x27;*&#x27; is supported as a wildcard value).</div>
                        <div>The adapter name used is the connection caption in the Network Control Panel or the InterfaceAlias of <code>Get-DnsClientServerAddress</code>.</div>
                </td>
            </tr>
            <tr>
                <td colspan="1">
                    <div class="ansibleOptionAnchor" id="parameter-"></div>
                    <b>dns_servers</b>
                    <a class="ansibleOptionLink" href="#parameter-" title="Permalink to this option"></a>
                    <div style="font-size: small">
                        <span style="color: purple">list</span>
                         / <span style="color: red">required</span>
                    </div>
                </td>
                <td>
                </td>
                <td>
                        <div>Single or ordered list of DNS servers (IPv4 and IPv6 addresses) to configure for lookup.</div>
                        <div>An empty list will configure the adapter to use the DHCP-assigned values on connections where DHCP is enabled, or disable DNS lookup on statically-configured connections.</div>
                        <div>IPv6 DNS servers can only be set on Windows Server 2012 or newer, older hosts can only set IPv4 addresses.</div>
                        <div style="font-size: small; color: darkgreen"><br/>aliases: ipv4_addresses, ip_addresses, addresses</div>
                </td>
            </tr>
    </table>
    <br/>




Examples
--------

.. code-block:: yaml

    - name: Set a single address on the adapter named Ethernet
      ansible.windows.win_dns_client:
        adapter_names: Ethernet
        dns_servers: 192.168.34.5

    - name: Set multiple lookup addresses on all visible adapters (usually physical adapters that are in the Up state), with debug logging to a file
      ansible.windows.win_dns_client:
        adapter_names: '*'
        dns_servers:
        - 192.168.34.5
        - 192.168.34.6
        log_path: C:\dns_log.txt

    - name: Set IPv6 DNS servers on the adapter named Ethernet
      ansible.windows.win_dns_client:
        adapter_names: Ethernet
        dns_servers:
        - '2001:db8::2'
        - '2001:db8::3'

    - name: Configure all adapters whose names begin with Ethernet to use DHCP-assigned DNS values
      ansible.windows.win_dns_client:
        adapter_names: 'Ethernet*'
        dns_servers: []




Status
------


Authors
~~~~~~~

- Matt Davis (@nitzmahone)
- Brian Scholer (@briantist)
