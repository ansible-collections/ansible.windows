#!powershell

# Copyright: Contributors to the Ansible project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic
#AnsibleRequires -PowerShell ansible_collections.ansible.windows.plugins.module_utils.Process

$spec = @{
    options = @{
        chdir = @{ type = "path" }
        config = @{ type = "dict" }
        config_file = @{ type = "path" }
        executable = @{ type = "path"; default = "dsc.exe" }
        ignore_settings_file = @{ type = "bool"; default = $false }
        parameters = @{ type = "dict" }
        parameters_file = @{ type = "path" }
        remote_config_file = @{ type = "bool"; default = $false }
        resource_path = @{ type = "list"; elements = "path" }
        system_root = @{ type = "path" }
        trace_level = @{
            type = "str"
            choices = @("error", "warn", "info", "debug", "trace")
            default = "warn"
        }
    }
    required_one_of = @(
        , @("config", "config_file")
    )
    mutually_exclusive = @(
        , @("config", "config_file")
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$defaultSchema = "https://aka.ms/dsc/schemas/v3/bundled/config/document.json"

# Exit codes as defined in dsc/src/util.rs of the DSC repository.
$dscExitCodeNames = @{
    1 = "invalid arguments"
    2 = "DSC error"
    3 = "JSON error"
    4 = "invalid input"
    5 = "validation failed"
    6 = "interrupted"
    7 = "resource not found"
    8 = "assertion failed"
    9 = "server failed"
    10 = "bicep failed"
}

function Get-DscProperty {
    <#
    .SYNOPSIS
    Gets a property of a deserialized JSON object by exact name, or $null when it doesn't exist.
    Arrays are returned as a single object rather than being enumerated.
    #>
    param (
        [AllowNull()]
        [Object]
        $Object,

        [Parameter(Mandatory)]
        [String]
        $Name
    )

    if ($null -eq $Object) {
        return $null
    }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return , $Object[$Name]
        }
        return $null
    }

    if ($Object -isnot [System.Management.Automation.PSCustomObject]) {
        return $null
    }

    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }

    return , $property.Value
}

function Get-DscExecutionInfo {
    <#
    .SYNOPSIS
    Gets the execution information of a DSC result node. DSC 3.2+ returns it as 'executionInformation', older
    releases only under 'metadata.Microsoft.DSC' which is deprecated and removed in a future major version.
    #>
    param (
        [AllowNull()]
        [Object]
        $Node
    )

    $executionInfo = Get-DscProperty $Node 'executionInformation'
    if ($null -ne $executionInfo) {
        return $executionInfo
    }

    $metadata = Get-DscProperty $Node 'metadata'
    return (Get-DscProperty $metadata 'Microsoft.DSC')
}

function ConvertTo-DscArray {
    <#
    .SYNOPSIS
    Wraps a value in an array, returning an empty array for $null (@($null) has a count of 1).
    #>
    param (
        [AllowNull()]
        [Object]
        $Value
    )

    if ($null -eq $Value) {
        return , @()
    }

    return , @($Value)
}

function Test-DscNestedResult {
    <#
    .SYNOPSIS
    Checks whether a value is a list of nested resource results, as returned for group resources such as
    Microsoft.DSC/Group and Microsoft.DSC/Include.
    #>
    param (
        [AllowNull()]
        [Object]
        $Value
    )

    if ($null -eq $Value -or $Value -is [String] -or $Value -isnot [System.Collections.IList]) {
        return $false
    }

    if ($Value.Count -eq 0) {
        return $false
    }

    foreach ($item in $Value) {
        if ($item -isnot [System.Management.Automation.PSCustomObject]) {
            return $false
        }

        foreach ($required in @('name', 'type', 'result')) {
            if ($null -eq $item.PSObject.Properties[$required]) {
                return $false
            }
        }
    }

    return $true
}

function Select-DscDiff {
    <#
    .SYNOPSIS
    Selects the named properties from a resource state for use in the diff output.
    #>
    param (
        [AllowNull()]
        [Object]
        $State,

        [AllowEmptyCollection()]
        [String[]]
        $Properties
    )

    $diff = @{}
    if ($State -isnot [System.Management.Automation.PSCustomObject]) {
        return $diff
    }

    foreach ($name in $Properties) {
        $property = $State.PSObject.Properties[$name]
        if ($null -ne $property) {
            $diff[$name] = $property.Value
        }
    }

    return $diff
}

