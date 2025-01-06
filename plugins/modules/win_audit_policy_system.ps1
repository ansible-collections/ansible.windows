#!powershell

# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Module Ansible.ModuleUtils.CommandUtil



$categories_rc = run-command -command 'auditpol /list /category /r'
$subcategories_rc = run-command -command 'auditpol /list /subcategory:* /r'

If ($categories_rc.item('rc') -eq 0) {
    $categories = ConvertFrom-Csv $categories_rc.item('stdout') | Select-Object -expand Category*
}
Else {
    $module.FailJson("Failed to retrive audit policy categories. Please make sure the auditpol command is functional on
    the system and that the account ansible is running under is able to retrieve them." , $($_.Exception.Message))
}

If ($subcategories_rc.item('rc') -eq 0) {
    $subcategories = ConvertFrom-Csv $subcategories_rc.item('stdout') | Select-Object -expand Category* |
        Where-Object { $_ -notin $categories }
}
Else {
    $module.FailJson("Failed to retrive audit policy subcategories. Please make sure the auditpol command is functional on
    the system and that the account ansible is running under is able to retrieve them." , $($_.Exception.Message))
}

$spec = @{
    options = @{
        category = @{ type = 'str' ; choices = $categories }
        subcategory = @{ type = 'str' ; choices = $subcategories }
        audit_type = @{ type = 'list'; elements = 'str' ; required = $true }
    }
    supports_check_mode = $true
    mutually_exclusive = @(
        , @('subcategory', 'category')
    )
    required_one_of = @(
        , @('subcategory', 'category')
    )
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$category = $module.Params.category
$subcategory = $module.Params.subcategory
$audit_type = $module.Params.audit_type
$check_mode = $module.Checkmode
Function Get-AuditPolicy ($GetString) {
    $auditpolcsv = Run-Command -command $GetString
    If ($auditpolcsv.item('rc') -eq 0) {
        $Obj = ConvertFrom-CSV $auditpolcsv.item('stdout') | Select-Object @{n = 'subcategory'; e = { $_.Subcategory.ToLower() } },
        @{ n = 'audit_type'; e = { $_."Inclusion Setting".ToLower() } }
    }
    Else {
        return $auditpolcsv.item('stderr')
    }

    $HT = @{}
    Foreach ( $Item in $Obj ) {
        $HT.Add($Item.subcategory, $Item.audit_type)
    }
    $HT
}



$SetString = 'auditpol /set'
$GetString = 'auditpol /get /r'

If ($category) { $SetString = "$SetString /category:`"$category`""; $GetString = "$GetString /category:`"$category`"" }
Elseif ($subcategory) { $SetString = "$SetString /subcategory:`"$subcategory`""; $GetString = "$GetString /subcategory:`"$subcategory`"" }

if ('success' -in $audit_type -and 'failure' -in $audit_type) {
    $SetString = "$SetString /success:enable /failure:enable"; $audit_type_check = "success and failure"
}
Elseif ( 'success' -in $audit_type ) {
    $SetString = "$SetString /success:enable /failure:disable"; $audit_type_check = "success"
}
Elseif ( 'failure' -in $audit_type ) {
    $SetString = "$SetString /success:disable /failure:enable"; $audit_type_check = "failure"
}
Else {
    $SetString = "$SetString /success:disable /failure:disable"; $audit_type_check = 'No Auditing'
}


$CurrentRule = Get-AuditPolicy $GetString
#exit if the audit_type is already set properly for the category
If (-not ($CurrentRule.Values | Where-Object { $_ -ne $audit_type_check }) ) {
    $module.result.current_audit_policy = $CurrentRule
    $module.ExitJson()
}

If (-not $check_mode) {
    $ApplyPolicy = Run-Command -command $SetString

    If ($ApplyPolicy.Item('rc') -ne 0) {
        $module.result.current_audit_policy = Get-AuditPolicy $GetString
        $module.FailJson("Failed to set audit policy $($_.Exception.Message)")
    }
}

$module.result.changed = $true
$module.result.current_audit_policy = Get-AuditPolicy $GetString
$module.ExitJson()