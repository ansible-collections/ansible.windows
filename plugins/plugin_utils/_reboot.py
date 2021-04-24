# Copyright: (c) 2021, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

"""Reboot action for Windows hosts

This contains the code to reboot a Windows host for use by other action plugins
in this collection. Right now it should only be used in ansible.windows as the
interface is not final and could be subject to change.
"""

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import datetime
import random
import time
import traceback

from ansible.errors import AnsibleConnectionFailure, AnsibleError
from ansible.module_utils.common.text.converters import to_native, to_text
from ansible.utils.display import Display

from ansible.plugins.connection import ConnectionBase
try:
    from typing import (
        Any,
        Callable,
        Dict,
        Tuple,
    )
except ImportError:
    # Satisfy Python 2 which doesn't have typing.
    Any = Callable = Dict = Tuple = None


# This is not ideal but the psrp connection plugin doesn't catch all these exceptions as an AnsibleConnectionFailure.
# Until we can guarantee we are using a version of psrp that handles all this we try to handle those issues.
try:
    from requests.exceptions import (
        ConnectionError as RequestsConnectionError,
        Timeout as RequestsTimeout,
    )
except ImportError:
    RequestsConnectionError = RequestsTimeout = None


_DEFAULT_BOOT_TIME_COMMAND = "(Get-CimInstance -ClassName Win32_OperatingSystem -Property LastBootUpTime)" \
                             ".LastBootUpTime.ToFileTime()"
display = Display()


class _ReturnResultException(Exception):

    def __init__(self, msg, **result):
        super(_ReturnResultException, self).__init__(msg)
        self.result = result


def reboot_action(
        task_action,
        connection,
        boot_time_command=_DEFAULT_BOOT_TIME_COMMAND,
        connection_timeout=5,
        msg='Reboot initiated by Ansible',
        post_reboot_delay=0,
        pre_reboot_delay=2,
        reboot_timeout=600,
        test_command='whoami',
):  # type: (str, ConnectionBase, str, int, str, int, int, int, str) -> Dict
    """Reboot a Windows Host.

    Used by action plugins in ansible.windows to reboot a Windows host. It
    takes in the action plugin so it can run the commands on the targeted host
    and monitor the reboot process. The return dict will have the following
    keys set:

        changed: Whether a change occurred (reboot was done)
        elapsed: Seconds elapsed between the reboot and it coming back online
        failed: Whether a failure occurred
        rebooted: Whether the host was rebooted

    When failed=True there may be more keys to give some information around
    the failure like msg, exception. There are other keys that might be
    returned as well but they are dependent on the failure that occurred.

    Verbosity levels used:
        2: Message when each reboot step is completed
        3: Connection plugin operations and their results
        5: Raw commands run and the results of those commands
        Debug:

    Args:
        task_action: The name of the action plugin that is running for logging.
        connection: The connection plugin to run the reboot again.
        boot_time_command: The command to run when getting the boot timeout.
        connection_timeout: Override the connection timeout of the connection
            plugin when polling the rebooted host.
        msg: The message to display to interactive users when rebooting the
            host.
        post_reboot_delay: Seconds to wait after sending the reboot command
            before checking to see if it has returned.
        pre_reboot_delay: Seconds to wait when sending the reboot command.
        reboot_timeout: Seconds to wait while polling for the host to come
            back online.
        test_command: Command to run when the host is back online and
            determines the machine is ready for management.

    Returns:
        (Dict[str, Any]): The return result as a dictionary. Use the 'failed'
            key to determine if there was a failure or not.
    """
    result = {
        'changed': False,
        'elapsed': 0,
        'failed': False,
        'rebooted': False,
    }

    # Get current boot time
    try:
        previous_boot_time = _get_system_boot_time(task_action, connection, boot_time_command)
    except Exception as e:
        if isinstance(e, _ReturnResultException):
            result.update(e.result)

        result['failed'] = True
        result['msg'] = to_text(e)
        result['exception'] = traceback.format_exc()
        return result

    # Get the original connection_timeout option var so it can be reset after
    original_connection_timeout = None
    reset_connection_timeout = True
    try:
        original_connection_timeout = connection.get_option('connection_timeout')
        display.vvv("%s: saving original connect_timeout of %s" % (task_action, original_connection_timeout))
    except KeyError:
        display.vvv("%s: connect_timeout connection option has not been set" % task_action)
        reset_connection_timeout = False

    # Initiate reboot
    reboot_command = 'shutdown.exe /r /t %s /c "%s"' % (pre_reboot_delay, msg)
    try:
        _perform_reboot(task_action, connection, reboot_command)
    except Exception as e:
        if isinstance(e, _ReturnResultException):
            result.update(e.result)

        result['failed'] = True
        result['msg'] = to_text(e)
        result['exception'] = traceback.format_exc()
        return result

    start = datetime.datetime.utcnow()

    try:
        result['rebooted'] = True

        if post_reboot_delay != 0:
            display.vv("%s: waiting an additional %s seconds" % (task_action, post_reboot_delay))
            time.sleep(post_reboot_delay)

        # Keep on trying to run the last boot time check until it is successful or the timeout is raised
        display.vv('%s validating reboot' % task_action)
        _do_until_success_or_timeout(task_action, connection, 'last boot time check', reboot_timeout,
                                     _check_boot_time, task_action, connection, previous_boot_time, boot_time_command,
                                     connection_timeout)

        # Reset the connection plugin connection timeout back to the original
        if reset_connection_timeout:
            _set_connection_timeout(task_action, connection, original_connection_timeout)

        # Run test command until ti is successful or a timeout occurs
        display.vv('%s running post reboot test command' % task_action)
        _do_until_success_or_timeout(task_action, connection, 'post-reboot test command', reboot_timeout,
                                     _run_test_command, task_action, connection, test_command)

        display.vv("%s: system successfully rebooted" % task_action)

    except Exception as e:
        if isinstance(e, _ReturnResultException):
            result.update(e.result)

        result['failed'] = True
        result['msg'] = to_text(e)
        result['exception'] = traceback.format_exc()

    elapsed = datetime.datetime.utcnow() - start
    result['elapsed'] = elapsed.seconds

    return result


