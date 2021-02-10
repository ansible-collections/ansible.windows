#!powershell

# Copyright: (c) 2015, Phil Schwartz <schwartzmx@gmail.com>
# Copyright: (c) 2015, Trond Hindenes
# Copyright: (c) 2015, Hans-Joachim Kliemeck <git@kliemeck.de>
# Copyright: (c) 2020, Laszlo Papp <laca@placa.me>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#Requires -Module Ansible.ModuleUtils.Legacy
#Requires -Module Ansible.ModuleUtils.PrivilegeUtil
#Requires -Module Ansible.ModuleUtils.SID

$ErrorActionPreference = "Stop"
$result = @{
    changed = $false
	msg = ""
}


# win_acl module (File/Resources Permission Additions/Removal)

#Functions
function Get-UserSID {
    param(
        [String]$AccountName
    )

    $userSID = $null
    $searchAppPools = $false

    if ($AccountName.Split("\").Count -gt 1) {
        if ($AccountName.Split("\")[0] -eq "IIS APPPOOL") {
            $searchAppPools = $true
            $AccountName = $AccountName.Split("\")[1]
        }
    }

    if ($searchAppPools) {
        Import-Module -Name WebAdministration
        $testIISPath = Test-Path -LiteralPath "IIS:"
        if ($testIISPath) {
            $appPoolObj = Get-ItemProperty -LiteralPath "IIS:\AppPools\$AccountName"
            $userSID = $appPoolObj.applicationPoolSid
        }
    }
    else {
        $userSID = Convert-ToSID -account_name $AccountName
    }

    return $userSID
}

Function SetPrivilegeTokens() {
    # Set privilege tokens only if admin.
    # Admins would have these privs or be able to set these privs in the UI Anyway

    $adminRole = [System.Security.Principal.WindowsBuiltInRole]::Administrator
    $myWindowsID = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $myWindowsPrincipal = new-object System.Security.Principal.WindowsPrincipal($myWindowsID)


    if ($myWindowsPrincipal.IsInRole($adminRole)) {
        # Need to adjust token privs when executing Set-ACL in certain cases.
        # e.g. d:\testdir is owned by group in which current user is not a member and no perms are inherited from d:\
        # This also sets us up for setting the owner as a feature.
        # See the following for details of each privilege
        # https://msdn.microsoft.com/en-us/library/windows/desktop/bb530716(v=vs.85).aspx
        $privileges = @(
            "SeRestorePrivilege",  # Grants all write access control to any file, regardless of ACL.
            "SeBackupPrivilege",  # Grants all read access control to any file, regardless of ACL.
            "SeTakeOwnershipPrivilege"  # Grants ability to take owernship of an object w/out being granted discretionary access
        )
        foreach ($privilege in $privileges) {
            $state = Get-AnsiblePrivilege -Name $privilege
            if ($state -eq $false) {
                Set-AnsiblePrivilege -Name $privilege -Value $true
            }
        }
    }
}

Function HandleReset() {
   SetPrivilegeTokens
   if(!(Get-Item -LiteralPath $path).PSParentPath){
       if ($null -ne $path_qualifier) {
           Pop-Location
       }
      Fail-Json -obj $result -message "$path is a root folder! Cannot reset ACL!"
	  }
   try
   {
      $objACL = Get-ACL -LiteralPath $path
      # Save the ACL for reverting when needed
      if($objACL.AreAccessRulesProtected){
         $result.changed=$true
         $objacl.SetAccessRuleProtection($false,$false)
         # If inheritance set, we need to write and re-read the ACL to get the inherited ACEs except when $check_mode.
		 if(!$check_mode){
		    If ($path_item.PSProvider.Name -eq "Registry") {
                Set-ACL -LiteralPath $path -AclObject $objACL
            } else {
                (Get-Item -LiteralPath $path).SetAccessControl($objACL)
            }
            $objACL = Get-ACL -LiteralPath $path
			}
	     }
      $changed=$false
      # Remove any non-inherited ACE
      $objACL.Access|Where-Object{!$_.isinherited}|ForEach-Object{
         $result.changed=$true
	     if(!$changed){$changed=$true}
	     [void]$objACL.RemoveAccessRule($_)
         }
      if($changed -and (!$check_mode)){
	     If ($path_item.PSProvider.Name -eq "Registry") {
                Set-ACL -LiteralPath $path -AclObject $objACL
            } else {
                (Get-Item -LiteralPath $path).SetAccessControl($objACL)
            }
         }
   }
   catch {
       if ($null -ne $path_qualifier) {
           Pop-Location
       }
      Fail-Json -obj $result -message "an exception occurred when resetting the ACL - $($_.Exception.Message)"
   }
   # Make sure we revert the location stack to the original path just for cleanups sake
   if ($null -ne $path_qualifier) {
       Pop-Location
   }
   Exit-Json -obj $result
}

$params = Parse-Args $args -supports_check_mode $true

$check_mode = Get-AnsibleParam -obj $params -name "_ansible_check_mode" -default $false
# Get the path parameter with expanded environment variables.
$path=Get-AnsibleParam -obj $params -name "path" -type "str" -failifempty $true
$path = (New-Object -ComObject Wscript.Shell).ExpandEnvironmentStrings($path)
# We mount the HKCR, HKU, and HKCC registry hives so PS can access them.
# Network paths have no qualifiers so we use -EA SilentlyContinue to ignore that
$path_qualifier = Split-Path -Path $path -Qualifier -ErrorAction SilentlyContinue
if ($path_qualifier -eq "HKCR:" -and (-not (Test-Path -LiteralPath HKCR:\))) {
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT > $null
}
if ($path_qualifier -eq "HKU:" -and (-not (Test-Path -LiteralPath HKU:\))) {
    New-PSDrive -Name HKU -PSProvider Registry -Root HKEY_USERS > $null
}
if ($path_qualifier -eq "HKCC:" -and (-not (Test-Path -LiteralPath HKCC:\))) {
    New-PSDrive -Name HKCC -PSProvider Registry -Root HKEY_CURRENT_CONFIG > $null
}
If (-Not (Test-Path -LiteralPath $path)) {
    Fail-Json -obj $result -message "$path does not exist on the host"
}
$path_item = Get-Item -LiteralPath $path -Force
# Bug in Set-Acl, Get-Acl where -LiteralPath only works for the Registry provider if the location is in that root
# qualifier. We also don't have a qualifier for a network path so only change if not null
if ($null -ne $path_qualifier) {
    Push-Location -LiteralPath $path_qualifier
}
$state = Get-AnsibleParam -obj $params -name "state" -type "str" -default "present" -validateset "absent","present","reset"
# Reset logic placed here as in this case no more parameters are required
if($state -eq 'reset'){ HandleReset }

$user = Get-AnsibleParam -obj $params -name "user" -type "str" -failifempty $true
$rights = Get-AnsibleParam -obj $params -name "rights" -type "str" -failifempty $true

$type = Get-AnsibleParam -obj $params -name "type" -type "str" -failifempty $true -validateset "allow","deny"

$inherit = Get-AnsibleParam -obj $params -name "inherit" -type "str"
$propagation = Get-AnsibleParam -obj $params -name "propagation" -type "str" -default "None" -validateset "InheritOnly","None","NoPropagateInherit"


# Test that the user/group is resolvable on the local machine
$sid = Get-UserSID -AccountName $user
if (!$sid) {
    if ($null -ne $path_qualifier) {
        Pop-Location
    }
    Fail-Json -obj $result -message "$user is not a valid user or group on the host machine or domain"
}

If (Test-Path -LiteralPath $path -PathType Leaf) {
    $inherit = "None"
}
ElseIf ($null -eq $inherit) {
    $inherit = "ContainerInherit, ObjectInherit"
}

$myMessage=""
Try {
    SetPrivilegeTokens
	$PathType='FileSystem'
	If ($path_item.PSProvider.Name -eq "Registry") {$PathType='Registry'}

    $InheritanceFlag = [System.Security.AccessControl.InheritanceFlags]$inherit
    $PropagationFlag = [System.Security.AccessControl.PropagationFlags]$propagation
    $objType =[System.Security.AccessControl.AccessControlType]$type
    $objUser = New-Object System.Security.Principal.SecurityIdentifier($sid)
    $objACE = New-Object System.Security.AccessControl."$($PathType)AccessRule" ($objUser, $Rights, $InheritanceFlag, $PropagationFlag, $objType)
    $objACL = Get-ACL -LiteralPath $path
	$objOldRules=$objACL.AccessToString
    $objRights=$null
    if($PathType -eq 'Registry'){
       $objRights=[System.Security.AccessControl.RegistryRights]$rights
    }else{
       $objRights=[System.Security.AccessControl.FileSystemRights]$rights
    }

	Try {
		$ar=$null
        If ($state -eq "present"){
			$objACL.AddAccessRule($objACE)
		} else {
		   [void]$objACL.RemoveAccessRule($objACE)
		   # Enumerate all remaining rights for the given SID except the InheritOnly ones
           $objACL.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])|Where-Object{
             ($_.IdentityReference.Value -eq $sid) -and
             (($_.PropagationFlags -band [System.Security.AccessControl.PropagationFlags]'InheritOnly') -ne
			     [System.Security.AccessControl.PropagationFlags]'InheritOnly') -and
			 ($_.AccessControlType -eq $objType)
             }|ForEach-Object{
             if(!$ar){$ar=$_."$($PathType)Rights"}else{$ar=$ar -bor $_."$($PathType)Rights"}
             }
		}
		$myMessage="Actual rights: "
		$objACL.GetAccessRules($true, $true, [System.Security.Principal.SecurityIdentifier])|Where-Object{$_.IdentityReference.Value -eq $sid}|ForEach-Object{
		   $myMessage += "$($_.AccessControlType): $($_."$($PathType)Rights"): $(if($_.IsInherited){'Inherited,'}) $($_.InheritanceFlags); "
		   }
		if($objOldRules -eq $objACL.AccessToString){
		   $result.changed = $false
		   $result.msg=$myMessage
		} else {
		   if(!($check_mode)){
		      If ($path_item.PSProvider.Name -eq "Registry") {
                  Set-ACL -LiteralPath $path -AclObject $objACL
              } else {
                  (Get-Item -LiteralPath $path).SetAccessControl($objACL)
              }
		   }
           $result.changed = $true
		   $myMessage=$myMessage.Replace('Actual rights: ','New rights: ')
		   $result.msg=$myMessage
		}
		# result Failed if SID still has any of the rights to be removed.
		if(((([int]$ar) -band ([int]$objRights)) -ne 0 ) -and ($state -ne "present")){
		   $result.stderr="$user still has $ar rights!"
		   $result.msg=$myMessage
           if ($null -ne $path_qualifier) {
               Pop-Location
           }
		   Fail-Json -obj $result -message "$user still has $ar rights! $myMessage"
		}
    }
    Catch {
        if ($null -ne $path_qualifier) {
            Pop-Location
        }
        Fail-Json -obj $result -message "an exception occurred when adding the specified rule - $($_.Exception.Message)"
    }
}
Catch {
    if ($null -ne $path_qualifier) {
        Pop-Location
    }
    Fail-Json -obj $result -message "an error occurred when attempting to $state $rights permission(s) on $path for $user - $($_.Exception.Message)"
}
Finally {
    # Make sure we revert the location stack to the original path just for cleanups sake
    if ($null -ne $path_qualifier) {
        Pop-Location
    }
}
Exit-Json -obj $result
