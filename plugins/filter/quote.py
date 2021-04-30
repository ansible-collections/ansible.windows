# Copyright (c) 2020 Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.errors import AnsibleFilterError
from ansible.module_utils.common.collections import is_sequence
from ansible.module_utils.common.text.converters import to_text

from ..plugin_utils._quote import (
    quote_c,
    quote_cmd,
    quote_pwsh,
)


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
        quote_func = quote_c
    elif shell == 'cmd':
        quote_func = quote_cmd
    elif shell == 'powershell':
        quote_func = quote_pwsh
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
