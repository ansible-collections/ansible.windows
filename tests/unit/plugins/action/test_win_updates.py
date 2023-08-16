# -*- coding: utf-8 -*-
# (c) 2018, Jordan Borean <jborean@redhat.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# Make coding more python3-ish
from __future__ import absolute_import, division, print_function

__metaclass__ = type

import ntpath
import json
import os
import re
from unittest.mock import MagicMock

from ansible.errors import AnsibleConnectionFailure
from ansible.playbook.task import Task
from ansible_collections.ansible.windows.plugins.action import win_updates

# Some raw info on the updates in the test expectations
UPDATE_INFO = {
    '1abb2377-20ef-43ff-aabc-0de4711ab205': {
        'title': '2020-10 Security Update for Adobe Flash Player for Windows Server 2019 for x64-based Systems (KB4580325)',
        'kb': '4580325',
        'categories': ['Security Updates', 'Windows Server 2019'],
    },
    '89e11227-761b-4396-bf37-37a2b641fa84': {
        'title': '2021-01 Update for Windows Server 2019 for x64-based Systems (KB4589208)',
        'kb': '4589208',
        'categories': ['Updates', 'Windows Server 2019'],
    },
    '74819184-828b-4f97-bb4b-089a0c58e366': {
        'title': '2021-05 Cumulative Update for Windows Server 2019 (1809) for x64-based Systems (KB5003171)',
        'kb': '5003171',
        'categories': ['Security Updates'],
    },
    '9e94ae7a-f0f4-4ea1-b590-9f1388ee6126': {
        'title': '2021-05 Cumulative Update Preview for .NET Framework 3.5, 4.7.2 and 4.8 for Windows Server 2019 for x64 (KB5003396)',
        'kb': '5003396',
        'categories': ['Updates', 'Windows Server 2019'],
    },
    'a89e56f1-2002-40c6-a9af-3cf8be801df7': {
        'title': 'Security Intelligence Update for Microsoft Defender Antivirus - KB2267602 (Version 1.339.1923.0)',
        'kb': '2267602',
        'categories': ['Definition Updates', 'Microsoft Defender Antivirus'],
    },
    '5dae3a9d-4f41-445c-83f6-15fb4534e936': {
        'title': 'Security Intelligence Update for Microsoft Defender Antivirus - KB2267602 (Version 1.341.8.0)',
        'kb': '2267602',
        'categories': ['Definition Updates', 'Microsoft Defender Antivirus'],
    },
    '4326d7df-c256-4cca-99f7-c02a04443ec1': {
        'title': 'Security Intelligence Update for Microsoft Defender Antivirus - KB2267602 (Version 1.341.70.0)',
        'kb': '2267602',
        'categories': ['Definition Updates', 'Microsoft Defender Antivirus'],
    },
    '81929363-530d-4ccc-b9c7-8a1b89b20fe5': {
        'title': 'Security Intelligence Update for Microsoft Defender Antivirus - KB2267602 (Version 1.341.72.0)',
        'kb': '2267602',
        'categories': ['Definition Updates', 'Microsoft Defender Antivirus'],
    },
    '33a64099-ba99-4e7f-a2d7-cf7d7fc4029f': {
        'title': 'Security Update for Windows Server 2019 for x64-based Systems (KB4535680)',
        'kb': '4535680',
        'categories': ['Security Updates', 'Windows Server 2019'],
    },

    'f26a0046-1e1a-4305-8743-19c92c3095a5': {
        'title': 'Update for Removal of Adobe Flash Player for Windows Server 2019 for x64-based systems (KB4577586)',
        'kb': '4577586',
        'categories': ['Updates', 'Windows Server 2019'],
    },
    'd4919b6d-584d-436f-b877-dc3fc352a774': {
        'title': 'Windows Malicious Software Removal Tool x64 - v5.89 (KB890830)',
        'kb': '890830',
        'categories': ['Update Rollups', 'Windows Server 2016', 'Windows Server 2019'],
    },
}