function Resolve-DscResultNode {
    <#
    .SYNOPSIS
    Walks a resource result, recursing into nested group results, and returns whether it changed, the restart
    requirements it reported and its before/after diff entries.
    #>
    param (
        [Parameter(Mandatory)]
        [Object]
        $Node
    )

    $name = Get-DscProperty $Node 'name'
    $type = Get-DscProperty $Node 'type'
    $result = Get-DscProperty $Node 'result'

    $outcome = @{
        Changed = $false
        RestartRequired = @()
        Before = @{ name = $name; type = $type }
        After = @{ name = $name; type = $type }
    }

    $restartRequired = Get-DscProperty (Get-DscExecutionInfo $Node) 'restartRequired'
    if ($null -ne $restartRequired) {
        $outcome.RestartRequired = @($restartRequired)
    }

    # Group resources such as Microsoft.DSC/Group and Microsoft.DSC/Include return the results of their nested
    # resources as the after state.
    $afterState = Get-DscProperty $result 'afterState'
    if (Test-DscNestedResult $afterState) {
        $outcome.Before.resources = @()
        $outcome.After.resources = @()

        foreach ($child in @($afterState)) {
            $childOutcome = Resolve-DscResultNode -Node $child
            if ($childOutcome.Changed) {
                $outcome.Changed = $true
            }
            $outcome.RestartRequired = @($outcome.RestartRequired) + @($childOutcome.RestartRequired)
            $outcome.Before.resources += , $childOutcome.Before
            $outcome.After.resources += , $childOutcome.After
        }

        return $outcome
    }

    $changedProperties = ConvertTo-DscArray (Get-DscProperty $result 'changedProperties')
    if ($changedProperties.Count -gt 0) {
        $outcome.Changed = $true
        $outcome.Before.properties = Select-DscDiff (Get-DscProperty $result 'beforeState') $changedProperties
        $outcome.After.properties = Select-DscDiff $afterState $changedProperties
    }

    return $outcome
}

function Get-DscTraceMessage {
    <#
    .SYNOPSIS
    Gets the messages of a trace level from the plaintext stderr output of dsc, where each trace line looks like
    '2025-01-01T00:00:00.000000Z  WARN The message'. This is best effort, lines that don't match are ignored.
    #>
    param (
        [AllowNull()]
        [AllowEmptyString()]
        [String]
        $Stderr,

        [Parameter(Mandatory)]
        [String]
        $Level
    )

    foreach ($line in ($Stderr -split "`r?`n")) {
        if ($line -match "^\d{4}-\d{2}-\d{2}T\S+\s+$Level\s+(?<message>.+)$") {
            $Matches.message.Trim()
        }
    }
}

if ($module.Params.config_file) {
    $configFilePath = $module.Params.config_file
    $inputObject = $null
}
else {
    $configDoc = $module.Params.config

    # The '$schema' property must always be provided as part of the config document, populate a default if necessary.
    if ($null -eq $configDoc['$schema']) {
        $configDoc['$schema'] = $defaultSchema
    }

    $configFilePath = "-"
    $inputObject = ConvertTo-Json -InputObject $configDoc -Depth 100 -Compress
}

if ($module.Params.chdir -and -not (Test-Path -LiteralPath $module.Params.chdir -PathType Container)) {
    $module.FailJson("The directory specified by chdir '$($module.Params.chdir)' does not exist")
}

# Build the argument list, the global options come first, then the config options, then the subcommand and its options.
$dscArgs = [System.Collections.Generic.List[String]]::new()
$dscArgs.Add("--trace-format=plaintext")
$dscArgs.Add("--progress-format=none")
$dscArgs.Add("--trace-level=$($module.Params.trace_level)")
if ($module.Params.ignore_settings_file) {
    $dscArgs.Add("--ignore-settings-file")
}

