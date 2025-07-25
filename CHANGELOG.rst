=============================
Ansible Windows Release Notes
=============================

.. contents:: Topics

v3.2.0
======

Release Summary
---------------

Release summary for v3.2.0

Minor Changes
-------------

- win_find - add support for 'any' to find both directories and files (https://github.com/ansible-collections/ansible.windows/issues/797).
- win_template - Preserve user-supplied value for ``ansible_managed`` when set on Ansible Core 2.19+.

Bugfixes
--------

- win_copy - report correct information about symlinks in action plugin.
- win_service - Fix crash when attempting to create a service with the ``--check`` flag.

v3.1.0
======

Release Summary
---------------

Release summary for v3.1.0

Minor Changes
-------------

- setup - add "CloudStack KVM Hypervisor" for Windows VM in virtual facts (https://github.com/ansible-collections/ansible.windows/pull/785).
- setup - added ``ansible_product_uuid`` to align with Python facts - https://github.com/ansible-collections/ansible.windows/issues/789
- win_dns_client - add support for suffixsearchlist (https://github.com/ansible-collections/ansible.windows/issues/656).
- win_powershell - Add support for running scripts on a Windows host with an active Windows Application Control policy in place. Scripts that are unsigned will be run in Constrained Language Mode while scripts that are signed and trusted by the remote host's WDAC policy will be run in Full Language Mode.
- win_powershell - Added the ``path`` and ``remote_src`` options which can be used to specify a local or remote PowerShell script to run.
- win_shell - Add support for running scripts on a Windows host with an active Windows Application Control policy in place. Scripts will always run in Contrained Language Mode as they are executed in memory, use the ``ansible.windows.win_powershell`` module to run signed scripts in Full Language Mode on a WDAC enabled host.

Bugfixes
--------

- win_package - fail to remove package when no product id is provided with path as an URL (https://github.com/ansible-collections/ansible.windows/issues/667).

v3.0.0
======

Release Summary
---------------

Major release of the ansible.windows collection. This release includes fixes for Ansible 2.19 and removes some deprecated modules.

Minor Changes
-------------

- Set minimum supported Ansible version to 2.16 to align with the versions still supported by Ansible.
- win_template - Added ``comment_start_string`` and ``comment_end_string`` as options to align with the builtin ``template`` module.

Removed Features (previously deprecated)
----------------------------------------

- win_domain - Removed deprecated module, use ``microsoft.ad.domain`` instead
- win_domain_controller - Removed deprecated module, use ``microsoft.ad.domain_controller`` instead
- win_domain_membership - Removed deprecated module, use ``microsoft.ad.membership`` instead
- win_feature - Removed deprecated return value ``restart_needed`` in ``feature_result``, use ``reboot_required`` instead
- win_updates - Removed deprecated return value ``filtered_reason``, use ``filtered_reasons`` instead

Bugfixes
--------

- win_find - allow users case sensitive match the filename (https://github.com/ansible-collections/ansible.windows/issues/473).
- win_powershell - Handle failure on output conversion when the output object uses a custom adapter set that fails to enumerate the method members. This is seen when using the output from ``Get-WmiObject`` - https://github.com/ansible-collections/ansible.windows/issues/767
- win_regedit - Handle decimal values with no decimal values which may be the result of a Jinja2 template
- win_template - Added support for Ansible 2.19 and the introduction of the data tagging feature.

v2.8.0
======

Release Summary
---------------

Release summary for v2.8.0

Minor Changes
-------------

- setup - Remove dependency on shared function loaded by Ansible
- win_get_url - Added ``checksum`` and ``checksum_algorithm`` to verify the package before installation. Also returns ``checksum`` if ``checksum_algorithm`` is provided - https://github.com/ansible-collections/ansible.windows/issues/596

Bugfixes
--------

- setup - Add better detection for VMWare base virtualization platforms - https://github.com/ansible-collections/ansible.windows/issues/753
- win_package - Support check mode with local file path sources

v2.7.0
======

Release Summary
---------------

Release summary for v2.7.0

Minor Changes
-------------

- win_get_url - if checksum is passed and destination file exists with different checksum file is always downloaded (https://github.com/ansible-collections/ansible.windows/issues/717)
- win_get_url - if checksum is passed and destination file exists with identical checksum no download is done unless force=yes (https://github.com/ansible-collections/ansible.windows/issues/717)
- win_group - Added ``--diff`` output support.
- win_group - Added ``members`` option to set the group membership. This is designed to replace the functionality of the ``win_group_membership`` module.
- win_group - Added ``sid`` return value representing the security identifier of the group when ``state=present``.
- win_group - Migrate to newer Ansible.Basic fragment for better input validation and testing support.

Bugfixes
--------

- win_group_membership - Fix bug when input ``members`` contained duplicate members that were not already present in the group - https://github.com/ansible-collections/ansible.windows/issues/736

New Modules
-----------

- win_audit_policy_system - Used to make changes to the system wide Audit Policy
- win_audit_rule - Adds an audit rule to files, folders, or registry keys
- win_auto_logon - Adds or Sets auto logon registry keys.
- win_computer_description - Set windows description, owner and organization
- win_credential - Manages Windows Credentials in the Credential Manager
- win_feature_info - Gather information about Windows features
- win_file_compression - Alters the compression of files and directories on NTFS partitions.
- win_http_proxy - Manages proxy settings for WinHTTP
- win_inet_proxy - Manages proxy settings for WinINet and Internet Explorer
- win_listen_ports_facts - Recopilates the facts of the listening ports of the machine
- win_mapped_drive - Map network drives for users
- win_product_facts - Provides Windows product and license information
- win_route - Add or remove a static route
- win_user_profile - Manages the Windows user profiles.

v2.6.0
======

Release Summary
---------------

Release summary for v2.6.0. Includes various modules promoted from ``community.windows``.

Minor Changes
-------------

- Added support for Windows Server 2025
- setup - Added ``ansible_os_install_date`` as the OS installation date in the ISO 8601 format ``yyyy-MM-ddTHH:mm:ssZ``. This date is represented in the UTC timezone - https://github.com/ansible-collections/ansible.windows/issues/663

Bugfixes
--------

- ansible.windows.win_powershell - Add extra checks to avoid ``GetType`` error when converting the output object - ttps://github.com/ansible-collections/ansible.windows/issues/708
- win_powershell - Ensure ``$Ansible.Result = @()`` as an empty array is returned as an empty list and not null - https://github.com/ansible-collections/ansible.windows/issues/686
- win_updates - Only set the Access control sections on the temporary directory created by the module. This avoids the error when the ``SeSecurityPrivilege`` privilege isn't present.

New Modules
-----------

- win_certificate_info - Get information on certificates from a Windows Certificate Store
- win_dhcp_lease - Manage Windows Server DHCP Leases
- win_dns_record - Manage Windows Server DNS records
- win_dns_zone - Manage Windows Server DNS Zones
- win_eventlog - Manage Windows event logs
- win_firewall - Enable or disable the Windows Firewall
- win_hosts - Manages hosts file entries on Windows.
- win_hotfix - Install and uninstalls Windows hotfixes
- win_region - Set the region and format settings
- win_timezone - Sets Windows machine timezone

v2.5.0
======

Release Summary
---------------

Release summary for v2.5.0. This is the first release that provides official support for using the ``ssh`` connection plugin.

Minor Changes
-------------

- Set minimum supported Ansible version to 2.15 to align with the versions still supported by Ansible.
- owner - Migrated to ``Ansible.Basic`` format to add basic checks like invocation args checking
- win_powershell - Changed `sensitive_parameters` to use `New-Object`, rather than `::new()`

Bugfixes
--------

- setup - Better handle orphaned users when attempting to retrieve ``ansible_machine_id`` - https://github.com/ansible-collections/ansible.windows/issues/606
- win_owner - Try to enable extra privileges if available to set the owner even when the caller may not have explicit rights to do so normally - https://github.com/ansible-collections/ansible.windows/issues/633
- win_powershell - Fix up depth handling on ``$Ansible.Result`` when using a custom ``executable`` - https://github.com/ansible-collections/ansible.windows/issues/642
- win_powershell - increase open timeout for ``executable`` parameter to prevent exceptions on first-run or slower targets. (https://github.com/ansible-collections/ansible.windows/issues/644).
- win_updates - Base64 encode the update wrapper and payload to prevent locale-specific encoding issues.
- win_updates - Handle race condition when ``Wait-Process`` did not handle when the process had ended - https://github.com/ansible-collections/ansible.windows/issues/623

v2.4.0
======

Release Summary
---------------

Release summary for v2.4.0

Minor Changes
-------------

- win_powershell - Added the ``sensitive_parameters`` option that can be used to pass in a SecureString or PSCredential parameter value.
- win_setup - Added the ``ansible_win_rm_certificate_thumbprint`` fact to display the thumbprint of the certificate in use
- win_user - Added the ability to set an account expiration date using the ``account_expires`` option - https://github.com/ansible-collections/ansible.windows/issues/610

Bugfixes
--------

- setup - Provide WMI/CIM fallback for facts that rely on SMBIOS when that is unavailable

v2.3.0
======

Release Summary
---------------

Release summary for v2.3.0

Minor Changes
-------------

- win_uri - Max depth for json object conversion used to be 2. Can now send json objects with up to 20 levels of nesting

Bugfixes
--------

- win_get_url - Fix Tls1.3 getting removed from the list of security protocols
- win_powershell - Remove unecessary using in code causing stray error records in output - https://github.com/ansible-collections/ansible.windows/issues/571

v2.2.0
======

Release Summary
---------------

Release summary for v2.2.0

Minor Changes
-------------

- Set minimum supported Ansible version to 2.14 to align with the versions still supported by Ansible.
- win_share - Added a new param called ``scope_name`` that allows file shares to be scoped for Windows Server failover cluster roles.

Bugfixes
--------

- Process.cs - Fix up the ``ProcessCreationFlags.CreateProtectedProcess`` typo in the enum name
- setup - Fix up typo ``collection -> collect`` when a timeout occurred during a fact subset
- win_acl - Fix broken path in case of volume junction
- win_service_info - Warn and not fail if ERROR_FILE_NOT_FOUND when trying to query a service - https://github.com/ansible-collections/ansible.windows/issues/556
- win_updates - Fix up typo for Download progress event messages - https://github.com/ansible-collections/ansible.windows/issues/554

v2.1.0
======

Release Summary
---------------

Release summary for v2.1.0

Minor Changes
-------------

- win_updates - Avoid using a scheduled task to spawn the updates background job when running as become. This provides an alternative method available to users in case the task scheduler does not work on their system - https://github.com/ansible-collections/ansible.windows/issues/543

Bugfixes
--------

- Remove some code which is no longer valid for dotnet 5+
- win_async - Set maximum data size allowed when deserializing async output - https://github.com/ansible-collections/ansible.windows/pull/520
- win_group_membership - Return accurate results when using check_mode - https://github.com/ansible-collections/ansible.windows/issues/532
- win_updates - Add special handling for KB2267602 in case it fails - https://github.com/ansible-collections/ansible.windows/issues/530
- win_updates - Fix up endless retries when an update failed to install more than once - https://github.com/ansible-collections/ansible.windows/issues/343

v2.0.0
======

Release Summary
---------------

Version ``2.0.0`` is a major release of the ``ansible.windows`` collection that removes some deprecated features. Please review the changelog to see what deprecated features have been removed in this release.

Minor Changes
-------------

- win_certificate_store - the private key check, when exporting to pkcs12, has been modified to handle the case where the ``PrivateKey`` property is null despite it being there
- win_find - Added ``depth`` option to control how deep to go when scanning into the target path - https://github.com/ansible-collections/ansible.windows/issues/335

Deprecated Features
-------------------

- Add warning when using Server 2012 or 2012 R2 with the ``setup`` module. These OS' are nearing the End of Life and will not be tested in CI when that time is reached.
- win_domain - Module is deprecated in favour of the ``microsoft.ad.domain`` module, the ``ansible.windows.win_domain`` module will be removed in the ``3.0.0`` release of this collection.
- win_domain_controller - Module is deprecated in favour of the ``microsoft.ad.domain_controller`` module, the ``ansible.windows.win_domain_controller`` module will be removed in the ``3.0.0`` release of this collection.
- win_domain_membership - Module is deprecated in favour of the ``microsoft.ad.membership`` module, the ``ansible.windows.win_domain_membership`` module will be removed in the ``3.0.0`` release of this collection.

Removed Features (previously deprecated)
----------------------------------------

- win_get_url - Removed the deprecated option alias ``passwordd``, use ``url_password`` instead.
- win_get_url - Removed the deprecated option alias ``user`` and ``username``, use ``url_username`` instead.
- win_package - Removed deprecated module option ``ensure``, use ``state`` instead.
- win_package - Removed deprecated module option ``productid``, use ``product_id`` instead.
- win_package - Removed deprecated module option ``username``, ``user_name``, ``password``, and ``user_password``. Use ``become`` with ``become_flags: logon_type=new_credentials logon_flags=netcredentials_only`` on the task instead to replicate the same functionality instead.
- win_reboot - Removed backwards compatibility check where ``ignore_errors: true`` will be treated like ``ignore_unreachable: true``. Going forward ``ignore_errors: true`` will only ignore errors the plugin encountered and not an unreachable host. Use ``ignore_unreachable: true`` to ignore that error like any other module.
- win_regedit - Removed support for using a ``path`` with forward slashes as a key separator. Using a forward slash has been deprecated since Ansible 2.9. If using forward slashes in the ``win_regedit`` ``path`` value, make sure to change the forward slash ``/`` to a backslash ``\``. If enclosed in double quotes the backslash will have to be doubled up.
- win_updates - Removed deprecated alias ``blacklist``, use ``reject_list`` instead.
- win_updates - Removed deprecated alias ``whitelist``, use ``accept_list`` instead.
- win_updates - Removed deprecated module option ``use_scheduled_task``. This option did not change any functionality in the module and can be safely removed from the task entry.
- win_uri - Removed the deprecated option alias ``password``, use ``url_password`` instead.
- win_uri - Removed the deprecated option alias ``user`` and ``username``, use ``url_username`` instead.

Bugfixes
--------

- win_updates - Add retry mechanism when polling output in case file is locked by another process like an Anti Virus - https://github.com/ansible-collections/ansible.windows/issues/490

v1.14.0
=======

Release Summary
---------------

Release summary for v1.14.0

Minor Changes
-------------

- Process - Add support for starting a process with a custom parent
- win_updates - Added the ``rebooted`` return value to document if a host was rebooted - https://github.com/ansible-collections/ansible.windows/issues/485

Bugfixes
--------

- setup - Be more resilient when parsing the BIOS release date - https://github.com/ansible-collections/ansible.windows/pull/496
- win_package - Fix ``product_id`` check and skip downloaded requested file if the package is already installed - https://github.com/ansible-collections/ansible.windows/issues/479
- win_updates - Add better handling for the polling output for connection plugins that might drop newlines on the output - https://github.com/ansible-collections/ansible.windows/issues/477
- win_updates - Ensure failure condition doesn't lock the polling file - https://github.com/ansible-collections/ansible.windows/issues/490
- win_updates - Improve batch task runner reliability and attempt to return more info on failures - https://github.com/ansible-collections/ansible.windows/issues/448

v1.13.0
=======

Release Summary
---------------

Release summary for v1.13.0

Major Changes
-------------

- Set the minimum Ansible version supported by this collection to Ansible 2.12

Minor Changes
-------------

- win_reboot - Display connection messages under 4 v's ``-vvvv`` instead of 3

Bugfixes
--------

- setup - Fallback to using the WMI Win32_Processor provider if the SMBIOS version is too old to return processor core counts
- setup - Fix calculation for ``ansible_processor_threads_per_core`` to reflect the number of threads per core instead of threads per processor
- setup - Ignore processors that are not enabled in the ``ansible_processor_count`` return value
- setup - Support core and thread counts greater than 256 in ``ansible_processor_count`` and ``ansible_processor_threads_per_core``
- win_dns_client - Fix failure to lookup registry DNS servers when it contains null characters
- win_powershell - Support PowerShell 7 script syntax when targeting ``executable: pwsh.exe`` - https://github.com/ansible-collections/ansible.windows/issues/452
- win_wait_for - fix incorrect function name during ``state=drained`` - https://github.com/ansible-collections/ansible.windows/issues/451

v1.12.0
=======

Release Summary
---------------

Release summary for v1.12.0

Minor Changes
-------------

- win_acl - Added the ``follow`` parameter with will follow the symlinks and junctions before applying ACLs to change the target instead of the link
- win_powershell - Add support for setting diff output with ``$Ansible.Diff`` in the script
- win_uri - Use SHA256 for file idempotency checks instead of SHA1

Bugfixes
--------

- win_acl_inheritance - Fix broken pathqualifier when using a UNC path - (https://github.com/ansible-collections/ansible.windows/issues/408).
- win_certificate_store - Allow to reimport a certificate + key if the private key was not present the first time you imported it
- win_setup - Fix custom facts that return false are missing - https://github.com/ansible-collections/ansible.windows/issues/430
- win_updates - Fix broken call when logging a warning about updates with errors - https://github.com/ansible-collections/ansible.windows/issues/411
- win_updates - Handle running with a temp profile path that is deleted between reboots - https://github.com/ansible-collections/ansible.windows/issues/417

v1.11.1
=======

Release Summary
---------------

Release summary for v1.11.1

Bugfixes
--------

- win_command - Fix bug that stopped win_command from finding executables that are located more than once in ``PATH`` - https://github.com/ansible-collections/ansible.windows/issues/403
- win_copy - Fix error message when failing to find ``src`` on the controller filesystem

v1.11.0
=======

Release Summary
---------------

Release summary for v1.11.0

Minor Changes
-------------

- Raise minimum Ansible version to ``2.11`` or newer
- setup - also read ``*.json`` files in ``fact_path`` as raw JSON text in addition to ``.ps1`` scripts
- win_acl_inheritance - support for setting inheritance for registry keys
- win_command - Added the ``argv`` module option for specifying the command to run as a list to be escaped rather than the free form input
- win_command - Added the ``cmd`` module option for specifying the command to run as a module option rather than the free form input
- win_command - Migrated to the newer Ansible.Basic style module to improve module invocation output
- win_stat - Added ``get_size`` to control whether ``win_stat`` will calculate the size of files or directories - https://github.com/ansible-collections/ansible.windows/issues/384

Bugfixes
--------

- setup - Ignore PATH entries with invalid roots when trying to find ``facter.exe`` - https://github.com/ansible-collections/ansible.windows/issues/397
- setup - Ignore invalid ``PATH`` entries when trying to find ``facter.exe`` - https://github.com/ansible-collections/ansible.windows/issues/364
- win_find - Fix up share checks when the share contains the ``'`` character
- win_package - Skip ``msix`` provider on older hosts that do not implement the required cmdlets
- win_powershell - Do not attempt to serialize ETS properties of primitive types - https://github.com/ansible-collections/ansible.windows/issues/360
- win_powershell - Make sure ``target_object`` on an error record uses the ``depth`` object when serializing the value - https://github.com/ansible-collections/ansible.windows/issues/375
- win_stat - Fix up share checks when the share contains the ``'`` character
- win_updates - Try to display warnings on search suceeded with warnings - https://github.com/ansible-collections/ansible.windows/issues/366

v1.10.0
=======

Release Summary
---------------

Release summary for v1.10.0

Minor Changes
-------------

- setup - Added ipv4, ipv6, mtu and speed data to ansible_interfaces
- win_environment - Trigger ``WM_SETTINGCHANGE`` on a change to notify other host processes of an environment change
- win_path - Migrate to newer style module parser that adds features like module invocation under ``-vvv``
- win_path - Trigger ``WM_SETTINGCHANGE`` on a change to notify other host processes of an environment change

Bugfixes
--------

- win_reboot - Always set a minimum of 2 seconds for ``pre_reboot_delay`` to ensure the plugin can read the result

v1.9.0
======

Minor Changes
-------------

- win_dsc - deduplicated error writing code with a new function. No actual error text was changed.
- win_powershell - Added ``$Ansible.Verbosity`` for scripts to adjust code based on the verbosity Ansible is running as

Bugfixes
--------

- win_command - Use the 24 hour format for the hours of ``start`` and ``end`` - https://github.com/ansible-collections/ansible.windows/issues/303
- win_copy - improve dest folder size detection to handle broken and recursive symlinks as well as inaccesible folders - https://github.com/ansible-collections/ansible.windows/issues/298
- win_dsc - Provide better error message when trying to invoke a composite DSC resource
- win_shell - Use the 24 hour format for the hours of ``start`` and ``end`` - https://github.com/ansible-collections/ansible.windows/issues/303
- win_updates - Fix return value for ``updates`` and ``filtered_updates`` to match original stucture - https://github.com/ansible-collections/ansible.windows/issues/307
- win_updates - Fixed issue when attempting to run ``task.ps1`` with a host that has a restrictive execution policy set through GPO
- win_updates - prevent the host from going to sleep if a low sleep timeout is set - https://github.com/ansible-collections/ansible.windows/issues/310

v1.8.0
======

Minor Changes
-------------

- win_updates - Added the ``skip_optional`` module option to skip optional updates

Bugfixes
--------

- win_copy - Fix remote dest size calculation logic
- win_dns_client - Fix method used to read IPv6 DNS settings given by DHCP - https://github.com/ansible-collections/ansible.windows/issues/283
- win_file - Fix conflicts with existing ``LIB`` environment variable
- win_find - Fix conflicts with existing ``LIB`` environment variable
- win_stat - Fix conflicts with existing ``LIB`` environment variable
- win_updates - Fix conflicts with existing ``LIB`` environment variable
- win_updates - Ignore named pipes with illegal filenames when checking for the task named pipe during bootstrapping - https://github.com/ansible-collections/ansible.windows/issues/291
- win_updates - Improve error handling when starting background update task
- win_user - Fix ``msg`` return value when setting ``state: query``
- win_whoami - Fix conflicts with existing ``LIB`` environment variable

v1.7.3
======

Bugfixes
--------

- win_reboot - Fix local variable referenced before assignment issue - https://github.com/ansible-collections/ansible.windows/issues/276
- win_updates - Bypass execution policy checks when polling or cancelling the update task - https://github.com/ansible-collections/ansible.windows/issues/272
- win_user - Set validate user logic to always check local database

v1.7.2
======

Bugfixes
--------

- win_group - fixed ``description`` setting for a group that doesn't exist when running in check_mode (https://github.com/ansible-collections/ansible.windows/pull/260).

v1.7.1
======

Bugfixes
--------

- win_dsc - Fix import errors when running against host that wasn't installed with the ``en-US`` locale - https://github.com/ansible-collections/ansible.windows/issues/83
- win_state - Fixed the ``creationtime``, ``lastaccesstime``, and ``lastwritetime`` to report the time in UTC. This matches the ``stat`` module's behaviour and what many would expect for a epoch based timestamp - https://github.com/ansible-collections/ansible.windows/issues/240
- win_updates - Fixed ``win_updates`` output to not cast to an integer to preserve original behaviour and issues with non integer values - https://github.com/ansible-collections/ansible.windows/issues/247
- win_updates - fallback to run as SYSTEM if current user does not have batch logon rights - https://github.com/ansible-collections/ansible.windows/issues/253

v1.7.0
======

Minor Changes
-------------

- win_updates - Added ``accept_list`` and ``reject_list`` to replace ``whitelist`` and ``blacklist``
- win_updates - Added ``failure_msg`` result to the return value of each update that gives a human readable error message if the update failed to download or install
- win_updates - Added ``filtered_reasons`` that list all the reasons why the update has been filtered - https://github.com/ansible-collections/ansible.windows/issues/226
- win_updates - Added progress logs to display on higher verbosities the download and install progress for each host
- win_updates - Added the ``downloaded`` result to the return value of each update to indicate if an update was downloaded or not
- win_updates - Added the category ``*`` that matches all categories
- win_updates - Improve Windows Update HRESULT error messages
- win_updates - Improve the details present in the ``log_path`` log entries for better monitoring

Deprecated Features
-------------------

- win_updates - Deprecated the ``filtered_reason`` return value for each filtered up in favour of ``filtered_reasons``. This has been done to show all the reasons why an update was filtered and not just the first reason.
- win_updates - Deprecated the ``use_scheduled_task`` option as it is no longer used.
- win_updates - Deprecated the ``whitelist`` and ``blacklist`` options in favour of ``accept_list`` and ``reject_list`` respectively to conform to the new standards used in Ansible for these types of options.

Bugfixes
--------

- win_reboot - Handle connection failures when getting the first boot time command
- win_updates - Always return the ``failed_updates_count`` on a standard failure - https://github.com/ansible-collections/ansible.windows/issues/13
- win_updates - Always use a scheduled task which should be less prone to random token errors when trying to connect to Windows Update - https://github.com/ansible-collections/ansible.windows/issues/193
- win_updates - Attempt a reboot once when ``reboot=True`` is set and a failure occurred - https://github.com/ansible-collections/ansible.windows/issues/22
- win_updates - Improve the reboot detection behaviour when ``reboot=True`` is set - https://github.com/ansible-collections/ansible.windows/issues/25
- win_updates - Improve the reboot mechanism - https://github.com/ansible-collections/ansible.windows/issues/143
- win_updates - Reboot the host when ``reboot=True`` if the first search result indicates a reboot is required - https://github.com/ansible-collections/ansible.windows/issues/49

v1.6.0
======

Minor Changes
-------------

- win_reboot - Change the default ``test_command`` run after a reboot to wait for more services to start up before the plugin finished. This should better handle waiting until the logon screen appears rather than just when WinRM is first online.

Deprecated Features
-------------------

- win_reboot - Unreachable hosts can be ignored with ``ignore_errors: True``, this ability will be removed in a future version. Use ``ignore_unreachable: True`` to ignore unreachable hosts instead. - https://github.com/ansible-collections/ansible.windows/issues/62

Removed Features (previously deprecated)
----------------------------------------

- win_reboot - Removed ``shutdown_timeout`` and ``shutdown_timeout_sec`` which has not done anything since Ansible 2.5.

Bugfixes
--------

- win_certificate_store - Make sure `store_name: CertificateAuthority` refers to the `CA` store for backwards compatibility - https://github.com/ansible-collections/ansible.windows/pull/216
- win_reboot - Ensure documented return values are always returned even on a failure
- win_reboot - Handle more connection failures during the reboot phases
- win_reboot - User defined commands are run wrapped as a PowerShell command so they work on all shells - https://github.com/ansible-collections/ansible.windows/issues/36

v1.5.0
======

Minor Changes
-------------

- win_certificate_store - Added functionality to open the store for a service account using ``store_type=service store_location=<service name>``
- win_user - Support specifying groups using the SecurityIdentifier - https://github.com/ansible-collections/ansible.windows/issues/153

Bugfixes
--------

- setup - Return correct epoch integer value for the ``ansible_date_time.epoch_int`` fact
- win_template - Fix changed internal API that win_template uses to work with devel again
- win_user - Compare existing vs desired groups in a case insenstive way - https://github.com/ansible-collections/ansible.windows/issues/168

New Modules
-----------

- win_powershell - Run PowerShell scripts

v1.4.0
======

Minor Changes
-------------

- setup - Added more virtualization types to the virtual facts based on the Linux setup module

Bugfixes
--------

- win_package - fix msi detection when the msi product is already installed under a different version - https://github.com/ansible-collections/ansible.windows/issues/166
- win_package - treat a missing ``creates_path`` when ``creates_version`` as though the package was not installed instead of a failure - https://github.com/ansible-collections/ansible.windows/issues/169

v1.3.0
======

Minor Changes
-------------

- setup - add ``epoch_int`` option to date_time facts (https://github.com/ansible/ansible/issues/72479).
- win_environment - add ``variables`` dictionary option for setting many env vars at once (https://github.com/ansible-collections/ansible.windows/pull/113).
- win_find - Change ``hidden: yes`` to return hidden files and normal files to match the behaviour with ``find`` - https://github.com/ansible-collections/ansible.windows/issues/130
- win_service - Allow opening driver services using this module. Not all functionality is available for these types of services - https://github.com/ansible-collections/ansible.windows/issues/115

Bugfixes
--------

- setup - handle PATH environment vars that contain blank entries like ``C:\Windows;;C:\Program Files`` - https://github.com/ansible-collections/ansible.windows/pull/78#issuecomment-745229594
- win_package - Do not fail when trying to set SYSTEM ACE on read only path - https://github.com/ansible-collections/ansible.windows/issues/142
- win_service - Fix edge case bug when running against PowerShell 5.0 - https://github.com/ansible-collections/ansible.windows/issues/125
- win_service - Fix opening services with limited rights - https://github.com/ansible-collections/ansible.windows/issues/118
- win_service - Fix up account name lookup when dealing with netlogon formatted accounts (``DOMAIN\account``) - https://github.com/ansible-collections/ansible.windows/issues/156
- win_service_info - Provide failure details in warning when failing to open service

v1.2.0
======

v1.0.1
======

Bugfixes
--------

- win_copy - fix bug when copying a single file during a folder copy operation

v1.0.0
======

Minor Changes
-------------

- win_hostname - Added diff mode support
- win_hostname - Use new ``Ansible.Basic.AnsibleModule`` wrapper
- win_user - Added check mode support
- win_user - Added diff mode support
- win_user - Added the ``home_directory`` option
- win_user - Added the ``login_script`` option
- win_user - Added the ``profile`` option
- win_user - Use new ``Ansible.Basic.AnsibleModule`` wrapper for better invocation reporting
- win_user_right - Improved error messages to show what right and account an operation failed on
- win_user_right - Refactored to use ``Ansible.Basic.AnsibleModule`` for better module invocation reporting

Breaking Changes / Porting Guide
--------------------------------

- win_find - module has been refactored to better match the behaviour of the ``find`` module. Here is what has changed:
    * When the directory specified by ``paths`` does not exist or is a file, it will no longer fail and will just warn the user
    * Junction points are no longer reported as ``islnk``, use ``isjunction`` to properly report these files. This behaviour matches the win_stat module
    * Directories no longer return a ``size``, this matches the ``stat`` and ``find`` behaviour and has been removed due to the difficulties in correctly reporting the size of a directory
- win_user - Change idempotency checks for ``description`` to be case sensitive
- win_user - Change idempotency checks for ``fullname`` to be case sensitive

Deprecated Features
-------------------

- win_domain_controller - the ``log_path`` option has been deprecated and will be removed in a later release. This was undocumented and only related to debugging information for module development.
- win_package - the ``ensure`` alias for the ``state`` option has been deprecated and will be removed in a later release. Please use ``state`` instead of ``ensure``.
- win_package - the ``productid`` alias for the ``product_id`` option has been deprecated and will be removed in a later release. Please use ``product_id`` instead of ``productid``.
- win_package - the ``username`` and ``password`` options has been deprecated and will be removed in a later release. The same functionality can be done by using ``become: yes`` and ``become_flags: logon_type=new_credentials logon_flags=netcredentials_only`` on the task.

Removed Features (previously deprecated)
----------------------------------------

- win_stat - removed the deprecated ``get_md55`` option and ``md5`` return value.

v0.2.0
======

Release Summary
---------------

This is the first proper release of the ``ansible.windows`` collection on 2020-07-18.
The changelog describes all changes made to the modules and plugins included in this collection since Ansible 2.9.0.

Minor Changes
-------------

- Checks for and resolves a condition where effective nameservers are obfucated, usually by malware. See https://www.welivesecurity.com/2016/06/02/crouching-tiger-hidden-dns/
- Windows - add deprecation notice in the Windows setup module when running on Server 2008, 2008 R2, and Windows 7
- setup - Added `ansible_architecture2`` to match the same format that setup on POSIX hosts return. Unlike ``ansible_architecture`` this value is not localized to the host's language settings.
- setup - Implemented the ``gather_timeout`` option to restrict how long each subset can run for
- setup - Refactor to speed up the time taken to run the module
- setup.ps1 - parity with linux regarding missing local facts path (https://github.com/ansible/ansible/issues/57974)
- win_command, win_shell - Add the ability to override the console output encoding with ``output_encoding_override`` - https://github.com/ansible/ansible/issues/54896
- win_dns_client - Added support for setting IPv6 DNS servers - https://github.com/ansible/ansible/issues/55962
- win_domain_computer - Use new Ansible.Basic wrapper for better invocation reporting
- win_domain_controller - Added the ``domain_log_path`` to control the directory for the new AD log files location - https://github.com/ansible/ansible/issues/59348
- win_find - Improve performance when scanning heavily nested directories and align behaviour to the ``find`` module.
- win_package - Added proxy support for retrieving packages from a URL - https://github.com/ansible/ansible/issues/43818
- win_package - Added support for ``.appx``, ``.msix``, ``.appxbundle``, and ``.msixbundle`` package - https://github.com/ansible/ansible/issues/50765
- win_package - Added support for ``.msp`` packages - https://github.com/ansible/ansible/issues/22789
- win_package - Added support for specifying the HTTP method when getting files from a URL - https://github.com/ansible/ansible/issues/35377
- win_package - Move across to ``Ansible.Basic`` for better invocation logging
- win_package - Read uninstall strings from the ``QuietUninstallString`` if present to better support argumentless uninstalls of registry based packages.
- win_package - Scan packages in the current user's registry hive - https://github.com/ansible/ansible/issues/45950
- win_regedit - Use new Ansible.Basic wrapper for better invocation reporting
- win_share - Implement append parameter for access rules (https://github.com/ansible/ansible/issues/59237)
- windows setup - Added ``ansible_os_installation_type`` to denote the type of Windows installation the remote host is.

Breaking Changes / Porting Guide
--------------------------------

- setup - Make sure ``ansible_date_time.epoch`` is seconds since EPOCH in UTC to mirror the POSIX facts. The ``ansible_date_time.epoch_local`` contains seconds since EPOCH in the local timezone for backwards compatibility
- setup - Will now add the IPv6 scope on link local addresses for ``ansible_ip_addresses``
- setup - ``ansible_processor`` will now return the index before the other values to match the POSIX fact behaviour
- win_find - No longer filters by size on directories, this feature had a lot of bugs, slowed down the module, and not a supported scenario with the ``find`` module.

Deprecated Features
-------------------

- win_domain_computer - Deprecated the undocumented ``log_path`` option. This option will be removed in a major release after ``2022-07-01``.
- win_regedit - Deprecated using forward slashes as a path separator, use backslashes to avoid ambiguity between a forward slash in the key name or a forward slash as a path separator. This feature will be removed in a major release after ``2021-07-01``.

Bugfixes
--------

- Fix detection of DHCP setting so that resetting to DHCP doesn't cause ``CHANGED`` status on every run. See https://github.com/ansible/ansible/issues/66450
- setup - Remove usage of WMI to speed up execution time and work with standard user accounts
- win_acl - Fixed error when setting rights on directory for which inheritance from parent directory has been disabled.
- win_dns_client - Only configure network adapters that are IP Enabled - https://github.com/ansible/ansible/issues/58958
- win_dsc - Always import module that contains DSC resource to ensure the required assemblies are loaded before parsing it - https://github.com/ansible-collections/ansible.windows/issues/66
- win_find - Fix deduped files mistaken for directories (https://github.com/ansible/ansible/issues/58511)
- win_find - Get-FileStat used [int] instead of [int64] for file size calculations
- win_package - Handle quoted and unquoted strings in the registry ``UninstallString`` value - https://github.com/ansible/ansible/issues/40973
- win_reboot - add ``boot_time_command`` parameter to override the default command used to determine whether or not a system was rebooted (https://github.com/ansible/ansible/issues/58868)
- win_share - Allow for root letters paths
- win_uri win_get_url - Fix the behaviour of ``follow_redirects: safe`` to actual redirect on ``GET`` and ``HEAD`` requests - https://github.com/ansible/ansible/issues/65556
