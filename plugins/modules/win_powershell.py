#!/usr/bin/python
# -*- coding: utf-8 -*-

# Copyright: (c) 2021, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)


DOCUMENTATION = r'''
---
module: win_powershell
version_added: 1.5.0
short_description: Run PowerShell scripts
description:
- Runs a PowerShell script and outputs the data in a structured format.
- Use M(ansible.windows.win_command) or M(ansible.windows.win_shell) to run a tranditional PowerShell process with
  stdout, stderr, and rc results.
options:
  arguments:
    description:
    - A list of arguments to pass to I(executable) when running a script in another PowerShell process.
    type: list
    elements: str
  creates:
    description:  
    - A path or path filter pattern; when the referenced path exists on the target host, the task will be skipped.
    type: path
  executable:
    description:
    - A custom PowerShell executable to run the script in.
    - When not defined the script will run in the current module PowerShell interpreter.
    - Both the remote PowerShell and the one specified by I(executable) must be running on PowerShell v5.1 or newer.
    type: str
  input:
    description:
    - A list of objects to pass in as the input to the PowerShell script.
    type: list
  location:
    description:
    - The PowerShell location to set when starting the script.
    type: path
  parameters:
    description:
    - Parameters to pass into the script as key value pairs.
    - The key corresponds to the parameter name and the value is the value for that parameter.
    type: dict
  removes:
    description:
    - A path or path filter pattern; when the referenced path B(does not) exist on the target host, the task will be
      skipped.
    type: path
  script:
    description:
    - The PowerShell script to run.
    type: str
    required: true
seealso:
- module: ansible.windows.win_command
- module: ansible.builtin.win_shell
notes:
- The output of the script is serialized to json using the C(ConvertTo-Json) cmdlet. There are certain .NET types
  which do not serialize nicely and can cause the module to hang once it is completed. Take care when outputting any
  objects.
- The script has access to the C($Ansible) variable where it can set C(Result), C(Changed), C(Failed), or access
  C(Tmpdir).
- Any host output like C(Write-Host) or C([Console]::WriteLine) is not considered an output object.
author:
- Jordan Borean (@jborean93)
'''

EXAMPLES = r'''
- name: Run basic PowerShell script
  ansible.windows.win_powershell:
    script: |
      echo "Hello World"

- name: Run PowerShell script with parameters
  ansible.windows.win_powershell:
    script: |
      [CmdletBinding()]
      param (
        [String]
        $Path,

        [Switch]
        $Force
      )

      New-Item -Path $Path -ItemType Direcotry -Force:$Force
    parameters:
      Path: C:\temp
      Force: true

- name: Run PowerShell script with input
  ansible.windows.win_powershell:
    script: |
      [CmdletBinding()]
      param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [String[]]
        $Path
      )

      process {
        foreach ($pathEntry in $Path) {
            Test-Path -Path $pathEntry
        }
      }
    input:
    - C:\Windows
    - HKLM:\SYSTEM

- name: Run PowerShell script that modifies the module changed result
  ansible.windows.win_powershell:
    script: |
      if (Get-Service -Name test -ErrorAction SilentlyContinue) {
        Remove-Service -Name test
      }
      else {
        $Ansible.Changed = $false
      }

- name: Run PowerShell script in PowerShell 7
  ansible.windows.win_powershell:
    script: |
      $PSVersionTable.PSVersion.Major
    executable: pwsh.exe
  register: pwsh_output
  failed_when:
  - pwsh_output.output[0] != 7
'''

