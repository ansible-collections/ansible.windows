#!powershell

# Copyright: Contributors to the Ansible project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils.Process

$spec = @{
    options = @{
        config = @{ type = "dict" }
        config_file = @{ type = "path" }

        parameters = @{ type = "dict" }

        trace_level = @{
            choices = ("error", "warn", "info", "debug", "trace" )
            default = "warn"
        }
    }
    required_one_of = @(
        , @( "config", "config_file" )
    )
    mutually_exclusive = @(
        , @( "config", "config_file" )
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$configSubcommand = if ($module.CheckMode) { "test" } else { "set" }

if ($module.Params.config_file) {
    $configFilePath = $module.Params.config_file
    $inputObject = $null
}
else {
    $configDoc = $module.Params.config
    # '$schema' property must always be provided as part of config document; populate a default if necessary
    if ($null -eq $configDoc['$schema']) {
        $configDoc['$schema'] = "https://aka.ms/dsc/schemas/v3/bundled/config/document.json"
    }
    $configFilePath = "-"
    $inputObject = $configDoc | ConvertTo-Json -Depth 100 -Compress
}

# Create parameters argument, if provided
# It must be a JSON object with `parameters` property
$paramValuesArgs = @()
if ($module.Params.parameters) {
    $parametersJson = @{ parameters = $module.Params.parameters } | ConvertTo-Json -Depth 100 -Compress
    $paramValuesArgs = @( "--parameters=$parametersJson" )
}

$dscArgs = @{
    FilePath = "dsc.exe"
    ArgumentList = @(
        "--trace-format=plaintext"
        "--progress-format=none"
        "--trace-level=$($module.Params.trace_level)"
        "config"
        $paramValuesArgs
        $configSubcommand,
        "--file=$configFilePath"
        "--output-format=json"
    )
    InputObject = $inputObject
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

$module.Result.result = ConvertFrom-Json $dscReturn.Stdout
$module.Result.changed = $false
if ($module.DiffMode) {
    $module.Result.diff = @{
        before = @{ resources = @() }
        after = @{ resources = @() }
    }
}

# Determine how to parse DSC's output
switch ($module.Result.result.metadata."Microsoft.DSC".operation) {
    "set" {
        $beforeProp = "beforeState"
        $afterProp = "afterState"
        $changedPropertiesProp = "changedProperties"
    }
    "test" {
        $beforeProp = "actualState"
        $afterProp = "desiredState"
        $changedPropertiesProp = "differingProperties"
    }
    default {
        $module.FailJson("Unexpected operation result of type '$_'")
        $module.ExitJson()
    }
}

function Select-Diff {
    param (
        [Parameter(Mandatory, ValueFromPipeline = $true)]
        [PSCustomObject] $State,
        [Parameter(Mandatory, Position = 0)]
        [string[]] $ChangedProperties
    )

    process {
        $diff = @{}
        foreach ($p in $ChangedProperties) {
            if ($State | Get-Member $p) {
                $diff[$p] = $State.$p
            }
        }
        return $diff
    }
}

# Aggregate each resource's result
foreach ($resource in $module.Result.result.results) {
    $before = $resource.result.$beforeProp
    $after = $resource.result.$afterProp
    $changedProperties = $resource.result.$changedPropertiesProp

    if (($before._inDesiredState -eq $false) -or $changedProperties) {
        $module.Result.changed = $true
    }

    # Create diff, if requested
    if ($module.Result.diff) {
        if ($changedProperties) {
            $module.Result.diff.before.resources += @{
                name = $resource.name
                type = $resource.type
                properties = $before | Select-Diff $changedProperties
            }
            $module.Result.diff.after.resources += @{
                name = $resource.name
                type = $resource.type
                properties = $after | Select-Diff $changedProperties
            }
        }
        else {
            # If this resource has not changed, still emit name and type for identification
            $diff = @{ name = $resource.name; type = $resource.type }
            $module.Result.diff.before.resources += $diff
            $module.Result.diff.after.resources += $diff
        }
    }
}

$module.ExitJson()