class UpdateModuleMock:
    """Mocks the execute_module calls for win_updates"""

    def __init__(
        self,
        test_name,
        module_arg_return,
    ):
        self._path = os.path.abspath(os.path.join(__file__, '..', '..', '..', 'test_data', 'win_updates', test_name))
        self._reader = self._read_gen()
        self._module_arg_return = module_arg_return
        self._is_start = True

    def __iter__(self):
        return self

    def __next__(self):
        return next(self._reader)

    def _read_gen(self):
        output = []
        with open(self._path, mode='rb') as fd:
            for line in fd:
                if self._is_start:
                    yield {
                        'changed': False,
                        'invocation': {'module_args': self._module_arg_return},
                        'cancel_options': {
                            'cancel_id': 'cancel_id',
                            'task_pid': 666,
                        },
                        'poll_options': {
                            'pipe_name': 'pipe_name',
                        },
                    }
                    self._is_start = False

                line = line.strip()

                if line == b'FAILURE':
                    yield AnsibleConnectionFailure("connection error")
                    continue

                if not line:
                    if not output:
                        continue

                    result = {
                        'changed': False,
                        'output': output,
                    }
                    output = []
                    yield result
                    continue

                parsed_line = json.loads(line)
                if 'task' in parsed_line:
                    output.append(parsed_line)

                else:
                    self._is_start = True
                    yield parsed_line


def mock_connection_init(test_id, default_rc=0, default_stderr=b'', newline_separator=b'\n'):
    progress_helper = UpdateModuleMock(
        test_id,
        default_rc=default_rc,
        default_stderr=default_stderr,
        newline_separator=newline_separator,
    )
    mock_connection = MagicMock()
    mock_connection._shell.tmpdir = 'shell_tmpdir'
    mock_connection._shell.join_path = ntpath.join
    mock_connection.exec_command = progress_helper.poll

    return mock_connection


def win_updates_init(task_args, async_val=0, check_mode=False, connection=None):
    task = MagicMock(Task)
    task.args = task_args
    task.check_mode = check_mode
    task.async_val = async_val

    connection = connection or MagicMock()

    # Used for older Ansible versions
    play_context = MagicMock()
    play_context.check_mode = check_mode

    plugin = win_updates.ActionModule(task, connection, play_context, loader=None, templar=None,
                                      shared_loader_obj=None)
    return plugin


def run_action(monkeypatch, test_id, task_vars, check_mode=False, poll_rc=0, poll_stderr=b'', poll_newline_separator=b'\n'):
    module_arg_return = task_vars.copy()

    plugin = win_updates_init(
        task_vars,
        check_mode=check_mode,
        connection=MagicMock(),
    )
    execute_module = MagicMock()
    execute_module.side_effect = UpdateModuleMock(test_id, module_arg_return).__iter__()
    monkeypatch.setattr(plugin, '_execute_module', execute_module)

    return plugin.run()


def test_run_with_async(monkeypatch):
    plugin = win_updates_init({}, async_val=1)
    execute_module = MagicMock()
    execute_module.return_value = {'invocation': {'module_args': {'accept_list': [], '_operation_options': {'wait': True}}}, 'updates': ['test']}
    monkeypatch.setattr(plugin, '_execute_module', execute_module)

    # Running with async should just call the module and return back the result - sans the _wait invocation arg
    actual = plugin.run()
    assert actual == {'invocation': {'module_args': {'accept_list': []}}, 'updates': ['test']}

    assert execute_module.call_count == 1
    assert execute_module.call_args[1]['module_name'] == 'ansible.windows.win_updates'
    assert execute_module.call_args[1]['module_args']['_operation_options'] == {'wait': True}
    assert execute_module.call_args[1]['task_vars'] == {}


def test_failed_to_start_module(monkeypatch):
    plugin = win_updates_init({},)
    execute_module = MagicMock()
    execute_module.return_value = {
        'failed': True,
        'msg': 'Failed to start module details',
    }
    monkeypatch.setattr(plugin, '_execute_module', execute_module)
    monkeypatch.setattr(plugin, '_transfer_file', MagicMock())

    actual = plugin.run()
    assert actual['failed']
    assert actual['msg'] == 'Failed to start module details'
    assert 'exception' in actual
    assert actual['found_update_count'] == 0
    assert actual['failed_update_count'] == 0
    assert actual['installed_update_count'] == 0
    assert actual['filtered_updates'] == {}
    assert actual['updates'] == {}


