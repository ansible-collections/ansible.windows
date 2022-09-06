#!powershell

# Copyright: (c) 2022, Oleg Galushko (@inorangestylee)
# Copyright: (c) 2015, Hans-Joachim Kliemeck <git@kliemeck.de>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        path = @{ type = 'str'; required = $true }
        reorganize = @{ type = 'bool'; default = $false }
        state = @{ type = 'str'; default = 'absent'; choices = @('absent', 'present') }
    }
    supports_check_mode = $true
}

function Get-AclEx {
    [CmdletBinding()]
    [OutputType([System.Security.AccessControl.NativeObjectSecurity])]
    param(
        [System.String] $LiteralPath
    )

    $item = Get-Item -LiteralPath $LiteralPath
    return $item.GetAccessControl()
}

function Set-AclEx {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [System.String] $LiteralPath,
        [System.Security.AccessControl.NativeObjectSecurity] $AclObject
    )

    $item = Get-Item -LiteralPath $LiteralPath
    if ($PSCmdlet.ShouldProcess($LiteralPath)) {
        if ($item.PSProvider.Name -eq 'Registry') {
            Set-Acl -LiteralPath $LiteralPath -AclObject $AclObject
        }
        else {
            $item.SetAccessControl($AclObject)
        }
    }
}

function Remove-AclExplicitDuplicate {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([System.Security.AccessControl.NativeObjectSecurity])]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [System.Security.AccessControl.NativeObjectSecurity] $acl
    )

    Begin {}

    Process {
        $properties = $acl.Access |
            Get-Member -MemberType Property |
            Where-Object { $_.Name -ne 'IsInherited' } |
            Select-Object -ExpandProperty Name

        ForEach ($inheritedRule in $($acl.Access | Where-Object { $_.IsInherited })) {
            ForEach ($explicitRule in $($acl.Access | Where-Object { -not $_.IsInherited })) {
                If ($null -eq (Compare-Object -ReferenceObject $explicitRule -DifferenceObject $inheritedRule -Property $properties)) {
                    if ($PSCmdlet.ShouldProcess($acl)) {
                        $acl.RemoveAccessRule($explicitRule)
                    }
                }
            }
        }
        return $acl
    }

    End {}
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$path = $module.Params.path
if (-not $path.StartsWith('\\?\')) {
    $path = [System.Environment]::ExpandEnvironmentVariables($path)
}

$reorganize = $module.Params.reorganize
$state = $module.Params.state
$check_mode = $module.CheckMode

$module.Result.changed = $false

$regeditHives = @{
    'HKCR' = 'HKEY_CLASSES_ROOT'
    'HKU' = 'HKEY_USERS'
    'HKCC' = 'HKEY_CURRENT_CONFIG'
}

$pathQualifier = Split-Path -Path $path -Qualifier -ErrorAction SilentlyContinue
# UNC paths will not return a qualifier, so $pathQualifier will be $null in that case
if ($pathQualifier) {
    $pathQualifier = $pathQualifier.Replace(':', '')
}

if ($pathQualifier -in $regeditHives.Keys -and (-not (Test-Path -LiteralPath "${pathQualifier}:\"))) {
    $null = New-PSDrive -Name $pathQualifier -PSProvider 'Registry' -Root $regeditHives.$pathQualifier
}

If (-Not (Test-Path -LiteralPath $path)) {
    $module.FailJson("$path does not exist")
}

try {
    $acl = Get-AclEx -LiteralPath $path
}
catch {
    $module.FailJson("Failed to find '$path': $($_.ToString())", $_)
}


if ($acl.AreAccessRulesProtected) { $currentState = 'absent' } else { $currentState = 'present' }
$module.Diff.before = @{ state = $currentState }

If (($state -eq 'present') -and $acl.AreAccessRulesProtected) {
    try {
        $acl.SetAccessRuleProtection($false, $false)
    }
    catch {
        $module.FailJson("Failed to enable inheritance of '$path': $($_.ToString())", $_)
    }
    if ($reorganize) {
        Set-AclEx -LiteralPath $path -AclObject $acl -WhatIf:$check_mode
        $acl = Remove-AclExplicitDuplicate -acl $acl
    }
    Set-AclEx -LiteralPath $path -AclObject $acl -WhatIf:$check_mode
    $module.Result.changed = $true
}

if (($state -eq 'absent') -and (-not $acl.AreAccessRulesProtected)) {
    try {
        $acl.SetAccessRuleProtection($true, $reorganize)
    }
    catch {
        $module.FailJson("Failed to disable inheritance of '$path': $($_.ToString())", $_)
    }
    Set-AclEx -LiteralPath $path -AclObject $acl -WhatIf:$check_mode
    $module.Result.changed = $true
}

if (-not $check_mode) {
    try {
        $acl = Get-AclEx -LiteralPath $path
    }
    catch {
        $module.FailJson("Failed to get acl of '$path': $($_.ToString())", $_)
    }
}

if ($acl.AreAccessRulesProtected) { $currentState = 'absent' } else { $currentState = 'present' }
$module.Diff.after = @{ state = $currentState }

$module.ExitJson()
