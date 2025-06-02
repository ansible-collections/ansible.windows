# Copyright: (c) 2015, Michael DeHaan <michael.dehaan@gmail.com>
# Copyright: (c) 2018, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import os
import shutil
import tempfile

from jinja2.defaults import (
    BLOCK_END_STRING,
    BLOCK_START_STRING,
    COMMENT_END_STRING,
    COMMENT_START_STRING,
    VARIABLE_END_STRING,
    VARIABLE_START_STRING,
)

from ansible import constants as C
from ansible.config.manager import ensure_type
from ansible.errors import AnsibleError, AnsibleFileNotFound, AnsibleAction, AnsibleActionFail
from ansible.module_utils._text import to_bytes, to_text, to_native
from ansible.module_utils.parsing.convert_bool import boolean
from ansible.module_utils.six import string_types
from ansible.plugins.action import ActionBase

try:
    # try the 2.19+ version that can preserve user-set `ansible_managed` first
    from ansible._internal._templating._template_vars import generate_ansible_template_vars
except ImportError:
    def generate_ansible_template_vars(*args, include_ansible_managed: bool = True, **kwargs):
        from ansible import template
        # accept the extra arg at the call-site and silently discard for older core releases
        return template.generate_ansible_template_vars(*args, **kwargs)


USE_DATA_TAGGING = False
try:
    from ansible.template import trust_as_template
    AnsibleEnvironment = None

    USE_DATA_TAGGING = True
except ImportError:
    from ansible.template import AnsibleEnvironment  # type: ignore[no-redef]


