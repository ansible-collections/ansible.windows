# -*- coding: utf-8 -*-
# (c) 2018, Jordan Borean <jborean@redhat.com>
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

# Make coding more python3-ish
from __future__ import (absolute_import, division, print_function)
from sys import call_tracing
__metaclass__ = type

import ntpath
import os

from ansible.module_utils.common.text.converters import to_bytes
from ansible.playbook.task import Task

from ansible_collections.ansible.windows.tests.unit.compat.mock import MagicMock
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


class UpdateProgressHelper:
    """Mocks the functionality of POLL_SCRIPT to get update results for testing"""

    def __init__(self, test_name, default_rc=0, default_stderr=b''):
        self._path = os.path.abspath(os.path.join(__file__, '..', '..', '..', 'test_data', 'win_updates', test_name))
        self._reader = self._read_gen()
        self._rc = default_rc
        self._stderr = default_stderr

    def poll(self, cmd, **kwargs):
        return next(self._reader)

    def _read_gen(self):
        offset = 0
        lines = []
        with open(self._path, mode='rb') as fd:
            while True:
                line = fd.readline().strip()

                # Every blank line is treated as no more data is available and the script should return the values
                # retrieved. A subsequent call will continue to return the remaining data.
                if not line:
                    lines.append(to_bytes(offset))
                    b_stdout = b'\n'.join(lines)
                    lines = []
                    yield self._rc, b_stdout, self._stderr

                lines.append(line)
                offset += len(line)


def mock_connection_init(test_id, default_rc=0, default_stderr=b''):
    progress_helper = UpdateProgressHelper(test_id, default_rc=default_rc, default_stderr=default_stderr)
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


def run_action(monkeypatch, test_id, task_vars, check_mode=False, poll_rc=0, poll_stderr=b''):
    module_arg_return = task_vars.copy()
    module_arg_return['_wait'] = False

    plugin = win_updates_init(task_vars, check_mode=check_mode,
                              connection=mock_connection_init(test_id, default_rc=poll_rc, default_stderr=poll_stderr))
    execute_module = MagicMock()
    execute_module.return_value = {
        'invocation': {'module_args': module_arg_return},
        'output_path': 'update_output_path',
        'task_pid': 666,
        'cancel_id': 'update_cancel_id',
    }
    monkeypatch.setattr(plugin, '_execute_module', execute_module)
    monkeypatch.setattr(plugin, '_transfer_file', MagicMock())

    return plugin.run()


def test_run_with_async(monkeypatch):
    plugin = win_updates_init({}, async_val=1)
    execute_module = MagicMock()
    execute_module.return_value = {'invocation': {'module_args': {'_wait': True, 'accept_list': []}}, 'updates': ['test']}
    monkeypatch.setattr(plugin, '_execute_module', execute_module)

    # Running with async should just call the module and return back the result - sans the _wait invocation arg
    actual = plugin.run()
    assert actual == {'invocation': {'module_args': {'accept_list': []}}, 'updates': ['test']}

    assert execute_module.call_count == 1
    assert execute_module.call_args[1]['module_name'] == 'ansible.windows.win_updates'
    assert execute_module.call_args[1]['module_args']['_wait']
    assert execute_module.call_args[1]['module_args']['_output_path'] is None
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
    actual = run_action(monkeypatch, 'fail_poll_script.txt', {}, poll_rc=1, poll_stderr=b'stderr msg')

    assert actual['rc'] == 1
    assert actual['stdout'] == 'stdout message\n14'
    assert actual['stderr'] == 'stderr msg'
    assert actual['failed']
    assert actual['msg'] == 'Failed to poll update task, see rc, stdout, stderr for more info'
    assert 'exception' in actual
    assert actual['found_update_count'] == 0
    assert actual['failed_update_count'] == 0
    assert actual['installed_update_count'] == 0
    assert actual['filtered_updates'] == {}
    assert actual['updates'] == {}


def test_poll_script_invalid_json_output(monkeypatch):
    actual = run_action(monkeypatch, 'fail_poll_script_invalid_json.txt', {}, poll_rc=0, poll_stderr=b'stderr msg')

    assert actual['rc'] == 0
    assert actual['stdout'] == '{"task":unquoted}\n17'
    assert actual['stderr'] == 'stderr msg'
    assert actual['failed']
    assert actual['msg'].startswith('Failed to decode poll result json: ')
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
    assert actual['failed']
    assert actual['msg'] == 'Searching for updates: Exception from HRESULT: 0x80240032 - The search criteria string was invalid ' \
        '(WU_E_INVALID_CRITERIA 80240032)'
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
            assert u['failure_msg'] == 'Unknown WUA HRESULT 2147944003 (UNKNOWN 80070643)'

        else:
            assert u['installed']
            assert 'failure_hresult_code' not in u