$dscArgs.Add("config")
if ($null -ne $module.Params.parameters -and $module.Params.parameters.Count -gt 0) {
    # Parameter values must be a JSON object with a top-level 'parameters' property.
    $parametersJson = ConvertTo-Json -InputObject @{ parameters = $module.Params.parameters } -Depth 100 -Compress
    $dscArgs.Add("--parameters=$parametersJson")
}
if ($module.Params.parameters_file) {
    $dscArgs.Add("--parameters-file=$($module.Params.parameters_file)")
}
if ($module.Params.system_root) {
    $dscArgs.Add("--system-root=$($module.Params.system_root)")
}

$dscArgs.Add("set")
$dscArgs.Add("--file=$configFilePath")
$dscArgs.Add("--output-format=json")
if ($module.CheckMode) {
    $dscArgs.Add("--what-if")
}

$processParams = @{
    FilePath = $module.Params.executable
    ArgumentList = $dscArgs.ToArray()
}
if ($null -ne $inputObject) {
    $processParams.InputObject = $inputObject
}
if ($module.Params.chdir) {
    $processParams.WorkingDirectory = $module.Params.chdir
}
if ($module.Params.resource_path) {
    # The Environment parameter replaces the whole environment of the process so it must be seeded from the current one.
    $environment = [System.Environment]::GetEnvironmentVariables()
    $environment['DSC_RESOURCE_PATH'] = @($module.Params.resource_path) -join ';'
    $processParams.Environment = $environment
}

try {
    $dscReturn = Start-AnsibleWindowsProcess @processParams
}
catch {
    $module.FailJson("Failed to run '$($module.Params.executable)': $($_.Exception.Message)", $_)
}

$rc = [int]$dscReturn.ExitCode
$module.Result.rc = $rc
$module.Result.stderr = $dscReturn.Stderr

foreach ($warning in (Get-DscTraceMessage -Stderr $dscReturn.Stderr -Level WARN)) {
    $module.Warn($warning)
}

if ($rc -ne 0) {
    $codeName = if ($dscExitCodeNames.ContainsKey($rc)) { $dscExitCodeNames[$rc] } else { "unknown error" }
    $msg = "dsc config set failed with exit code $rc ($codeName)"

    $errors = @(Get-DscTraceMessage -Stderr $dscReturn.Stderr -Level ERROR)
    if ($errors.Count -gt 0) {
        $msg += ": $($errors[-1])"
    }
    $module.FailJson($msg)
}

try {
    $dscResult = ConvertFrom-Json -InputObject $dscReturn.Stdout -ErrorAction Stop
}
catch {
    $module.FailJson("dsc returned output that is not valid JSON: $($_.Exception.Message)", $_)
}
$module.Result.result = $dscResult

$executionInfo = Get-DscExecutionInfo $dscResult
$module.Result.security_context = Get-DscProperty $executionInfo 'securityContext'
$module.Result.execution_type = Get-DscProperty $executionInfo 'executionType'

# Aggregate each resource's result.
$module.Result.changed = $false
$restartRequired = [System.Collections.Generic.List[Object]]::new()
$diffBefore = @()
$diffAfter = @()
foreach ($node in (ConvertTo-DscArray (Get-DscProperty $dscResult 'results'))) {
    $outcome = Resolve-DscResultNode -Node $node
    if ($outcome.Changed) {
        $module.Result.changed = $true
    }
    foreach ($entry in @($outcome.RestartRequired)) {
        $restartRequired.Add($entry)
    }
    $diffBefore += , $outcome.Before
    $diffAfter += , $outcome.After
}

# DSC 3.2+ aggregates the restart requirements of all resources, older releases need the per resource values.
$restartEntries = Get-DscProperty $executionInfo 'restartRequired'
if ($null -ne $restartEntries) {
    $restartEntries = @($restartEntries)
}
else {
    $seenRestart = [System.Collections.Generic.HashSet[String]]::new()
    $restartEntries = @(foreach ($entry in $restartRequired) {
            if ($seenRestart.Add((ConvertTo-Json -InputObject $entry -Depth 10 -Compress))) {
                $entry
            }
        })
}
$module.Result.restart_requirements = $restartEntries
$module.Result.reboot_required = @($restartEntries | Where-Object {
        $_ -is [System.Management.Automation.PSCustomObject] -and $null -ne $_.PSObject.Properties['system']
    }).Count -gt 0

if ($module.DiffMode) {
    $module.Result.diff = @{
        before = @{ resources = $diffBefore }
        after = @{ resources = $diffAfter }
    }
}

$module.ExitJson()
