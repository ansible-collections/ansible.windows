#!powershell

# Copyright: (c) 2020 VMware, Inc. All Rights Reserved.
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        type = @{ type = "str"; choices = "reservation", "lease"; default = "reservation" }
        ip = @{ type = "str" }
        scope_id = @{ type = "str" }
        mac = @{ type = "str" }
        duration = @{ type = "int" }
        dns_hostname = @{ type = "str" }
        dns_regtype = @{ type = "str"; choices = "aptr", "a", "noreg"; default = "aptr" }
        reservation_name = @{ type = "str" }
        description = @{ type = "str" }
        state = @{ type = "str"; choices = "absent", "present"; default = "present" }
        computer_name = @{ type = "str" }
    }
    # At least one of mac or ip is required for both states ($true = any, not all)
    required_if = @(
        @("state", "present", @("mac", "ip"), $true),
        @("state", "absent", @("mac", "ip"), $true)
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$type = $module.Params.type
$ip = $module.Params.ip
$scope_id = $module.Params.scope_id
$mac = $module.Params.mac
$duration = $module.Params.duration
$dns_hostname = $module.Params.dns_hostname
$dns_regtype = $module.Params.dns_regtype
$reservation_name = $module.Params.reservation_name
$description = $module.Params.description
$state = $module.Params.state

# Build the optional ComputerName splat used by every DHCP cmdlet call.
# Empty when computer_name is not supplied so splatting is always safe.
$extra_args = @{}
if ($null -ne $module.Params.computer_name) {
    $extra_args.ComputerName = $module.Params.computer_name
}

# Ensure the lease key is always present in the return value regardless of
# the code path taken. Overwritten with real data on create/update paths.
$module.Result.lease = $null

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------

Function ConvertTo-DashedMac {
    <#
    .SYNOPSIS
        Normalises a MAC address to uppercase dash-separated format.
    .DESCRIPTION
        Accepts colon-separated (AA:BB:CC:DD:EE:FF), dash-separated
        (AA-BB-CC-DD-EE-FF), flat twelve-hex-char (AABBCCDDEEFF) and
        Cisco dot-triplet (aabb.ccdd.eeff) MAC addresses and returns the
        uppercase dash-separated form expected by the Windows DHCP server
        cmdlets. Returns $false when the format is not recognised so the
        caller can fail with a meaningful error.
    .PARAMETER Mac
        Raw MAC address string as supplied by the Ansible module parameter.
    .OUTPUTS
        [string] Uppercase dash-separated MAC, or [bool] $false on invalid input.
    #>
    Param([string]$Mac)

    # Colon-separated: AA:BB:CC:DD:EE:FF
    if ($Mac -match '^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$') {
        return ($Mac -replace ':', '-').ToUpper()
    }
    # Dash-separated: AA-BB-CC-DD-EE-FF (already target format, normalise case)
    elseif ($Mac -match '^([0-9A-Fa-f]{2}-){5}[0-9A-Fa-f]{2}$') {
        return $Mac.ToUpper()
    }
    # Flat twelve hex chars: AABBCCDDEEFF
    elseif ($Mac -match '^[0-9A-Fa-f]{12}$') {
        return $Mac.Insert(2, '-').Insert(5, '-').Insert(8, '-').Insert(11, '-').Insert(14, '-').ToUpper()
    }
    # Cisco dot-triplet: aabb.ccdd.eeff
    elseif ($Mac -match '^[0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4}\.[0-9A-Fa-f]{4}$') {
        $flat = $Mac -replace '\.', ''
        return $flat.Insert(2, '-').Insert(5, '-').Insert(8, '-').Insert(11, '-').Insert(14, '-').ToUpper()
    }
    else {
        return $false
    }
}

function ConvertTo-DnsRegType {
    <#
    .SYNOPSIS
        Maps an Ansible dns_regtype choice to the value expected by the DHCP cmdlets.
    .DESCRIPTION
        Translates the short Ansible-facing strings ("aptr", "a", "noreg") to the
        PowerShell DHCP server enum strings. Defaults to NoRegistration for any
        unrecognised value, which is the safest fallback.
    .PARAMETER RegType
        The raw dns_regtype string from the Ansible module parameter.
    .OUTPUTS
        [string] DHCP cmdlet-compatible DNS registration type string.
    #>
    Param([string]$RegType)

    switch ($RegType) {
        "aptr" { return "AandPTR" }
        "a" { return "A" }
        default { return "NoRegistration" }
    }
}

Function ConvertTo-LeaseSummaryFromObject {
    <#
    .SYNOPSIS
        Converts a live DHCP server object to a normalised LeaseSummary hashtable.
    .DESCRIPTION
        Accepts a DhcpServerv4Lease or DhcpServerv4Reservation object returned by
        the DHCP cmdlets and produces the flat hashtable used for Ansible return
        values and diff output. IPAddress and ScopeId are serialised to strings
        via IPAddressToString. AddressState is coerced to string to ensure
        consistent comparison with ConvertTo-LeaseSummaryFromParam
    .
        Always pair with ConvertTo-LeaseSummaryFromParam
     when comparing before/after
        so that Test-DhcpLeaseChanged always receives homogeneous inputs.
    .PARAMETER Object
        A live DhcpServerv4Lease or DhcpServerv4Reservation object.
    .OUTPUTS
        [hashtable] LeaseSummary with keys: address_state, client_id, ip_address,
        scope_id, name, description.
    #>
    Param($Object)

    return @{
        address_state = $Object.AddressState.ToString()
        client_id = $Object.ClientId
        ip_address = $Object.IPAddress.IPAddressToString
        scope_id = $Object.ScopeId.IPAddressToString
        name = $Object.Name
        description = $Object.Description
    }
}

Function ConvertTo-LeaseSummaryFromParam {
    <#
    .SYNOPSIS
        Builds a LeaseSummary hashtable from a params hashtable (check_mode path).
    .DESCRIPTION
        Produces the same key set as ConvertTo-LeaseSummaryFromObject from a plain
        params hashtable, so that Test-DhcpLeaseChanged always compares two
        structurally identical hashtables regardless of whether a real DHCP object
        is available. Used when check_mode is active and no write has occurred.
        ClientId is sourced from params which must already be uppercase dashed
        (guaranteed by ConvertTo-DashedMac or copied from an existing lease object).
    .PARAMETER Params
        The write-operation params hashtable built by the calling function.
    .OUTPUTS
        [hashtable] LeaseSummary with keys: address_state, client_id, ip_address,
        scope_id, name, description.
    #>
    Param([hashtable]$Params)

    return @{
        address_state = $Params.AddressState
        client_id = $Params.ClientId
        ip_address = $Params.IPAddress
        scope_id = $Params.ScopeId
        name = $Params.Name
        description = $Params.Description
    }
}

Function Test-DhcpLeaseChanged {
    <#
    .SYNOPSIS
        Returns $true when two LeaseSummary hashtables differ on any tracked field.
    .DESCRIPTION
        Compares the before and after LeaseSummary hashtables key by key.
        Both inputs must be LeaseSummary hashtables produced by either
        ConvertTo-LeaseSummaryFromObject or ConvertTo-LeaseSummaryFromParam
     —
        never a raw DHCP object or a raw params hashtable — to guarantee that
        property names and value types are identical on both sides and avoid
        false positives from type mismatches.
    .PARAMETER Before
        LeaseSummary hashtable representing state before the operation.
    .PARAMETER After
        LeaseSummary hashtable representing the intended or observed state after.
    .OUTPUTS
        [bool] $true if any field differs, $false if all fields are equal.
    #>

    Param(
        [AllowNull()]
        [hashtable]$Before,

        [AllowNull()]
        [hashtable]$After
    )

    if ($null -eq $Before) {
        $Before = @{}
    }

    if ($null -eq $After) {
        $After = @{}
    }

    $keys = @(
        $Before.Keys
        $After.Keys
    ) | Sort-Object -Unique

    foreach ($key in $keys) {
        $beforeHasKey = $Before.ContainsKey($key)
        $afterHasKey = $After.ContainsKey($key)

        # IF the key value is null do not consider it a change
        if ($afterHasKey -and $null -eq $After[$key]) {
            continue
        }

        if ($beforeHasKey -ne $afterHasKey) {
            return $true
        }

        if ($Before[$key] -ne $After[$key]) {
            return $true
        }
    }

    return $false
}

Function New-ReservationParamSet {
    <#
    .SYNOPSIS
        Builds the params hashtable for reservation create or update operations.
    .DESCRIPTION
        Resolves ClientId, Description and Name from module-level variables,
        falling back to values on the existing lease object where the caller did
        not supply an explicit value. Centralises the resolution logic that was
        previously duplicated across the convert-lease-to-reservation, update-
        reservation and create-reservation paths.
        When CurrentLease is $null (create path) Name falls back to the generated
        "reservation-<ClientId>" pattern. HostName and other cmdlet-specific keys
        are added by the caller after this function returns.
    .PARAMETER CurrentLease
        Existing DHCP lease or reservation object. May be $null on the create path.
    .PARAMETER MacDashed
        Uppercase dash-separated MAC address, or $null if not supplied by caller.
    .PARAMETER Description
        Description string from the Ansible module parameter, or $null.
    .PARAMETER ReservationName
        Reservation name from the Ansible module parameter, or $null.
    .OUTPUTS
        [hashtable] Params hashtable with at minimum ClientId, Description, Name.
    #>
    Param(
        $CurrentLease,
        [string]$MacDashed,
        [string]$Description,
        [string]$ReservationName
    )

    $params = @{}

    # Prefer the caller-supplied MAC; fall back to the value already on the server
    $params.ClientId = if ($MacDashed) { $MacDashed } else { $CurrentLease.ClientId }

    # Prefer the caller-supplied description; fall back to the existing value
    $params.Description = if ($Description) { $Description } else { $CurrentLease.Description }

    if ($ReservationName) {
        $params.Name = $ReservationName
    }
    elseif ($CurrentLease -and $CurrentLease.Name) {
        # Preserve the name already on the server if no override was requested
        $params.Name = $CurrentLease.Name
    }
    else {
        # No name available from either source — generate a deterministic fallback
        $params.Name = "reservation-" + $params.ClientId
    }

    return $params
}

Function Find-DhcpLease {
    <#
    .SYNOPSIS
        Searches the DHCP server for an existing lease or reservation.
    .DESCRIPTION
        Attempts lookup by MAC address first, then by IP address if no result was
        found or MAC was not supplied. Pushes as much filtering as possible to the
        server side to avoid fetching all leases across all scopes:
          - scope_id + MAC  : fully server-side via -ScopeId and -ClientId
          - MAC only        : -ClientId server-side per scope, scope enumeration
                              unavoidable
          - scope_id + IP   : -ScopeId server-side, IP matched client-side
                              (Get-DhcpServerv4Lease has no -IPAddress parameter)
          - IP only         : full enumeration, IP matched client-side
        Uses the script-scope $extra_args splat for optional ComputerName.
    .PARAMETER MacDashed
        Uppercase dash-separated MAC address, or $null.
    .PARAMETER IpAddress
        IP address string, or $null.
    .PARAMETER ScopeId
        DHCP scope ID string, or $null.
    .OUTPUTS
        A DhcpServerv4Lease / DhcpServerv4Reservation object, or $null if not found.
    #>
    Param(
        [string]$MacDashed,
        [string]$IpAddress,
        [string]$ScopeId
    )

    if ($MacDashed) {
        try {
            if ($ScopeId) {
                # Best case: both dimensions filtered on the server.
                # Get-DhcpServerv4Lease throws CimException error 20016 when no entry
                # exists for the given ClientId — treat that as not found ($null),
                # not as a module failure.
                $lease = Get-DhcpServerv4Lease -ScopeId $ScopeId -ClientId $MacDashed @extra_args -ErrorAction Stop
            }
            else {
                # No scope — enumerate scopes but push ClientId filter to server
                $lease = Get-DhcpServerv4Scope @extra_args | Get-DhcpServerv4Lease -ClientId $MacDashed @extra_args
            }
        }
        catch {
            # DHCP error 20016: no lease found for this ClientId — not a real error
            if ($_.FullyQualifiedErrorId -like 'DHCP 20016,*') {
                $lease = $null
            }
            else {
                $module.FailJson("Unable to retrieve DHCP lease by MAC: $($_.Exception.Message)", $_)
            }
        }
        if ($lease) { return $lease }
    }

    if ($IpAddress) {
        try {
            if ($ScopeId) {
                # Scope known — server filters scope, client filters IP
                $lease = Get-DhcpServerv4Lease -ScopeId $ScopeId @extra_args | Where-Object { $_.IPAddress -eq $IpAddress }
            }
            else {
                # No scope and no MAC — full enumeration, client-side IP filter
                $lease = Get-DhcpServerv4Scope @extra_args | Get-DhcpServerv4Lease @extra_args | Where-Object { $_.IPAddress -eq $IpAddress }
            }
        }
        catch {
            # DHCP error 20016: scope exists but contains no leases — not a real error
            if ($_.FullyQualifiedErrorId -like 'DHCP 20016,*') {
                $lease = $null
            }
            else {
                $module.FailJson("Unable to retrieve DHCP lease by IP: $($_.Exception.Message)", $_)
            }
        }
        if ($lease) { return $lease }
    }

    return $null
}

Function Write-LeaseResult {
    <#
    .SYNOPSIS
        Populates module.Result.lease, Diff.after and Result.changed after any write.
    .DESCRIPTION
        Single point of responsibility for emitting result and diff data after every
        create, update, convert or delete operation.

        Delete path (-Deleted switch):
            Verifies the entry is actually gone by attempting a re-read. Fails the
            module if the entry is still present. Sets changed=$true and
            Diff.after=@{}. Skips verification in check_mode since no write occurred.

        Write path (default):
            In normal mode: re-reads the entry from the DHCP server to obtain
            authoritative post-write values, then derives changed by comparing
            the before and after LeaseSummary hashtables via Test-DhcpLeaseChanged.
            In check_mode: derives result from the $Params hashtable without
            contacting the server (no write occurred). Uses
            ConvertTo-LeaseSummaryFromParam
         to produce a homogeneous input for
            Test-DhcpLeaseChanged.

        Uses script-scope $module and $extra_args.
    .PARAMETER OriginalLease
        LeaseSummary hashtable captured before the write via
        ConvertTo-LeaseSummaryFromObject. Pass @{} for create operations where
        no prior entry existed.
    .PARAMETER Params
        The write-operation params hashtable. Used as the check_mode fallback
        for Result.lease and Diff.after, and as input to
        ConvertTo-LeaseSummaryFromParam
    .
    .PARAMETER ClientId
        ClientId string used to re-read the entry after the write.
    .PARAMETER ScopeId
        ScopeId string used to re-read the entry after the write.
    .PARAMETER FetchAsReservation
        When set, re-reads via Get-DhcpServerv4Reservation instead of
        Get-DhcpServerv4Lease. Use for create-reservation paths only;
        all update and convert paths use Get-DhcpServerv4Lease.
    .PARAMETER Deleted
        When set, switches to the delete verification path. OriginalLease and
        Params are not used. ClientId and ScopeId are required for re-read.
    #>
    Param(
        $OriginalLease = $null,
        [hashtable]$Params = $null,
        [string]$ClientId,
        [string]$ScopeId,
        [switch]$FetchAsReservation,
        [switch]$Deleted
    )

    if ($Deleted) {
        # Verify the entry was actually removed; skip in check_mode (nothing was written)
        if (-not $module.CheckMode) {
            try {
                $still = Get-DhcpServerv4Lease -ClientId $ClientId -ScopeId $ScopeId @extra_args -ErrorAction Stop
            }
            catch {
                # DHCP error 20016: scope exists but contains no leases — not a real error
                if ($_.FullyQualifiedErrorId -like 'DHCP 20016,*') {
                    # Not found is the expected outcome — suppress the error
                    $still = $null
                }
                else {
                    $module.FailJson("Unable to retrieve DHCP lease by IP: $($_.Exception.Message)", $_)
                }
            }
            if ($still) {
                $module.FailJson("DHCP entry still exists after removal attempt")
            }
        }
        $module.Result.changed = $true
        $module.Diff.after = @{}
        return
    }

    if (-not $module.CheckMode) {
        # Re-read from the server to get authoritative post-write values
        try {
            if ($FetchAsReservation) {
                $fetched = Get-DhcpServerv4Reservation -ClientId $ClientId -ScopeId $ScopeId @extra_args -ErrorAction Stop
            }
            else {
                $fetched = Get-DhcpServerv4Lease -ClientId $ClientId -ScopeId $ScopeId @extra_args -ErrorAction Stop
            }
        }
        catch {
            $module.FailJson("Could not re-read DHCP entry after write: $($_.Exception.Message)", $_)
        }
        $summary = ConvertTo-LeaseSummaryFromObject -Object $fetched
        $module.Result.lease = $summary
        $module.Diff.after = $summary
        $module.Result.changed = Test-DhcpLeaseChanged -Before $OriginalLease -After $summary
    }
    else {
        # check_mode: no write occurred; derive result from the intended params
        $summary = ConvertTo-LeaseSummaryFromParam -Params $Params
        $module.Result.lease = $summary
        $module.Diff.after = $summary
        $module.Result.changed = Test-DhcpLeaseChanged -Before $OriginalLease -After $summary
    }
}

# ---------------------------------------------------------------------------
# Delete functions
# ---------------------------------------------------------------------------

Function Remove-DhcpLease {
    <#
    .SYNOPSIS
        Removes a plain (non-reservation) DHCP lease from the server.
    .DESCRIPTION
        Pipes the existing lease object into Remove-DhcpServerv4Lease, honouring
        check_mode via -WhatIf. On failure the current lease summary is written to
        Result.lease before calling FailJson so the caller can see what was targeted.
        Delegates post-remove verification and result emission to Write-LeaseResult
        with -Deleted so that the deletion is confirmed by re-reading the server.
    .PARAMETER Lease
        The existing DhcpServerv4Lease object to remove.
    #>
    Param($Lease)

    try {
        $Lease | Remove-DhcpServerv4Lease -WhatIf:$module.CheckMode @extra_args -ErrorAction Stop
    }
    catch {
        # Surface the current lease in the return value to aid debugging
        $module.Result.lease = ConvertTo-LeaseSummaryFromObject -Object $Lease
        $module.FailJson("Unable to remove DHCP lease: $($_.Exception.Message)", $_)
    }

    Write-LeaseResult -Deleted -ClientId $Lease.ClientId -ScopeId $Lease.ScopeId.IPAddressToString
}

Function Remove-DhcpReservation {
    <#
    .SYNOPSIS
        Removes a DHCP reservation from the server.
    .DESCRIPTION
        Pipes the existing lease object into Remove-DhcpServerv4Reservation,
        honouring check_mode via -WhatIf. On failure the current lease summary is
        written to Result.lease before calling FailJson. Delegates post-remove
        verification and result emission to Write-LeaseResult with -Deleted.
        Note: the post-delete re-read in Write-LeaseResult uses
        Get-DhcpServerv4Lease which covers both lease and reservation states,
        so no separate Get-DhcpServerv4Reservation call is needed here.
    .PARAMETER Lease
        The existing DhcpServerv4Reservation object to remove.
    #>
    Param($Lease)

    try {
        $Lease | Remove-DhcpServerv4Reservation -WhatIf:$module.CheckMode @extra_args -ErrorAction Stop
    }
    catch {
        $module.Result.lease = ConvertTo-LeaseSummaryFromObject -Object $Lease
        $module.FailJson("Unable to remove DHCP reservation: $($_.Exception.Message)", $_)
    }

    Write-LeaseResult -Deleted -ClientId $Lease.ClientId -ScopeId $Lease.ScopeId.IPAddressToString
}

# ---------------------------------------------------------------------------
# Create functions
# ---------------------------------------------------------------------------

Function New-DhcpLease {
    <#
    .SYNOPSIS
        Creates a new plain DHCP lease.
    .DESCRIPTION
        Calls Add-DhcpServerv4Lease with the supplied params hashtable, honouring
        check_mode via -WhatIf. On success, delegates result and diff emission to
        Write-LeaseResult which re-reads the entry from the server in normal mode.
        In check_mode Write-LeaseResult derives the result from the params hashtable.
        Passes @{} as OriginalLease because no prior entry existed.
    .PARAMETER LeaseParams
        Hashtable of parameters for Add-DhcpServerv4Lease (ClientId, IPAddress,
        ScopeId, and optionally AddressState, LeaseExpiryTime, DnsRR, Description).
    #>
    Param([hashtable]$LeaseParams)

    try {
        Add-DhcpServerv4Lease @LeaseParams -WhatIf:$module.CheckMode @extra_args -ErrorAction Stop
    }
    catch {
        $module.FailJson("Could not create DHCP lease: $($_.Exception.Message)", $_)
    }

    Write-LeaseResult -OriginalLease @{} -Params $LeaseParams -ClientId $LeaseParams.ClientId -ScopeId $LeaseParams.ScopeId
}

Function New-DhcpReservation {
    <#
    .SYNOPSIS
        Creates a new DHCP reservation.
    .DESCRIPTION
        Calls Add-DhcpServerv4Reservation with the supplied params hashtable.
        HostName is stripped from the params before calling the cmdlet because
        Add-DhcpServerv4Reservation does not accept that parameter.
        In check_mode, where no prior lease exists to convert, the cmdlet is called
        with only the three mandatory parameters (ScopeId, ClientId, IPAddress) plus
        -WhatIf so the DHCP server validates the request without writing.
        Delegates result and diff emission to Write-LeaseResult with
        -FetchAsReservation so the post-write re-read uses
        Get-DhcpServerv4Reservation.
    .PARAMETER LeaseParams
        Hashtable of parameters including at minimum ClientId, IPAddress, ScopeId,
        Name. HostName is removed internally if present.
    #>
    Param([hashtable]$LeaseParams)

    # Add-DhcpServerv4Reservation does not accept a HostName parameter;
    # clone to avoid mutating the caller's hashtable
    $resParams = $LeaseParams.Clone()
    $resParams.Remove('HostName')

    try {
        if ($module.CheckMode) {
            # In check_mode no prior lease exists — supply only mandatory params
            Add-DhcpServerv4Reservation -ScopeId $resParams.ScopeId -ClientId $resParams.ClientId `
                -IPAddress $resParams.IPAddress -WhatIf @extra_args -ErrorAction Stop
        }
        else {
            Add-DhcpServerv4Reservation @resParams @extra_args -ErrorAction Stop
        }
    }
    catch {
        $module.FailJson("Could not create DHCP reservation: $($_.Exception.Message)", $_)
    }

    Write-LeaseResult -OriginalLease @{} -Params $resParams -ClientId $resParams.ClientId -ScopeId $resParams.ScopeId -FetchAsReservation
}

# ---------------------------------------------------------------------------
# Conversion functions
# ---------------------------------------------------------------------------

Function Convert-DhcpLeaseToReservation {
    <#
    .SYNOPSIS
        Converts an existing plain lease to a reservation.
    .DESCRIPTION
        Promotes a plain lease to a reservation by calling Add-DhcpServerv4Reservation
        on the existing lease object, then immediately updates the reservation with the
        resolved params via Set-DhcpServerv4Reservation. The two-step approach is
        required because Add-DhcpServerv4Reservation does not accept all reservation
        attributes (e.g. Description) in one call.
        In check_mode both cmdlets receive -WhatIf and the intermediate re-read is
        skipped. Write-LeaseResult handles the final result and diff emission.
    .PARAMETER CurrentLease
        The existing plain DhcpServerv4Lease object to promote.
    .PARAMETER Params
        Resolved reservation params from New-ReservationParamSet.
    #>
    Param($CurrentLease, [hashtable]$Params)

    $originalSummary = ConvertTo-LeaseSummaryFromObject -Object $CurrentLease

    try {
        $CurrentLease | Add-DhcpServerv4Reservation @Params -WhatIf:$module.CheckMode @extra_args -ErrorAction Stop
    }
    catch {
        $module.FailJson("Could not convert lease to reservation: $($_.Exception.Message)", $_)
    }

    if (-not $module.CheckMode) {
        # Re-read after promotion so Set-DhcpServerv4Reservation has a live object to pipe
        try {
            $promoted = Get-DhcpServerv4Lease -ClientId $Params.ClientId -ScopeId $CurrentLease.ScopeId.IPAddressToString @extra_args -ErrorAction Stop
        }
        catch {
            $module.FailJson("Could not retrieve entry after lease to reservation promotion: $($_.Exception.Message)", $_)
        }

        try {
            # Apply remaining attributes (Description, Name) that Add- does not accept
            $promoted | Set-DhcpServerv4Reservation @Params -WhatIf:$module.CheckMode @extra_args -ErrorAction Stop
        }
        catch {
            $module.FailJson("Could not update reservation after promotion: $($_.Exception.Message)", $_)
        }
    }

    Write-LeaseResult -OriginalLease $originalSummary -Params $Params -ClientId $Params.ClientId -ScopeId $CurrentLease.ScopeId.IPAddressToString
}

Function Convert-DhcpReservationToLease {
    <#
    .SYNOPSIS
        Converts an existing reservation to a plain lease.
    .DESCRIPTION
        Removes the reservation then immediately creates a new plain lease using
        the identity attributes (ClientId, IPAddress, ScopeId, HostName) preserved
        from the original reservation object. AddressState is forced to 'Active'.
        The two operations are intentionally not wrapped in a single transaction —
        if Add-DhcpServerv4Lease fails after the reservation has been removed the
        operator will need to recreate it, which is consistent with the original
        module behaviour. Write-LeaseResult handles result and diff emission.
    .PARAMETER CurrentLease
        The existing DhcpServerv4Reservation object to demote.
    #>
    Param($CurrentLease)

    $originalSummary = ConvertTo-LeaseSummaryFromObject -Object $CurrentLease

    # Capture identity attributes before removing the reservation
    $leaseParams = @{
        ClientId = $CurrentLease.ClientId
        IPAddress = $CurrentLease.IPAddress.IPAddressToString
        ScopeId = $CurrentLease.ScopeId.IPAddressToString
        HostName = $CurrentLease.HostName
        AddressState = 'Active'
    }

    try {
        $CurrentLease | Remove-DhcpServerv4Reservation -WhatIf:$module.CheckMode @extra_args -ErrorAction Stop
    }
    catch {
        $module.FailJson("Could not remove reservation during conversion: $($_.Exception.Message)", $_)
    }

    try {
        Add-DhcpServerv4Lease @leaseParams -WhatIf:$module.CheckMode @extra_args -ErrorAction Stop
    }
    catch {
        $module.FailJson("Could not create lease during reservation to lease conversion: $($_.Exception.Message)", $_)
    }

    Write-LeaseResult -OriginalLease $originalSummary -Params $leaseParams -ClientId $leaseParams.ClientId -ScopeId $leaseParams.ScopeId
}

# ---------------------------------------------------------------------------
# Update function
# ---------------------------------------------------------------------------

Function Update-DhcpReservation {
    <#
    .SYNOPSIS
        Updates attributes on an existing DHCP reservation.
    .DESCRIPTION
        Pipes the current reservation into Set-DhcpServerv4Reservation with the
        resolved params. Delegates result and diff emission to Write-LeaseResult
        which re-reads the reservation after the update so that Result.changed
        reflects the actual server state rather than the intended state.
        In check_mode Set-DhcpServerv4Reservation receives -WhatIf and
        Write-LeaseResult derives the result from the params hashtable.
    .PARAMETER CurrentLease
        The existing DhcpServerv4Reservation object to update.
    .PARAMETER Params
        Resolved reservation params from New-ReservationParamSet.
    #>
    Param($CurrentLease, [hashtable]$Params)

    $originalSummary = ConvertTo-LeaseSummaryFromObject -Object $CurrentLease

    try {
        $CurrentLease | Set-DhcpServerv4Reservation @Params -WhatIf:$module.CheckMode @extra_args -ErrorAction Stop
    }
    catch {
        $module.FailJson("Could not update DHCP reservation: $($_.Exception.Message)", $_)
    }

    Write-LeaseResult -OriginalLease $originalSummary -Params $Params -ClientId $CurrentLease.ClientId -ScopeId $CurrentLease.ScopeId.IPAddressToString
}

# ---------------------------------------------------------------------------
# State dispatchers
# ---------------------------------------------------------------------------

Function Invoke-AbsentState {
    <#
    .SYNOPSIS
        Ensures the target DHCP entry does not exist (state=absent).
    .DESCRIPTION
        If no entry was found the module is already in the desired state and
        a message is returned without setting changed. Otherwise dispatches to
        Remove-DhcpReservation or Remove-DhcpLease based on the entry type.
    .PARAMETER CurrentLease
        The existing DHCP object, or $null if no entry was found.
    .PARAMETER IsReservation
        $true when the existing entry is a reservation, $false for a plain lease.
    #>
    Param($CurrentLease, [bool]$IsReservation)

    if (-not $CurrentLease) {
        # Already absent — nothing to do
        $module.Result.msg = "The lease doesn't exist."
        return
    }

    if ($IsReservation) {
        Remove-DhcpReservation -Lease $CurrentLease
    }
    else {
        Remove-DhcpLease -Lease $CurrentLease
    }
}

Function Invoke-PresentState {
    <#
    .SYNOPSIS
        Ensures the target DHCP entry exists and matches the desired configuration (state=present).
    .DESCRIPTION
        Routes to the appropriate leaf function based on whether an entry currently
        exists and what its type is:

          No existing entry  + type=lease        -> New-DhcpLease
          No existing entry  + type=reservation  -> New-DhcpReservation
          Plain lease exists + type=reservation  -> Convert-DhcpLeaseToReservation
          Plain lease exists + type=lease        -> already correct type, no action
          Reservation exists + type=lease        -> Convert-DhcpReservationToLease
          Reservation exists + type=reservation  -> Update-DhcpReservation

        Scope_id is required when creating a new entry (the server cannot infer it).
        Uses script-scope variables: $scope_id, $mac_dashed, $ip, $duration,
        $dns_hostname, $dns_regtype, $description, $reservation_name, $type.
    .PARAMETER CurrentLease
        The existing DHCP object, or $null if no entry was found.
    .PARAMETER IsReservation
        $true when the existing entry is a reservation, $false for a plain lease.
    #>
    Param($CurrentLease, [bool]$IsReservation)

    # --- No existing entry: create ---
    if (-not $CurrentLease) {
        if (-not $scope_id) {
            $module.FailJson("The scope_id parameter is required for state=present when no lease or reservation exists")
        }

        if ($type -eq "lease") {
            $leaseParams = @{
                ClientId = $mac_dashed
                IPAddress = $ip
                ScopeId = $scope_id
                AddressState = 'Active'
                Confirm = $false
            }
            if ($dns_hostname) { $leaseParams.HostName = $dns_hostname }
            if ($description) { $leaseParams.Description = $description }
            if ($duration) { $leaseParams.LeaseExpiryTime = (Get-Date).AddDays($duration) }
            if ($dns_regtype) { $leaseParams.DnsRR = $dns_regtype }

            New-DhcpLease -LeaseParams $leaseParams
        }
        else {
            # Build base params then apply reservation-specific resolution
            $baseParams = @{
                IPAddress = $ip
                ScopeId = $scope_id
                Confirm = $false
            }
            if ($dns_hostname) { $baseParams.HostName = $dns_hostname }
            if ($description) { $baseParams.Description = $description }

            # New-ReservationParamSet resolves ClientId and Name
            $resParams = New-ReservationParamSet -CurrentLease $null `
                -MacDashed $mac_dashed -Description $description `
                -ReservationName $reservation_name
            # Merge base params into the resolved set
            foreach ($key in $baseParams.Keys) {
                if (-not $resParams.ContainsKey($key)) { $resParams[$key] = $baseParams[$key] }
            }

            New-DhcpReservation -LeaseParams $resParams
        }
    }
    # --- Existing plain lease ---
    elseif (-not $IsReservation) {
        if ($type -eq "reservation") {
            # Promote the plain lease to a reservation
            $params = New-ReservationParamSet -CurrentLease $CurrentLease `
                -MacDashed $mac_dashed -Description $description `
                -ReservationName $reservation_name
            Convert-DhcpLeaseToReservation -CurrentLease $CurrentLease -Params $params
        }
        elseif ($duration -or $description -or $dns_hostname -or $dns_regtype) {
            # type=lease and entry already exists: no fields can be updated without
            # remove and recreate. Set-DhcpServerv4Lease does not exist in the Windows
            # DHCP module — destructive update is out of scope for this module.
            # Emit a debug message for each ignored parameter so the operator knows
            # their input was received but could not be applied.
            if ($duration) {
                $module.Debug("duration is ignored on an existing lease: Set-DhcpServerv4Lease does not exist. Remove and recreate the lease to change it.")
            }
            if ($description) {
                $module.Debug("description is ignored on an existing lease: Set-DhcpServerv4Lease does not exist. Remove and recreate the lease to change it.")
            }
            if ($dns_hostname) {
                $module.Debug("dns_hostname is ignored on an existing lease: Set-DhcpServerv4Lease does not exist. Remove and recreate the lease to change it.")
            }
            if ($dns_regtype) {
                $module.Debug("dns_regtype is ignored on an existing lease: Set-DhcpServerv4Lease does not exist. Remove and recreate the lease to change it.")
            }
        }
        # else: type=lease, no duration supplied — desired state already reached, nothing to do
    }
    # --- Existing reservation ---
    else {
        if ($type -eq "lease") {
            # Demote the reservation to a plain lease
            Convert-DhcpReservationToLease -CurrentLease $CurrentLease
        }
        else {
            # Update reservation attributes in place
            $params = New-ReservationParamSet -CurrentLease $CurrentLease `
                -MacDashed $mac_dashed -Description $description `
                -ReservationName $reservation_name
            Update-DhcpReservation -CurrentLease $CurrentLease -Params $params
        }
    }
}

# ---------------------------------------------------------------------------
# Module entry point
# ---------------------------------------------------------------------------

# Import the Windows DHCP Server PowerShell module.
# SkipEditionCheck is required on PowerShell Core (pwsh) because the DhcpServer
# CDXML module has not declared itself compatible with the Core edition, even
# though it works in practice. Re-evaluate on future Windows Server releases.
$importParams = @{ Name = 'DhcpServer' }
if ($IsCoreCLR) {
    $importParams.SkipEditionCheck = $true
}
try {
    Import-Module @importParams -ErrorAction Stop
}
catch {
    $module.FailJson("The DhcpServer module failed to load properly: $($_.Exception.Message)", $_)
}

# Normalise MAC address to uppercase dash-separated format expected by DHCP cmdlets
$mac_dashed = $null
if ($mac) {
    $mac_dashed = ConvertTo-DashedMac -Mac $mac
    if ($mac_dashed -eq $false) {
        $module.FailJson("The MAC address is not properly formatted")
    }
}

# Translate Ansible dns_regtype choice to the DHCP cmdlet enum string
if ($dns_regtype) {
    $dns_regtype = ConvertTo-DnsRegType -RegType $dns_regtype
}

# Locate any existing entry matching the supplied MAC and/or IP.
# ScopeId is passed when available to narrow the server-side search.
$current_lease = Find-DhcpLease -MacDashed $mac_dashed -IpAddress $ip -ScopeId $scope_id

# Determine whether the found entry (if any) is a reservation
$is_reservation = $current_lease -and ($current_lease.AddressState -like "*Reservation*")

# Capture the before state for Ansible diff mode
if ($current_lease) {
    $module.Diff.before = ConvertTo-LeaseSummaryFromObject -Object $current_lease
}

if ($state -eq "absent") {
    Invoke-AbsentState -CurrentLease $current_lease -IsReservation $is_reservation
}
else {
    Invoke-PresentState -CurrentLease $current_lease -IsReservation $is_reservation
}

$module.ExitJson()