class ActionModule(ActionBase):

    TRANSFERS_FILES = True

    def run(self, tmp=None, task_vars=None):
        ''' handler for template operations '''

        if task_vars is None:
            task_vars = dict()

        result = super(ActionModule, self).run(tmp, task_vars)
        del tmp  # tmp no longer has any effect

        # Options type validation
        # stings
        for s_type in ('src', 'dest', 'state', 'newline_sequence', 'variable_start_string', 'variable_end_string', 'block_start_string',
                       'block_end_string', 'comment_start_string', 'comment_end_string'):
            if s_type in self._task.args:
                value = ensure_type(self._task.args[s_type], 'string')
                if value is not None and not isinstance(value, string_types):
                    raise AnsibleActionFail("%s is expected to be a string, but got %s instead" % (s_type, type(value)))
                self._task.args[s_type] = value

        # booleans
        try:
            trim_blocks = boolean(self._task.args.get('trim_blocks', True), strict=False)
            lstrip_blocks = boolean(self._task.args.get('lstrip_blocks', False), strict=False)
        except TypeError as e:
            raise AnsibleActionFail(to_native(e))

        # assign to local vars for ease of use
        source = self._task.args.get('src', None)
        dest = self._task.args.get('dest', None)
        state = self._task.args.get('state', None)
        newline_sequence = self._task.args.get('newline_sequence', "\r\n")
        variable_start_string = self._task.args.get('variable_start_string', VARIABLE_START_STRING)
        variable_end_string = self._task.args.get('variable_end_string', VARIABLE_END_STRING)
        block_start_string = self._task.args.get('block_start_string', BLOCK_START_STRING)
        block_end_string = self._task.args.get('block_end_string', BLOCK_END_STRING)
        comment_start_string = self._task.args.get('comment_start_string', COMMENT_START_STRING)
        comment_end_string = self._task.args.get('comment_end_string', COMMENT_END_STRING)
        output_encoding = self._task.args.get('output_encoding', 'utf-8') or 'utf-8'

        # Option `lstrip_blocks' was added in Jinja2 version 2.7.
        if lstrip_blocks:
            try:
                import jinja2.defaults
            except ImportError:
                raise AnsibleError('Unable to import Jinja2 defaults for determining Jinja2 features.')

            try:
                jinja2.defaults.LSTRIP_BLOCKS
            except AttributeError:
                raise AnsibleError("Option `lstrip_blocks' is only available in Jinja2 versions >=2.7")

        wrong_sequences = ["\\n", "\\r", "\\r\\n"]
        allowed_sequences = ["\n", "\r", "\r\n"]

        # We need to convert unescaped sequences to proper escaped sequences for Jinja2
        if newline_sequence in wrong_sequences:
            newline_sequence = allowed_sequences[wrong_sequences.index(newline_sequence)]

        try:
            # logical validation
            if state is not None:
                raise AnsibleActionFail("'state' cannot be specified on a template")
            elif source is None or dest is None:
                raise AnsibleActionFail("src and dest are required")
            elif newline_sequence not in allowed_sequences:
                raise AnsibleActionFail("newline_sequence needs to be one of: \n, \r or \r\n")
            else:
                try:
                    source = self._find_needle('templates', source)
                except AnsibleError as e:
                    raise AnsibleActionFail(to_text(e))

            # Get vault decrypted tmp file
            try:
                tmp_source = self._loader.get_real_file(source)
            except AnsibleFileNotFound as e:
                raise AnsibleActionFail("could not find src=%s, %s" % (source, to_text(e)))
            b_tmp_source = to_bytes(tmp_source, errors='surrogate_or_strict')

            # template the source data locally & get ready to transfer
            try:
                if USE_DATA_TAGGING:
                    template_data = trust_as_template(self._loader.get_text_file_contents(source))

                else:
                    with open(b_tmp_source, 'rb') as f:
                        try:
                            template_data = to_text(f.read(), errors='surrogate_or_strict')
                        except UnicodeError:
                            raise AnsibleActionFail("Template source files must be utf-8 encoded")

                # set jinja2 internal search path for includes
                searchpath = task_vars.get('ansible_search_path', [])
                searchpath.extend([self._loader._basedir, os.path.dirname(source)])

                # We want to search into the 'templates' subdir of each search path in
                # addition to our original search paths.
                newsearchpath = []
                for p in searchpath:
                    newsearchpath.append(os.path.join(p, 'templates'))
                    newsearchpath.append(p)
                searchpath = newsearchpath

                # add ansible 'template' vars
                temp_vars = task_vars.copy()
                temp_vars.update(
                    generate_ansible_template_vars(
                        self._task.args.get('src', None),
                        fullpath=source,
                        dest_path=dest,
                        include_ansible_managed='ansible_managed' not in temp_vars  # do not clobber ansible_managed when set by the user
                    )
                )

                overrides = dict(
                    block_start_string=block_start_string,
                    block_end_string=block_end_string,
                    variable_start_string=variable_start_string,
                    variable_end_string=variable_end_string,
                    comment_start_string=comment_start_string,
                    comment_end_string=comment_end_string,
                    trim_blocks=trim_blocks,
                    lstrip_blocks=lstrip_blocks
                )

                if USE_DATA_TAGGING:
                    overrides['newline_sequence'] = newline_sequence
                    data_templar = self._templar.copy_with_new_env(searchpath=searchpath, available_variables=temp_vars)
                    resultant = data_templar.template(
                        template_data,
                        preserve_trailing_newlines=True,
                        escape_backslashes=False,
                        overrides=overrides,
                    )

                else:
                    # force templar to use AnsibleEnvironment to prevent issues with native types
                    # https://github.com/ansible/ansible/issues/46169
                    data_templar = self._templar.copy_with_new_env(
                        environment_class=AnsibleEnvironment,
                        searchpath=searchpath,
                        newline_sequence=newline_sequence,
                        available_variables=temp_vars,
                    )

                    resultant = data_templar.do_template(
                        template_data,
                        preserve_trailing_newlines=True,
                        escape_backslashes=False,
                        overrides=overrides,
                    )
            except AnsibleAction:
                raise
            except Exception as e:
                raise AnsibleActionFail("%s: %s" % (type(e).__name__, to_text(e)))
            finally:
                self._loader.cleanup_tmp_file(b_tmp_source)

            new_task = self._task.copy()

            # remove 'template only' options:
            for remove in ('newline_sequence', 'block_start_string', 'block_end_string', 'variable_start_string', 'variable_end_string',
                           'comment_start_string', 'comment_end_string', 'trim_blocks', 'lstrip_blocks', 'output_encoding'):
                new_task.args.pop(remove, None)

            local_tempdir = tempfile.mkdtemp(dir=C.DEFAULT_LOCAL_TMP)

            try:
                result_file = os.path.join(local_tempdir, os.path.basename(source))
                with open(to_bytes(result_file, errors='surrogate_or_strict'), 'wb') as f:
                    f.write(to_bytes(resultant, encoding=output_encoding, errors='surrogate_or_strict'))

                new_task.args.update(
                    dict(
                        src=result_file,
                        dest=dest,
                    ),
                )
                copy_action = self._shared_loader_obj.action_loader.get('ansible.windows.win_copy',
                                                                        task=new_task,
                                                                        connection=self._connection,
                                                                        play_context=self._play_context,
                                                                        loader=self._loader,
                                                                        templar=self._templar,
                                                                        shared_loader_obj=self._shared_loader_obj)
                result.update(copy_action.run(task_vars=task_vars))
            finally:
                shutil.rmtree(to_bytes(local_tempdir, errors='surrogate_or_strict'))

        except AnsibleAction as e:
            result.update(e.result)
        finally:
            self._remove_tmp_path(self._connection._shell.tmpdir)

        return result
