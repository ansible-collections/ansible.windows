#!powershell

# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -PowerShell Ansible.ModuleUtils.AddType
#AnsibleRequires -CSharpUtil Ansible.Basic
#Requires -Module Ansible.ModuleUtils.CamelConversion

$spec = @{
    options = @{
        path = @{ type = "str"; default = "\" }
        name = @{ type = "str" }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$path = $module.Params.path
$name = $module.Params.name

Function ConvertTo-NormalizedUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [String]$InputObject
    )

    $candidates = @(if ($InputObject.Contains('\')) {
            $nameSplit = $InputObject.Split('\', 2)

            if ($nameSplit[0] -eq '.') {
                # If the domain portion is . try using the hostname then falling back to just the username.
                # Usually the hostname just works except when running on a DC where it's a domain account
                # where looking up just the username should work.
                , @($env:COMPUTERNAME, $nameSplit[1])
                $nameSplit[1]
            }
            else {
                , $nameSplit
            }
        }
        else {
            $InputObject
        })

    $sid = for ($i = 0; $i -lt $candidates.Length; $i++) {
        $candidate = $candidates[$i]
        $ntAccount = New-Object -TypeName System.Security.Principal.NTAccount -ArgumentList $candidate
        try {
            $ntAccount.Translate([System.Security.Principal.SecurityIdentifier])
            break
        }
        catch [System.Security.Principal.IdentityNotMappedException] {
            if ($i -eq ($candidates.Length - 1)) {
                throw
            }
            continue
        }
    }

    $sid.Translate([System.Security.Principal.NTAccount]).Value
}

Add-CSharpType -AnsibleModule $module -References @'
public enum TASK_ACTION_TYPE
{
    TASK_ACTION_EXEC          = 0,
    // The below are not supported and are only kept for documentation purposes
    TASK_ACTION_COM_HANDLER   = 5,
    TASK_ACTION_SEND_EMAIL    = 6,
    TASK_ACTION_SHOW_MESSAGE  = 7
}

public enum TASK_LOGON_TYPE
{
    TASK_LOGON_NONE                           = 0,
    TASK_LOGON_PASSWORD                       = 1,
    TASK_LOGON_S4U                            = 2,
    TASK_LOGON_INTERACTIVE_TOKEN              = 3,
    TASK_LOGON_GROUP                          = 4,
    TASK_LOGON_SERVICE_ACCOUNT                = 5,
    TASK_LOGON_INTERACTIVE_TOKEN_OR_PASSWORD  = 6
}

public enum TASK_RUN_LEVEL
{
    TASK_RUNLEVEL_LUA      = 0,
    TASK_RUNLEVEL_HIGHEST  = 1
}

public enum TASK_STATE
{
    TASK_STATE_UNKNOWN   = 0,
    TASK_STATE_DISABLED  = 1,
    TASK_STATE_QUEUED    = 2,
    TASK_STATE_READY     = 3,
    TASK_STATE_RUNNING   = 4
}

public enum TASK_TRIGGER_TYPE2
{
    TASK_TRIGGER_EVENT                 = 0,
    TASK_TRIGGER_TIME                  = 1,
    TASK_TRIGGER_DAILY                 = 2,
    TASK_TRIGGER_WEEKLY                = 3,
    TASK_TRIGGER_MONTHLY               = 4,
    TASK_TRIGGER_MONTHLYDOW            = 5,
    TASK_TRIGGER_IDLE                  = 6,
    TASK_TRIGGER_REGISTRATION          = 7,
    TASK_TRIGGER_BOOT                  = 8,
    TASK_TRIGGER_LOGON                 = 9,
    TASK_TRIGGER_SESSION_STATE_CHANGE  = 11
}

public enum TASK_SESSION_STATE_CHANGE_TYPE
{
    TASK_CONSOLE_CONNECT	= 1,
    TASK_CONSOLE_DISCONNECT	= 2,
    TASK_REMOTE_CONNECT	    = 3,
    TASK_REMOTE_DISCONNECT	= 4,
    TASK_SESSION_LOCK	    = 7,
    TASK_SESSION_UNLOCK	    = 8
}
'@

Function Get-PropertyValue($task_property, $com, $property) {
    $raw_value = $com.$property

    if ($null -eq $raw_value) {
        return $null
    }
    elseif ($raw_value.GetType().Name -eq "__ComObject") {
        $com_values = @{}
        Get-Member -InputObject $raw_value -MemberType Property | ForEach-Object {
            $com_value = Get-PropertyValue -task_property $property -com $raw_value -property $_.Name
            $com_values.$($_.Name) = $com_value
        }

        return , $com_values
    }

    switch ($property) {
        DaysOfWeek {
            $value_list = @()
            $map = @(
                @{ day = "sunday"; bitwise = 0x01 }
                @{ day = "monday"; bitwise = 0x02 }
                @{ day = "tuesday"; bitwise = 0x04 }
                @{ day = "wednesday"; bitwise = 0x08 }
                @{ day = "thursday"; bitwise = 0x10 }
                @{ day = "friday"; bitwise = 0x20 }
                @{ day = "saturday"; bitwise = 0x40 }
            )
            foreach ($entry in $map) {
                $day = $entry.day
                $bitwise = $entry.bitwise
                if ($raw_value -band $bitwise) {
                    $value_list += $day
                }
            }

            $value = $value_list -join ","
            break
        }
        DaysOfMonth {
            $value_list = @()
            $map = @(
                @{ day = "1"; bitwise = 0x01 }
                @{ day = "2"; bitwise = 0x02 }
                @{ day = "3"; bitwise = 0x04 }
                @{ day = "4"; bitwise = 0x08 }
                @{ day = "5"; bitwise = 0x10 }
                @{ day = "6"; bitwise = 0x20 }
                @{ day = "7"; bitwise = 0x40 }
                @{ day = "8"; bitwise = 0x80 }
                @{ day = "9"; bitwise = 0x100 }
                @{ day = "10"; bitwise = 0x200 }
                @{ day = "11"; bitwise = 0x400 }
                @{ day = "12"; bitwise = 0x800 }
                @{ day = "13"; bitwise = 0x1000 }
                @{ day = "14"; bitwise = 0x2000 }
                @{ day = "15"; bitwise = 0x4000 }
                @{ day = "16"; bitwise = 0x8000 }
                @{ day = "17"; bitwise = 0x10000 }
                @{ day = "18"; bitwise = 0x20000 }
                @{ day = "19"; bitwise = 0x40000 }
                @{ day = "20"; bitwise = 0x80000 }
                @{ day = "21"; bitwise = 0x100000 }
                @{ day = "22"; bitwise = 0x200000 }
                @{ day = "23"; bitwise = 0x400000 }
                @{ day = "24"; bitwise = 0x800000 }
                @{ day = "25"; bitwise = 0x1000000 }
                @{ day = "26"; bitwise = 0x2000000 }
                @{ day = "27"; bitwise = 0x4000000 }
                @{ day = "28"; bitwise = 0x8000000 }
                @{ day = "29"; bitwise = 0x10000000 }
                @{ day = "30"; bitwise = 0x20000000 }
                @{ day = "31"; bitwise = 0x40000000 }
            )

            foreach ($entry in $map) {
                $day = $entry.day
                $bitwise = $entry.bitwise
                if ($raw_value -band $bitwise) {
                    $value_list += $day
                }
            }

            $value = $value_list -join ","
            break
        }
        WeeksOfMonth {
            $value_list = @()
            $map = @(
                @{ week = "1"; bitwise = 0x01 }
                @{ week = "2"; bitwise = 0x02 }
                @{ week = "3"; bitwise = 0x04 }
                @{ week = "4"; bitwise = 0x04 }
            )

            foreach ($entry in $map) {
                $week = $entry.week
                $bitwise = $entry.bitwise
                if ($raw_value -band $bitwise) {
                    $value_list += $week
                }
            }

            $value = $value_list -join ","
            break
        }
        MonthsOfYear {
            $value_list = @()
            $map = @(
                @{ month = "january"; bitwise = 0x01 }
                @{ month = "february"; bitwise = 0x02 }
                @{ month = "march"; bitwise = 0x04 }
                @{ month = "april"; bitwise = 0x08 }
                @{ month = "may"; bitwise = 0x10 }
                @{ month = "june"; bitwise = 0x20 }
                @{ month = "july"; bitwise = 0x40 }
                @{ month = "august"; bitwise = 0x80 }
                @{ month = "september"; bitwise = 0x100 }
                @{ month = "october"; bitwise = 0x200 }
                @{ month = "november"; bitwise = 0x400 }
                @{ month = "december"; bitwise = 0x800 }
            )

            foreach ($entry in $map) {
                $month = $entry.month
                $bitwise = $entry.bitwise
                if ($raw_value -band $bitwise) {
                    $value_list += $month
                }
            }

            $value = $value_list -join ","
            break
        }
        Type {
            if ($task_property -eq "actions") {
                $value = [Enum]::ToObject([TASK_ACTION_TYPE], $raw_value).ToString()
            }
            elseif ($task_property -eq "triggers") {
                $value = [Enum]::ToObject([TASK_TRIGGER_TYPE2], $raw_value).ToString()
            }
            break
        }
        RunLevel {
            $value = [Enum]::ToObject([TASK_RUN_LEVEL], $raw_value).ToString()
            break
        }
        LogonType {
            $value = [Enum]::ToObject([TASK_LOGON_TYPE], $raw_value).ToString()
            break
        }
        UserId {
            $value = ConvertTo-NormalizedUser -InputObject $raw_value
        }
        GroupId {
            $value = ConvertTo-NormalizedUser -InputObject $raw_value
        }
        default {
            $value = $raw_value
            break
        }
    }

    return , $value
}

$service = New-Object -ComObject Schedule.Service
try {
    $service.Connect()
}
catch {
    $module.FailJson("failed to connect to the task scheduler service: $($_.Exception.Message)", $_)
}

try {
    $task_folder = $service.GetFolder($path)
    $module.Result.folder_exists = $true
}
catch {
    $module.Result.folder_exists = $false
    if ($null -ne $name) {
        $module.Result.task_exists = $false
    }
    $module.ExitJson()
}

$folder_tasks = $task_folder.GetTasks(1)
$folder_task_names = @()
$folder_task_count = 0
$task = $null
for ($i = 1; $i -le $folder_tasks.Count; $i++) {
    $task_name = $folder_tasks.Item($i).Name
    $folder_task_names += $task_name
    $folder_task_count += 1

    if ($null -ne $name -and $task_name -eq $name) {
        $task = $folder_tasks.Item($i)
    }
}
$module.Result.folder_task_names = $folder_task_names
$module.Result.folder_task_count = $folder_task_count

if ($null -ne $name) {
    if ($null -ne $task) {
        $module.Result.task_exists = $true

        # task state
        $module.Result.state = @{
            last_run_time = (Get-Date $task.LastRunTime -Format s)
            last_task_result = $task.LastTaskResult
            next_run_time = (Get-Date $task.NextRunTime -Format s)
            number_of_missed_runs = $task.NumberOfMissedRuns
            status = [Enum]::ToObject([TASK_STATE], $task.State).ToString()
        }

        # task definition
        $task_definition = $task.Definition
        $ignored_properties = @("XmlText")
        $properties = @("principal", "registration_info", "settings")
        $collection_properties = @("actions", "triggers")

        foreach ($property in $properties) {
            $property_name = $property -replace "_"
            $module.Result.$property = @{}
            $values = $task_definition.$property_name
            Get-Member -InputObject $values -MemberType Property | ForEach-Object {
                if ($_.Name -notin $ignored_properties) {
                    $module.Result.$property.$($_.Name) = (Get-PropertyValue -task_property $property -com $values -property $_.Name)
                }
            }
        }

        foreach ($property in $collection_properties) {
            $module.Result.$property = @()
            $collection = $task_definition.$property
            $collection_count = $collection.Count
            for ($i = 1; $i -le $collection_count; $i++) {
                $item = $collection.Item($i)
                $item_info = @{}

                Get-Member -InputObject $item -MemberType Property | ForEach-Object {
                    if ($_.Name -notin $ignored_properties) {
                        $value = (Get-PropertyValue -task_property $property -com $item -property $_.Name)
                        $item_info.$($_.Name) = $value

                        # This was added after StateChange was represented by the raw enum value so we include both
                        # for backwards compatibility.
                        if ($_.Name -eq 'StateChange') {
                            $item_info.StateChangeStr = if ($value) {
                                [Enum]::ToObject([TASK_SESSION_STATE_CHANGE_TYPE], $value).ToString()
                            }
                        }
                    }
                }
                $module.Result.$property += $item_info
            }
        }
    }
    else {
        $module.Result.task_exists = $false
    }
}

# Convert-DictToSnakeCase returns a Hashtable but Ansible.Basic expect a Dictionary. This is a hack until the snake
# conversion code has been moved to this collection and updated to handle this.
$new_result = [System.Collections.Generic.Dictionary[[String], [Object]]]@{}
foreach ($kvp in (Convert-DictToSnakeCase -dict $module.Result).GetEnumerator()) {
    $new_result[$kvp.Name] = $kvp.Value
}
$module.Result = $new_result

$module.ExitJson()