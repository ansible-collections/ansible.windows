# Copyright: (c) 2021, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

"""Reboot action for Windows hosts

This contains the code to reboot a Windows host for use by other action plugins
in this collection. Right now it should only be used in ansible.windows as the
interface is not final and could be subject to change.
"""

# FOR INTERNAL COLLECTION USE ONLY
# The interfaces in this file are meant for use within the ansible.windows collection
# and may not remain stable to outside uses. Changes may be made in ANY release, even a bugfix release.
# See also: https://github.com/ansible/community/issues/539#issuecomment-780839686
# Please open an issue if you have questions about this.

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import datetime
import json
import random
import time
import traceback
import uuid

from ansible.errors import AnsibleConnectionFailure, AnsibleError
from ansible.module_utils.common.text.converters import to_native, to_text
from ansible.plugins.connection import ConnectionBase
from ansible.utils.display import Display

from ._quote import quote_pwsh

try:
    from typing import (
        Any,
        Callable,
        Dict,
        Optional,
        Tuple,
    )
except ImportError:
    # Satisfy Python 2 which doesn't have typing.
    Any = Callable = Dict = Optional = Tuple = None


# This is not ideal but the psrp connection plugin doesn't catch all these exceptions as an AnsibleConnectionFailure.
# Until we can guarantee we are using a version of psrp that handles all this we try to handle those issues.
try:
    from requests.exceptions import (
        RequestException,
    )
except ImportError:
    RequestException = AnsibleConnectionFailure


_LOGON_UI_KEY = r'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon\AutoLogonChecked'

_DEFAULT_BOOT_TIME_COMMAND = "(Get-CimInstance -ClassName Win32_OperatingSystem -Property LastBootUpTime)" \
                             ".LastBootUpTime.ToFileTime()"

display = Display()


class _ReturnResultException(Exception):
    """Used to sneak results back to the return dict from an exception"""

    def __init__(self, msg, **result):
        super(_ReturnResultException, self).__init__(msg)
        self.result = result


class _TestCommandFailure(Exception):
    """Differentiates between a connection failure and just a command assertion failure during the reboot loop"""
    pass


