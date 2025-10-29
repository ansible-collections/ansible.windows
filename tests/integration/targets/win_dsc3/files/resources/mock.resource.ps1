[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$properties = $Input | ConvertFrom-Json -AsHashTable

$cmd = $args[0]
$changed = $properties.__changed
$properties.Remove("__changed")
$diff = $null

if (("set", "test") -contains $cmd) {
    $diff = @()
    foreach ($k in $changed.Keys) {
        $properties[$k] = $changed[$k]
        $diff += $k
    }

    if ($cmd -eq "test") {
        $properties["_inDesiredState"] = ![bool]$diff
    }
}

ConvertTo-Json $properties -Compress -Depth 100 | Write-Output
if ($null -ne $diff) {
    ConvertTo-Json $diff -Compress -Depth 100 | Write-Output
}
