#!powershell

# Copyright: (c) 2017, Noah Sparks <nsparks@outlook.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell Ansible.ModuleUtils.SID

$spec = @{
    options = @{
        path = @{ type = "str" ; required = $true ; aliases = @("destination", "dest") }
        user = @{ type = "str" ; required = $true }
        rights = @{ type = "list" ; elements = "str" }
        inheritance_flags = @{
            type = "list"
            elements = "str"
            default = @('ContainerInherit', 'ObjectInherit')
            choices = @('None', 'ContainerInherit', 'ObjectInherit')
        }
        propagation_flags = @{ type = "str" ; choices = @('None', 'InheritOnly', 'NoPropagateInherit') ; default = 'None' }
        audit_flags = @{ type = "list" ; elements = "str" ; default = @('success') ; choices = @('failure', 'success') }
        state = @{ type = 'str' ; default = 'present'; choices = 'absent', 'present' }
    }
    required_if = @(
        , @("state", "present", @(, "rights"))
    )
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$check_mode = $module.CheckMode

$path = $module.Params.path
$user = $module.Params.user
$rights = $module.Params.rights
$inheritance_flags = $module.Params.inheritance_flags
$propagation_flags = $module.Params.propagation_flags
$audit_flags = $module.Params.audit_flags
$state = $module.Params.state


Function Get-CurrentAuditRule ($path) {
    Try { $ACL = Get-Acl $path -Audit }
    Catch { Return "Unable to retrieve the ACL on $Path" }

    $HT = Foreach ($Obj in $ACL.Audit) {
        @{
            user = $Obj.IdentityReference.ToString()
            rights = ($Obj | Select-Object -expand "*rights").ToString()
            audit_flags = $Obj.AuditFlags.ToString()
            is_inherited = $Obj.IsInherited.ToString()
            inheritance_flags = $Obj.InheritanceFlags.ToString()
            propagation_flags = $Obj.PropagationFlags.ToString()
        }
    }
    If (-Not $HT) {
        @{}
    }
    Else { $HT }
}

Function Confirm-AllElement {
    param (
        [Parameter(Mandatory = $true)]
        [array]$SubSet,
        [Parameter(Mandatory = $true)]
        [array]$SuperSet
    )
    $SubSet = $SubSet -split ',\s*' | ForEach-Object { $_.Trim().ToString() }
    $SuperSet = $SuperSet -split ',\s*' | ForEach-Object { $_.Trim().ToString() }

    foreach ($item in $SubSet) {
        if (-not ($SuperSet -contains $item)) {
            return $false
        }
    }

    return $true
}

Function Confirm-AuditRule {
    param (
        [Parameter(Mandatory = $true)]
        [Object]$DesiredRule,
        [Parameter(Mandatory = $true)]
        [Object]$ExistingRule,
        [Parameter(Mandatory = $true)]
        [Object]$SID
    )
    $audit_flags_contained = Confirm-AllElement $DesiredRule.AuditFlags $ExistingRule.AuditFlags
    $rights_contained = Confirm-AllElement ($DesiredRule | Select-Object -ExpandProperty "*Rights") ($ExistingRule | Select-Object -ExpandProperty "*Rights")
    $inheritance_flags_contained = Confirm-AllElement @($DesiredRule.InheritanceFlags) @($ExistingRule.InheritanceFlags)
    If (
        $audit_flags_contained -and
        $rights_contained -and
        $inheritance_flags_contained -and
        $ExistingRule.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]) -eq $SID -and
        $ExistingRule.PropagationFlags -eq $DesiredRule.PropagationFlags
    ) {
        return $true
    }
    else {
        return $false
    }
}


If (-not (Test-Path -LiteralPath $path) ) { $module.FailJson("defined path ($path) is not found/invalid") }

Try { $SID = Convert-ToSid $user }
Catch { $module.FailJson("Failed to lookup the identity ($user): $_", $_) }

$ItemType = (Get-Item -LiteralPath $path -Force).GetType()

switch ($ItemType) {
    ([Microsoft.Win32.RegistryKey]) { $registry = $true; $module.result.path_type = 'registry' }
    ([System.IO.FileInfo]) { $file = $true; $module.result.path_type = 'file' }
    ([System.IO.DirectoryInfo]) { $module.result.path_type = 'directory' }
}

Try { $ACL = Get-Acl $path -Audit }
Catch { $module.FailJson("Unable to retrieve the ACL on $($Path): $_", $_) }

If ($state -eq 'absent') {
    $ToRemove = ($ACL.Audit | Where-Object { $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]) -eq $SID -and
            $_.IsInherited -eq $false }).IdentityReference
    If (-Not $ToRemove) {
        $module.result.current_audit_rules = Get-CurrentAuditRule $path
        $module.ExitJson()
    }
    Try { $ToRemove | ForEach-Object { $ACL.PurgeAuditRules($_) } }
    Catch {
        $module.result.current_audit_rules = Get-CurrentAuditRule $path
        $module.FailJson("Failed to remove audit rule: $_", $_)
    }
}
Else {
    If ( $registry ) {
        $PossibleRights = [System.Enum]::GetNames([System.Security.AccessControl.RegistryRights])
        Foreach ($right in $rights) {
            if ($right -notin $PossibleRights) { $module.FailJson("$right does not seem to be a valid REGISTRY right") }
        }
        $NewAccessRule = New-Object System.Security.AccessControl.RegistryAuditRule($user, $rights, $inheritance_flags, $propagation_flags, $audit_flags)
    }
    Else {
        $PossibleRights = [System.Enum]::GetNames([System.Security.AccessControl.FileSystemRights])
        Foreach ($right in $rights) {
            if ($right -notin $PossibleRights) { $module.FailJson("$right does not seem to be a valid FILE SYSTEM right") }
        }
        If ($file -and $inheritance_flags -ne 'none') { $module.FailJson("The target type is a file. inheritance_flags must be changed to 'none'") }
        $NewAccessRule = New-Object System.Security.AccessControl.FileSystemAuditRule($user, $rights, $inheritance_flags, $propagation_flags, $audit_flags)
    }
    Foreach ($group in $ACL.Audit | Where-Object { $_.IsInherited -eq $false }) {
        $RuleExists = Confirm-AuditRule -DesiredRule $NewAccessRule -ExistingRule $group -SID $SID
        If ( $RuleExists ) {
            $module.result.current_audit_rules = Get-CurrentAuditRule $path
            $module.ExitJson()
        }
    }
    If ( -not $check_mode) {
        Try { $ACL.AddAuditRule($NewAccessRule) }
        Catch { $module.FailJson("Failed to set the audit rule: $_", $_) }
    }
}

Try { Set-Acl -Path $path -ACLObject $ACL -WhatIf:$check_mode }
Catch {
    $module.result.current_audit_rules = Get-CurrentAuditRule $path
    $module.FailJson("Failed to apply audit change: $_", $_)
}
$module.result.current_audit_rules = Get-CurrentAuditRule $path
$module.result.changed = $true
$module.ExitJson()