def test_failure_with_poll_script(monkeypatch):
    actual = run_action(monkeypatch, 'fail_poll_script.txt', {})

    assert actual['failed']
    assert actual['msg'] == 'Error message during polling'
    assert 'exception' in actual
    assert actual['found_update_count'] == 0
    assert actual['failed_update_count'] == 0
    assert actual['installed_update_count'] == 0
    assert actual['filtered_updates'] == {}
    assert actual['updates'] == {}


def test_failure_with_poll_script_critical_stdout(monkeypatch):
    actual = run_action(monkeypatch, 'fail_poll_script_critical_stdout.txt', {})

    assert actual['rc'] == 1
    assert actual['stdout'] == "stdout data"
    assert actual['stderr'] == "stderr data"
    assert actual['failed']
    assert actual['msg'] == "Failure while running win_updates poll"
    assert 'exception' in actual
    assert actual['found_update_count'] == 0
    assert actual['failed_update_count'] == 0
    assert actual['installed_update_count'] == 0
    assert actual['filtered_updates'] == {}
    assert actual['updates'] == {}


def test_install_with_multiple_reboots(monkeypatch):
    # Was tested against a Server 2019 host with the parameters set below.
    reboot_mock = MagicMock()
    reboot_mock.return_value = {'failed': False}
    monkeypatch.setattr(win_updates, 'reboot_host', reboot_mock)

    actual = run_action(monkeypatch, 'full_run.txt', {
        'category_names': '*',
        'state': 'installed',
        'reboot': 'yes',
    })

    assert reboot_mock.call_count == 2
    assert actual['changed']
    assert not actual['reboot_required']
    assert actual['rebooted'] is True
    assert actual['found_update_count'] == 8
    assert actual['failed_update_count'] == 0
    assert actual['installed_update_count'] == 8
    assert actual['filtered_updates'] == {}
    assert len(actual['updates']) == 8

    for u_id, u in actual['updates'].items():
        assert u['id'] == u_id
        assert u['id'] in UPDATE_INFO
        u_info = UPDATE_INFO[u['id']]
        assert u['title'] == u_info['title']
        assert u['kb'] == [u_info['kb']]
        assert u['categories'] == u_info['categories']
        assert u['downloaded']
        assert u['installed']


def test_install_without_reboot(monkeypatch):
    reboot_mock = MagicMock()
    reboot_mock.return_value = {'failed': False}
    monkeypatch.setattr(win_updates, 'reboot_host', reboot_mock)

    actual = run_action(monkeypatch, 'install_no_reboot.txt', {
        'reject_list': ['KB2267602'],
    })

    assert reboot_mock.call_count == 0
    assert actual['changed']
    assert actual['reboot_required']
    assert actual['rebooted'] is False
    assert actual['found_update_count'] == 3
    assert actual['failed_update_count'] == 0
    assert actual['installed_update_count'] == 3

    assert len(actual['filtered_updates']) == 3
    for u_id, u in actual['filtered_updates'].items():
        assert u['id'] == u_id
        assert u['id'] in UPDATE_INFO
        u_info = UPDATE_INFO[u['id']]
        assert u['title'] == u_info['title']
        assert u['kb'] == [u_info['kb']]
        assert u['categories'] == u_info['categories']
        assert not u['downloaded']
        assert not u['installed']

        if u_info['kb'] == '2267602':
            assert u['filtered_reason'] == 'blacklist'
            assert u['filtered_reasons'] == ['reject_list', 'category_names']
        else:
            assert u['filtered_reason'] == 'category_names'
            assert u['filtered_reasons'] == ['category_names']

    assert len(actual['updates']) == 3
    for u_id, u in actual['updates'].items():
        assert u['id'] == u_id
        assert u['id'] in UPDATE_INFO
        u_info = UPDATE_INFO[u['id']]
        assert u['title'] == u_info['title']
        assert u['kb'] == [u_info['kb']]
        assert u['categories'] == u_info['categories']
        assert u['downloaded']
        assert u['installed']


