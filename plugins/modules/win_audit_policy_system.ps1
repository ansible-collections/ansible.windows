#!powershell

# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
##Requires -Module Ansible.ModuleUtils.AddType
#AnsibleRequires -PowerShell ..module_utils.Process
$spec = @{
    options = @{
        category = @{ type = 'str' }
        subcategory = @{ type = 'str' }
        audit_type = @{ type = 'list'; elements = 'str' ; required = $true ; choices = @("failure", "none", "success") }
    }
    supports_check_mode = $true
    mutually_exclusive = @(
        , @('subcategory', 'category')
    )
    required_one_of = @(
        , @('subcategory', 'category')
    )
}


Function Get-AuditPolicy {
    param (
        [string]$Command
    )
    $categoriesParams = @{
        CommandLine = $Command
    }
    $auditpolcsv = Start-AnsibleWindowsProcess @categoriesParams
    If ($($auditpolcsv.ExitCode) -eq 0) {
        $Obj = ConvertFrom-CSV $($auditpolcsv.Stdout) | Select-Object @{
            n = 'subcategory'
            e = { $_.Subcategory.ToLower() }
        },
        @{
            n = 'audit_type'
            e = { $_."Inclusion Setting".ToLower() }
        }
    }
    Else {
        return $($auditpolcsv.Stderr)
    }

    $HT = @{}
    Foreach ($Item in $Obj) {
        $HT.Add($($Item.subcategory), $($Item.audit_type))
    }
    $HT
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$category = $module.Params.category
$subCategory = $module.Params.subcategory
$audit_type = $module.Params.audit_type
$check_mode = $module.Checkmode

$categoriesParams = @{ CommandLine = "auditpol /list /category /r" }
$categories_rc = Start-AnsibleWindowsProcess @categoriesParams
$subcategoriesParams = @{ CommandLine = "auditpol /list /subcategory:* /r" }
$subcategories_rc = Start-AnsibleWindowsProcess @subcategoriesParams

If ($categories_rc.ExitCode -eq 0) {
    $categories = ConvertFrom-Csv $categories_rc.Stdout | Select-Object -expand Category*
}
Else {
    $module.FailJson("Failed to retrive audit policy categories: $categories_rc.Stderr")
}

If ($subcategories_rc.ExitCode -eq 0) {
    $subcategories = ConvertFrom-Csv $subcategories_rc.Stdout | Select-Object -ExpandProperty 'Category*' | Where-Object { $_ -notin $categories }
}
Else {
    $module.FailJson("Failed to retrieve audit policy subcategories: $subcategories_rc.Stderr")
}
# Validate user inputs. The avaible choices is known in run time after the module utils import.
If ($category -and $category -notin $categories) { $module.FailJson("Invalid category provided") }
If ($subcategory -and $subcategory -notin $subcategories) { $module.FailJson("Invalid sub category provided") }


$SetCommand = 'auditpol /set'
$GetCommand = 'auditpol /get /r'

If ($category) {
    $SetCommand = "$SetCommand /category:`"$category`""
    $GetCommand = "$GetCommand /category:`"$category`""
}
Else {
    $SetCommand = "$SetCommand /subcategory:`"$subcategory`""
    $GetCommand = "$GetCommand /subcategory:`"$subcategory`""
}

if ('success' -in $audit_type -and 'failure' -in $audit_type) {
    $SetCommand = "$SetCommand /success:enable /failure:enable"; $audit_type_check = "success and failure"
}
Elseif ( 'success' -in $audit_type ) {
    $SetCommand = "$SetCommand /success:enable /failure:disable"; $audit_type_check = "success"
}
Elseif ( 'failure' -in $audit_type ) {
    $SetCommand = "$SetCommand /success:disable /failure:enable"; $audit_type_check = "failure"
}
Else {
    $SetCommand = "$SetCommand /success:disable /failure:disable"; $audit_type_check = 'No Auditing'
}


$CurrentRule = Get-AuditPolicy $GetCommand

#exit if the audit_type is already set properly for the category
If (-not ($CurrentRule.Values | Where-Object { $_ -ne $audit_type_check }) ) {
    $module.result.current_audit_policy = $CurrentRule
    $module.ExitJson()
}

If (-not $check_mode) {
    $categoriesParams = @{
        CommandLine = $SetCommand
    }
    $ApplyPolicy = Start-AnsibleWindowsProcess @categoriesParams

    If ($ApplyPolicy.ExitCode -ne 0) {
        $module.result.current_audit_policy = Get-AuditPolicy $GetCommand
        $module.FailJson("Failed to set audit policy $($ApplyPolicy.Stderr)")
    }
}

$module.result.changed = $true
$module.result.current_audit_policy = Get-AuditPolicy $GetCommand
$module.ExitJson()