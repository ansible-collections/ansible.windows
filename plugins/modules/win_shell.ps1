#!powershell

# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

using namespace System.IO
using namespace System.Management.Automation.Security
using namespace System.Text

#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Module Ansible.ModuleUtils.FileUtil

#AnsibleRequires -PowerShell ..module_utils.Process
#AnsibleRequires -PowerShell ..module_utils._PSModulePath

# Cleanse CLIXML from stderr (sift out error stream data, discard others for now)
Function Format-Stderr($raw_stderr) {
    Try {
        # NB: this regex isn't perfect, but is decent at finding CLIXML amongst other stderr noise
        If ($raw_stderr -match "(?s)(?<prenoise1>.*)#< CLIXML(?<prenoise2>.*)(?<clixml><Objs.+</Objs>)(?<postnoise>.*)") {
            $clixml = [xml]$matches["clixml"]
            $filtered = $clixml.Objs.ChildNodes |
                Where-Object { $_.Name -eq 'S' } |
                Where-Object { $_.S -eq 'Error' } |
                ForEach-Object { $_.'#text'.Replace('_x000D__x000A_', '') } |
                Out-String

            $merged_stderr = "{0}{1}{2}{3}" -f @(
                $matches["prenoise1"],
                $matches["prenoise2"],
                # filter out just the Error-tagged strings for now, and zap embedded CRLF chars
                $filtered,
                $matches["postnoise"]) | Out-String

            return $merged_stderr.Trim()

            # FUTURE: parse/return other streams
        }
        Else {
            $raw_stderr
        }
    }
    Catch {
        "***EXCEPTION PARSING CLIXML: $_***" + $raw_stderr
    }
}

$spec = @{
    options = @{
        chdir = @{ type = "path" }
        cmd = @{
            aliases = @('_raw_params')
            required = $true
            type = 'str'
        }
        creates = @{ type = "path" }
        executable = @{ type = 'path' }
        removes = @{ type = "path" }
        stdin = @{ type = "str" }
        no_profile = @{ type = "bool"; default = $false }
        output_encoding_override = @{ type = "str" }
    }
    supports_check_mode = $false
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$chdir = $module.Params.chdir
$cmd = $module.Params.cmd.Trim()
$creates = $module.Params.creates
$executable = $module.Params.executable
$removes = $module.Params.removes
$stdin = $module.Params.stdin
$noProfile = $module.Params.no_profile
$outputEncodingOverride = $module.Params.output_encoding_override

$module.Result.cmd = $cmd

if ($creates -and (Test-AnsiblePath -Path $creates)) {
    $module.Result.msg = "skipped, since $creates exists"
    $module.Result.skipped = $true
    $module.Result.rc = 0
    $module.ExitJson()
}
if ($removes -and -not (Test-AnsiblePath -Path $removes)) {
    $module.Result.msg = "skipped, since $removes does not exist"
    $module.Result.skipped = $true
    $module.Result.rc = 0
    $module.ExitJson()
}

if (-not $executable) {
    $executable = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
}
elseif (-not $executable.EndsWith('.exe')) {
    $executable = "$executable.exe"
}

$executableName = [Path]::GetFileNameWithoutExtension($executable)
$newEnvironment = $null
if ($executableName -in @("powershell", "pwsh")) {
    # force input encoding to preamble-free UTF8 so PS sub-processes (eg, Start-Job) don't blow up
    # We skip when running in CLM as it won't be able to call these APIs.
    if ([SystemPolicy]::GetSystemLockdownPolicy() -eq 'None') {
        $cmd = "[Console]::InputEncoding = New-Object Text.UTF8Encoding `$false; $cmd"
    }

    if ($executableName -eq 'powershell' -and $IsCoreCLR) {
        # when running on pwsh, we need to adjust the PSModulePath to avoid loading
        # incompatible modules in the child powershell process.
        $newEnvironment = [Environment]::GetEnvironmentVariables()
        $newEnvironment['PSModulePath'] = Get-WinPSModulePath
    }

    # Base64 encode the command so we don't have to worry about the various levels of escaping
    $encodedCommand = [Convert]::ToBase64String([Encoding]::Unicode.GetBytes($cmd))

    $pwshArgs = @(
        if ($noProfile) {
            "-noprofile"
        }
        if (-not $stdin) {
            # if not passing stdin, also set noninteractive to avoid any prompts hanging the module
            "-noninteractive"
        }
        "-encodedcommand"
        $encodedCommand
    )
    $command = "`"$executable`" $($pwshArgs -join " ")"
}
else {
    # FUTURE: support arg translation from executable (or executable_args?) to process arguments for arbitrary interpreter?
    $command = "`"$executable`" /c $cmd"
}

$commandParams = @{
    FilePath = $executable
    CommandLine = $command
    Environment = $newEnvironment
}

if ($chdir) {
    $commandParams.WorkingDirectory = $chdir
}
if ($stdin) {
    $commandParams.InputObject = $stdin
}
if ($outputEncodingOverride) {
    $commandParams.OutputEncoding = $outputEncodingOverride
}

$startDatetime = [DateTime]::UtcNow
try {
    $cmdResult = Start-AnsibleWindowsProcess @commandParams
}
catch {
    $module.Result.rc = 2

    # Keep on checking inner exceptions to see if it has the NativeErrorCode to
    # report back.
    $exp = $_.Exception
    while ($exp) {
        if ($exp.PSObject.Properties.Name -contains 'NativeErrorCode') {
            $module.Result.rc = $exp.NativeErrorCode
            break
        }
        $exp = $exp.InnerException
    }

    $module.FailJson("Failed to run: '$rawCmdLine': $($_.Exception.Message)", $_)
}

$module.Result.changed = $true
$module.Result.stdout = $cmdResult.Stdout
$module.Result.stderr = Format-Stderr $cmdResult.Stderr
$module.Result.rc = $cmdResult.ExitCode

$endDatetime = [DateTime]::UtcNow
$module.Result.start = $startDatetime.ToString("yyyy-MM-dd HH:mm:ss.ffffff")
$module.Result.end = $endDatetime.ToString("yyyy-MM-dd HH:mm:ss.ffffff")
$module.Result.delta = $($endDatetime - $startDatetime).ToString("h\:mm\:ss\.ffffff")

if ($module.Result.rc -ne 0) {
    $module.FailJson("non-zero return code")
}

$module.ExitJson()
