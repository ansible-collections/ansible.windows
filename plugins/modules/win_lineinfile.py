#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2015, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_lineinfile
version_added: 3.9.0
short_description: Ensure a particular line is in a file, or replace an existing line using a back-referenced regular expression
description:
- This module will search a file for a line, and ensure that it is present or absent.
- This is primarily useful when you want to change a single line in a file only.
- For non-Windows targets, use the M(ansible.builtin.lineinfile) module instead.
options:
  path:
    description:
    - The path of the file to modify.
    - Note that the Windows path delimiter C(\\) must be escaped as C(\\\\) when the line is double quoted.
    type: path
    required: true
    aliases: [ dest, destfile, name ]
  backup:
    description:
    - Determine whether a backup should be created.
    - When set to V(true), create a backup file including the timestamp information
      so you can get the original file back if you somehow clobbered it incorrectly.
    type: bool
    default: false
  regex:
    description:
    - The regular expression to look for in every line of the file.
    - For O(state=present), the pattern to replace if found; only the last line found will be replaced.
    - For O(state=absent), the pattern of the line to remove.
    - Uses .NET compatible regular expressions, see
      U(https://learn.microsoft.com/en-us/dotnet/standard/base-types/regular-expression-language-quick-reference).
    type: str
    aliases: [ regexp ]
  state:
    description:
    - Whether the line should be there or not.
    type: str
    choices: [ absent, present ]
    default: present
  line:
    description:
    - Required for O(state=present). The line to insert/replace into the file.
    - If O(backrefs) is set, may contain backreferences that will get expanded with the O(regex) capture
      groups if the regex matches.
    - Be aware that the line is processed first on the controller and thus is dependent on yaml quoting rules.
      Any double quoted line will have control characters, such as C(\\r\\n), expanded. To print such characters
      literally, use single or no quotes.
    type: str
  backrefs:
    description:
    - Used with O(state=present).
    - If set, O(line) can contain backreferences (both positional and named) that will get populated if the
      O(regex) matches.
    - This flag changes the operation of the module slightly; O(insertbefore) and O(insertafter) will be ignored,
      and if the O(regex) does not match anywhere in the file, the file will be left unchanged.
    - If the O(regex) does match, the last matching line will be replaced by the expanded O(line) parameter.
    type: bool
    default: false
  insertafter:
    description:
    - Used with O(state=present).
    - If specified, the line will be inserted after the last match of the specified regular expression.
    - A special value V(EOF) is available for inserting the line at the end of the file.
    - If the specified regular expression has no matches, V(EOF) will be used instead.
    - May not be used with O(backrefs).
    - Defaults to V(EOF) when neither O(insertafter) nor O(insertbefore) is specified.
    type: str
  insertbefore:
    description:
    - Used with O(state=present).
    - If specified, the line will be inserted before the last match of the specified regular expression.
    - A special value V(BOF) is available for inserting the line at the beginning of the file.
    - If the specified regular expression has no matches, the line will be inserted at the end of the file.
    - May not be used with O(backrefs).
    type: str
  create:
    description:
    - Used with O(state=present).
    - If specified, the file will be created if it does not already exist.
    - By default it will fail if the file is missing.
    type: bool
    default: false
  validate:
    description:
    - Validation to run before copying into place.
    - Use C(%s) in the command to indicate the current file to validate.
    - The command is passed securely so shell features like expansion and pipes will not work.
    type: str
  encoding:
    description:
    - Specifies the encoding of the source text file to operate on (and thus what the output encoding will be).
    - The default of V(auto) will cause the module to auto-detect the encoding of the source file and ensure that
      the modified file is written with the same encoding.
    - An explicit encoding can be passed as a string that is a valid value to pass to the .NET framework
      C(System.Text.Encoding.GetEncoding()) method, see
      U(https://learn.microsoft.com/en-us/dotnet/api/system.text.encoding.getencoding).
    - This is mostly useful with O(create=true) if you want to create a new file with a specific encoding.
    - If O(create=true) is specified without a specific encoding, the default encoding (UTF-8, no BOM) will be used.
    type: str
    default: auto
  newline:
    description:
    - Specifies the line separator style to use for the modified file.
    - This defaults to the windows line separator C(\\r\\n).
    - Note that the indicated line separator will be used for file output regardless of the original line
      separator that appears in the input file.
    type: str
    choices: [ unix, windows ]
    default: windows
seealso:
- module: ansible.builtin.assemble
- module: ansible.builtin.lineinfile
- module: ansible.windows.win_copy
- module: ansible.windows.win_template
author:
- Brian Lloyd (@brianlloyd)
'''

EXAMPLES = r'''
- name: Insert path without converting \r\n
  ansible.windows.win_lineinfile:
    path: c:\file.txt
    line: c:\return\new

- name: Replace a line matching a regex
  ansible.windows.win_lineinfile:
    path: C:\Temp\example.conf
    regex: '^name='
    line: 'name=JohnDoe'

- name: Remove a line matching a regex
  ansible.windows.win_lineinfile:
    path: C:\Temp\example.conf
    regex: '^name='
    state: absent

- name: Ensure the localhost entry is correct
  ansible.windows.win_lineinfile:
    path: C:\Temp\example.conf
    regex: '^127\.0\.0\.1'
    line: '127.0.0.1 localhost'

- name: Uncomment and set a Listen directive
  ansible.windows.win_lineinfile:
    path: C:\Temp\httpd.conf
    regex: '^Listen '
    insertafter: '^#Listen '
    line: Listen 8080

- name: Insert a comment before a services entry
  ansible.windows.win_lineinfile:
    path: C:\Temp\services
    regex: '^# port for http'
    insertbefore: '^www.*80/tcp'
    line: '# port for http by default'

- name: Create file if it doesn't exist with a specific encoding
  ansible.windows.win_lineinfile:
    path: C:\Temp\utf16.txt
    create: true
    encoding: utf-16
    line: This is a utf-16 encoded file

- name: Add a line to a file and ensure the resulting file uses unix line separators
  ansible.windows.win_lineinfile:
    path: C:\Temp\testfile.txt
    line: Line added to file
    newline: unix

- name: Update a line using backrefs
  ansible.windows.win_lineinfile:
    path: C:\Temp\example.conf
    backrefs: true
    regex: '(^name=)'
    line: '$1JohnDoe'
'''

RETURN = r'''
backup_file:
  description: Name of the backup file that was created.
  returned: if O(backup=true) and a change was made
  type: str
  sample: C:\Path\To\File.txt.11540.20150212-220915.bak
encoding:
  description: The encoding that was used to read from and write to the file.
  returned: success
  type: str
  sample: utf-8
found:
  description: The number of lines that matched and were removed.
  returned: O(state=absent)
  type: int
  sample: 1
msg:
  description: A short description of the change that was made.
  returned: success
  type: str
  sample: line added
'''