RETURN = r'''
result:
  description:
  - The values that were set by C($Ansible.Result) in the script.
  - Defaults to an empty dict but can be set to anything by the script.
  returned: always
  type: raw
  sample: {'key': 'value', 'other key': 1}
host_out:
  description:
  - The strings written to the host output, typically the stdout.
  - This is not the same as objects sent to the output stream in PowerShell.
  returned: always
  type: str
  sample: "Line 1\nLine 2"
host_err:
  description:
  - The strings written to the host error output, typically the stderr.
  - This is not the same as objects sent to the error stream in PowerShell.
  returned: always
  type: str
  sample: "Error 1\nError 2"
output:
  description:
  - A list containing all the objects outputted by the script.
  - The list elements can be anything as it is based on what was ran.
  returned: always
  type: list
  sample: ['output 1', 2, ['inner list'], {'key': 'value'}, None]
error:
  description:
  - A list of error records created by the script.
  returned: always
  type: list
  elements: dict
  contains:
    output:
      description:
      - The formatted error record message as typically seen in a PowerShell console.
      type: str
      returned: always
      sample: |
        Write-Error "error" : error
            + CategoryInfo          : NotSpecified: (:) [Write-Error], WriteErrorException
            + FullyQualifiedErrorId : Microsoft.PowerShell.Commands.WriteErrorException
    exception:
      description:
      - Details about the exception behind the error record.
      type: dict
      contains:
        message:
          description:
          - The exception message.
          type: str
          returned: always
          sample: The method ran into an error
        type:
          description:
          - The full .NET type of the Exception class.
          type: str
          returned: always
          sample: System.Exception
        help_link:
          description:
          - A link to the help details for the exception.
          - May not be set as it's dependent on whether the .NET exception class provides this info.
          type: str
          returned: always
          sample: http://docs.ansible.com/
        source:
          description:
          - Name of the application or object that causes the error.
          - This may be an empty string as it's dependent on the code that raises the exception.
          type: str
          returned: always
          sample: C:\Windows
        hresult:
          description:
          - The signed integer assigned to this exception.
          - May not be set as it's dependent on whether the .NET exception class provides this info.
          type: int
          returned: always
          sample: -1
        inner_exception:
          description:
          - The inner exception details if there is one present.
          - The dict contains the same keys as a normal exception.
          returned: always
          type: dict
    target_object:
      description:
      - The object which the error occured.
      - May be null if no object was specified when the record was created.
      type: str
      returned: always
      sample: C:\Windows
    category_info:
      description:
      - More information about the error record.
      type: dict
      contains:
        category:
          description:
          - The category name of the error record.
          type: str
          returned: always
          sample: NotSpecified
        category_id:
          description:
          - The integer representation of the category.
          type: int
          returned: always
          sample: 0
        activity:
          description:
          - Description of the operation which encountered the error.
          type: str
          returned: always
          sample: Write-Error
        reason:
          description:
          - Description of the error.
          type: str
          returned: always
          sample: WriteErrorException
        target_name:
          description:
          - Description of the target object.
          - Can be an empty string if no target was specified.
          type: str
          returned: always
          sample: C:\Windows
        target_type:
          description:
          - Description of the type of the target object.
          - Can be an empty string if no target object was specified.
          type: str
          returned: always
          sample: String
    fully_qualified_error_id:
      description:
      - The unique identifier for the error condition
      - May be null if no id was specified when the record was created.
      type: str
      returned: always
      sample: ParameterBindingFailed
    script_stack_trace:
      description:
      - The script stack trace for the error record.
      type: str
      returned: always
      sample: at <ScriptBlock>, <No file>: line 1
    pipeline_iteration_info:
      description:
      - The status of the pipeline when this record was created.
      - The values are 0 index based.
      - Each element entry represents the command index in a pipeline statement.
      - The value of each element represents the pipeline input idx in that command.
      - For Example C('C:\Windows', 'C:\temp' | Get-ChildItem | Get-Item), C([1, 2, 9]) represents an error occured
        with the 2nd output, 3rd, and 9th output of the 1st, 2nd, and 3rd command in that pipeline respectively.
      type: list
      elements: int
      returned: always
      sample: [0, 0]
warning:
  description:
  - A list of warning messages created by the script.
  - TODO: Document $WarningPreference and how it affects this
  returned: always
  type: list
  elements: str
  sample: ['warning record']
verbose:
  description:
  - A list of warning messages created by the script.
  - TODO: Document $VerbosePreference and how it affects this
  returned: always
  type: list
  elements: str
  sample: ['verbose record']
debug:
  description:
  - A list of warning messages created by the script.
  - TODO: Document $DebugPreference and how it affects this
  returned: always
  type: list
  elements: str
  sample: ['debug record']
information:
  description:
  - A list of information records created by the script.
  - The information stream was only added in PowerShell v5, older versions will always have an empty list as a value.
  returned: always
  type: list
  elements: dict
  contains:
    message_data:
      description:
      - Message data associated with the record.
      - The value here can be of any type.
      type: raw
      returned: always
      sample: information record
    source:
      description:
      - The source of the record.
      type: str
      returned: always
      sample: Write-Information
    time_generated:
      description:
      - The time the record was generated.
      - This is the time in UTC as an ISO 8601 formatted string.
      type: str
      returned: always
      sample: 2021-02-11T04:46:00.4694240Z
    tags:
      description:
      - A list of tags associated with the record.
      type: list
      elements: str
      returned: always
      sample: ['Host']
    user:
      description:
      - The user that generated the record.
      type: str
      returned: always
      sample: MyUser
    computer:
      description:
      - The computer that generated the record.
      type: str
      returned: always
      sample: MY-HOST
    process_id:
      description:
      - The native process that generated the record.
      type: int
      returned: always:
      sample: 12932
    native_thread_id:
      description:
      - The native thread that generated the record.
      type: int
      returned: always
      sample: 2923
    managed_thread_id:
      description:
      - The managed (.NET) thread that generated the record.
      type: int
      returned: always
      sample: 10234
'''
