#!powershell

# Copyright: (c) 2014, Paul Durivage <paul.durivage@rackspace.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.AccessToken
#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        account_disabled = @{ type = 'bool' }
        account_locked = @{ type = 'bool' }
        description = @{ type = 'str' }
        fullname = @{ type = 'str' }
        groups = @{ type = 'list'; elements = 'str' }
        groups_action = @{ type = 'str'; choices = 'add', 'remove', 'replace'; default = 'replace' }
        home_directory = @{ type = 'str' }
        login_script = @{ type = 'str' }
        name = @{ type = 'str'; required = $true }
        password = @{ type = 'str'; no_log = $true }
        password_expired = @{ type = 'bool' }
        password_never_expires = @{ type = 'bool' }
        profile = @{ type = 'str' }
        state = @{ type = 'str'; choices = 'present', 'absent', 'query'; default = 'present' }
        update_password = @{ type = 'str'; choices = 'always', 'on_create'; default = 'always' }
        user_cannot_change_password = @{ type = 'bool' }

    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$accountDisabled = $module.Params.account_disabled
$accountLocked = $module.Params.account_locked
$description = $module.Params.description
$fullname = $module.Params.fullname
$groups = $module.Params.groups
$groupsAction = $module.Params.groups_action
$homeDirectory = $module.Params.home_directory
$loginScript = $module.Params.login_script
$name = $module.Params.name
$password = $module.Params.password
$passwordExpired = $module.Params.password_expired
$passwordNeverExpires = $module.Params.password_never_expires
$userProfile = $module.Params.profile
$state = $module.Params.state
$updatePassword = $module.Params.update_password
$userCannotChangePassword = $module.Params.user_cannot_change_password

$module.Diff.before = ""
$module.Diff.after = ""

if ($accountLocked -eq $true) {
    $module.FailJson("account_locked must be set to 'no' if provided")
}

$ADS_UF_PASSWD_CANT_CHANGE = 64
$ADS_UF_DONT_EXPIRE_PASSWD = 65536
$ADSI = [ADSI]"WinNT://$env:COMPUTERNAME"

Function Get-AnsibleLocalGroup {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Sid
    )

    $groupSid = New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList $Sid

    $ADSI.Children | Where-Object {
        if ($_.SchemaClassName -ne 'Group') {
            return $false
        }

        $sid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $_.ObjectSid.Value, 0
        return $sid -eq $groupSid

    } | ForEach-Object -Process {
        [PSCustomObject]@{
            Name = $_.Name.Value
            SecurityIdentifier = $groupSid
            BaseObject = $_
        }
    }
}

Function Get-AnsibleLocalUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Name
    )

    $ADSI.Children | Where-Object {
        $_.SchemaClassName -eq 'User' -and $_.Name -eq $Name

    } | ForEach-Object -Process {
        $sid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $_.ObjectSid.Value, 0
        $flags = $_.UserFlags.Value

        [PSCustomObject]@{
            Name = $_.Name.Value
            FullName = $_.FullName.Value
            Path = $_.Path
            Description = $_.Description.Value
            HomeDirectory = $_.HomeDirectory.Value
            LoginScript = $_.LoginScript.Value
            PasswordExpired = [bool]$_.PasswordExpired.Value
            PasswordNeverExpires = [bool]($flags -band $ADS_UF_DONT_EXPIRE_PASSWD)
            Profile = $_.Profile.Value
            UserCannotChangePassword = [bool]($flags -band $ADS_UF_PASSWD_CANT_CHANGE)
            AccountDisabled = $_.AccountDisabled
            IsAccountLocked = $_.IsAccountLocked
            SecurityIdentifier = $sid
            Groups = @(
                $_.Groups() | ForEach-Object -Process {
                    $rawSid = $_.GetType().InvokeMember('ObjectSid', 'GetProperty', $null, $_, $null)
                    $groupSid = New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList $rawSid, 0

                    [PSCustomObject]@{
                        Name = $_.GetType().InvokeMember('Name', 'GetProperty', $null, $_, $null)
                        Path = $_.GetType().InvokeMember('ADsPath', 'GetProperty', $null, $_, $null)
                        SecurityIdentifier = $groupSid
                    }
                })
            BaseObject = $_
        }
    }
}

Function Get-UserDiff {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $User
    )

    if (-not $User) {
        ""

    }
    else {
        $groups = [System.Collections.Generic.List[String]]@()
        foreach ($group in $User.Groups) {
            try {
                $name = $group.SecurityIdentifier.Translate([Security.Principal.NTAccount]).Value
            }
            catch [Security.Principal.IdentityNotMappedException] {
                $name = $group.Name
            }
            $groups.Add($name)
        }

        @{
            account_disabled = $User.AccountDisabled
            account_locked = $User.IsAccountLocked
            description = $User.Description
            fullname = $User.FullName
            groups = $groups
            home_directory = $User.HomeDirectory
            login_script = $User.LoginScript
            name = $User.Name
            password = 'REDACTED'
            password_expired = $User.PasswordExpired
            password_never_expires = $User.PasswordNeverExpires
            profile = $User.Profile
            user_cannot_change_password = $User.UserCannotChangePassword
        }
    }
}

