[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSDSCDscExamplesPresent", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSDSCDscTestsPresent", "")]
param()

#Requires -Version 5.0 -Modules CimCmdlets

Function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([Hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$KeyParam
    )
    Write-Verbose -Message "In Get-TargetResource"
    @{ Value = [bool](Get-Variable -Name DSCMachineStatus -Scope Global -ValueOnly) }
}

Function Set-TargetResource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$KeyParam,
        [Bool]$Value = $true
    )
    Write-Verbose -Message "In Set-TargetResource"
    Set-Variable -Name DSCMachineStatus -Scope Global -Value ([int]$Value)
}

Function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([Boolean])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [String]$KeyParam,
        [Bool]$Value = $true
    )
    Write-Verbose -Message "In Test-TargetResource"
    $false
}

Export-ModuleMember -Function *-TargetResource

