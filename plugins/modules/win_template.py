#!/usr/bin/python
# -*- coding: utf-8 -*-

# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_template
short_description: Template a file out to a remote server
description:
- Templates are processed by the L(Jinja2 templating language,http://jinja.pocoo.org/docs/).
- Documentation on the template formatting can be found in the
  L(Template Designer Documentation,http://jinja.pocoo.org/docs/templates/).
- Additional variables listed below can be used in templates.
- C(ansible_managed) (configurable via the C(defaults) section of C(ansible.cfg)) contains a string which can be used to
  describe the template name, host, modification time of the template file and the owner uid.
- C(template_host) contains the node name of the template's machine.
- C(template_uid) is the numeric user id of the owner.
- C(template_path) is the path of the template.
- C(template_fullpath) is the absolute path of the template.
- C(template_destpath) is the path of the template on the remote system (added in 2.8).
- C(template_run_date) is the date that the template was rendered.
options:
  backup:
    description:
    - Determine whether a backup should be created.
    - When set to C(yes), create a backup file including the timestamp information
      so you can get the original file back if you somehow clobbered it incorrectly.
    type: bool
    default: no
  block_end_string:
    description:
    - The string marking the end of a block.
    type: str
    default: '%}'
  block_start_string:
    description:
    - The string marking the beginning of a block.
    type: str
    default: '{%'
  dest:
    description:
    - Location to render the template to on the remote machine.
    type: path
    required: yes
  force:
    description:
    - Determine when the file is being transferred if the destination already exists.
    - When set to C(yes), replace the remote file when contents are different than the source.
    - When set to C(no), the file will only be transferred if the destination does not exist.
    type: bool
    default: yes
  lstrip_blocks:
    description:
    - Determine when leading spaces and tabs should be stripped.
    - When set to C(yes) leading spaces and tabs are stripped from the start of a line to a block.
    - This functionality requires Jinja 2.7 or newer.
    type: bool
    default: no
  newline_sequence:
    description:
    - Specify the newline sequence to use for templating files.
    type: str
    choices: [ '\n', '\r', '\r\n' ]
    default: '\r\n'
  output_encoding:
    description:
    - Overrides the encoding used to write the template file defined by C(dest).
    - It defaults to C(utf-8), but any encoding supported by python can be used.
    - The source template file must always be encoded using C(utf-8), for homogeneity.
    type: str
    default: utf-8
  src:
    description:
    - Path of a Jinja2 formatted template on the Ansible controller.
    - This can be a relative or an absolute path.
    - The file must be encoded with C(utf-8) but I(output_encoding) can be used to control the encoding of the output
      template.
    type: path
    required: yes
  trim_blocks:
    description:
    - Determine when newlines should be removed from blocks.
    - When set to C(yes) the first newline after a block is removed (block, not variable tag!).
    type: bool
    default: yes
  variable_end_string:
    description:
    - The string marking the end of a print statement.
    type: str
    default: '}}'
  variable_start_string:
    description:
    - The string marking the beginning of a print statement.
    type: str
    default: '{{'
notes:
- Including a string that uses a date in the template will result in the template being marked 'changed' each time.
- >
  Also, you can override jinja2 settings by adding a special header to template file.
  i.e. C(#jinja2:variable_start_string:'[%', variable_end_string:'%]', trim_blocks: False)
  which changes the variable interpolation markers to C([% var %]) instead of C({{ var }}).
  This is the best way to prevent evaluation of things that look like, but should not be Jinja2.
- Using raw/endraw in Jinja2 will not work as you expect because templates in Ansible are recursively
  evaluated.
- To find Byte Order Marks in files, use C(Format-Hex <file> -Count 16) on Windows, and use C(od -a -t x1 -N 16 <file>)
  on Linux.
- Beware fetching files from windows machines when creating templates because certain tools, such as Powershell ISE,
  and regedit's export facility add a Byte Order Mark as the first character of the file, which can cause tracebacks.
- You can use the M(ansible.windows.win_copy) module with the C(content:) option if you prefer the template inline, as part of the
  playbook.
- For Linux you can use M(ansible.builtin.template) which uses '\\n' as C(newline_sequence) by default.
seealso:
- module: ansible.windows.win_copy
- module: ansible.builtin.copy
- module: ansible.builtin.template
author:
- Jon Hawkesworth (@jhawkesworth)
'''

EXAMPLES = r'''
- name: Create a file from a Jinja2 template
  ansible.windows.win_template:
    src: /mytemplates/file.conf.j2
    dest: C:\Temp\file.conf

- name: Create a Unix-style file from a Jinja2 template
  ansible.windows.win_template:
    src: unix/config.conf.j2
    dest: C:\share\unix\config.conf
    newline_sequence: '\n'
    backup: yes
'''

RETURN = r'''
backup_file:
    description: Name of the backup file that was created.
    returned: if backup=yes
    type: str
    sample: C:\Path\To\File.txt.11540.20150212-220915.bak
'''
