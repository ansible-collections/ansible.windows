# Copyright (c) 2026 Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import annotations

import os

from ansible.errors import AnsibleActionFail
from ansible.module_utils.common.validation import check_type_bool
from ansible.plugins.action import ActionBase


class ActionModule(ActionBase):

    def run(
        self,
        tmp: str | None = None,
        task_vars: dict[str, object] | None = None,
    ) -> dict[str, object]:
        self._supports_async = True
        self._supports_check_mode = True

        if task_vars is None:
            task_vars = dict()

        super(ActionModule, self).run(tmp, task_vars)
        del tmp  # tmp no longer has any effect

        module_args = self._task.args
        config_file = module_args.get('config_file', None)
        remote_config_file = check_type_bool(module_args.get('remote_config_file', False))

        tmpdir = self._connection._shell.tmpdir
        remove_tmpdir = False
        try:

            if config_file and not remote_config_file:
                if module_args.get('config', None):
                    raise AnsibleActionFail("parameters are mutually exclusive: config, config_file")

                if self._task.async_val:
                    raise AnsibleActionFail("async operations are not supported with local config_file")

                if not tmpdir:
                    tmpdir = self._make_tmp_path()
                    remove_tmpdir = True

                full_path = self._find_needle('files', config_file)
                tmp_src = self._connection._shell.join_path(
                    tmpdir,
                    os.path.basename(full_path),
                )
                module_args['config_file'] = tmp_src
                module_args['remote_config_file'] = True

                self._transfer_file(full_path, tmp_src)

            module_result = self._execute_module(
                module_name='ansible.windows.dsc3',
                module_args=module_args,
                task_vars=task_vars,
                wrap_async=self._task.async_val,
            )
            if (
                config_file and not remote_config_file and
                'invocation' in module_result and
                'module_args' in module_result['invocation']
            ):
                # Restores the invocation back to the original state.
                module_result['invocation']['module_args']['config_file'] = config_file
                module_result['invocation']['module_args']['remote_config_file'] = remote_config_file

            return module_result

        finally:
            if tmpdir and remove_tmpdir:
                self._remove_tmp_path(tmpdir)
