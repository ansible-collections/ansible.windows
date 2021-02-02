=============================
Ansible Windows Release Notes
=============================

.. contents:: Topics


v1.4.0
======

Release Summary
---------------

- Release summary for v1.4.0

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