def _check_boot_time(task_action, connection, previous_boot_time, boot_time_command, timeout):
    """Checks the system boot time has been changed or not"""
    display.vvv("%s: attempting to get system boot time" % task_action)

    # override connection timeout from defaults to custom value
    if timeout:
        display.vvvvv("%s: setting connect_timeout to %s" % (task_action, timeout))
        connection.set_option("connection_timeout", timeout)
        if not _reset_connection(task_action, connection):
            display.warning("Connection plugin does not allow the connection timeout to be overridden")

    # try and get boot time
    current_boot_time = _get_system_boot_time(task_action, connection, boot_time_command)
    if current_boot_time == previous_boot_time:
        raise ValueError("boot time has not changed")


def _do_until_success_or_timeout(task_action, connection, action_desc, timeout, func, *args, **kwargs):
    # type: (str, ConnectionBase, str, int, Callable, Any, Any) -> Any
    """Runs the function multiple times ignoring errors until a timeout occurs"""
    max_end_time = datetime.datetime.utcnow() + datetime.timedelta(seconds=timeout)

    fail_count = 0
    max_fail_sleep = 12
    reset_required = False

    while datetime.datetime.utcnow() < max_end_time:
        try:
            if reset_required:
                # Keep on trying the reset until it succeeds.
                _reset_connection(task_action, connection)
                reset_required = False

            else:
                res = func(*args, **kwargs)
                display.vvvvv('%s: %s success' % (task_action, action_desc))

                return res

        except Exception as e:
            # The error may be due to a connection problem, just reset the connection just in case
            reset_required = True

            # Use exponential backoff with a max timeout, plus a little bit of randomness
            random_int = random.randint(0, 1000) / 1000
            fail_sleep = 2 ** fail_count + random_int
            if fail_sleep > max_fail_sleep:
                fail_sleep = max_fail_sleep + random_int

            try:
                error = to_text(e).splitlines()[-1]
            except IndexError as e:
                error = to_text(e)

            display.vvvvv("{action}: {desc} fail {e_type} '{err}', retrying in {sleep:.4} seconds...\n{test}".format(
                action=task_action,
                desc=action_desc,
                e_type=type(e).__name__,
                err=error,
                sleep=fail_sleep,
                test=traceback.format_exc(),
            ))

            fail_count += 1
            time.sleep(fail_sleep)

    raise Exception('Timed out waiting for %s (timeout=%s)' % (action_desc, timeout))


def _execute_command(task_action, connection, command):  # type: (str, ConnectionBase, str) -> Tuple[int, str, str]
    """Runs a command on the Windows host and returned the result"""
    display.vvvvv("%s: running command: %s" % (task_action, command))

    # Need to wrap the command in our PowerShell encoded wrapper. This is done to align the command input to a
    # common shell and to allow the psrp connection plugin to report the correct exit code without manually setting
    # $LASTEXITCODE for just that plugin.
    command = connection._shell._encode_script(command)

    try:
        rc, stdout, stderr = connection.exec_command(command, in_data=None, sudoable=False)
    except (RequestsConnectionError, RequestsTimeout) as e:
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
    display.vv("%s: getting boot time" % task_action)
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


def _reset_connection(task_action, connection, ignore_errors=False):  # type: (str, ConnectionBase, tru) -> bool
    """Resets the connection handling any errors and returns a bool stating if it is resettable"""
    res = True
    if getattr(_reset_connection, '_skip', False):
        return res

    display.vvv("%s: resetting connection plugin" % task_action)
    try:
        connection.reset()

    except AttributeError:
        res = False
        setattr(_reset_connection, '_skip', True)

    except (AnsibleError, RequestsConnectionError, RequestsTimeout) as e:
        if ignore_errors:
            return res

        raise AnsibleError(to_native(e))

    return res


def _run_test_command(task_action, connection, command):  # type: (str, ConnectionBase, str) -> None
    """Runs the user specified test command until the host is able to run it properly"""
    display.vvv("%s: attempting post-reboot test command" % task_action)

    rc, stdout, stderr = _execute_command(task_action, connection, command)

    if rc != 0:
        msg = "%s: Test command failed - rc: %s, stdout: %s, stderr: %s" % (task_action, rc, stdout, stderr)
        raise RuntimeError(msg)


def _set_connection_timeout(task_action, connection, timeout):  # type: (str, ConnectionBase, int) -> None
    """Sets the connection plugin connection_timeout option and resets the connection"""
    current_connection_timeout = connection.get_option('connection_timeout')
    if timeout == current_connection_timeout:
        return

    display.vvv("%s: setting connect_timeout %s" % (task_action, timeout))
    connection.set_option("connection_timeout", timeout)

    _reset_connection(task_action, connection, ignore_errors=True)