Function Test-LocalCredential {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]
        $Username,

        [Parameter(Mandatory = $true)]
        [String]
        $Password
    )

    try {
        $handle = [Ansible.AccessToken.TokenUtil]::LogonUser($Username, ".", $Password, "Network", "Default")
        $handle.Dispose()
        $isValid = $true
    }
    catch [Ansible.AccessToken.Win32Exception] {
        # following errors indicate the creds are correct but the user was
        # unable to log on for other reasons, which we don't care about
        $successCodes = @(
            0x0000052F, # ERROR_ACCOUNT_RESTRICTION
            0x00000530, # ERROR_INVALID_LOGON_HOURS
            0x00000531, # ERROR_INVALID_WORKSTATION
            0x00000569  # ERROR_LOGON_TYPE_GRANTED
        )

        if ($_.Exception.NativeErrorCode -eq 0x0000052E) {
            # ERROR_LOGON_FAILURE - the user or pass was incorrect
            $isValid = $false
        }
        elseif ($_.Exception.NativeErrorCode -in $successCodes) {
            $isValid = $true
        }
        else {
            # an unknown failure, reraise exception
            throw $_
        }
    }

    $isValid
}

$user = Get-AnsibleLocalUser -Name $name
$module.Diff.before = Get-UserDiff -User $user

