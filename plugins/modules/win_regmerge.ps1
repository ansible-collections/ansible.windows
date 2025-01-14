#!powershell

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ..module_utils.Process



Function Convert-RegistryPath {
    Param (
        [parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]$Path
    )

    $output = $Path -replace "HKLM:", "HKLM"
    $output = $output -replace "HKCU:", "HKCU"

    Return $output
}

$spec = @{
    options = @{
        path = @{ type = 'str' }
        content = @{ type = 'str' }
        compare_to = @{ type = 'str' }
    }
    supports_check_mode = $true
    mutually_exclusive = @(
        , @('path', 'content')
    )
    required_one_of = @(
        , @('path', 'content')
    )
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)
$path = $module.Params.path
$content = $module.Params.content
$compare_to = $module.Params.compare_to
$check_mode = $module.Checkmode

if ( $content ) {
    $path = [System.IO.Path]::GetTempFileName()
    Set-Content -LiteralPath $path -Value $content
    $remove_path = $True
}

$should_compare = $False

If ( $compare_to ) {
    If (Test-Path -LiteralPath $compare_to -PathType container ) {
        $should_compare = $True
    }
    Else {
        $module.result.compare_to_key_found = $false
    }
}
If ( $should_compare ) {
    $guid = [guid]::NewGuid()
    $exported_path = $env:TEMP + "\" + $guid.ToString() + 'ansible_win_regmerge.reg'
    $expanded_compare_key = Convert-RegistryPath ( $compare_to )

    # export from the reg key location to a file
    $export_reg_cmd = @{ CommandLine = "reg.exe EXPORT `"$expanded_compare_key`" `"$exported_path`"" }
    $res = Start-AnsibleWindowsProcess @export_reg_cmd
    if ($res.ExitCode -ne 0) {
        $module.FailJson("error exporting registry '$expanded_compare_key' to '$exported_path'", $res.Stderr)
    }

    # compare the two files
    $comparison_result = Compare-Object -ReferenceObject $(Get-Content -LiteralPath $path) -DifferenceObject $(Get-Content -LiteralPath $exported_path)

    If ($null -ne $comparison_result -and (Get-Member -InputObject $comparison_result -Name "count" -MemberType Properties )) {
        # Something is different, actually do reg merge
        if (-not $check_mode) {
            $import_reg_cmd = @{ CommandLine = "reg.exe IMPORT $path" }
            $res = Start-AnsibleWindowsProcess @import_reg_cmd
            if ($res.ExitCode -ne 0) {
                $module.FailJson("error importing registry values from '$path'", $res.Stderr)
            }
        }
        $module.result.changed = $true
        $module.result.difference_count = $comparison_result.count
    }
    Else {
        $module.result.difference_count = 0
    }

    Remove-Item -LiteralPath $exported_path
    $module.result.compared = $true

}
Else {
    # not comparing, merge and report changed
    if (-not $check_mode) {
        $import_reg_cmd = @{ CommandLine = "reg.exe IMPORT $path" }
        $res = Start-AnsibleWindowsProcess @import_reg_cmd
        if ($res.ExitCode -ne 0) {
            $module.FailJson("error importing registry values from '$path'", $res.Stderr)
        }
    }
    $module.result.changed = $true
    $module.result.compared = $false
}

if ( $remove_path ) {
    Remove-Item -LiteralPath $path
}

$module.ExitJson()
