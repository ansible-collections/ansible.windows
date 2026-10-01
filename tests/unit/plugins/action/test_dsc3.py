# -*- coding: utf-8 -*-
# Copyright: Contributors to the Ansible project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

import ntpath
from unittest.mock import MagicMock

import pytest

from ansible.errors import AnsibleActionFail
from ansible.playbook.task import Task
from ansible.plugins.action import ActionBase
from ansible_collections.ansible.windows.plugins.action import dsc3


def dsc3_init(task_args, async_val=0, check_mode=False, tmpdir='shell_tmpdir'):
    task = MagicMock(Task)
    task.args = task_args
    task.check_mode = check_mode
    task.async_val = async_val

    connection = MagicMock()
    connection._shell.tmpdir = tmpdir
    connection._shell.join_path = ntpath.join

    plugin = dsc3.ActionModule(task, connection, MagicMock(), loader=None, templar=None, shared_loader_obj=None)
    return plugin


def mock_transfer(monkeypatch, plugin, module_result, controller_path='/controller/files/test.config.dsc.yml'):
    find_needle = MagicMock(return_value=controller_path)
    monkeypatch.setattr(plugin, '_find_needle', find_needle)

    transfer_file = MagicMock()
    monkeypatch.setattr(plugin, '_transfer_file', transfer_file)

    execute_module = MagicMock(return_value=module_result)
    monkeypatch.setattr(plugin, '_execute_module', execute_module)

    return find_needle, transfer_file, execute_module


def test_config_and_local_config_file_are_exclusive():
    plugin = dsc3_init({'config': {'resources': []}, 'config_file': 'test.config.dsc.yml'})

    with pytest.raises(AnsibleActionFail, match='parameters are mutually exclusive: config, config_file'):
        plugin.run()


def test_directives_and_local_config_file_are_exclusive():
    plugin = dsc3_init({'directives': {'securityContext': 'elevated'}, 'config_file': 'test.config.dsc.yml'})

    with pytest.raises(AnsibleActionFail, match='parameters are mutually exclusive: directives, config_file'):
        plugin.run()


def test_async_with_local_config_file_fails():
    plugin = dsc3_init({'config_file': 'test.config.dsc.yml'}, async_val=60)

    with pytest.raises(AnsibleActionFail, match='async operations are not supported with local config_file'):
        plugin.run()


def test_local_config_file_is_transferred(monkeypatch):
    plugin = dsc3_init({'config_file': 'config_docs/test.config.dsc.yml', 'trace_level': 'info'})
    find_needle, transfer_file, execute_module = mock_transfer(monkeypatch, plugin, {
        'changed': False,
        'rc': 0,
        'invocation': {
            'module_args': {
                'config_file': 'shell_tmpdir\\test.config.dsc.yml',
                'remote_config_file': True,
                'trace_level': 'info',
            },
        },
    })

    actual = plugin.run()

    find_needle.assert_called_once_with('files', 'config_docs/test.config.dsc.yml')
    transfer_file.assert_called_once_with('/controller/files/test.config.dsc.yml', 'shell_tmpdir\\test.config.dsc.yml')

    assert execute_module.call_count == 1
    assert execute_module.call_args[1]['module_name'] == 'ansible.windows.dsc3'
    assert execute_module.call_args[1]['module_args'] == {
        'config_file': 'shell_tmpdir\\test.config.dsc.yml',
        'remote_config_file': True,
        'trace_level': 'info',
    }
    assert execute_module.call_args[1]['task_vars'] == {}
    assert execute_module.call_args[1]['wrap_async'] == 0

    assert actual['changed'] is False
    assert actual['rc'] == 0
    # The invocation is restored to what the task specified.
    assert actual['invocation']['module_args']['config_file'] == 'config_docs/test.config.dsc.yml'
    assert actual['invocation']['module_args']['remote_config_file'] is False
    assert actual['invocation']['module_args']['trace_level'] == 'info'


def test_remote_config_file_defaults_to_false(monkeypatch):
    plugin = dsc3_init({'config_file': 'test.config.dsc.yml'})
    find_needle, transfer_file, execute_module = mock_transfer(monkeypatch, plugin, {'changed': False})

    plugin.run()

    transfer_file.assert_called_once()
    assert execute_module.call_args[1]['module_args']['remote_config_file'] is True


