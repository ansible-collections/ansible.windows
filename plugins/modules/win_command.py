#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2016, Ansible, inc
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

DOCUMENTATION = r'''
---
module: win_command
short_description: Executes a command on a remote Windows node
description:
     - The C(win_command) module takes the command name followed by a list of space-delimited arguments.
     - The given command will be executed on all selected nodes. It will not be
       processed through the shell, so variables like C($env:HOME) and operations
       like C("<"), C(">"), C("|"), and C(";") will not work (use the M(ansible.windows.win_shell)
       module if you need these features).
     - For non-Windows targets, use the M(ansible.builtin.command) module instead.
options:
  _raw_params:
    description:
      - The C(win_command) module takes a free form command to run.
      - This is mutually exclusive with the C(cmd) and C(argv) options.
      - There is no parameter actually named '_raw_params'. See the examples!
    type: str
  cmd:
    description:
    - The command and arguments to run.
    - This is mutually exclusive with the C(_raw_params) and C(argv) options.
    type: str
    version_added: '1.11.0'
  argv:
    description:
    - A list that contains the executable and arguments to run.
    - The module will attempt to quote the arguments specified based on the
      L(Win32 C command-line argument rules,https://docs.microsoft.com/en-us/cpp/c-language/parsing-c-command-line-arguments).
    - Not all applications use the same quoting rules so the escaping may not work, for those scenarios use C(cmd) instead.
    type: list
    elements: str
    version_added: '1.11.0'
  creates:
    description:
      - A path or path filter pattern; when the referenced path exists on the target host, the task will be skipped.
    type: path
  removes:
    description:
      - A path or path filter pattern; when the referenced path B(does not) exist on the target host, the task will be skipped.
    type: path
  chdir:
    description:
      - Set the specified path as the current working directory before executing a command.
    type: path
  stdin:
    description:
    - Set the stdin of the command directly to the specified value.
    type: str
  output_encoding_override:
    description:
    - This option overrides the encoding of stdout/stderr output.
    - You can use this option when you need to run a command which ignore the console's codepage.
    - You should only need to use this option in very rare circumstances.
    - This value can be any valid encoding C(Name) based on the output of C([System.Text.Encoding]::GetEncodings()).
      See U(https://docs.microsoft.com/dotnet/api/system.text.encoding.getencodings).
    type: str
notes:
    - If you want to run a command through a shell (say you are using C(<),
      C(>), C(|), etc), you actually want the M(ansible.windows.win_shell) module instead. The
      M(ansible.windows.win_command) module is much more secure as it's not affected by the user's
      environment.
    - C(creates), C(removes), and C(chdir) can be specified after the command. For instance, if you only want to run a command if a certain file does not
      exist, use this.
    - Do not try to use the older style free form format and the newer style cmd/argv format. See the examples for how both of these formats are defined.
seealso:
- module: ansible.builtin.command
- module: community.windows.psexec
- module: ansible.builtin.raw
- module: community.windows.win_psexec
- module: ansible.windows.win_shell
author:
    - Matt Davis (@nitzmahone)
'''

EXAMPLES = r'''
# Older style using the free-form and args format. The command is on the same
# line as the module and 'args' is used to define the options for win_command.
- name: Save the result of 'whoami' in 'whoami_out'
  ansible.windows.win_command: whoami
  register: whoami_out

- name: Run command that only runs if folder exists and runs from a specific folder
  ansible.windows.win_command: wbadmin -backupTarget:C:\backup\
  args:
    chdir: C:\somedir\
    creates: C:\backup\

- name: Run an executable and send data to the stdin for the executable
  ansible.windows.win_command: powershell.exe -
  args:
    stdin: Write-Host test

# Newer style using module options. The command and other arguments are
# defined as module options and are indended like another other module.
- name: Run the 'whoami' executable with the '/all' argument
  ansible.windows.win_command:
    cmd: whoami.exe /all

- name: Run executable in 'C:\Program Files' with a custom chdir
  ansible.windows.win_command:
    # When using cmd, the arguments need to be quoted manually
    cmd: '"C:\Program Files\My Application\run.exe" "argument 1" -force'
    chdir: C:\Windows\TEMP

- name: Run executable using argv and have win_command escape the spaces as needed
  ansible.windows.win_command:
    # When using argv, each entry is quoted in the module
    argv:
      - C:\Program Files\My Application\run.exe
      - argument 1
      - -force

- name: Run an executable that outputs text with big5 encoding
  ansible.windows.win_command: C:\someprog.exe
  args:
    output_encoding_override: big5
'''

RETURN = r'''
msg:
    description: changed
    returned: always
    type: bool
    sample: true
start:
    description: The command execution start time
    returned: always
    type: str
    sample: '2016-02-25 09:18:26.429568'
end:
    description: The command execution end time
    returned: always
    type: str
    sample: '2016-02-25 09:18:26.755339'
delta:
    description: The command execution delta time
    returned: always
    type: str
    sample: '0:00:00.325771'
stdout:
    description: The command standard output
    returned: always
    type: str
    sample: 'Clustering node rabbit@slave1 with rabbit@main ...'
stderr:
    description: The command standard error
    returned: always
    type: str
    sample: 'ls: cannot access foo: No such file or directory'
cmd:
    description: The command executed by the task
    returned: always
    type: str
    sample: 'rabbitmqctl join_cluster rabbit@main'
rc:
    description: The command return code (0 means success)
    returned: always
    type: int
    sample: 0
stdout_lines:
    description: The command standard output split in lines
    returned: always
    type: list
    sample: ['Clustering node rabbit@slave1 with rabbit@main ...']
stderr_lines:
    description: The command standard error split in lines
    returned: always
    type: list
    sample: "['ls: cannot access foo: No such file or directory']"
'''
