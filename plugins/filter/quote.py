# Copyright (c) 2020 Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import re

from ansible.errors import AnsibleFilterError
from ansible.module_utils.common.collections import is_sequence
from ansible.module_utils._text import to_text

_UNSAFE_C = re.compile(u'[\\s\t"]')
_UNSAFE_CMD = re.compile(u'[\\s\\(\\)\\^\\|%!"<>&]')

# PowerShell has 5 characters it uses as a single quote, we need to double up on all of them.
# https://github.com/PowerShell/PowerShell/blob/b7cb335f03fe2992d0cbd61699de9d9aafa1d7c1/src/System.Management.Automation/engine/parser/CharTraits.cs#L265-L272
# https://github.com/PowerShell/PowerShell/blob/b7cb335f03fe2992d0cbd61699de9d9aafa1d7c1/src/System.Management.Automation/engine/parser/CharTraits.cs#L18-L21
_UNSAFE_PWSH = re.compile(u"(['\u2018\u2019\u201a\u201b])")


def _quote_c(s):
    # https://docs.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way
    if not s:
        return u'""'

    if not _UNSAFE_C.search(s):
        return s

    # Replace any double quotes in an argument with '\"'.
    s = s.replace('"', '\\"')

    # We need to double up on any '\' chars that preceded a double quote (now '\"').
    s = re.sub(r'(\\+)\\"', r'\1\1\"', s)

    # Double up '\' at the end of the argument so it doesn't escape out end quote.
    s = re.sub(r'(\\+)$', r'\1\1', s)

    # Finally wrap the entire argument in double quotes now we've escaped the double quotes within.
    return u'"{0}"'.format(s)


def _quote_cmd(s):
    # https://docs.microsoft.com/en-us/archive/blogs/twistylittlepassagesallalike/everyone-quotes-command-line-arguments-the-wrong-way#a-better-method-of-quoting
    if not s:
        return u'""'

    if not _UNSAFE_CMD.search(s):
        return s

    # Escape the metachars as we are quoting the string to stop cmd from interpreting that metachar. For example
    # 'file &whoami.exe' would result in 'whoami.exe' being executed and then that output being used as the argument
    # instead of the literal string.
    # https://stackoverflow.com/questions/3411771/multiple-character-replace-with-python
    for c in u'^()%!"<>&|':  # '^' must be the first char that we scan and replace
        if c in s:
            # I can't find any docs that explicitly say this but to escape ", it needs to be prefixed with \^.
            s = s.replace(c, (u"\\^" if c == u'"' else u"^") + c)

    return u'^"{0}^"'.format(s)


def _quote_pwsh(s):
    # https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_quoting_rules?view=powershell-5.1
    if not s:
        return u"''"

    # We should always quote values in PowerShell as it has conflicting rules where strings can and can't be quoted.
    # This means we quote the entire arg with single quotes and just double up on the single quote equivalent chars.
    return u"'{0}'".format(_UNSAFE_PWSH.sub(u'\\1\\1', s))


def quote(value, shell=None):
    """Quotes argument(s) for the various shells in Windows command processing.

    Quotes argument(s) for the various Windows command line shells. Default to escaping arguments based on the Win32 C
    argv parsing rules that 'win_command' uses but shell='cmd' or shell='powershell' can be set to escape arguments for
    those respective shells. Each value is escaped in a way to ensure the process gets the literal argument passed in
    and meta chars escaped.

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
                k = to_text(key, errors='surrogate_or_strict')
                v = quote_func(to_text(value, errors='surrogate_or_strict', nonstring='passthru'))
                new_arguments.append(u'%s=%s' % (k, v))
        else:
            new_arguments.append(quote_func(to_text(arg, errors='surrogate_or_strict', nonstring='passthru')))

    return u" ".join(new_arguments)


class FilterModule:

    def filters(self):
        return {
            'quote': quote,
        }
