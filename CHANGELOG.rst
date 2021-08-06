=============================
Ansible Windows Release Notes
=============================

.. contents:: Topics


v1.7.2
======

Release Summary
---------------

- First release for Automation Hub
- Release summary for v1.7.2

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
