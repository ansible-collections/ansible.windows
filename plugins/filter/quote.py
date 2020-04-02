# Copyright (c) 2020 Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import re

from ansible.errors import AnsibleFilterError
from ansible.module_utils.common.collections import is_sequence

_UNSAFE_C = re.compile(r'[\s\t"]')
_UNSAFE_CMD = re.compile(r'[\s\(\)\%\!^\"\<\>\&\|]')


def _quote_c(s):
    # https://docs.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
    if not s:
        return '""'

    if not _UNSAFE_C.search(s):
        return s

    # Replace any double quotes in an argument with '\"'.
    s = s.replace('"', '\\"')

    # We need to double up on any '\' chars that preceded a double quote (now '\"').
    s = re.sub(r'(\\+)\\"', r'\1\1\"', s)

    # Double up '\' at the end of the argument so it doesn't escape out end quote.
    s = re.sub(r'(\\+)$', r'\1\1', s)

    # Finally wrap the entire argument in double quotes now we've escaped the double quotes within.
    return '"{0}"'.format(s)


def _quote_cmd(s):
    # https://docs.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way#a-better-method-of-quoting
    if not s:
        return '""'

    if not _UNSAFE_CMD.search(s):
        return s

    # Escape the metachars as we are quoting the string to stop cmd from interpreting that metachar. For example
    # 'file &whoami.exe' would result in 'whoami.exe' being executed and then that output being used as the argument
    # instead of the literal string.
    # https://stackoverflow.com/questions/3411771/multiple-character-replace-with-python
    for c in '^()%!"<>&|':  # '^' must be the first char that we scan and replace
        if c in s:
            s = s.replace(c, "^" + c)

    return '^"{0}^"'.format(s)


def _quote_pwsh(s):
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_quoting_rules?view=powershell-5.1
    if not s:
        return "''"

    # We should always quote values in PowerShell as it has conflicting rules where strings can and can't be quoted.
    # This means we quote the entire arg with single quotes and escape the single quotes already in the arg.
    return "'{0}'".format(s.replace("'", "''"))


def quote(value, shell=None):
    """
    Quotes argument(s) for the various shells in Windows command processing. Will default to escaping arguments based
    on the Win32 C argv parsing rules that 'win_command' uses but shell='cmd' or shell='powershell' can be set to
    escape arguments for those respective shells. Each value is escaped in a way to ensure the process gets the literal
    argument passed in and meta chars escaped.

    When passing in a dict, the arguments will be in the form 'key={{ value | ansible.windows.quote }}' to match the
    MSI parameter format.

    :params value: A string, list, or dict of value(s) to quote.
    :params shell: The shell that is used to escape the args for.
    :return: The quoted argument(s) from the input.
    """
    if not shell:
        quote_func = _quote_c
    elif shell == 'cmd':
        quote_func = _quote_cmd
    elif shell == 'powershell':
        quote_func = _quote_pwsh
    else:
        raise AnsibleFilterError("Invalid shell specified, valid shell are None, 'cmd', or 'powershell'")

    if not is_sequence(value):
        value = [value]

    new_arguments = []
    for arg in value:
        if isinstance(arg, dict):
            # Quoting a dict assumes you are quoting a KEY=value pair for MSI arguments. The key can only be
            # '[A-Z0-9_\.]' so we don't attempt to quote the key, only the value. If another format is desired then it
            # need to be done manually, i.e. '/KEY:{{ value | ansible.windows.quote }}'.
            for key, value in arg.items():
                new_arguments.append('%s=%s' % (key, quote_func(value)))
        else:
            new_arguments.append(quote_func(arg))

    return " ".join(new_arguments)


class FilterModule:

    def filters(self):
        return {
            'quote': quote,
        }
