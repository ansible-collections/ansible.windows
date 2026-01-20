[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$before = ($env:FAKE_BEFORE_STATE ?? "{}") | ConvertFrom-Json -AsHashTable
$after = ($env:FAKE_AFTER_STATE ?? "{}") | ConvertFrom-Json -AsHashTable

$cmd = $args[0]

switch ($cmd) {
    "get" {
        $diff = $null
    }
    "set" {
        $diff = @()
    }
    "test" {
        $diff = @()
        $after = $Input | ConvertFrom-Json -AsHashTable
    }
}

if ($null -ne $diff) {
    foreach ($k in $after.Keys) {
        if ((-not $before.ContainsKey($k)) -or ($after[$k] -ne $before[$k])) {
            $diff += $k
        }
    }
}

switch ($cmd) {
    "get" { $outputState = $before }
    "set" { $outputState = $after }
    "test" {
        $outputState = $before
        $outputState["_inDesiredState"] = ![bool]$diff
    }
}

ConvertTo-Json $outputState -Compress -Depth 100 | Write-Output
if ($null -ne $diff) {
    ConvertTo-Json $diff -Compress -Depth 100 | Write-Output
}

if ($null -ne $env:FAKE_EXIT_CODE) {
    exit $env:FAKE_EXIT_CODE -as [int]
}
