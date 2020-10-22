# Copyright (c) 2020 Ansible Project
# Simplified BSD License (see licenses/simplified_bsd.txt or https://opensource.org/licenses/BSD-2-Clause)

#AnsibleRequires -CSharpUtil .Process

Function Resolve-ExecutablePath {
    <#
    .SYNOPSIS
    Tries to resolve the file path to a valid executable.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $FilePath,

        [String]
        $WorkingDirectory
    )

    # Ensure the path has an extension set, default to .exe
    if (-not [IO.Path]::HasExtension($FilePath)) {
        $FilePath = "$FilePath.exe"
    }

    # See the if path is resolvable using the normal PATH logic. Also resolves absolute paths and relative paths if
    # they exist.
    $command = Get-Command -Name $FilePath -CommandType Application -ErrorAction SilentlyContinue
    if ($command) {
        $command.Source
        return
    }

    # If -WorkingDirectory is specified, check if the path is relative to that
    if ($WorkingDirectory) {
        $file = $PSCmdlet.GetUnresolvedProviderPathFromPSPath((Join-Path -Path $WorkingDirectory -ChildPath $FilePath))
        if (Test-Path -LiteralPath $file) {
            $file
            return
        }
    }

    # Just hope for the best and use whatever was provided.
    $FilePath
}

Function ConvertFrom-EscapedArgument {
    <#
    .SYNOPSIS
    Extract individual arguments from a command line string.

    .PARAMETER InputObject
    The command line string to extract the arguments from.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [String[]]
        $InputObject
    )

    process {
        foreach ($command in $InputObject) {
            [Ansible.Windows.Process.ProcessUtil]::ParseCommandLine($command)
        }
    }
}

Function ConvertTo-EscapedArgument {
    <#
    .SYNOPSIS
    Escapes an argument value so it can be used in a call to CreateProcess.

    .PARAMETER InputObject
    The argument(s) to escape.
    #>
    [CmdletBinding()]
    [OutputType([String])]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [String[]]
        $InputObject
    )

    process {
        foreach ($argument in $InputObject) {
            if (-not $argument) {
                return '""'
            }
            elseif ($argument -notmatch '[\s"]') {
                return $argument
            }

            # Replace any double quotes in an argument with '\"'
            $argument = $argument -replace '"', '\"'

            # Double up on any '\' chars that preceded a double quote
            $argument = $argument -replace '(\\+)\"', '$1$1\"'

            # Double up '\' at the end of the argument so it doesn't escape end quote.
            $argument = $argument -replace '(\\+)$', '$1$1'

            # Finally wrap the entire argument in double quotes now we've escaped the double quotes within
            '"{0}"' -f $argument
        }
    }
}

Function Start-AnsibleWindowsProcess {
    <#
    .SYNOPSIS
    Start a process and wait for it to finish.

    .PARAMETER FilePath
    The file to execute.

    .PARAMETER ArgumentList
    Arguments to execute, these will be escaped so the literal value is used.

    .PARAMETER CommandLine
    The raw command line to call with CreateProcess. These values are not escaped for you so use at your own risk.

    .PARAMETER WorkingDirectory
    The working directory to set on the new process, defaults to the current working dir.

    .PARAMETER Environment
    Override the environment to set for the new process, if not set then the current environment will be used.

    .PARAMETER InputObject
    A string or byte[] array to send to the process' stdin when it has started.

    .PARAMETER OutputEncodingOverride
    The encoding name to use when reading the stdout/stderr of the process. Defaults to utf-8 if not set.

    .PARAMETER WaitChildren
    Whether to wait for any child process spawned to finish before returning. This only works on Windows hosts on
    Server 2012/Windows 8 or newer.

    .OUTPUTS
    [PSCustomObject]@{
        Command = The final command used to start the process
        Stdout = The stdout of the process
        Stderr = The stderr of the process
        ExitCode = The return code from the process
    }
    #>
    [CmdletBinding(DefaultParameterSetName='ArgumentList')]
    [OutputType('Ansible.Windows.Process.Info')]
    param (
        [Parameter(Mandatory=$true, ParameterSetName='ArgumentList')]
        [Parameter(ParameterSetName='CommandLine')]
        [String]
        $FilePath,

        [Parameter(ParameterSetName='ArgumentList')]
        [String[]]
        $ArgumentList,

        [Parameter(ParameterSetName='CommandLine')]
        [String]
        $CommandLine,

        [String]
        $WorkingDirectory,

        [Collections.IDictionary]
        $Environment,

        [Object]
        $InputObject,

        [String]
        [Alias('OutputEncoding')]
        $OutputEncodingOverride,

        [Switch]
        $WaitChildren
    )

    if ($WorkingDirectory) {
        if (-not (Test-Path -LiteralPath $WorkingDirectory)) {
            Write-Error -Message "Could not find specified -WorkingDirectory '$WorkingDirectory'"
            return
        }
    }

    if ($FilePath) {
        $applicationName = Resolve-ExecutablePath -FilePath $FilePath -WorkingDirectory $WorkingDirectory
    }
    else {
        $applicationName = [NullString]::Value
    }

    # When -ArgumentList is used, we need to escape each argument, including the FilePath to build our CommandLine.
    if ($PSCmdlet.ParameterSetName -eq 'SplitArgs') {
        $CommandLine = ConvertTo-EscapedArgument -Argument $applicationName
        if ($ArgumentList) {
            $escapedArguments = @($ArgumentList | ConvertTo-EscapedArgument)
            $CommandLine += " $($escapedArguments -join ' '))"
        }
    }

    $stdin = switch ($InputObject) {
        { $null -eq $_ } { $null }
        { $_ -is [byte[]] } { ,$_ }
        { $_ -is [String] } { ,[Text.Encoding]::UTF8.GetBytes($InputObject) }
        default {
            Write-Error -Message "InputObject must be a string or byte[]"
            return
        }
    }

    $res = [Ansible.Windows.Process.ProcessUtil]::CreateProcess($applicationName, $CommandLine, $WorkingDirectory,
        $Environment, $stdin, $OutputEncodingOverride, $WaitChildren)

    [PSCustomObject]@{
        PSTypeName = 'Ansible.Windows.Process.Info'
        Command = $CommandLine
        Stdout = $res.Stdout
        Stderr = $res.Stderr
        ExitCode = $res.ExitCode
    }
}

$export_members = @{
    Function = 'ConvertFrom-EscapedArgument', 'ConvertTo-EscapedArgument', 'Start-AnsibleWindowsProcess'
}
Export-ModuleMember @export_members