def reboot_host(
        task_action,
        connection,
        boot_time_command=_DEFAULT_BOOT_TIME_COMMAND,
        connect_timeout=5,
        msg='Reboot initiated by Ansible',
        post_reboot_delay=0,
        pre_reboot_delay=2,
        reboot_timeout=600,
        test_command=None,
):  # type: (str, ConnectionBase, str, float, str, float, float, float, Optional[str]) -> Dict
    """Reboot a Windows Host.

    Used by action plugins in ansible.windows to reboot a Windows host. It
    takes in the connection plugin so it can run the commands on the targeted
    host and monitor the reboot process. The return dict will have the
    following keys set:

        changed: Whether a change occurred (reboot was done)
        elapsed: Seconds elapsed between the reboot and it coming back online
        failed: Whether a failure occurred
        unreachable: Whether it failed to connect to the host on the first cmd
        rebooted: Whether the host was rebooted

    When failed=True there may be more keys to give some information around
    the failure like msg, exception. There are other keys that might be
    returned as well but they are dependent on the failure that occurred.

    Verbosity levels used:
        2: Message when each reboot step is completed
        3: Connection plugin operations and their results
        5: Raw commands run and the results of those commands
        Debug: Everything, very verbose

    Args:
        task_action: The name of the action plugin that is running for logging.
        connection: The connection plugin to run the reboot commands on.
        boot_time_command: The command to run when getting the boot timeout.
        connect_timeout: Override the connection timeout of the connection
            plugin when polling the rebooted host.
        msg: The message to display to interactive users when rebooting the
            host.
        post_reboot_delay: Seconds to wait after sending the reboot command
            before checking to see if it has returned.
        pre_reboot_delay: Seconds to wait when sending the reboot command.
        reboot_timeout: Seconds to wait while polling for the host to come
            back online.
        test_command: Command to run when the host is back online and
            determines the machine is ready for management. When not defined
            the default command should wait until the reboot is complete and
            all pre-login configuration has completed.

    Returns:
        (Dict[str, Any]): The return result as a dictionary. Use the 'failed'
            key to determine if there was a failure or not.
    """
    result = {
        'changed': False,
        'elapsed': 0,
        'failed': False,
        'unreachable': False,
        'rebooted': False,
    }
    host_context = {'do_close_on_reset': True}

    # Get current boot time. A lot of tasks that require a reboot leave the WSMan stack in a bad place. Will try to
    # get the initial boot time 3 times before giving up.
    try:
        previous_boot_time = _do_until_success_or_retry_limit(task_action, connection, host_context,
                                                              'pre-reboot boot time check', 3, _get_system_boot_time,
                                                              task_action, connection, boot_time_command)

    except Exception as e:
        # Report a the failure based on the last exception received.
        if isinstance(e, _ReturnResultException):
            result.update(e.result)

        if isinstance(e, AnsibleConnectionFailure):
            result['unreachable'] = True
        else:
            result['failed'] = True

        result['msg'] = to_text(e)
        result['exception'] = traceback.format_exc()
        return result

    # Get the original connection_timeout option var so it can be reset after
    original_connection_timeout = None
    reset_connection_timeout = True
    try:
        original_connection_timeout = connection.get_option('connection_timeout')
        display.vvv("%s: saving original connection_timeout of %s" % (task_action, original_connection_timeout))
    except KeyError:
        display.vvv("%s: connection_timeout connection option has not been set" % task_action)
        reset_connection_timeout = False

    # Initiate reboot
    # This command may be wrapped in other shells or command making it hard to detect what shutdown.exe actually
    # returned. We use this hackery to return a json that contains the stdout/stderr/rc as a structured object for our
    # code to parse and detect if something went wrong.
    reboot_command = '''$ErrorActionPreference = 'Continue'

if ($%s) {
    Remove-Item -LiteralPath '%s' -Force -ErrorAction SilentlyContinue
}

$stdout = $null
$stderr = . { shutdown.exe /r /t %s /c %s | Set-Variable stdout } 2>&1 | ForEach-Object ToString

ConvertTo-Json -Compress -InputObject @{
    stdout = (@($stdout) -join "`n")
    stderr = (@($stderr) -join "`n")
    rc = $LASTEXITCODE
}
''' % (str(not test_command), _LOGON_UI_KEY, int(pre_reboot_delay), quote_pwsh(msg))

    expected_test_result = None  # We cannot have an expected result if the command is user defined
    if not test_command:
        # It turns out that LogonUI will create this registry key if it does not exist when it's about to show the
        # logon prompt. Normally this is a volatile key but if someone has explicitly created it that might no longer
        # be the case. We ensure it is not present on a reboot so we can wait until LogonUI creates it to determine
        # the host is actually online and ready, e.g. no configurations/updates still to be applied.
        # We echo a known successful statement to catch issues with powershell failing to start but the rc mysteriously
        # being 0 causing it to consider a successful reboot too early (seen on ssh connections).
        expected_test_result = 'success-%s' % str(uuid.uuid4())
        test_command = "Get-Item -LiteralPath '%s' -ErrorAction Stop; '%s'" % (_LOGON_UI_KEY, expected_test_result)

    start = None
    try:
        _perform_reboot(task_action, connection, reboot_command)

        start = datetime.datetime.utcnow()
        result['changed'] = True
        result['rebooted'] = True

        if post_reboot_delay != 0:
            display.vv("%s: waiting an additional %s seconds" % (task_action, post_reboot_delay))
            time.sleep(post_reboot_delay)

        # Keep on trying to run the last boot time check until it is successful or the timeout is raised
        display.vv('%s validating reboot' % task_action)
        _do_until_success_or_timeout(task_action, connection, host_context, 'last boot time check', reboot_timeout,
                                     _check_boot_time, task_action, connection, host_context, previous_boot_time,
                                     boot_time_command, connect_timeout)

        # Reset the connection plugin connection timeout back to the original
        if reset_connection_timeout:
            _set_connection_timeout(task_action, connection, host_context, original_connection_timeout)

        # Run test command until ti is successful or a timeout occurs
        display.vv('%s running post reboot test command' % task_action)
        _do_until_success_or_timeout(task_action, connection, host_context, 'post-reboot test command', reboot_timeout,
                                     _run_test_command, task_action, connection, test_command,
                                     expected=expected_test_result)

        display.vv("%s: system successfully rebooted" % task_action)

    except Exception as e:
        if isinstance(e, _ReturnResultException):
            result.update(e.result)

        result['failed'] = True
        result['msg'] = to_text(e)
        result['exception'] = traceback.format_exc()

    if start:
        elapsed = datetime.datetime.utcnow() - start
        result['elapsed'] = elapsed.seconds

    return result


def _check_boot_time(task_action, connection, host_context, previous_boot_time, boot_time_command, timeout):
    """Checks the system boot time has been changed or not"""
    display.vvv("%s: attempting to get system boot time" % task_action)

    # override connection timeout from defaults to custom value
    if timeout:
        _set_connection_timeout(task_action, connection, host_context, timeout)

    # try and get boot time
    current_boot_time = _get_system_boot_time(task_action, connection, boot_time_command)
    if current_boot_time == previous_boot_time:
        raise _TestCommandFailure("boot time has not changed")


