# Copyright: (c) 2018, Matt Davis <mdavis@ansible.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.errors import AnsibleError
from ansible.module_utils.common.text.converters import to_native
from ansible.module_utils.common.validation import check_type_str, check_type_float
from ansible.plugins.action import ActionBase
from ansible.utils.display import Display

from ..plugin_utils._reboot import reboot_host

display = Display()


def _positive_float(val):
    float_val = check_type_float(val)
    if float_val < 0:
        return 0

    else:
        return float_val


class ActionModule(ActionBase):
    TRANSFERS_FILES = False
    _VALID_ARGS = frozenset((
        'boot_time_command',
        'connect_timeout',
        'connect_timeout_sec',
        'msg',
        'post_reboot_delay',
        'post_reboot_delay_sec',
        'pre_reboot_delay',
        'pre_reboot_delay_sec',
        'reboot_timeout',
        'reboot_timeout_sec',
        'shutdown_timeout',
        'shutdown_timeout_sec',
        'test_command',
    ))

    def run(self, tmp=None, task_vars=None):
        self._supports_check_mode = True
        self._supports_async = True

        if self._play_context.check_mode:
            return {'changed': True, 'elapsed': 0, 'rebooted': True}

        if task_vars is None:
            task_vars = {}

        super(ActionModule, self).run(tmp, task_vars)

        parameters = {}
        for names, check_func in [
            (['boot_time_command'], check_type_str),
            (['connect_timeout', 'connect_timeout_sec'], _positive_float),
            (['msg'], check_type_str),
            (['post_reboot_delay', 'post_reboot_delay_sec'], _positive_float),
            (['pre_reboot_delay', 'pre_reboot_delay_sec'], _positive_float),
            (['reboot_timeout', 'reboot_timeout_sec'], _positive_float),
            (['test_command'], check_type_str),
        ]:
            for name in names:
                value = self._task.args.get(name, None)
                if value:
                    break
            else:
                value = None

            # Defaults are applied in reboot_action so skip adding to kwargs if the input wasn't set (None)
            if value is not None:
                try:
                    value = check_func(value)
                except TypeError as e:
                    raise AnsibleError("Invalid value given for '%s': %s." % (names[0], to_native(e)))

                # Setting a lower value and kill PowerShell when sending the shutdown command. Just use the defaults
                # if this is the case.
                if names[0] == 'pre_reboot_delay' and value < 2:
                    continue

                parameters[names[0]] = value

        result = reboot_host(self._task.action, self._connection, **parameters)

        return result