def test_install_with_initial_reboot_required(monkeypatch):
    reboot_mock = MagicMock()
    reboot_mock.return_value = {'failed': False}
    monkeypatch.setattr(win_updates, 'reboot_host', reboot_mock)

    actual = run_action(monkeypatch, 'install_reboot_req.txt', {
        'category_names': ['*'],
        'reboot': True,
    })

    assert reboot_mock.call_count == 2
    assert actual['changed']
    assert not actual['reboot_required']
    assert actual['rebooted'] is True
    assert actual['found_update_count'] == 6
    assert actual['failed_update_count'] == 0
    assert actual['installed_update_count'] == 5  # 1 found update was already installed at the beginning
    assert actual['filtered_updates'] == {}

    assert len(actual['updates']) == 6
    for u_id, u in actual['updates'].items():
        assert u['id'] == u_id
        assert u['id'] in UPDATE_INFO
        u_info = UPDATE_INFO[u['id']]
        assert u['title'] == u_info['title']
        assert u['kb'] == [u_info['kb']]
        assert u['categories'] == u_info['categories']

        if u_info['kb'] == '5003171':
            assert not u['downloaded']
            assert not u['installed']
        else:
            assert u['downloaded']
            assert u['installed']


def test_install_with_reboot_fail(monkeypatch):
    reboot_mock = MagicMock()
    reboot_mock.return_value = {'failed': True, 'msg': 'Failure msg from reboot'}
    monkeypatch.setattr(win_updates, 'reboot_host', reboot_mock)

    actual = run_action(monkeypatch, 'install_reboot_req_failure.txt', {
        'category_names': ['*'],
        'reboot': True,
    })

    assert reboot_mock.call_count == 1
    assert not actual['changed']
    assert actual['reboot_required']
    assert actual['rebooted'] is True
    assert actual['failed']
    assert actual['msg'] == 'Failed to reboot host: Failure msg from reboot'
    assert actual['found_update_count'] == 6
    assert actual['failed_update_count'] == 0
    assert actual['installed_update_count'] == 0
    assert actual['filtered_updates'] == {}

    assert len(actual['updates']) == 6
    for u_id, u in actual['updates'].items():
        assert u['id'] == u_id
        assert u['id'] in UPDATE_INFO
        u_info = UPDATE_INFO[u['id']]
        assert u['title'] == u_info['title']
        assert u['kb'] == [u_info['kb']]
        assert u['categories'] == u_info['categories']
        assert not u['downloaded']
        assert not u['installed']


def test_install_with_reboot_check_mode(monkeypatch):
    reboot_mock = MagicMock()
    reboot_mock.return_value = {'failed': True, 'msg': 'Failure msg from reboot'}
    monkeypatch.setattr(win_updates, 'reboot_host', reboot_mock)

    actual = run_action(monkeypatch, 'install_reboot_req_failure.txt', {
        'category_names': ['*'],
        'reboot': True,
    }, check_mode=True)

    assert reboot_mock.call_count == 0
    assert actual['changed']
    assert not actual['reboot_required']
    assert actual['rebooted'] is True
    assert 'failed' not in actual
    assert 'msg' not in actual
    assert actual['found_update_count'] == 6
    assert actual['failed_update_count'] == 0
    assert actual['installed_update_count'] == 0
    assert actual['filtered_updates'] == {}

    assert len(actual['updates']) == 6
    for u_id, u in actual['updates'].items():
        assert u['id'] == u_id
        assert u['id'] in UPDATE_INFO
        u_info = UPDATE_INFO[u['id']]
        assert u['title'] == u_info['title']
        assert u['kb'] == [u_info['kb']]
        assert u['categories'] == u_info['categories']
        assert not u['downloaded']
        assert not u['installed']


def test_install_reboot_with_two_failures(monkeypatch):
    reboot_mock = MagicMock()
    reboot_mock.return_value = {'failed': False}
    monkeypatch.setattr(win_updates, 'reboot_host', reboot_mock)

    actual = run_action(monkeypatch, 'install_reboot_two_failures.txt', {
        'category_names': ['*'],
        'reboot': True,
    })

    assert reboot_mock.call_count == 1
    assert actual['changed']
    assert not actual['reboot_required']
    assert actual['rebooted'] is True
    assert actual['failed']
    assert actual['msg'] == 'Searching for updates: Exception from HRESULT: 0x80240032 - The search criteria string was invalid ' \
        '(WU_E_INVALID_CRITERIA 0x80240032)'
    assert 'exception' in actual
    assert actual['found_update_count'] == 0
    assert actual['failed_update_count'] == 0
    assert actual['installed_update_count'] == 0
    assert actual['filtered_updates'] == {}
    assert actual['updates'] == {}


