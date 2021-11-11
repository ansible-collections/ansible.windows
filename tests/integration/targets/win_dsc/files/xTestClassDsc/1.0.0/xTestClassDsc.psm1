[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSDSCDscExamplesPresent", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSDSCDscTestsPresent", "")]
param()

enum Ensure {
    Absent
    Present
}

[DscResource()]
class xTestClassDsc {
    [DscProperty(Key)]
    [Ensure]$Ensure

    [xTestClassDsc] Get() {
        return $this
    }

    [bool] Test() {
        return $true
    }

    [void] Set() {
        [System.ServiceProcess.ServiceControllerStatus] $stopped = [System.ServiceProcess.ServiceControllerStatus]::Stopped
        if (-not $stopped) {
            throw "test"
        }
    }
}