@pytest.mark.parametrize('remote_config_file', [True, 'yes'])
def test_remote_config_file_is_not_transferred(monkeypatch, remote_config_file):
    task_args = {'config_file': 'C:\\dsc\\test.config.dsc.yml', 'remote_config_file': remote_config_file}
    plugin = dsc3_init(task_args, async_val=60)
    find_needle, transfer_file, execute_module = mock_transfer(monkeypatch, plugin, {
        'changed': True,
        'invocation': {
            'module_args': {
                'config_file': 'C:\\dsc\\test.config.dsc.yml',
                'remote_config_file': True,
            },
        },
    })

    actual = plugin.run()

    find_needle.assert_not_called()
    transfer_file.assert_not_called()
    assert execute_module.call_args[1]['module_args'] == task_args
    assert execute_module.call_args[1]['wrap_async'] == 60
    assert actual['changed'] is True
    assert actual['invocation']['module_args']['config_file'] == 'C:\\dsc\\test.config.dsc.yml'
    assert actual['invocation']['module_args']['remote_config_file'] is True


def test_inline_config_is_passed_through(monkeypatch):
    task_args = {
        'config': {'resources': [{'name': 'echo', 'type': 'Microsoft.DSC.Debug/Echo', 'properties': {'output': 'hi'}}]},
        'directives': {'securityContext': 'elevated'},
        'what_if': True,
    }
    plugin = dsc3_init(task_args, check_mode=True)
    find_needle, transfer_file, execute_module = mock_transfer(monkeypatch, plugin, {'changed': False})

    plugin.run()

    find_needle.assert_not_called()
    transfer_file.assert_not_called()
    assert execute_module.call_args[1]['module_args'] == task_args


def test_result_includes_base_action_result(monkeypatch):
    plugin = dsc3_init({'config': {'resources': []}})
    monkeypatch.setattr(ActionBase, 'run', lambda self, tmp=None, task_vars=None: {'_base_key': 'base'})
    execute_module = MagicMock(return_value={'changed': False, 'rc': 0})
    monkeypatch.setattr(plugin, '_execute_module', execute_module)

    actual = plugin.run()

    assert actual == {'_base_key': 'base', 'changed': False, 'rc': 0}


def test_tmpdir_is_created_and_removed(monkeypatch):
    plugin = dsc3_init({'config_file': 'test.config.dsc.yml'}, tmpdir=None)
    make_tmp_path = MagicMock(return_value='new_tmpdir')
    monkeypatch.setattr(plugin, '_make_tmp_path', make_tmp_path)
    remove_tmp_path = MagicMock()
    monkeypatch.setattr(plugin, '_remove_tmp_path', remove_tmp_path)
    find_needle, transfer_file, execute_module = mock_transfer(monkeypatch, plugin, {'changed': False})

    plugin.run()

    make_tmp_path.assert_called_once_with()
    transfer_file.assert_called_once_with('/controller/files/test.config.dsc.yml', 'new_tmpdir\\test.config.dsc.yml')
    assert execute_module.call_args[1]['module_args']['config_file'] == 'new_tmpdir\\test.config.dsc.yml'
    remove_tmp_path.assert_called_once_with('new_tmpdir')


def test_tmpdir_is_removed_on_failure(monkeypatch):
    plugin = dsc3_init({'config_file': 'test.config.dsc.yml'}, tmpdir=None)
    monkeypatch.setattr(plugin, '_make_tmp_path', MagicMock(return_value='new_tmpdir'))
    remove_tmp_path = MagicMock()
    monkeypatch.setattr(plugin, '_remove_tmp_path', remove_tmp_path)
    find_needle, transfer_file, execute_module = mock_transfer(monkeypatch, plugin, {})
    execute_module.side_effect = Exception('module failed')

    with pytest.raises(Exception, match='module failed'):
        plugin.run()

    remove_tmp_path.assert_called_once_with('new_tmpdir')


def test_existing_tmpdir_is_kept(monkeypatch):
    plugin = dsc3_init({'config_file': 'test.config.dsc.yml'})
    make_tmp_path = MagicMock()
    monkeypatch.setattr(plugin, '_make_tmp_path', make_tmp_path)
    remove_tmp_path = MagicMock()
    monkeypatch.setattr(plugin, '_remove_tmp_path', remove_tmp_path)
    mock_transfer(monkeypatch, plugin, {'changed': False})

    plugin.run()

    make_tmp_path.assert_not_called()
    remove_tmp_path.assert_not_called()