def _do_until_success_or_retry_limit(task_action, connection, host_context, action_desc, retries, func, *args,
                                     **kwargs):
    # type: (str, ConnectionBase, Dict, str, int, Callable, Any, Any) -> Any
    """Runs the function multiple times ignoring errors until the retry limit is hit"""

    def wait_condition(idx):
        return idx < retries

    return _do_until_success_or_condition(task_action, connection, host_context, action_desc, wait_condition,
                                          func, *args, **kwargs)


def _do_until_success_or_timeout(task_action, connection, host_context, action_desc, timeout, func, *args, **kwargs):
    # type: (str, ConnectionBase, Dict, str, float, Callable, Any, Any) -> Any
    """Runs the function multiple times ignoring errors until a timeout occurs"""
    max_end_time = datetime.datetime.utcnow() + datetime.timedelta(seconds=timeout)

    def wait_condition(idx):
        return datetime.datetime.utcnow() < max_end_time

    try:
        return _do_until_success_or_condition(task_action, connection, host_context, action_desc, wait_condition,
                                              func, *args, **kwargs)
    except Exception:
        raise Exception('Timed out waiting for %s (timeout=%s)' % (action_desc, timeout))


def _do_until_success_or_condition(task_action, connection, host_context, action_desc, condition, func, *args,
                                   **kwargs):
    # type: (str, ConnectionBase, Dict, str, Callable, Callable, Any, Any) -> Any
    """Runs the function multiple times ignoring errors until the condition is false"""
    fail_count = 0
    max_fail_sleep = 12
    reset_required = False
    last_error = None

    while fail_count == 0 or condition(fail_count):
        try:
            if reset_required:
                # Keep on trying the reset until it succeeds.
                _reset_connection(task_action, connection, host_context)
                reset_required = False

            else:
                res = func(*args, **kwargs)
                display.vvvvv('%s: %s success' % (task_action, action_desc))

                return res

        except Exception as e:
            last_error = e

            if not isinstance(e, _TestCommandFailure):
                # The error may be due to a connection problem, just reset the connection just in case
                reset_required = True

            # Use exponential backoff with a max timeout, plus a little bit of randomness
            random_int = random.randint(0, 1000) / 1000
            fail_sleep = 2 ** fail_count + random_int
            if fail_sleep > max_fail_sleep:
                fail_sleep = max_fail_sleep + random_int

            try:
                error = to_text(e).splitlines()[-1]
            except IndexError:
                error = to_text(e)

            display.vvvvv("{action}: {desc} fail {e_type} '{err}', retrying in {sleep:.4} seconds...\n{tcb}".format(
                action=task_action,
                desc=action_desc,
                e_type=type(e).__name__,
                err=error,
                sleep=fail_sleep,
                tcb=traceback.format_exc(),
            ))

            fail_count += 1
            time.sleep(fail_sleep)

    if last_error:
        raise last_error


def _execute_command(task_action, connection, command):  # type: (str, ConnectionBase, str) -> Tuple[int, str, str]
    """Runs a command on the Windows host and returned the result"""
    display.vvvvv("%s: running command: %s" % (task_action, command))

    # Need to wrap the command in our PowerShell encoded wrapper. This is done to align the command input to a
    # common shell and to allow the psrp connection plugin to report the correct exit code without manually setting
    # $LASTEXITCODE for just that plugin.
    command = connection._shell._encode_script(command)

    try:
        rc, stdout, stderr = connection.exec_command(command, in_data=None, sudoable=False)
    except RequestException as e:
        # The psrp connection plugin should be doing this but until we can guarantee it does we just convert it here
        # to ensure AnsibleConnectionFailure refers to actual connection errors.
        raise AnsibleConnectionFailure("Failed to connect to the host: %s" % to_native(e))

    rc = rc or 0
    stdout = to_text(stdout, errors='surrogate_or_strict').strip()
    stderr = to_text(stderr, errors='surrogate_or_strict').strip()

    display.vvvvv("%s: command result - rc: %s, stdout: %s, stderr: %s" % (task_action, rc, stdout, stderr))

    return rc, stdout, stderr


def _get_system_boot_time(task_action, connection, boot_time_command):  # type: (str, ConnectionBase, str) -> str
    """Gets a unique identifier to represent the boot time of the Windows host"""
    display.vvv("%s: getting boot time" % task_action)
    rc, stdout, stderr = _execute_command(task_action, connection, boot_time_command)

    if rc != 0:
        msg = "%s: failed to get host boot time info" % task_action
        raise _ReturnResultException(msg, rc=rc, stdout=stdout, stderr=stderr)

    display.vvv("%s: last boot time: %s" % (task_action, stdout))
    return stdout


