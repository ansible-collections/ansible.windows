# DNS record integration target

Use an isolated Windows member server by default. The target creates uniquely
named file-backed forward and reverse zones, and checks that
its zones, zone files, and regression directory are removed in `always` cleanup.
It restores an initially absent DNS feature after cleanup.

Cleanup waits up to 120 seconds for connectivity to recover, then attempts each
owned resource independently. Unreachable operations remain failures in the final
cleanup assertions. Override `win_dns_record_cleanup_timeout` to change the wait.

For an isolated test domain controller with DNS already installed, explicitly set:

```yaml
win_dns_record_allow_domain_controller: true
win_dns_record_manage_dns_feature: false
```

Domain controllers are refused by default. The opt-in requires feature management
to be disabled, so setup and cleanup cannot install or remove DNS on the DC.
The same fixture ownership and cleanup checks apply to both server roles.

The default execution host is the inventory DNS host. This exercises explicit
`computer_name` selection but does not test two-host authentication.

For a two-host run, set these variables on the DNS inventory host:

```yaml
win_dns_record_manage_dns_feature: false
win_dns_record_execution_host: dns_execution_host
```

DNS must already be installed on the DNS server when feature management is
disabled. The execution host must already have the `DnsServer` PowerShell tools
and authentication that can manage the selected DNS server. The target checks
these prerequisites before creating zones and rejects a second inventory alias
that resolves to the DNS server itself. It does not install tools on the second
host.

For a separate cleanup failure-path run, set
`win_dns_record_inject_failure: true`. The target deliberately fails after
preparation, then runs the same `always` cleanup and removal assertions. The run
is expected to fail at the injected task; successful cleanup assertions verify
fixture removal and restoration of the DNS feature. This option defaults to
`false`.
