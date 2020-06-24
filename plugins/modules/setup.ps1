#!powershell

# Copyright: (c) 2018, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

#AnsibleRequires -CSharpUtil Ansible.Basic

$spec = @{
    options = @{
        fact_path = @{ type = 'path' }
        gather_subset = @{ type = 'list'; elements = 'str'; default = 'all' }
        gather_timeout = @{ type = 'int'; default = 10 }
    }
    supports_check_mode = $true
}
$module = [Ansible.Basic.AnsibleModule]::Create($args, $spec)

$factPath = $module.Params.fact_path
$gatherSubset = $module.Params.gather_subset
$gatherTimeout = $module.Params.gather_timeout

$osversion = [Environment]::OSVersion.Version
if ($osversion -lt [version]"6.2") {
    # Server 2008, 2008 R2, and Windows 7 are not tested in CI and we want to let customers know about it before
    # removing support altogether.
    $versionString = "{0}.{1}" -f ($osversion.Major, $osversion.Minor)
    $module.Warn("The Windows version '$versionString' will no longer be supported or tested in future releases")
}

Function Get-LazyCimInstance {
    <#
    .SYNOPSIS
    Like Get-CimInstance but it caches the result so it is only retrieved once. Needs to be thread safe.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $ClassName,

        [String]
        $Namespace = 'Root\CIMV2'
    )
    # We don't want 2 threads to call Get-CimInstance at once so we have a mutex per class that only allows one get/set
    # to occur at the same time. Without this we could be wasting cycles trying to get the same instance due to a race
    # condition.
    $null = $cimMutex.$ClassName.WaitOne()
    try {
        if (-not $cimInstances.ContainsKey($ClassName)) {
            $cimInstances.$ClassName = Get-CimInstance -ClassName $ClassName -Namespace $Namespace
        }

        $cimInstances.$ClassName
    } finally {
        $cimMutex.$ClassName.ReleaseMutex()
    }
}

Function New-SessionStateFunction {
    <#
    .SYNOPSIS
    Create a session state function object that is loadable into a runspace pool.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $Name
    )

    New-Object -TypeName System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList @(
        $Name, (Get-Content -LiteralPath Function:\$Name)
    )
}

Function New-SessionStateVariable {
    <#
    .SYNOPSIS
    Create a session state variable object that is loadable into a runspace pool.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [String]
        $Name
    )

    New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList @(
        $Name, (Get-Variable -Name $Name -ValueOnly), $null
    )
}