if ($state -eq 'present') {
    if (-not $user) {
        $module.Diff.after = @{name = $name }

        $userAdsi = $ADSI.Create('User', $name)
        if ($null -ne $password) {
            $userAdsi.SetPassword($password)
            $module.Diff.after.password = 'REDACTED'
        }

        if (-not $module.CheckMode) {
            $userAdsi.SetInfo()
            $user = Get-AnsibleLocalUser -Name $name
        }

        $module.Result.changed = $true
    }

    # When in check mode and a new user was created, $user will still be $null
    if ($user) {
        $module.Diff.after = Get-UserDiff -User $user

        if ($null -ne $password -and $updatePassword -eq 'always') {
            # ValidateCredentials will fail if either of these are true- just force update...
            if ($user.AccountDisabled -or $user.PasswordExpired) {
                $passwordMatch = $false

            }
            else {
                try {
                    $passwordMatch = Test-LocalCredential -Username $user.Name -Password $password
                }
                catch [System.ComponentModel.Win32Exception] {
                    $module.FailJson("Failed to validate the user's credentials: $($_.Exception.Message)", $_)
                }
            }

            if (-not $passwordMatch) {
                if (-not $module.CheckMode) {
                    $user.BaseObject.SetPassword($password)
                }
                $module.Result.changed = $true
                $module.Diff.after.password = 'CHANGED REDACTED'
            }
        }

        if ($null -ne $accountDisabled -and $accountDisabled -ne $user.AccountDisabled) {
            $user.BaseObject.AccountDisabled = $accountDisabled
            $module.Result.changed = $true
            $module.Diff.after.account_disabled = $accountDisabled
        }

        if ($null -ne $accountLocked -and $accountLocked -ne $user.IsAccountLocked) {
            $user.BaseObject.IsAccountLocked = $accountLocked
            $module.Result.changed = $true
            $module.Diff.after.account_locked = $accountLocked
        }

        if ($null -ne $fullname -and $fullname -cne $user.FullName) {
            $user.BaseObject.FullName = $fullname
            $module.Result.changed = $true
            $module.Diff.after.fullname = $fullname
        }

        if ($null -ne $description -and $description -cne $user.Description) {
            $user.BaseObject.Description = $description
            $module.Result.changed = $true
            $module.Diff.after.description = $description
        }

        if ($null -ne $homeDirectory -and $homeDirectory -ne $user.HomeDirectory) {
            $user.BaseObject.HomeDirectory = $homeDirectory
            $module.Result.changed = $true
            $module.Diff.after.home_directory = $homeDirectory
        }

        if ($null -ne $loginScript -and $loginScript -ne $user.LoginScript) {
            $user.BaseObject.LoginScript = $loginScript
            $module.Result.changed = $true
            $module.Diff.after.login_script = $loginScript
        }

        if ($null -ne $passwordExpired -and $passwordExpired -ne $user.PasswordExpired) {
            $user.BaseObject.PasswordExpired = [int]$passwordExpired
            $module.Result.changed = $true
            $module.Diff.after.password_expired = $passwordExpired
        }

        if ($null -ne $passwordNeverExpires -and $passwordNeverExpires -ne $user.PasswordNeverExpires) {
            if ($passwordNeverExpires) {
                $newFlags = $user.BaseObject.UserFlags.Value -bor $ADS_UF_DONT_EXPIRE_PASSWD
            }
            else {
                $newFlags = $user.BaseObject.UserFlags.Value -bxor $ADS_UF_DONT_EXPIRE_PASSWD
            }
            $user.BaseObject.UserFlags = $newFlags
            $module.Result.changed = $true
            $module.Diff.after.password_never_expires = $passwordNeverExpires
        }

        if ($null -ne $userProfile -and $userProfile -ne $user.Profile) {
            $user.BaseObject.Profile = $userProfile
            $module.Result.changed = $true
            $module.Diff.after.profile = $userProfile
        }

        if ($null -ne $userCannotChangePassword -and $userCannotChangePassword -ne $user.UserCannotChangePassword) {
            if ($userCannotChangePassword) {
                $newFlags = $user.BaseObject.UserFlags.Value -bor $ADS_UF_PASSWD_CANT_CHANGE
            }
            else {
                $newFlags = $user.BaseObject.UserFlags.Value -bxor $ADS_UF_PASSWD_CANT_CHANGE
            }
            $user.BaseObject.UserFlags = $newFlags
            $module.Result.changed = $true
            $module.Diff.after.user_cannot_change_password = $userCannotChangePassword
        }

        if ($module.Result.changed -and -not $module.CheckMode) {
            $user.BaseObject.SetInfo()
        }

        if ($null -ne $groups) {
            $desiredGroups = [string[]]@($groups | Where-Object { -not [String]::IsNullOrWhiteSpace($_) } | ForEach-Object -Process {
                    $inputGroup = $_

                    try {
                        $sid = New-Object -TypeName Security.Principal.SecurityIdentifier -ArgumentList $inputGroup
                    }
                    catch [ArgumentException] {
                        $account = New-Object -TypeName Security.Principal.NTAccount -ArgumentList $inputGroup

                        try {
                            $sid = $account.Translate([Security.Principal.SecurityIdentifier])
                        }
                        catch [Security.Principal.IdentityNotMappedException] {
                            $module.FailJson("group '$inputGroup' not found")
                        }
                    }

                    # Make sure the group specified in the module args are an actual local group.
                    if (-not (Get-AnsibleLocalGroup -Sid $sid.Value)) {
                        $module.FailJson("group '$inputGroup' not found")
                    }

                    $sid.Value
                })
            $existingGroups = [string[]]@($user.Groups.SecurityIdentifier.Value)

            $toAdd = [string[]]@()
            $toRemove = [string[]]@()
            if ($groupsAction -eq 'add') {
                $toAdd = [Linq.Enumerable]::Except($desiredGroups, $existingGroups)

            }
            elseif ($groupsAction -eq 'remove') {
                $toRemove = [Linq.Enumerable]::Intersect($desiredGroups, $existingGroups)

            }
            else {
                $toAdd = [Linq.Enumerable]::Except($desiredGroups, $existingGroups)
                $toRemove = [Linq.Enumerable]::Except($existingGroups, $desiredGroups)
            }

            $actionMap = @{
                Add = $toAdd
                Remove = $toRemove
            }
            foreach ($action in $actionMap.GetEnumerator()) {
                foreach ($group in $action.Value) {
                    if (-not $group) {
                        continue
                    }
                    $groupAdsi = Get-AnsibleLocalGroup -Sid $group

                    if (-not $module.CheckMode) {
                        try {
                            if ($action.Key -eq 'Add') {
                                $groupAdsi.BaseObject.Add($user.Path)
                            }
                            else {
                                $groupAdsi.BaseObject.Remove($user.Path)
                            }
                        }
                        catch {
                            $module.FailJson(
                                "Failed to $($action.Key.ToLower()) $($groupAdsi.Name): $($_.Exception.Message)", $_
                            )
                        }
                    }
                    $module.Result.changed = $true

                    if ($action.Key -eq 'Add') {
                        $module.Diff.after.groups.Add($groupAdsi.Name)
                    }
                    else {
                        $null = $module.Diff.after.groups.Remove($groupAdsi.Name)
                    }
                }
            }
        }
    }
    $module.Result.state = 'present'

}
elseif ($state -eq 'absent') {
    if ($user) {
        if (-not $module.CheckMode) {
            $ADSI.Delete('User', $user.Name)
        }
        $module.Result.changed = $true
        $module.Result.msg = "User '$($user.Name)' deleted successfully"
        $user = $null

    }
    else {
        $module.Result.msg = "User '$name' was not found"
    }

    $module.Result.state = 'absent'
    $module.Diff.after = ""

}
else {
    $module.Result.msg = "Querying user '$name'"
    $module.Result.state = if ($user) { 'present' } else { 'absent' }
    $module.Diff.after = $module.Diff.before
}

$user = Get-AnsibleLocalUser -Name $name
$module.Result.name = $name

if ($user) {
    $module.Result.fullname = $user.FullName
    $module.Result.path = $user.Path
    $module.Result.description = $user.Description
    $module.Result.password_expired = $user.PasswordExpired
    $module.Result.password_never_expires = $user.PasswordNeverExpires
    $module.Result.user_cannot_change_password = $user.UserCannotChangePassword
    $module.Result.account_disabled = $user.AccountDisabled
    $module.Result.account_locked = $user.IsAccountLocked
    $module.Result.sid = $user.SecurityIdentifier.Value
    $module.Result.groups = @(
        foreach ($grp in $user.Groups) {
            @{ name = $grp.Name; path = $grp.Path }
        }
    )
}

$module.ExitJson()
