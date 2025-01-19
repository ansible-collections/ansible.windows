#!powershell

# Copyright: (c) 2017, Andrew Saraceni <andrew.saraceni@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy
#Requires -Module Ansible.ModuleUtils.SID

$ErrorActionPreference = "Stop"

Function Get-InputMember {
    <#
    .SYNOPSIS
    Converts the input member list to a unique list of accounts and their SIDs.
    .PARAMETER Member
    The input members.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]
        $Member
    )

    begin {
        $member_list = [System.Collections.Generic.HashSet[string]]@()
    }

    process {
        foreach ($m in $Member) {
            $sid = Convert-ToSID -account_name $m
            if ($member_list.Add($sid)) {
                $account_name = Convert-FromSID -sid $sid
                @{
                    sid = $sid
                    account_name = $account_name
                }
            }
        }
    }
}

function Get-GroupMember {
    <#
    .SYNOPSIS
    Retrieve group members for a given group, and return in a common format.
    .NOTES
    Returns an array of hashtables of the same type as returned from Test-GroupMember.
    #>
    param(
        [System.DirectoryServices.DirectoryEntry]$Group
    )

    # instead of using ForEach pipeline we use a standard loop and cast the
    # object to the ADSI adapter type before using it to get the SID and path
    # this solves an random issue where multiple casts could fail once the raw
    # object is invoked at least once
    $raw_members = $Group.psbase.Invoke("Members")
    $current_members = [System.Collections.ArrayList]@()
    foreach ($raw_member in $raw_members) {
        $raw_member = [ADSI]$raw_member
        $sid_bytes = $raw_member.InvokeGet("objectSID")
        $ads_path = $raw_member.InvokeGet("ADsPath")
        $member_info = @{
            sid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $sid_bytes, 0
            adspath = $ads_path
        }
        $current_members.Add($member_info) > $null
    }

    $members = @()
    foreach ($current_member in $current_members) {
        $parsed_member = @{
            sid = $current_member.sid
            account_name = $null
        }

        $rootless_adspath = $current_member.adspath.Replace("WinNT://", "")
        $split_adspath = $rootless_adspath.Split("/")

        # Ignore lookup on a broken SID, and just return the SID as the account_name
        if ($split_adspath.Count -eq 1 -and $split_adspath[0] -like "S-1*") {
            $parsed_member.account_name = $split_adspath[0]
        }
        else {
            $account_name = Convert-FromSID -sid $current_member.sid
            $parsed_member.account_name = $account_name
        }

        $members += $parsed_member
    }

    return $members
}

$params = Parse-Args $args -supports_check_mode $true
$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -type "bool" -default $false

$name = Get-AnsibleParam -obj $params -name "name" -type "str" -failifempty $true
$members = Get-AnsibleParam -obj $params -name "members" -type "list" -failifempty $true
$state = Get-AnsibleParam -obj $params -name "state" -type "str" -default "present" -validateset "present", "absent", "pure"

$result = @{
    changed = $false
    name = $name
}
if ($state -in @("present", "pure")) {
    $result.added = @()
}
if ($state -in @("absent", "pure")) {
    $result.removed = @()
}

$adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
$group = $adsi.Children | Where-Object { $_.SchemaClassName -eq "group" -and $_.Name -eq $name }

if (!$group) {
    Fail-Json -obj $result -message "Could not find local group $name"
}

$target_members = $members | Get-InputMember
$current_members = Get-GroupMember -Group $group
$pure_members = @()

foreach ($member in $target_members) {
    if ($state -eq "pure") {
        $pure_members += $member
    }

    $user_in_group = $false
    foreach ($current_member in $current_members) {
        if ($current_member.sid -eq $member.sid) {
            $user_in_group = $true
            break
        }
    }

    $member_sid = "WinNT://{0}" -f $member.sid

    try {
        if ($state -in @("present", "pure") -and !$user_in_group) {
            if (!$check_mode) {
                $group.Add($member_sid)
            }
            $result.added += $member.account_name
            $result.changed = $true
        }
        elseif ($state -eq "absent" -and $user_in_group) {
            if (!$check_mode) {
                $group.Remove($member_sid)
            }
            $result.removed += $member.account_name
            $result.changed = $true
        }
    }
    catch {
        Fail-Json -obj $result -message $_.Exception.Message
    }
}

if ($state -eq "pure") {
    # Perform removals for existing group members not defined in $members
    $current_members = Get-GroupMember -Group $group

    foreach ($current_member in $current_members) {
        $user_to_remove = $true
        foreach ($pure_member in $pure_members) {
            if ($pure_member.sid -eq $current_member.sid) {
                $user_to_remove = $false
                break
            }
        }

        $member_sid = "WinNT://{0}" -f $current_member.sid

        try {
            if ($user_to_remove) {
                if (!$check_mode) {
                    $group.Remove($member_sid)
                }
                $result.removed += $current_member.account_name
                $result.changed = $true
            }
        }
        catch {
            Fail-Json -obj $result -message $_.Exception.Message
        }
    }
}

$final_members = Get-GroupMember -Group $group

if ($final_members) {
    $result.members = [Array]$final_members.account_name
}
else {
    $result.members = @()
}

if ($check_mode) {
    if ($result.added.count -gt 0) {
        $result.members += $result.added
    }
    if ($result.removed.count -gt 0) {
        $result.members = $result.members | Where-Object { $_ -notin $result.removed }
    }
}

Exit-Json -obj $result