$factMeta = @(
    @{
        Subsets = 'all_ipv4_addresses', 'all_ipv6_addresses'
        Code = {
            $netcfg = Get-LazyCimInstance -ClassName Win32_NetworkAdapterConfiguration
            $ips = @($netcfg.IPAddress | Where-Object { $_ })

            $ansibleFacts.ansible_ip_addresses = $ips
        }
    },
    @{
        Subsets = 'bios'
        Code = {
            $win32Bios = Get-LazyCimInstance -ClassName Win32_Bios
            $win32CS = Get-LazyCimInstance -ClassName Win32_ComputerSystem

            $ansibleFacts.ansible_bios_date = $win32Bios.ReleaseDate.ToString("MM/dd/yyyy")
            $ansibleFacts.ansible_bios_version = $win32Bios.SMBIOSBIOSVersion
            $ansibleFacts.ansible_product_name = $win32CS.Model.Trim()
            $ansibleFacts.ansible_product_serial = $win32Bios.SerialNumber
        }
    },
    @{
        Subsets = 'date_time'
        Code = {
            $datetime = (Get-Date)
            $datetimeUtc = $datetime.ToUniversalTime()

            $ansibleFacts.ansible_date_time = @{
                date = $datetime.ToString("yyyy-MM-dd")
                day = $datetime.ToString("dd")
                epoch = (Get-Date -UFormat "%s")
                hour = $datetime.ToString("HH")
                iso8601 = $datetimeUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")
                iso8601_basic = $datetime.ToString("yyyyMMddTHHmmssffffff")
                iso8601_basic_short = $datetime.ToString("yyyyMMddTHHmmss")
                iso8601_micro = $datetimeUtc.ToString("yyyy-MM-ddTHH:mm:ss.ffffffZ")
                minute = $datetime.ToString("mm")
                month = $datetime.ToString("MM")
                second = $datetime.ToString("ss")
                time = $datetime.ToString("HH:mm:ss")
                tz = ([System.TimeZoneInfo]::Local.Id)
                tz_offset = $datetime.ToString("zzzz")
                # Ensure that the weekday is in English
                weekday = $datetime.ToString("dddd", [System.Globalization.CultureInfo]::InvariantCulture)
                weekday_number = (Get-Date -UFormat "%w")
                weeknumber = (Get-Date -UFormat "%W")
                year = $datetime.ToString("yyyy")
            }
        }
    },
    @{
        Subsets = 'distribution'
        Code = {
            $win32OS = Get-LazyCimInstance -ClassName Win32_OperatingSystem
            $osversion = [Environment]::OSVersion.Version

            $productType = switch($win32OS.ProductType) {
                1 { "workstation" }
                2 { "domain_controller" }
                3 { "server" }
                default { "unknown" }
            }

            $currentVersionPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
            $installationType = if (Test-Path -LiteralPath $currentVersionPath) {
                $installTypeProp = Get-ItemProperty -LiteralPath $currentVersionPath -ErrorAction SilentlyContinue
                [String]$installTypeProp.InstallationType
            }

            $ansibleFacts.ansible_distribution = $win32OS.Caption
            $ansibleFacts.ansible_distribution_version = $osversion.ToString()
            $ansibleFacts.ansible_distribution_major_version = $osversion.Major.ToString()
            $ansibleFacts.ansible_os_family = "Windows"
            $ansibleFacts.ansible_os_name = ($win32OS.Name.Split('|')[0]).Trim()
            $ansibleFacts.ansible_os_product_type = $productType
            $ansibleFacts.ansible_os_installation_type = $installationType
        }
    },
    @{
        Subsets = 'env'
        Code = {
            $envVars = @{}
            foreach ($item in Get-ChildItem -LiteralPath Env:) {
                # Powershell ConvertTo-Json fails if string ends with \
                $value = $item.Value.TrimEnd("\")
                $envVars.Add($item.Name, $value)
            }

            $ansibleFacts.ansible_env = $envVars
        }
    },
    @{
        Subsets = 'facter'
        Code = {
            $facter = Get-Command -Name facter -CommandType Application -ErrorAction SilentlyContinue

            if ($facter) {
                # Get JSON from Facter, and parse it out.
                $facterOutput = &facter -j
                $facts = "$facterOutput" | ConvertFrom-Json

                ForEach($fact in $facts.PSObject.Properties) {
                    $ansibleFacts."facter_$($fact.Name)" = $fact.Value
                }
            }
        }
    },
    @{
        Subsets = 'interfaces'
        Code = {
            $netcfg = @(Get-LazyCimInstance -ClassName Win32_NetworkAdapterConfiguration |
                Where-Object { $null-ne $_.IPAddress })

            $namespaces = Get-LazyCimInstance -ClassName __Namespace -Namespace root
            if ($namespaces | Where-Object { $_.Name -eq "StandardCimv" }) {
                $netAdapters = Get-LazyCimInstance -ClassName MSFT_NetAdapter -Namespace Root\StandardCimv2
            } else {
                $netAdapters = Get-LazyCimInstance -ClassName Win32_NetworkAdapter | Select-Object -Property @(
                    @{ N = 'InterfaceGUID'; E = { $_.GUID }},
                    @{ N = 'Name'; E = { $_.NetConnectionID }}
                )
            }

            $formattedNetCfg = @(foreach ($adapter in $netcfg) {
                $thisAdapter = @{
                    default_gateway = $null
                    connection_name = $null
                    dns_domain = $adapter.dnsdomain
                    interface_index = $adapter.InterfaceIndex
                    interface_name = $adapter.description
                    macaddress = $adapter.macaddress
                }

                if ($adapter.defaultIPGateway) {
                    $thisadapter.default_gateway = $adapter.DefaultIPGateway[0].ToString()
                }

                $netAdapter = $netAdapters | Where-Object { $_.InterfaceGUID -eq $adapter.SettingID }
                if ($netAdapter) {
                    $thisadapter.connection_name = $netAdapter.Name
                }

                $thisAdapter
            })

            $ansibleFacts.ansible_interfaces = $formattedNetCfg
        }
    },
    @{
        Subsets = 'local'
        Code = {
            if (-not $factPath) {
                return
            }

            if (Test-Path -Path $factPath) {
                $factFiles = Get-ChildItem -Path $factpath | Where-Object {
                    -not $_.PSIsContainer -and $_.Extension -eq '.ps1'
                }

                foreach ($factsFile in $factFiles) {
                    $out = & $($FactsFile.FullName)
                    $ansibleFacts."ansible_$(($factsFile.Name).Split('.')[0])" = $out
                }
            } else {
                $module.Warn("Non existing path was set for local facts - $factPath")
            }
        }
    },
    @{
        Subsets = 'memory'
        Code = {
            $win32CS = Get-LazyCimInstance -ClassName Win32_ComputerSystem
            $win32OS = Get-LazyCimInstance -ClassName Win32_OperatingSystem

            # Win32_PhysicalMemory is empty on some virtual platforms
            $ansibleFacts.ansible_memtotal_mb = ([math]::ceiling($win32CS.TotalPhysicalMemory / 1024 / 1024))
            $ansibleFacts.ansible_memfree_mb = ([math]::ceiling($win32OS.FreePhysicalMemory / 1024))
            $ansibleFacts.ansible_swaptotal_mb = ([math]::round($win32OS.TotalSwapSpaceSize / 1024))
            $ansibleFacts.ansible_pagefiletotal_mb = ([math]::round($win32OS.SizeStoredInPagingFiles / 1024))
            $ansibleFacts.ansible_pagefilefree_mb = ([math]::round($win32OS.FreeSpaceInPagingFiles / 1024))
        }
    },
    @{
        Subsets = 'platform'
        Code = {
            $win32CS = Get-LazyCimInstance -ClassName Win32_ComputerSystem
            $win32OS = Get-LazyCimInstance -ClassName Win32_OperatingSystem
            $osversion = [Environment]::OSVersion

            $domainSuffix = $win32CS.Domain.Substring($win32CS.Workgroup.length)
            $ipProps = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
            $fqdn = $ipProps.HostName

            if ($ipProps.DomainName) {
                $fqdn = "$($fqdn).$($ipProps.DomainName)"
            }

            # The Machine SID is stored in HKLM:\SECURITY\SAM\Domains\Account and is
            # only accessible by the Local System account. This method get's the local
            # admin account (ends with -500) and lops it off to get the machine sid.
            $machineSid = $null
            try {
                $adminGroup = (New-Object -TypeName System.Security.Principal.SecurityIdentifier -ArgumentList @(
                    "S-1-5-32-544")).Translate([System.Security.Principal.NTAccount]).Value

                $namespace = 'System.DirectoryServices.AccountManagement'

                Add-Type -AssemblyName $namespace
                $context = New-Object -TypeName "$namespace.PrincipalContext" -ArgumentList @(
                    [System.DirectoryServices.AccountManagement.ContextType]::Machine)
                $principal = New-Object -TypeName "$namespace.GroupPrincipal" -ArgumentList $context, $adminGroup
                $searcher = New-Object -TypeName "$namespace.PrincipalSearcher" -ArgumentList $principal
                $groups = $searcher.FindOne()

                foreach ($user in $groups.Members) {
                    if ($user.Sid.Value.EndsWith("-500")) {
                        $machineSid = $user.Sid.AccountDomainSid.Value
                        break
                    }
                }
            } catch {
                $module.Warn("Error during machine sid retrieval: $($_.Exception.Message)")
            }

            # Check if a reboot is pending, this is legacy behaviour from Legacy.psm1
            $serverFeatureParams = @{
                ClassName = 'MSFT_ServerManagerTasks'
                Namespace = 'root\microsoft\windows\servermanager'
                MethodName = 'GetServerFeature'
                ErrorAction = 'SilentlyContinue'
            }
            $featureData = Invoke-CimMethod @serverFeatureParams

            $pendingRenamePath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager'
            $pendingRenameName = 'PendingFileRenameOperations'
            $pendingRenames = if (Test-Path -LiteralPath $pendingRenamePath) {
                Get-ItemProperty -LiteralPath $pendingRenamePath -Name $pendingRenameName -ErrorAction SilentlyContinue
            }

            $cbsReboot = Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending'
            $rebootPending = ($featureData -and $featureData.RequiresReboot) -or $pendingRenames -or $cbsReboot

            $ansiblefacts.ansible_architecture = $win32OS.OSArchitecture
            $ansiblefacts.ansible_domain = $domainSuffix
            $ansiblefacts.ansible_fqdn = $fqdn
            $ansiblefacts.ansible_hostname = $ipProps.HostName
            $ansiblefacts.ansible_netbios_name = $win32CS.Name
            $ansiblefacts.ansible_kernel = $osversion.Version.ToString()
            $ansiblefacts.ansible_nodename = $fqdn
            $ansiblefacts.ansible_machine_id = $machineSid
            $ansiblefacts.ansible_owner_contact = ([string] $win32CS.PrimaryOwnerContact)
            $ansiblefacts.ansible_owner_name = ([string] $win32CS.PrimaryOwnerName)
            # FUTURE: should this live in its own subset?
            $ansiblefacts.ansible_reboot_pending = $rebootPending
            $ansiblefacts.ansible_system = $osversion.Platform.ToString()
            $ansiblefacts.ansible_system_description = ([string] $win32OS.Description)
            $ansiblefacts.ansible_system_vendor = $win32CS.Manufacturer
        }
    },
    @{
        Subsets = 'powershell_version'
        Code = {
            $ansibleFacts.ansible_powershell_version = $PSVersionTable.PSVersion.Major
        }
    },
    @{
        Subsets = 'processor'
        Code = {
            $win32CS = Get-LazyCimInstance -ClassName Win32_ComputerSystem
            # Make sure we pick the first CPU in a multi-socket configuration.
            $win32CPU = @(Get-LazyCimInstance -ClassName Win32_Processor)[0]

            $cpuList = for ($i=1; $i -le $win32CS.NumberOfLogicalProcessors; $i++) {
                $win32CPU.Manufacturer
                $win32CPU.Name
            }

            $ansibleFacts.ansible_processor = $cpuList
            $ansibleFacts.ansible_processor_cores = $win32CPU.NumberOfCores
            $ansibleFacts.ansible_processor_count = $win32CS.NumberOfProcessors
            $ansibleFacts.ansible_processor_threads_per_core = ($win32CPU.NumberOfLogicalProcessors / $win32CPU.NumberofCores)
            $ansibleFacts.ansible_processor_vcpus = $win32CS.NumberOfLogicalProcessors
        }
    },
    @{
        Subsets = 'uptime'
        Code = {
            $win32OS = Get-LazyCimInstance -ClassName Win32_OperatingSystem

            $ansibleFacts.ansible_lastboot = $win32OS.lastbootuptime.ToString("u")
            $ansibleFacts.ansible_uptime_seconds = $([System.Convert]::ToInt64($(Get-Date).Subtract($win32OS.lastbootuptime).TotalSeconds))
        }
    },
    @{
        Subsets = 'user'
        Code = {
            $user = [Security.Principal.WindowsIdentity]::GetCurrent()

            $ansibleFacts.ansible_user_dir = $env:userprofile
            # Win32_UserAccount.FullName is probably the right thing here, but it can be expensive to get on large domains
            $ansibleFacts.ansible_user_gecos = ""
            $ansibleFacts.ansible_user_id = $env:username
            $ansibleFacts.ansible_user_sid = $user.User.Value
        }
    },
    @{
        Subsets = 'windows_domain'
        Code = {
            $win32CS = Get-LazyCimInstance -ClassName Win32_ComputerSystem

            $domainRoles = @{
                0 = "Stand-alone workstation"
                1 = "Member workstation"
                2 = "Stand-alone server"
                3 = "Member server"
                4 = "Backup domain controller"
                5 = "Primary domain controller"
            }
            $domainRole = $domainRoles.Get_Item([Int32]$win32CS.DomainRole)

            $ansibleFacts.ansible_windows_domain = $win32CS.Domain
            $ansibleFacts.ansible_windows_domain_member = $win32CS.PartOfDomain
            $ansibleFacts.ansible_windows_domain_role = $domainRole
        }
    },
    @{

        Subsets = 'winrm'
        Code = {
            try {
                $certs = @(Get-ChildItem -Path WSMan:\localhost\Listener\* -ErrorAction SilentlyContinue | Where-Object {
                    'Transport=HTTPS' -in $_.Keys
                } | Get-ChildItem | Where-Object Name -eq 'CertificateThumbprint' | ForEach-Object {
                    Get-Item -LiteralPath Cert:\LocalMachine\My\$($_.Value)
                })
            } catch {
                $certs = @()
                $module.Warn("Error during certificate expiration retrieval: $($_.Exception.Message)")
            }

            $certs | Sort-Object -Property NotAfter | Select-Object -First 1 | ForEach-Object -Process {
                # this fact was renamed from ansible_winrm_certificate_expires due to collision with ansible_winrm_X connection var pattern
                $ansibleFacts.ansible_win_rm_certificate_expires = $_.NotAfter.ToString('yyyy-MM-dd HH:mm:ss')
            }
        }
    },
    @{
        Subsets = 'virtual'
        Code = {
            $machineInfo = Get-LazyCimInstance -ClassName Win32_ComputerSystem

            $machineType, $machineRole = switch ($machineInfo.model) {
                "Virtual Machine" { "Hyper-V", "guest" }
                "VMware Virtual Platform" { "VMware", "guest" }
                "VirtualBox" { "VirtualBox", "guest" }
                "HVM domU" { "Xen", "guest" }
                default { "NA", "NA" }
            }

            $ansibleFacts.ansible_virtualization_role = $machineRole
            $ansibleFacts.ansible_virtualization_type = $machineType
        }
    }
)

$ansibleFacts = [Hashtable]::Synchronized(@{})

# Holds a lock for each CIM class so the Get-LazyCimInstance only get/sets once in a thread safe fashion. This list
# needs to be updated whenever we add another CIM class to retrieve in the facts.
$cimMutex = [Hashtable]::Synchronized(@{})
$cimInstances = [Hashtable]::Synchronized(@{})
@(
    '__Namespace',
    'MSFT_NetAdapter',
    'Win32_Bios',
    'Win32_ComputerSystem',
    'Win32_NetworkAdapter',
    'Win32_NetworkAdapterConfiguration',
    'Win32_OperatingSystem',
    'Win32_Processor'
) | ForEach-Object -Process {$cimMutex.$_ = New-Object -TypeName System.Threading.Mutex -ArgumentList @($false, $_)}

$initialSessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$initialSessionState.Commands.Add((New-SessionStateFunction -Name 'Get-LazyCimInstance'))
$initialSessionState.Variables.Add((New-SessionStateVariable -Name ansibleFacts))
$initialSessionState.Variables.Add((New-SessionStateVariable -Name cimInstances))
$initialSessionState.Variables.Add((New-SessionStateVariable -Name cimMutex))
$initialSessionState.Variables.Add((New-SessionStateVariable -Name factPath))
$initialSessionState.Variables.Add((New-SessionStateVariable -Name gatherTimeout))
$initialSessionState.Variables.Add((New-SessionStateVariable -Name module))
$pool = [RunspaceFactory]::CreateRunspacePool(1, 4, $initialSessionState, $Host)

$groupedSubsets = @{
    min = [System.Collections.Generic.List[string]]@('date_time','distribution','dns','env','local','platform','powershell_version','user')
    network = [System.Collections.Generic.List[string]]@('all_ipv4_addresses','all_ipv6_addresses','interfaces','windows_domain', 'winrm')
    hardware = [System.Collections.Generic.List[string]]@('bios','memory','processor','uptime','virtual')
    external = [System.Collections.Generic.List[string]]@('facter')
}
# build "all" set from everything mentioned in the group- this means every value must be in at least one subset to be considered legal
$allSet = [System.Collections.Generic.HashSet[string]]@()

foreach($kv in $groupedSubsets.GetEnumerator()) {
    $null = $allSet.UnionWith($kv.Value)
}

# dynamically create an "all" subset now that we know what should be in it
$groupedSubsets.all = [System.Collections.Generic.List[string]]$allSet

# start with all, build up gather and exclude subsets
$actualSubset = [System.Collections.Generic.HashSet[string]]$groupedSubsets.all
$explicitSubset = [System.Collections.Generic.HashSet[string]]@()
$excludeSubset = [System.Collections.Generic.HashSet[string]]@()

foreach ($item in $gatherSubset) {
    if ($item.StartsWith('!')) {
        $item = $item.Substring(1)

        if ($item -eq "all") {
            $allMinusMin = [System.Collections.Generic.HashSet[string]]@($allSet)
            $null = $allMinusMin.ExceptWith($groupedSubsets.min)
            $null = $excludeSubset.UnionWith($allMinusMin)

        } elseif($groupedSubsets.ContainsKey($item)) {
            $null = $excludeSubset.UnionWith($grouped_subsets[$item])

        } elseif($all_set.Contains($item)) {
            $null = $excludeSubset.Add($item)
        }
        # NB: invalid exclude values are ignored, since that's what posix setup does
    } else {
        if ($groupedSubsets.ContainsKey($item)) {
            $null = $explicitSubset.UnionWith($groupedSubsets.$item)

        } elseif ($allSet.Contains($item)) {
            $null = $explicitSubset.Add($item)

        } else {
            # NB: POSIX setup fails on invalid value; we warn, because we don't implement the same set as POSIX
            # and we don't have platform-specific config for this...
            $module.Warn("invalid value $item specified in gather_subset")
        }
    }
}

$null = $actualSubset.ExceptWith($excludeSubset)
$null = $actualSubset.UnionWith($explicitSubset)

$ansibleFacts.gather_subset = $gatherSubset
$ansibleFacts.module_setup = $true
$module.Result.ansible_facts = $ansibleFacts

$pool.Open()
try {
    $jobs = @(foreach ($meta in $factMeta.GetEnumerator()) {
        $metaSubsets = [System.Collections.Generic.HashSet[String]]@($meta.Subsets)

        $skip = $true
        foreach ($subset in $metaSubsets) {
            if ($actualSubset.Contains($subset)) {
                $skip = $false
                break
            }
        }

        if ($skip) {
            continue
        }

        $ps = [PowerShell]::Create()
        $ps.RunspacePool = $pool
        $null = $ps.AddScript($meta.Code)

        [PSCustomObject]@{
            Name = $metaSubsets -join ', '
            AsyncResult = $ps.BeginInvoke()
            PowerShell = $ps
            Timer = [System.Diagnostics.StopWatch]::StartNew()  # Keeps track of how long left to wait for.
        }
    })

    foreach ($job in $jobs) {
        # We need to wait for the timeout specified minus the total time it has currently run for.
        $waitTime = ($gatherTimeout * 1000) - $job.Timer.Elapsed.TotalMilliseconds
        $null = $job.AsyncResult.AsyncWaitHandle.WaitOne((0, $waitTime | Measure-Object -Maximum).Maximum)
        $job.Timer.Stop()

        if ($job.AsyncResult.IsCompleted) {
            # We don't care about any actual output as each scriptblock sets the ansibleFacts hashtable in the code.
            $null = $job.PowerShell.EndInvoke($job.AsyncResult)
            $job.PowerShell.Dispose()

            # Make sure we warn on any errors that may have occurred.
            foreach ($errorRecord in $job.PowerShell.Streams.Error) {
                $module.Warn("Error when collectiong $($job.Name): $($errorRecord | Out-String)")
            }
        } else {
            # Give a best effort chance to stop it, we can't call .Stop() in case it blocks.
            $null = $job.PowerShell.BeginStop()
            $module.Warn("Failed to collection $($job.Name) due to timeout")
        }
    }
} finally {
    $pool.Dispose()
}

$module.ExitJson()