def test_install_with_initial_reboot_required_but_no_reboot(monkeypatch):
    reboot_mock = MagicMock()
    reboot_mock.return_value = {'failed': False}
    monkeypatch.setattr(win_updates, 'reboot_host', reboot_mock)

    actual = run_action(monkeypatch, 'install_reboot_req_no_reboot.txt', {
        'category_names': ['*'],
    })

    assert reboot_mock.call_count == 0
    assert not actual['changed']
    assert actual['failed']
    assert actual['msg'] == 'A reboot is required before more updates can be installed'
    assert actual['reboot_required']
    assert actual['rebooted'] is False
    assert actual['found_update_count'] == 5
    assert actual['failed_update_count'] == 0
    assert actual['installed_update_count'] == 0
    assert actual['filtered_updates'] == {}

    assert len(actual['updates']) == 5
    for u_id, u in actual['updates'].items():
        assert u['id'] == u_id
        assert u['id'] in UPDATE_INFO
        u_info = UPDATE_INFO[u['id']]
        assert u['title'] == u_info['title']
        assert u['kb'] == [u_info['kb']]
        assert u['categories'] == u_info['categories']
        assert not u['downloaded']
        assert not u['installed']


def test_install_non_integer_kb_values(monkeypatch):
    # custom_kb.txt contains 3 updates and 3 filtered updates an empty kb, integer kb, and string kb value.
    actual = run_action(monkeypatch, 'custom_kb.txt', {
        'reject_list': ['KB2267602'],
    })

    assert len(actual['filtered_updates']) == 3
    for u_id, u in actual['filtered_updates'].items():
        assert u['id'] == u_id
        if u['id'] == 'f26a0046-1e1a-4305-8743-19c92c3095a5':
            assert u['kb'] == ['']

        elif u['id'] == '9e94ae7a-f0f4-4ea1-b590-9f1388ee6126':
            assert u['kb'] == ['5003396']

        elif u['id'] == '4326d7df-c256-4cca-99f7-c02a04443ec1':
            assert u['kb'] == ['OTHER']

        else:
            assert False, ("Unknown update in filtered updates %s" % u['id'])

    assert len(actual['updates']) == 3
    for u_id, u in actual['updates'].items():
        assert u['id'] == u_id
        if u['id'] == '74819184-828b-4f97-bb4b-089a0c58e366':
            assert u['kb'] == ['']

        elif u['id'] == 'd4919b6d-584d-436f-b877-dc3fc352a774':
            assert u['kb'] == ['890830']

        elif u['id'] == '1abb2377-20ef-43ff-aabc-0de4711ab205':
            assert u['kb'] == ['NET4800']

        else:
            assert False, ("Unknown update in filtered updates %s" % u['id'])


def test_fail_install(monkeypatch):
    reboot_mock = MagicMock()
    reboot_mock.return_value = {'failed': False}
    monkeypatch.setattr(win_updates, 'reboot_host', reboot_mock)

    actual = run_action(monkeypatch, 'failed_install.txt', {
        'category_names': ['SecurityUpdates', 'DefinitionUpdates'],
        'accept_list': ['KB5003171', 'KB2267602'],
    })

    assert reboot_mock.call_count == 0
    assert actual['changed']
    assert actual['failed']
    assert actual['reboot_required']
    assert actual['rebooted'] is False
    assert actual['found_update_count'] == 2
    assert actual['failed_update_count'] == 1
    assert actual['installed_update_count'] == 1

    assert len(actual['filtered_updates']) == 4
    for u_id, u in actual['filtered_updates'].items():
        assert u['id'] == u_id
        assert u['id'] in UPDATE_INFO
        u_info = UPDATE_INFO[u['id']]
        assert u['title'] == u_info['title']
        assert u['kb'] == [u_info['kb']]
        assert u['categories'] == u_info['categories']
        assert not u['downloaded']
        assert not u['installed']

        assert u['filtered_reason'] == 'whitelist'
        if u_info['kb'] == '4580325':
            assert u['filtered_reasons'] == ['accept_list']
        else:
            assert u['filtered_reasons'] == ['accept_list', 'category_names']

    assert len(actual['updates']) == 2
    for u_id, u in actual['updates'].items():
        assert u['id'] == u_id
        assert u['id'] in UPDATE_INFO
        u_info = UPDATE_INFO[u['id']]
        assert u['title'] == u_info['title']
        assert u['kb'] == [u_info['kb']]
        assert u['categories'] == u_info['categories']
        assert u['downloaded']

        if u_info['kb'] == '2267602':
            assert not u['installed']
            assert u['failure_hresult_code'] == 2147944003
            assert u['failure_msg'] == 'Unknown WUA HRESULT 2147944003 (UNKNOWN 0x80070643)'

        else:
            assert u['installed']
            assert 'failure_hresult_code' not in u


