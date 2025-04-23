# Copyright: (c) 2025, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import annotations

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

        result = super(ActionModule, self).run(tmp, task_vars)
        del tmp  # tmp no longer has any effect

        module_args = self._task.args
        path = module_args.get('path', None)
        remote_src = check_type_bool(module_args.get('remote_src', False))
        script = module_args.get('script', None)

        if path and not remote_src:
            if script:
                raise AnsibleActionFail("parameters are mutually exclusive: path, script")

            # Replace the script argument with the contents of the local script.
            full_path = self._find_needle('files', path)
            module_args['script'] = self._loader.get_text_file_contents(full_path)
            del module_args['path']

        module_result = self._execute_module(
            module_name='ansible.windows.win_powershell',
            module_args=module_args,
            task_vars=task_vars,
            wrap_async=self._task.async_val,
        )
        if (
            path and not remote_src and
            'invocation' in module_result and
            'module_args' in module_result['invocation']
        ):
            # Restores the invocation back to the original state.
            module_result['invocation']['module_args']['script'] = None
            module_result['invocation']['module_args']['path'] = path

        result.update(module_result)
        return result
