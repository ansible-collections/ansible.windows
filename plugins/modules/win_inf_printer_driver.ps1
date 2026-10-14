#!powershell

# Copyright: (c) 2018, daBONDi (@daBONDi)
# Copyright: (c) 2022, nsjoseph (@nsjoseph)
# Copyright: (c) 2026, ch0nx (@ch0nx)
# SPDX-License-Identifier: GPL-3.0-only
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        inf_file = @{ type = 'str' }
        driver_name = @{ type = 'str'; required = $true }
        printer_env = @{ type = 'str'; choices = 'x86', 'x64'; default = 'x64' }
        state = @{ type = 'str'; choices = 'absent', 'present'; default = 'present' }
        remove_from_driver_store = @{ type = 'bool'; default = $false }
        remove_all = @{ type = 'bool'; default = $false }
    }
    required_if = @(
        , @('state', 'present', @('inf_file'))
    )
    supports_check_mode = $true
}

$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$inf_file = $module.Params.inf_file
$driver_name = $module.Params.driver_name
$printer_env = $module.Params.printer_env
$state = $module.Params.state
$remove_from_driver_store = $module.Params.remove_from_driver_store
$remove_all = $module.Params.remove_all

# Windows identifies print environments by their full name rather than the short architecture token.
$printer_environment = switch ($printer_env) {
    'x86' { 'Windows NT x86' }
    'x64' { 'Windows x64' }
}

function Install-Driver {
    if (-not (Test-Path -LiteralPath $inf_file)) {
        $module.FailJson("Cannot find or access the driver INF file at '$inf_file'.")
    }

    if ($module.CheckMode) {
        return
    }

    $inf_file_folder = (Get-Item -LiteralPath $inf_file).Directory.FullName.ToString()

    try {
        $driver_class = [WMIClass]'Win32_PrinterDriver'
        $driver_class.Scope.Options.EnablePrivileges = $true
        $driver_object = $driver_class.CreateInstance()
        $driver_object.Name = $driver_name
        $driver_object.DriverPath = $inf_file_folder
        $driver_object.Infname = $inf_file
        $driver_object.SupportedPlatform = $printer_environment
        $driver_object.Version = 3
        $return_value = $driver_class.AddPrinterDriver($driver_object)
        $null = $driver_class.Put()
        if ($return_value.ReturnValue -ne 0) {
            $module.FailJson("Error installing printer driver with WMI object. Return code: $($return_value.ReturnValue).")
        }
    }
    catch {
        $module.FailJson("Error installing printer driver: $($_.Exception.Message)", $_)
    }
}

function Uninstall-Driver {
    param (
        [Parameter(Mandatory = $true)]
        $TargetDriver
    )

    # By default only this printer driver is unregistered, and the package stays in the Windows driver store.
    $drivers_to_remove = @($TargetDriver)

    if ($remove_from_driver_store) {
        # Removing the package from the driver store affects every driver that shares the same INF file.
        $sharing_drivers = @(Get-PrinterDriver | Where-Object { $_.InfPath -eq $TargetDriver.InfPath })
        if (($sharing_drivers.Count -gt 1) -and (-not $remove_all)) {
            $module.FailJson("The INF file '$($TargetDriver.InfPath)' is used by $($sharing_drivers.Count) printer drivers. " +
                'Set remove_all=true to remove them all from the driver store, ' +
                "or set remove_from_driver_store=false to only unregister '$driver_name'.")
        }
        if ($sharing_drivers.Count -gt 1) {
            $drivers_to_remove = $sharing_drivers
        }
    }

    if (-not $module.CheckMode) {
        try {
            # A shared driver package cannot be deleted from the store while more than one
            # driver references it, so unregister every driver first and only pass
            # -RemoveFromDriverStore on the final removal, once the package is unreferenced.
            for ($i = 0; $i -lt $drivers_to_remove.Count; $i++) {
                if ($remove_from_driver_store -and ($i -eq ($drivers_to_remove.Count - 1))) {
                    $drivers_to_remove[$i] | Remove-PrinterDriver -RemoveFromDriverStore
                }
                else {
                    $drivers_to_remove[$i] | Remove-PrinterDriver
                }
            }
        }
        catch {
            $module.FailJson("Error removing printer driver: $($_.Exception.Message)", $_)
        }
    }

    return $drivers_to_remove
}

$existing_driver = Get-PrinterDriver -Name $driver_name -PrinterEnvironment $printer_environment -ErrorAction SilentlyContinue

if (($state -eq 'present') -and (-not $existing_driver)) {
    Install-Driver
    $module.Result.changed = $true
    $module.Diff.before = ''
    $module.Diff.after = "$driver_name ($printer_environment)`n"
}
elseif (($state -eq 'absent') -and $existing_driver) {
    $removed_drivers = Uninstall-Driver -TargetDriver $existing_driver
    $module.Result.changed = $true
    $module.Diff.before = ($removed_drivers | ForEach-Object { "$($_.Name) ($($_.PrinterEnvironment))`n" }) -join ''
    $module.Diff.after = ''
}

$module.ExitJson()