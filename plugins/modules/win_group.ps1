#!powershell

# Copyright: (c) 2014, Chris Hoffman <choffman@chathamfinancial.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        description = @{
            type = 'str'
        }
        members = @{
            type = 'dict'
            options = @{
                add = @{
                    type = 'list'
                    elements = 'str'
                    default = @()
                }
                remove = @{
                    type = 'list'
                    elements = 'str'
                    default = @()
                }
                set = @{
                    type = 'list'
                    elements = 'str'
                }
            }
            mutually_exclusive = @(
                , @('set', 'add')
                , @('set', 'remove')
            )
        }
        name = @{
            type = 'str'
            required = $true
        }
        state = @{
            type = 'str'
            default = 'present'
            choices = 'absent', 'present'
        }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$name = $module.Params.name
$state = $module.Params.state
$description = $module.Params.description
$members = $module.Params.members

$module.Diff.before = $null
$module.Diff.after = $null
$module.Result.sid = $null

Function ConvertTo-NTAccount {
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]
        $InputObject
    )

    process {
        foreach ($sid in $InputObject) {
            $sid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $sid
            try {
                $sid.Translate([System.Security.Principal.NTAccount]).Value
            }
            catch [System.Security.Principal.IdentityNotMappedException] {
                $sid.Value
            }
        }
    }
}

Function ConvertTo-SecurityIdentifier {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingEmptyCatchBlock", "",
        Justification = "We are using this to check if the input is a valid SID value.")]
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string[]]
        $InputObject
    )

    process {
        foreach ($name in $InputObject) {
            try {
                $sid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $name
                $sid.Value
                continue
            }
            catch [System.ArgumentException] {}

            $domain = $null
            $username = $name
            if ($username -like '*\*') {
                $domain, $username = $username -split '\\', 2
                if ($domain -eq '.') {
                    $domain = $env:COMPUTERNAME
                }
            }

            $account = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList @(
                if ($domain) {
                    $domain
                }
                $username
            )

            try {
                $account.Translate([System.Security.Principal.SecurityIdentifier]).Value
            }
            catch {
                $exp = New-Object -TypeName System.ArgumentException -ArgumentList @(
                    "Failed to translate '$name' to a SecurityIdentifier: $_",
                    $_.Exception
                )
                $err = New-Object -TypeName System.Management.Automation.ErrorRecord -ArgumentList @(
                    $exp,
                    'FailedToTranslateAccount',
                    'InvalidArgument',
                    $name)
                $PSCmdlet.WriteError($err)
            }
        }
    }
}

$adsi = [ADSI]"WinNT://$env:COMPUTERNAME"
$group = $adsi.Children | Where-Object { $_.SchemaClassName -eq 'group' -and $_.Name -eq $name }

[string[]]$existingSids = @()
if ($group) {
    $adsiMembers = $Group.PSBase.Invoke("Members")
    $existingSids = @(
        foreach ($member in $adsiMembers) {
            $sidBytes = ([ADSI]$member).InvokeGet("objectSID")
            $sid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $sidBytes, 0
            $sid.Value
        }
    )

    $module.Diff.before = @{
        name = $name
        # ADSI returns a collection for values even if they are single valued,
        # this ensures it's a single value in the diff output
        description = $group.Description | Select-Object -First 1
        members = @(
            $existingSids | ConvertTo-NTAccount | Sort-Object
        )
    }
}

if ($state -eq "present") {
    if (-not $group) {
        if (-not $module.CheckMode) {
            $group = $adsi.Create("Group", $name)
            $group.SetInfo()
        }
        else {
            $module.Result.sid = "S-1-5-0000"
        }

        $module.Result.changed = $true
    }

    [System.Collections.Generic.HashSet[string]]$diffMembers = @()

    # If in check mode and the group was created we skip the extra checks
    if ($group) {
        $sidBytes = ([ADSI]$group).InvokeGet("objectSID")
        $sid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $sidBytes, 0
        $module.Result.sid = $sid.Value

        $existingDescription = $group.Description | Select-Object -First 1

        if ($null -ne $description) {
            if ($existingDescription -ne $description) {
                if (-not $module.CheckMode) {
                    $group.Description = $description
                    $group.SetInfo()
                }
                $module.Result.changed = $true
            }
        }
        else {
            # For diff output
            $description = $existingDescription
        }

        [System.Collections.Generic.HashSet[string]]$toAdd = @()
        [System.Collections.Generic.HashSet[string]]$toRemove = @()
        if ($null -ne $members.set) {
            [string[]]$setMembers = @($members.set | ConvertTo-SecurityIdentifier)

            $toAdd = [System.Linq.Enumerable]::Except($setMembers, $existingSids)
            $toRemove = [System.Linq.Enumerable]::Except($existingSids, $setMembers)
        }
        else {
            if ($members.add) {
                [string[]]$addMembers = $members.add | ConvertTo-SecurityIdentifier
                $toAdd = [System.Linq.Enumerable]::Except($addMembers, $existingSids)
            }
            if ($members.remove) {
                [string[]]$removeMembers = $members.remove | ConvertTo-SecurityIdentifier
                $toRemove = [System.Linq.Enumerable]::Intersect($removeMembers, $existingSids)


            }
        }

        $diffMembers = $existingSids
        $toAdd | ForEach-Object {
            if (-not $module.CheckMode) {
                $group.Add("WinNT://$_")
            }
            $module.Result.changed = $true
            $null = $diffMembers.Add($_)
        }
        $toRemove | ForEach-Object {
            if (-not $module.CheckMode) {
                $group.Remove("WinNT://$_")
            }
            $module.Result.changed = $true
            $null = $diffMembers.Remove($_)
        }
    }

    $module.Diff.after = @{
        name = $name
        description = $description
        members = @(
            $diffMembers | ConvertTo-NTAccount | Sort-Object -Unique
        )
    }
}
elseif ($state -eq "absent" -and $group) {
    if (-not $module.CheckMode) {
        $adsi.Delete("Group", $group.Name.Value)
    }
    $module.Result.changed = $true
}

$module.ExitJson()
