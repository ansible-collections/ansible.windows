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
        directives = @{ type = "dict" }
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
        what_if = @{ type = "bool"; default = $false }
    }
    required_one_of = @(
        , @("config", "config_file")
    )
    mutually_exclusive = @(
        @("config", "config_file"),
        @("directives", "config_file")
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

    # Group resources nest their results. Microsoft.DSC/Include returns a bare list of results from test while
    # Microsoft.DSC/Group and the set operation of all group resources return the list in the after/actual state.
    $children = $null
    if (Test-DscNestedResult $result) {
        $children = @($result)
    }
    else {
        foreach ($stateName in @('afterState', 'actualState')) {
            $state = Get-DscProperty $result $stateName
            if (Test-DscNestedResult $state) {
                $children = @($state)
                break
            }
        }
    }

    if ($null -ne $children) {
        $outcome.Before.resources = @()
        $outcome.After.resources = @()

        foreach ($child in $children) {
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

    $resultProperties = @()
    if ($result -is [System.Management.Automation.PSCustomObject]) {
        $resultProperties = @($result.PSObject.Properties.Name)
    }

    if ('inDesiredState' -in $resultProperties -or 'differingProperties' -in $resultProperties) {
        # Result of a test operation.
        $inDesiredState = Get-DscProperty $result 'inDesiredState'
        $changedProperties = ConvertTo-DscArray (Get-DscProperty $result 'differingProperties')
        $outcome.Changed = if ($null -ne $inDesiredState) { -not [bool]$inDesiredState } else { $changedProperties.Count -gt 0 }
        $beforeState = Get-DscProperty $result 'actualState'
        $afterState = Get-DscProperty $result 'desiredState'
    }
    elseif ('beforeState' -in $resultProperties -or 'afterState' -in $resultProperties) {
        # Result of a set operation.
        $changedProperties = ConvertTo-DscArray (Get-DscProperty $result 'changedProperties')
        $outcome.Changed = $changedProperties.Count -gt 0
        $beforeState = Get-DscProperty $result 'beforeState'
        $afterState = Get-DscProperty $result 'afterState'
    }
    else {
        return $outcome
    }

    if ($changedProperties.Count -gt 0) {
        $outcome.Before.properties = Select-DscDiff $beforeState $changedProperties
        $outcome.After.properties = Select-DscDiff $afterState $changedProperties
    }

    return $outcome
}

function ConvertFrom-DscTrace {
    <#
    .SYNOPSIS
    Parses the stderr output of dsc when run with --trace-format=json. Each line is a JSON object with the level
    and message, lines that aren't JSON (for example output of adapters) are kept as is.
    #>
    param (
        [AllowNull()]
        [AllowEmptyString()]
        [String]
        $Stderr
    )

    $entries = [System.Collections.Generic.List[Object]]::new()
    if (-not $Stderr) {
        return , $entries
    }

    # Messages emitted before dsc configures its trace format may contain ANSI colour sequences.
    $ansiPattern = [String][Char]27 + '\[[0-9;]*m'

    foreach ($line in ($Stderr -split "`r?`n")) {
        if (-not $line.Trim()) {
            continue
        }

        $level = $null
        $message = $line -replace $ansiPattern, ''
        if ($line.TrimStart().StartsWith('{')) {
            try {
                $trace = ConvertFrom-Json -InputObject $line -ErrorAction Stop
                $traceLevel = Get-DscProperty $trace 'level'
                $fields = Get-DscProperty $trace 'fields'

                # Messages of dsc itself use 'message', the ones relayed from resources use 'trace_message'.
                $traceMessage = $null
                if ($fields -is [System.Management.Automation.PSCustomObject]) {
                    foreach ($fieldName in @('message', 'trace_message')) {
                        $traceMessage = Get-DscProperty $fields $fieldName
                        if ($null -ne $traceMessage) {
                            break
                        }
                    }
                    if ($null -eq $traceMessage) {
                        $stringField = $fields.PSObject.Properties | Where-Object { $_.Value -is [String] } | Select-Object -First 1
                        if ($stringField) {
                            $traceMessage = $stringField.Value
                        }
                    }
                }

                if ($null -ne $traceLevel -and $null -ne $traceMessage) {
                    $level = ([String]$traceLevel).ToUpperInvariant()
                    $message = [String]$traceMessage
                }
            }
            catch {
                # Not a trace line, keep the raw value.
                $level = $null
            }
        }

        $entries.Add([PSCustomObject]@{
                Level = $level
                Message = $message
                Raw = ($line -replace $ansiPattern, '')
            })
    }

    return , $entries
}

$whatIf = $module.Params.what_if
$configSubcommand = if ($module.CheckMode -and -not $whatIf) { "test" } else { "set" }

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

    if ($null -ne $module.Params.directives) {
        $docDirectives = $configDoc['directives']
        if ($null -eq $docDirectives) {
            $docDirectives = @{}
            $configDoc['directives'] = $docDirectives
        }
        elseif ($docDirectives -isnot [System.Collections.IDictionary]) {
            $module.FailJson("The directives property of config must be a dictionary when the directives option is also set")
        }

        foreach ($key in $module.Params.directives.Keys) {
            $docDirectives[$key] = $module.Params.directives[$key]
        }
    }

    $configFilePath = "-"
    $inputObject = ConvertTo-Json -InputObject $configDoc -Depth 100 -Compress
}

if ($module.Params.chdir -and -not (Test-Path -LiteralPath $module.Params.chdir -PathType Container)) {
    $module.FailJson("The directory specified by chdir '$($module.Params.chdir)' does not exist")
}

# Build the argument list, the global options come first, then the config options, then the subcommand and its options.
$dscArgs = [System.Collections.Generic.List[String]]::new()
$dscArgs.Add("--trace-format=json")
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

$dscArgs.Add($configSubcommand)
$dscArgs.Add("--file=$configFilePath")
$dscArgs.Add("--output-format=json")
if ($configSubcommand -eq "set" -and $whatIf) {
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
    foreach ($key in @($environment.Keys)) {
        if ($key -eq 'DSC_RESOURCE_PATH') {
            $environment.Remove($key)
        }
    }
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
$trace = ConvertFrom-DscTrace -Stderr $dscReturn.Stderr

$module.Result.rc = $rc
$module.Result.stderr = $dscReturn.Stderr
$module.Result.stderr_lines = @($trace | ForEach-Object {
        if ($_.Level) { "$($_.Level) $($_.Message)" } else { $_.Raw }
    })

$seenWarnings = [System.Collections.Generic.HashSet[String]]::new()
foreach ($entry in $trace) {
    if ($entry.Level -ne 'WARN') {
        continue
    }

    # Resources relay their own trace messages prefixed with their process id, dedupe those across resources.
    $key = $entry.Message -replace '^PID \d+: ', ''
    if ($seenWarnings.Add($key)) {
        $module.Warn($entry.Message)
    }
}

if ($rc -ne 0) {
    $codeName = if ($dscExitCodeNames.ContainsKey($rc)) { $dscExitCodeNames[$rc] } else { "unknown error" }
    $errors = @($trace | Where-Object { $_.Level -eq 'ERROR' })
    $detail = if ($errors.Count -gt 0) {
        $errors[-1].Message
    }
    elseif ($trace.Count -gt 0) {
        $trace[$trace.Count - 1].Raw
    }

    $msg = "dsc config $configSubcommand failed with exit code $rc ($codeName)"
    if ($detail) {
        $msg += ": $detail"
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
$operation = [String](Get-DscProperty $executionInfo 'operation')
if ($operation -notin @('set', 'test')) {
    $module.FailJson("Unexpected operation result of type '$operation'")
}
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
$module.Result.restart_required = $restartEntries
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
