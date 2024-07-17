#!powershell

# Copyright: (c) 2015, Hans-Joachim Kliemeck <git@kliemeck.de>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -CSharpUtil Ansible.Privilege
#AnsibleRequires -PowerShell ..module_utils._SecurityIdentifier

$spec = @{
    options = @{
        path = @{
            type = 'path'
            required = $true
        }
        recurse = @{
            type = 'bool'
            default = $false
        }
        user = @{
            type = 'str'
            required = $true
        }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$path = $module.Params.path
$recurse = $module.Params.recurse
$user = $module.Params.user

If (-not (Test-Path -LiteralPath $path)) {
    $module.FailJson("$path file or directory does not exist on the host")
}

# Test that the user/group is resolvable on the local machine
try {
    $sid = $user | ConvertTo-AnsibleWindowsSecurityIdentifier -ErrorAction Stop
}
catch {
    $module.FailJson([string]$_, $_)
}

$privEnabler = New-Object -TypeName Ansible.Privilege.PrivilegeEnabler -ArgumentList @(
    $false
    'SeBackupPrivilege' # Opens files without explicit rights
    'SeChangeNotifyPrivilege' # Bypass parent folder access checks
    'SeRestorePrivilege' # Sets DACL rules without explicit rights
    'SeTakeOwnershipPrivilege'  # Sets owner without explicit rights
)
Try {
    $file = Get-Item -LiteralPath $path
    $acl = Get-Acl -LiteralPath $file.FullName

    If ($acl.GetOwner([System.Security.Principal.SecurityIdentifier]) -ne $sid) {
        $acl.SetOwner($sid)
        Set-Acl -LiteralPath $file.FullName -AclObject $acl -WhatIf:$module.CheckMode
        $module.Result.changed = $true
    }

    If ($recurse -and $file -is [System.IO.DirectoryInfo]) {
        # Get-ChildItem falls flat on pre PSv5 when dealing with complex path chars
        $files = $file.EnumerateFileSystemInfos("*", [System.IO.SearchOption]::AllDirectories)
        ForEach ($file in $files) {
            $acl = Get-Acl -LiteralPath $file.FullName

            If ($acl.GetOwner([System.Security.Principal.SecurityIdentifier]) -ne $sid) {
                $acl.SetOwner($sid)
                Set-Acl -LiteralPath $file.FullName -AclObject $acl -WhatIf:$module.CheckMode
                $module.Result.changed = $true
            }
        }
    }
}
Catch {
    $module.FailJson("an error occurred when attempting to change owner on $path for $($user): $($_.Exception.Message)", $_)
}
Finally {
    $privEnabler.Dispose()
}

$module.ExitJson()
