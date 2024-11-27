#!powershell

# Copyright: (c) 2015, Phil Schwartz <schwartzmx@gmail.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        timezone = @{
            required = $true
            type = "str"
        }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$timezone = $module.Params.timezone

$module.Result.previous_timezone = $null
$module.Result.timezone = $timezone

Function Invoke-TzUtil {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $Module,

        [Parameter(Mandatory)]
        [string]
        $Action,

        [Parameter(ValueFromRemainingArguments)]
        [string[]]
        $ArgumentList
    )

    $stdout = $null
    $stderr = . { tzutil.exe @ArgumentList | Set-Variable -Name stdout } 2>&1 | ForEach-Object ToString

    if ($LASTEXITCODE) {
        $Module.Result.stdout = $stdout -join "`n"
        $Module.Result.stderr = $stderr -join "`n"
        $Module.Result.rc = $LASTEXITCODE
        $Module.FailJson("An error occurred when $Action.")
    }

    $stdout
}

# Get the current timezone set
$previousTz = Invoke-TzUtil /g -Module $module -Action "getting the current machine's timezone setting"
$module.Result.previous_timezone = $previousTz

if ($module.DiffMode) {
    $module.Diff.before = "$previousTz`n"
    $module.Diff.after = "$timezone`n"
}

if ($previousTz -ne $timezone) {
    # Check that timezone is listed as an available timezone to the machine
    $tzList = Invoke-TzUtil /l -Module $module -Action "listing the available timezones"

    if ($tzList -notcontains ($timezone -replace '_dstoff')) {
        $module.FailJson("The specified timezone: $timezone isn't supported on the machine.")
    }

    if (-not $module.CheckMode) {
        $null = Invoke-TzUtil /s $timezone -Module $module -Action "setting the specified timezone"
    }
    $module.Result.changed = $true
}

$module.ExitJson()
