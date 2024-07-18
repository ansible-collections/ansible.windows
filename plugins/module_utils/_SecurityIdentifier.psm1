# Copyright: (c) 2024, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# This module_util is for internal use only. It is not intended to be used by
# collections outside of ansible.windows.

Function ConvertTo-AnsibleWindowsSecurityIdentifier {
    <#
    .SYNOPSIS
    Converts an input string to a SecurityIdentifier object.

    .DESCRIPTION
    Attempts to convert the input string to a SecurityIdentifier object. The
    input is first treated as a SID string and if that fails it will try to
    translate the value as an account name using custom logic.

    .PARAMETER InputObject
    The input string to convert to a SecurityIdentifier object.

    .EXAMPLE
    ConvertTo-AnsibleWindowsSecurityIdentifier SYSTEM, 'S-1-5-18', 'DOMAIN\user', '.\local-user'

    'SYSTEM' | ConvertTo-AnsibleWindowsSecurityIdentifier
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        "PSAvoidUsingEmptyCatchBlock", "",
        Justification = "We don't care if converting to a SID fails, just that it failed or not")]
    [OutputType([System.Security.Principal.SecurityIdentifier])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [String[]]
        $InputObject
    )

    process {
        foreach ($obj in $InputObject) {
            # Try parse the raw string as a SID string first.
            try {
                New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $obj
                continue
            }
            catch [System.ArgumentException] {}

            # In the Netlogon form (DOMAIN\user). Check if the domain part is
            # '.' and convert it to the current hostname. Otherwise just treat
            # the value as the full username and let Windows parse it.
            if ($obj.Contains('\')) {
                $nameSplit = $obj -split '\\', 2
                if ($nameSplit[0] -eq '.') {
                    $domain = $env:COMPUTERNAME
                }
                else {
                    $domain = $nameSplit[0]
                }
                $account = $nameSplit[1]

                # NTAccount fails to find a local group when used with the
                # domain part. First check if the value references a local
                # group and unset the domain if it is.
                if ($domain -eq $env:COMPUTERNAME) {
                    $adsi = [ADSI]("WinNT://$domain,computer")
                    $group = $adsi.psbase.children | Where-Object {
                        $_.schemaClassName -eq "group" -and $_.Name -eq $account
                    } | Select-Object -First 1
                    if ($group) {
                        $domain = $null
                    }
                }
            }
            else {
                $domain = $null
                $account = $obj
            }

            $account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList @(
                if ($domain) {
                    $domain
                }
                $account
            )
            try {
                $account.Translate([System.Security.Principal.SecurityIdentifier])
            }
            catch [System.Security.Principal.IdentityNotMappedException] {
                $err = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList @(
                    $_.Exception,
                    "InvalidSidIdentity",
                    [System.Management.Automation.ErrorCategory]::InvalidArgument,
                    $obj
                )
                $err.ErrorDetails = "Failed to translate '$obj' to a SecurityIdentifier: $_"
                $PSCmdlet.WriteError($err)
            }
        }
    }
}

Export-ModuleMember -Function ConvertTo-AnsibleWindowsSecurityIdentifier