def _perform_reboot(task_action, connection, reboot_command, handle_abort=True):
    # type: (str, ConnectionBase, str, bool) -> None
    """Runs the reboot command"""
    display.vv("%s: rebooting server..." % task_action)

    stdout = stderr = None
    try:
        rc, stdout, stderr = _execute_command(task_action, connection, reboot_command)

    except AnsibleConnectionFailure as e:
        # If the connection is closed too quickly due to the system being shutdown, carry on
        display.vvv('%s: AnsibleConnectionFailure caught and handled: %s' % (task_action, to_text(e)))
        rc = 0

    if stdout:
        try:
            reboot_result = json.loads(stdout)
        except getattr(json.decoder, 'JSONDecodeError', ValueError):
            # While the reboot command should output json it may have failed for some other reason. We continue
            # reporting with that output instead
            pass
        else:
            stdout = reboot_result.get('stdout', stdout)
            stderr = reboot_result.get('stderr', stderr)
            rc = int(reboot_result.get('rc', rc))

    # Test for "A system shutdown has already been scheduled. (1190)" and handle it gracefully
    if handle_abort and (rc == 1190 or (rc != 0 and "(1190)" in stderr)):
        display.warning('A scheduled reboot was pre-empted by Ansible.')

        # Try to abort (this may fail if it was already aborted)
        rc, stdout, stderr = _execute_command(task_action, connection, 'shutdown.exe /a')
        display.vvv("%s: result from trying to abort existing shutdown - rc: %s, stdout: %s, stderr: %s"
                    % (task_action, rc, stdout, stderr))

        return _perform_reboot(task_action, connection, reboot_command, handle_abort=False)

    if rc != 0:
        msg = "%s: Reboot command failed" % task_action
        raise _ReturnResultException(msg, rc=rc, stdout=stdout, stderr=stderr)


def _reset_connection(task_action, connection, host_context, ignore_errors=False):
    # type: (str, ConnectionBase, Dict, bool) -> None
    """Resets the connection handling any errors"""
    def _wrap_conn_err(func, *args, **kwargs):
        try:
            func(*args, **kwargs)

        except (AnsibleError, RequestException) as e:
            if ignore_errors:
                return False

            raise AnsibleError(to_native(e))

        return True

    # While reset() should probably better handle this some connection plugins don't clear the existing connection on
    # reset() leaving resources still in use on the target (WSMan shells). Instead we try to manually close the
    # connection then call reset. If it fails once we want to skip closing to avoid a perpetual loop and just hope
    # reset() brings us back into a good state. If it's successful we still want to try it again.
    if host_context['do_close_on_reset']:
        display.vvv("%s: closing connection plugin" % task_action)
        try:
            success = _wrap_conn_err(connection.close)

        except Exception:
            host_context['do_close_on_reset'] = False
            raise

        host_context['do_close_on_reset'] = success

    # For some connection plugins (ssh) reset actually does something more than close so we also class that
    display.vvv("%s: resetting connection plugin" % task_action)
    try:
        _wrap_conn_err(connection.reset)

    except AttributeError:
        # Not all connection plugins have reset so we just ignore those, close should have done our job.
        pass


def _run_test_command(task_action, connection, command, expected=None):
    # type: (str, ConnectionBase, str, Optional[str]) -> None
    """Runs the user specified test command until the host is able to run it properly"""
    display.vvv("%s: attempting post-reboot test command" % task_action)

    rc, stdout, stderr = _execute_command(task_action, connection, command)

    if rc != 0:
        msg = "%s: Test command failed - rc: %s, stdout: %s, stderr: %s" % (task_action, rc, stdout, stderr)
        raise _TestCommandFailure(msg)

    if expected and expected not in stdout:
        msg = "%s: Test command failed - '%s' was not in stdout: %s" % (task_action, expected, stdout)
        raise _TestCommandFailure(msg)


def _set_connection_timeout(task_action, connection, host_context, timeout):
    # type: (str, ConnectionBase, Dict, float) -> None
    """Sets the connection plugin connection_timeout option and resets the connection"""
    try:
        current_connection_timeout = connection.get_option('connection_timeout')
    except KeyError:
        # Not all connection plugins implement this, just ignore the setting if it doesn't work
        return

    if timeout == current_connection_timeout:
        return

    display.vvv("%s: setting connect_timeout %s" % (task_action, timeout))
    connection.set_option("connection_timeout", timeout)

    _reset_connection(task_action, connection, host_context, ignore_errors=True)