def test_connection_failures_during_poll(monkeypatch):
    mock_warning = MagicMock()
    monkeypatch.setattr(win_updates.display, "warning", mock_warning)
    actual = run_action(monkeypatch, 'poll_error1.txt', {
        'category_names': ['*'],
    })

    assert actual['changed']
    assert actual['reboot_required']
    assert actual['rebooted'] is False
    assert actual['found_update_count'] == 3
    assert actual['failed_update_count'] == 0
    assert actual['installed_update_count'] == 3

    assert len(actual['filtered_updates']) == 3
    for u_id, u in actual['filtered_updates'].items():
        assert u['id'] == u_id
        assert u['id'] in UPDATE_INFO
        u_info = UPDATE_INFO[u['id']]
        assert u['title'] == u_info['title']
        assert u['kb'] == [u_info['kb']]
        assert u['categories'] == u_info['categories']
        assert not u['downloaded']
        assert not u['installed']

        if u_info['kb'] == '2267602':
            assert u['filtered_reason'] == 'blacklist'
            assert u['filtered_reasons'] == ['reject_list', 'category_names']
        else:
            assert u['filtered_reason'] == 'category_names'
            assert u['filtered_reasons'] == ['category_names']

    assert len(actual['updates']) == 3
    for u_id, u in actual['updates'].items():
        assert u['id'] == u_id
        assert u['id'] in UPDATE_INFO
        u_info = UPDATE_INFO[u['id']]
        assert u['title'] == u_info['title']
        assert u['kb'] == [u_info['kb']]
        assert u['categories'] == u_info['categories']
        assert u['downloaded']
        assert u['installed']

    assert mock_warning.call_count == 1
    assert mock_warning.mock_calls[0][1] == ('Connection failure when polling update result - attempting to retry: connection error',)


def test_multiple_connection_failures_during_poll(monkeypatch):
    mock_warning = MagicMock()
    monkeypatch.setattr(win_updates.display, "warning", mock_warning)
    actual = run_action(monkeypatch, 'poll_error2.txt', {
        'category_names': ['*'],
    })

    assert actual['unreachable']
    assert actual['msg'] == 'connection error'

    assert mock_warning.call_count == 3
    assert mock_warning.mock_calls[0][1] == ('Connection failure when polling update result - attempting to retry: connection error',)
    assert mock_warning.mock_calls[1][1] == ('Unknown failure when polling update result - attempting to cancel task: connection error',)
    assert mock_warning.mock_calls[2][1] == ('Unknown failure when cancelling update task: connection error',)


def test_repeated_update(monkeypatch):
    reboot_mock = MagicMock()
    reboot_mock.return_value = {'failed': False}
    monkeypatch.setattr(win_updates, 'reboot_host', reboot_mock)

    actual = run_action(monkeypatch, 'repeated_update.txt', {
        'category_names': ['*'],
        'reboot': True,
    })

    assert actual['failed']
    assert re.match(r'An update loop was detected,.*\. Updates in the reboot loop are: 501ef1af-14f0-4cb5-aa9b-aa340b9f9d2a', actual['msg'])
    assert actual['failed_update_count'] == 1
    assert actual['installed_update_count'] == 2
    assert actual['found_update_count'] == 3
    assert actual['updates']['85604fae-a5c5-4f6d-9012-3d86be1bccce']['installed']
    assert actual['updates']['5e406f0e-59fa-432d-bb9a-77d2db6f74ec']['installed']
    assert not actual['updates']['501ef1af-14f0-4cb5-aa9b-aa340b9f9d2a']['installed']
    assert actual['updates']['501ef1af-14f0-4cb5-aa9b-aa340b9f9d2a']['failure_hresult_code'] == -1
    assert actual['updates']['501ef1af-14f0-4cb5-aa9b-aa340b9f9d2a']['failure_msg'] == 'Unknown WUA HRESULT -1 (UNKNOWN 0xFFFFFFFF)'
