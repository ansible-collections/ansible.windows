#!powershell

# WANT_JSON
# POWERSHELL_COMMON

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

$params = Parse-Args $args -supports_check_mode $false
$path = Get-AnsibleParam -obj $params 'path' -type 'str' -failifempty $true

$result = @{
    changed = $false
}

if (-not $path.StartsWith('\\?\')) {
    $path = [System.Environment]::ExpandEnvironmentVariables($path)
}

$regeditHives = @{
    'HKCR' = 'HKEY_CLASSES_ROOT'
    'HKU' = 'HKEY_USERS'
    'HKCC' = 'HKEY_CURRENT_CONFIG'
}

$pathQualifier = Split-Path -Path $path -Qualifier -ErrorAction SilentlyContinue
$pathQualifier = $pathQualifier.Replace(':', '')

if ($pathQualifier -in $regeditHives.Keys -and (-not (Test-Path -LiteralPath "${pathQualifier}:\"))) {
    $null = New-PSDrive -Name $pathQualifier -PSProvider 'Registry' -Root $regeditHives.$pathQualifier
    Push-Location -LiteralPath "${pathQualifier}:\"
}

$acl = Get-Acl -LiteralPath $path

$result.inherited = $acl.AreAccessRulesProtected -eq $false

$user_details = @{}
$acl.Access | ForEach-Object {
    $user = $_.IdentityReference.Translate([System.Security.Principal.SecurityIdentifier]).Value
    if ($user_details.ContainsKey($user)) {
        $details = $user_details.$user
    }
    else {
        $details = @{
            isinherited = $false
        }
    }
    $details.isinherited = $_.IsInherited
    $user_details.$user = $details
}

$result.user_details = $user_details

Exit-Json $result
