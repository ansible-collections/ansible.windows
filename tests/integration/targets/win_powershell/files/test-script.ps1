[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $Name
)

@{
    Name = $Name
    Unicode = 'ü'
}
