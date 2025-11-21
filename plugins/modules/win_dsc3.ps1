#!powershell

# Copyright: Contributors to the Ansible project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils.Process

$spec = @{
    options = @{
        schema = @{ default = "https://aka.ms/dsc/schemas/v3/bundled/config/document.json" }
        parameters = @{ type = "dict" }
        variables = @{ type = "dict" }
        resources = @{
            type = "list"
            elements = "dict"
            options = @{
                type = @{ required = $true }
                name = @{ required = $true }
                properties = @{ type = "dict"; required = $true }
                dependsOn = @{ type = "list"; elements = "str" }
            }
            required = $true
        }

        command = @{ choices = ( "set", "get" ); default = "set" }
        raw_results = @{ type = "bool"; default = $false }
        extra_paths = @{ type = "list"; elements = "path" }
        resource_paths = @{ type = "list"; elements = "path" }
    }
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$command = $module.Params.command
if (($command -eq "set") -and ($module.CheckMode)) {
    $command = "test"
}

$configDoc = @{
    '$schema' = $module.Params.schema
    parameters = $module.Params.parameters
    variables = $module.Params.variables
    resources = $module.Params.resources
}

$traceLevel = switch ($module.Verbosity) {
    3 { "info" }
    4 { "debug" }
    5 { "trace" }
    default { "warn" }
}

$inputJson = $configDoc | ConvertTo-Json -Depth 100 -Compress
if ($module.Verbosity -ge 4) {
    $module.Result.win_dsc3_debug = @{ inputJson = @($inputJson) }
}

$dscArgs = @{
    FilePath = "dsc.exe"
    ArgumentList = @(
        "--trace-format=plaintext",
        "--progress-format=none",
        "--trace-level=${traceLevel}",
        "config"
        $command,
        "--file=-"
        "--output-format=json"
    )
    InputObject = $inputJson
}

# Add entries to PATH, if requested
foreach ($p in $module.Params.extra_paths) {
    $Env:PATH += ";$p"
}
# Ensure winget installed instance is always found, even if PATH has not been updated
$Env:PATH += ";$Env:ProgramFiles\WinGet\Links\;$Env:LOCALAPPDATA\Microsoft\WinGet\Links\"

# Set DSC_RESOURCE_PATH, if requested
if ($module.Params.resource_paths) {
    $Env:DSC_RESOURCE_PATH = $module.Params.resource_paths -join ";"
}

$dscReturn = Start-AnsibleWindowsProcess @dscArgs
$module.Result.rc = $dscReturn.ExitCode
$module.Result.stderr = $dscReturn.Stderr

if ($dscReturn.ExitCode -ne 0) {
    $reason = switch ($dscReturn.ExitCode) {
        1 { "Invalid arguments (ExitCode=1)" }
        2 { "Resource error (ExitCode=2)" }
        3 { "JSON serizliation error (ExitCode=3)" }
        4 { "Input YAML or JSON is invalid (ExitCode=4)" }
        5 { "Data failed schema validation (ExitCode=5)" }
        default { "Error: ExitCode=$_" }
    }
    $module.FailJson($reason)
    $module.ExitJson()
}

$dscOutput = ConvertFrom-Json $dscReturn.Stdout
$module.Result.metadata = $dscOutput.metadata
$module.Result.messages = $dscOutput.messages

$module.Result.changed = $false
$stateDiffs = @()

function Select-Diff {
    param (
        [string]$Name,
        [PSCustomObject]$Before,
        [PSCustomObject]$After,
        [ValidateNotNullOrEmpty()] [string[]]$properties
    )

    $diff = @{
        name = $Name
        before = @{}
        after = @{}
    }
    foreach ($p in $properties) {
        if ($Before | Get-Member $p) {
            $diff.before.$p = $Before.$p
        }
        $diff.after.$p = $After.$p
    }
    return $diff
}

$module.Result.config_results = @(
    $dscOutput.results | ForEach-Object {
        $changed = $false
        $result = if ($module.Params.raw_results)
        { $_ | Add-Member -NotePropertyName "state" -NotePropertyValue $null -PassThru }
        else { @{ metadata = $_.metadata; Name = $_.name; type = $_.type; state = $null } }

        if ($command -eq "set") {
            $result.state = $_.result.afterState
            if ($_.result.changedProperties) {
                $changed = $true
                $stateDiffs += Select-Diff -Name $_.name `
                    -Before $_.result.beforeState -After $_.result.afterState `
                    $_.result.changedProperties
            }
        }
        else {
            $result.state = $_.result.actualState
            if ($command -eq "test") {
                $changed = !$_.result._inDesiredState
                if ($_.result.differingProperties) {
                    $stateDiffs += Select-Diff -Name $_.name `
                        -Before $_.result.actualState -After $_result.desiredState `
                        $_.result.differingProperties
                }
            }
        }
        $module.Result.changed = $module.Result.changed -or $changed

        $result
    }
)

if ($stateDiffs) {
    # Restructure diffs of individual resource states under a single list
    $diffs = @{
        before = @{ config_results = @() }
        after = @{ config_results = @() }
    }
    foreach ($d in $stateDiffs) {
        $diffs.before.config_results += @{ name = $d.name; state = $d.before }
        $diffs.after.config_results += @{ name = $d.name; state = $d.after }
    }
    $module.Result.diff = $diffs
}
$module.ExitJson()
