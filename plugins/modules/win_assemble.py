#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2012, Stephen Fromm <sfromm@gmail.com>
# Copyright: (c) 2016, Toshio Kuratomi <tkuratomi@ansible.com>
# Copyright: (c) 2017, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_assemble
short_description: Assemble configuration files from fragments
description:
- Assembles a configuration file from fragments.
- Often a particular program will take a single configuration file and does not support a
  C(conf.d) style structure where it is easy to build up the configuration
  from multiple sources. M(ansible.windows.win_assemble) will take a directory of files that can be
  local or have already been transferred to the system, and concatenate them
  together to produce a destination file.
- Files are assembled in string sorting order.
- Puppet calls this idea I(fragments).
version_added: '2.3.0'
options:
  src:
    description:
    - An already existing directory full of source files.
    type: path
    required: true
  dest:
    description:
    - A file to create using the concatenation of all of the source files.
    type: path
    required: true
  backup:
    description:
    - Create a backup file (if V(true)), including the timestamp information so
      you can get the original file back if you somehow clobbered it
      incorrectly.
    type: bool
    default: false
  delimiter:
    description:
    - A delimiter to separate the file contents.
    type: str
  remote_src:
    description:
    - If V(false), it will search for src at originating/master machine.
    - If V(true), it will go to the remote/target machine for the src.
    type: bool
    default: true
  regexp:
    description:
    - Assemble files only if the given regular expression matches the filename.
    - If not set, all files are assembled.
    - Every V(\\) (backslash) must be escaped as V(\\\\) to comply to YAML syntax.
    - If O(remote_src=false), uses L(Python regular expressions,https://docs.python.org/3/library/re.html).
    - If O(remote_src=true), uses L(.NET regular expressions,https://learn.microsoft.com/en-us/dotnet/standard/base-types/regular-expressions).
    type: str
  ignore_hidden:
    description:
    - A boolean that controls if hidden files will be included or not.
    - Which files are considered hidden depends on the source location.
    - If O(remote_src=false), files that start with a '.' are considered hidden.
    - If O(remote_src=true), files that have the hidden attribute on supported 
      filesystems on the remote/target system are considered hidden.
    type: bool
    default: false
  header:
    description:
    - Content to place at the top of the generated file.
    type: str
  footer:
    description:
    - Content to place at the bottom of the generated file.
    type: str
  decrypt:
    description:
    - This option controls the autodecryption of source files using vault.
    - This is ignored if O(remote_src=true).
    type: bool
    default: true
attributes:
    action:
      support: full
    check_mode:
      support: full
    diff_mode:
      support: full
    platform:
      platforms: windows
    vault:
      support: partial
      details: Only supported when O(remote_src=false).
notes:
- It is recommended that backslashes C(\) are used instead of C(/) when dealing
  with remote paths.
seealso:
- module: ansible.builtin.assemble
- module: ansible.windows.win_copy
author:
- Daniel Osborne
'''

EXAMPLES = r'''
- name: Assemble from fragments from a directory
  ansible.windows.win_assemble:
    src: conf/
    dest: C:\\ProgramData\\Foo\\conf.ini

- name: Insert the provided delimiter between fragments
  ansible.windows.win_assemble:
    src: conf/
    dest: C:\\ProgramData\\Foo\\conf.ini
    delimiter: '### START FRAGMENT ###'
'''

RETURN = r'''
backup_file:
    description: Name of the backup file that was created.
    returned: if O(backup=true) and destination was pre-existing.
    type: str
    sample: C:\\Path\\To\\File.txt.11540.20150212-220915.bak
dest:
    description: Destination file/path.
    returned: success
    type: str
    sample: C:\\Temp\\assembled.txt
checksum:
    description: SHA1 checksum of the file after running copy.
    returned: success
    type: str
    sample: 6e642bb8dd5c2e027bf21dd923337cbb4214f827
size:
    description: Size of the target, after execution.
    returned: success
    type: int
    sample: 1220
'''

