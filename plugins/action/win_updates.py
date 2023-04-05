# Copyright: (c) 2021, Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import json
import os.path
import shutil
import tempfile
import traceback

from ansible import constants as C
from ansible.errors import AnsibleActionFail, AnsibleConnectionFailure
from ansible.module_utils.common.text.converters import to_bytes, to_native, to_text
from ansible.module_utils.common.validation import check_type_bool, check_type_int
from ansible.plugins.action import ActionBase
from ansible.utils.display import Display

try:
    from typing import (
        Dict,
        List,
        Optional,
        Tuple,
    )
except ImportError:
    # Satisfy Python 2 which doesn't have typing.
    Dict = List = Optional = Tuple = None

from ..plugin_utils._quote import quote_pwsh
from ..plugin_utils._reboot import reboot_host


display = Display()


_CANCEL_SCRIPT = r'''[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $CancelId,

    [Parameter(Mandatory)]
    [int]
    $TaskPid
)

$cancelEvent = $null
if ([Threading.EventWaitHandle]::TryOpenExisting($CancelId, [ref]$cancelEvent)) {
    [void]$cancelEvent.Set()
    $cancelEvent.Dispose()
}

# We don't want to wait around forever, try out best to wait until the task has ended.
Wait-Process -Id $TaskPid -ErrorAction SilentlyContinue -Timeout 10
'''


_POLL_SCRIPT = r'''[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $OutputPath,

    [Parameter(Mandatory)]
    [int]
    $Offset
)

$ErrorActionPreference = 'Stop'

$fs = $sr = $null
try {
    $fs = [System.IO.File]::Open($OutputPath, 'Open', 'Read', 'ReadWrite')
    [void]$fs.Seek($Offset, [System.IO.SeekOrigin]::Begin)
    $sr = New-Object -TypeName System.IO.StreamReader -ArgumentList $fs

    $read = $false
    while ($true) {
        $line = $sr.ReadLine()
        if (-not $line) {
            if ($read) {
                break
            }
            else {
                Start-Sleep -Seconds 1
                continue
            }
        }

        $read = $true
        $line
    }

    '{{"position": {0}}}' -f $fs.Position
}
finally {
    if ($sr) { $sr.Dispose() }
    if ($fs) { $fs.Dispose() }
}
'''


def _get_hresult_error(hresult):  # type: (int) -> str
    """Converts a WUA HRESULT to a human readable error message.

    Windows doesn't offer an automatic way to get an error message from a WUA HRESULT. This method is used to convert
    those results to a human readable error message based on the values extracted from wuerror.h from the Windows SDK.

    Args:
        hresult (int): The HRESULT to convert.

    Returns:
        (str): The error message for the HRESULT
    """
    # The code exists here so we don't have to transfer all this data when kicking off some updates.

    error_id, error_msg = {
        0x00240001: ('WU_S_SERVICE_STOP', 'Windows Update Agent was stopped successfully'),
        0x00240002: ('WU_S_SELFUPDATE', 'Windows Update Agent updated itself'),
        0x00240003: ('WU_S_UPDATE_ERROR', 'Operation completed successfully but there were errors applying the updates'),
        0x00240004: ('WU_S_MARKED_FOR_DISCONNECT', 'A callback was marked to be disconnected later because the request to disconnect the operation came while '
                                                   'a callback was executing'),
        0x00240005: ('WU_S_REBOOT_REQUIRED', 'The system must be restarted to complete installation of the update'),
        0x00240006: ('WU_S_ALREADY_INSTALLED', 'The update to be installed is already installed on the system'),
        0x00240007: ('WU_S_ALREADY_UNINSTALLED', 'The update to be removed is not installed on the system'),
        0x00240008: ('WU_S_ALREADY_DOWNLOADED', 'The update to be downloaded has already been downloaded'),
        0x00240009: ('WU_S_SOME_UPDATES_SKIPPED_ON_BATTERY', 'The operation completed successfully, but some updates were skipped because the system is '
                                                             'running on batteries'),
        0x0024000A: ('WU_S_ALREADY_REVERTED', 'The update to be reverted is not present on the system'),
        0x00240010: ('WU_S_SEARCH_CRITERIA_NOT_SUPPORTED', 'The operation is skipped because the update service does not support the requested search '
                                                           'criteria'),
        0x00242015: ('WU_S_UH_INSTALLSTILLPENDING', 'The installation operation for the update is still in progress'),
        0x00242016: ('WU_S_UH_DOWNLOAD_SIZE_CALCULATED', 'The actual download size has been calculated by the handler'),
        0x00245001: ('WU_S_SIH_NOOP', 'No operation was required by the server-initiated healing server response'),
        0x00246001: ('WU_S_DM_ALREADYDOWNLOADING', 'The update to be downloaded is already being downloaded'),
        0x00247101: ('WU_S_METADATA_SKIPPED_BY_ENFORCEMENTMODE', 'Metadata verification was skipped by enforcement mode'),
        0x00247102: ('WU_S_METADATA_IGNORED_SIGNATURE_VERIFICATION', 'A server configuration refresh resulted in metadata signature verification to be '
                                                                     'ignored'),
        0x00248001: ('WU_S_SEARCH_LOAD_SHEDDING', 'Search operation completed successfully but one or more services were shedding load'),
        0x80240001: ('WU_E_NO_SERVICE', 'Windows Update Agent was unable to provide the service'),
        0x80240002: ('WU_E_MAX_CAPACITY_REACHED', 'The maximum capacity of the service was exceeded'),
        0x80240003: ('WU_E_UNKNOWN_ID', 'An ID cannot be found'),
        0x80240004: ('WU_E_NOT_INITIALIZED', 'The object could not be initialized'),
        0x80240005: ('WU_E_RANGEOVERLAP', 'The update handler requested a byte range overlapping a previously requested range'),
        0x80240006: ('WU_E_TOOMANYRANGES', 'The requested number of byte ranges exceeds the maximum number (2^31 - 1)'),
        0x80240007: ('WU_E_INVALIDINDEX', 'The index to a collection was invalid'),
        0x80240008: ('WU_E_ITEMNOTFOUND', 'The key for the item queried could not be found'),
        0x80240009: ('WU_E_OPERATIONINPROGRESS', 'Another conflicting operation was in progress. Some operations such as installation cannot be performed '
                                                 'twice simultaneously'),
        0x8024000A: ('WU_E_COULDNOTCANCEL', 'Cancellation of the operation was not allowed'),
        0x8024000B: ('WU_E_CALL_CANCELLED', 'Operation was cancelled'),
        0x8024000C: ('WU_E_NOOP', 'No operation was required'),
        0x8024000D: ('WU_E_XML_MISSINGDATA', 'Windows Update Agent could not find required information in the update\'s XML data'),
        0x8024000E: ('WU_E_XML_INVALID', 'Windows Update Agent found invalid information in the update\'s XML data'),
        0x8024000F: ('WU_E_CYCLE_DETECTED', 'Circular update relationships were detected in the metadata'),
        0x80240010: ('WU_E_TOO_DEEP_RELATION', 'Update relationships too deep to evaluate were evaluated'),
        0x80240011: ('WU_E_INVALID_RELATIONSHIP', 'An invalid update relationship was detected'),
        0x80240012: ('WU_E_REG_VALUE_INVALID', 'An invalid registry value was read'),
        0x80240013: ('WU_E_DUPLICATE_ITEM', 'Operation tried to add a duplicate item to a list'),
        0x80240014: ('WU_E_INVALID_INSTALL_REQUESTED', 'Updates requested for install are not installable by caller'),
        0x80240016: ('WU_E_INSTALL_NOT_ALLOWED', 'Operation tried to install while another installation was in progress or the system was pending a '
                                                 'mandatory restart'),
        0x80240017: ('WU_E_NOT_APPLICABLE', 'Operation was not performed because there are no applicable updates'),
        0x80240018: ('WU_E_NO_USERTOKEN', 'Operation failed because a required user token is missing'),
        0x80240019: ('WU_E_EXCLUSIVE_INSTALL_CONFLICT', 'An exclusive update cannot be installed with other updates at the same time'),
        0x8024001A: ('WU_E_POLICY_NOT_SET', 'A policy value was not set'),
        0x8024001B: ('WU_E_SELFUPDATE_IN_PROGRESS', 'The operation could not be performed because the Windows Update Agent is self-updating'),
        0x8024001D: ('WU_E_INVALID_UPDATE', 'An update contains invalid metadata'),
        0x8024001E: ('WU_E_SERVICE_STOP', 'Operation did not complete because the service or system was being shut down'),
        0x8024001F: ('WU_E_NO_CONNECTION', 'Operation did not complete because the network connection was unavailable'),
        0x80240020: ('WU_E_NO_INTERACTIVE_USER', 'Operation did not complete because there is no logged-on interactive user'),
        0x80240021: ('WU_E_TIME_OUT', 'Operation did not complete because it timed out'),
        0x80240022: ('WU_E_ALL_UPDATES_FAILED', 'Operation failed for all the updates'),
        0x80240023: ('WU_E_EULAS_DECLINED', 'The license terms for all updates were declined'),
        0x80240024: ('WU_E_NO_UPDATE', 'There are no updates'),
        0x80240025: ('WU_E_USER_ACCESS_DISABLED', 'Group Policy settings prevented access to Windows Update'),
        0x80240026: ('WU_E_INVALID_UPDATE_TYPE', 'The type of update is invalid'),
        0x80240027: ('WU_E_URL_TOO_LONG', 'The URL exceeded the maximum length'),
        0x80240028: ('WU_E_UNINSTALL_NOT_ALLOWED', 'The update could not be uninstalled because the request did not originate from a WSUS server'),
        0x80240029: ('WU_E_INVALID_PRODUCT_LICENSE', 'Search may have missed some updates before there is an unlicensed application on the system'),
        0x8024002A: ('WU_E_MISSING_HANDLER', 'A component required to detect applicable updates was missing'),
        0x8024002B: ('WU_E_LEGACYSERVER', 'An operation did not complete because it requires a newer version of server'),
        0x8024002C: ('WU_E_BIN_SOURCE_ABSENT', 'A delta-compressed update could not be installed because it required the source'),
        0x8024002D: ('WU_E_SOURCE_ABSENT', 'A full-file update could not be installed because it required the source'),
        0x8024002E: ('WU_E_WU_DISABLED', 'Access to an unmanaged server is not allowed'),
        0x8024002F: ('WU_E_CALL_CANCELLED_BY_POLICY', 'Operation did not complete because the DisableWindowsUpdateAccess policy was set'),
        0x80240030: ('WU_E_INVALID_PROXY_SERVER', 'The format of the proxy list was invalid'),
        0x80240031: ('WU_E_INVALID_FILE', 'The file is in the wrong format'),
        0x80240032: ('WU_E_INVALID_CRITERIA', 'The search criteria string was invalid'),
        0x80240033: ('WU_E_EULA_UNAVAILABLE', 'License terms could not be downloaded'),
        0x80240034: ('WU_E_DOWNLOAD_FAILED', 'Update failed to download'),
        0x80240035: ('WU_E_UPDATE_NOT_PROCESSED', 'The update was not processed'),
        0x80240036: ('WU_E_INVALID_OPERATION', 'The object\'s current state did not allow the operation'),
        0x80240037: ('WU_E_NOT_SUPPORTED', 'The functionality for the operation is not supported'),
        0x80240038: ('WU_E_WINHTTP_INVALID_FILE', 'The downloaded file has an unexpected content type'),
        0x80240039: ('WU_E_TOO_MANY_RESYNC', 'Agent is asked by server to resync too many times'),
        0x80240040: ('WU_E_NO_SERVER_CORE_SUPPORT', 'WUA API method does not run on Server Core installation'),
        0x80240041: ('WU_E_SYSPREP_IN_PROGRESS', 'Service is not available while sysprep is running'),
        0x80240042: ('WU_E_UNKNOWN_SERVICE', 'The update service is no longer registered with AU'),
        0x80240043: ('WU_E_NO_UI_SUPPORT', 'There is no support for WUA UI'),
        0x80240044: ('WU_E_PER_MACHINE_UPDATE_ACCESS_DENIED', 'Only administrators can perform this operation on per-machine updates'),
        0x80240045: ('WU_E_UNSUPPORTED_SEARCHSCOPE', 'A search was attempted with a scope that is not currently supported for this type of search'),
        0x80240046: ('WU_E_BAD_FILE_URL', 'The URL does not point to a file'),
        0x80240047: ('WU_E_REVERT_NOT_ALLOWED', 'The update could not be reverted'),
        0x80240048: ('WU_E_INVALID_NOTIFICATION_INFO', 'The featured update notification info returned by the server is invalid'),
        0x80240049: ('WU_E_OUTOFRANGE', 'The data is out of range'),
        0x8024004A: ('WU_E_SETUP_IN_PROGRESS', 'Windows Update agent operations are not available while OS setup is running'),
        0x8024004B: ('WU_E_ORPHANED_DOWNLOAD_JOB', 'An orphaned downloadjob was found with no active callers'),
        0x8024004C: ('WU_E_LOW_BATTERY', 'An update could not be installed because the system battery power level is too low'),
        0x8024004D: ('WU_E_INFRASTRUCTUREFILE_INVALID_FORMAT', 'The downloaded infrastructure file is incorrectly formatted'),
        0x8024004E: ('WU_E_INFRASTRUCTUREFILE_REQUIRES_SSL', 'The infrastructure file must be downloaded using strong SSL'),
        0x8024004F: ('WU_E_IDLESHUTDOWN_OPCOUNT_DISCOVERY', 'A discovery call contributed to a non-zero operation count at idle timer shutdown'),
        0x80240050: ('WU_E_IDLESHUTDOWN_OPCOUNT_SEARCH', 'A search call contributed to a non-zero operation count at idle timer shutdown'),
        0x80240051: ('WU_E_IDLESHUTDOWN_OPCOUNT_DOWNLOAD', 'A download call contributed to a non-zero operation count at idle timer shutdown'),
        0x80240052: ('WU_E_IDLESHUTDOWN_OPCOUNT_INSTALL', 'An install call contributed to a non-zero operation count at idle timer shutdown'),
        0x80240053: ('WU_E_IDLESHUTDOWN_OPCOUNT_OTHER', 'An unspecified call contributed to a non-zero operation count at idle timer shutdown'),
        0x80240054: ('WU_E_INTERACTIVE_CALL_CANCELLED', 'An interactive user cancelled this operation, which was started from the Windows Update Agent UI'),
        0x80240055: ('WU_E_AU_CALL_CANCELLED', 'Automatic Updates cancelled this operation because it applies to an update that is no longer applicable to '
                                               'this computer'),
        0x80240056: ('WU_E_SYSTEM_UNSUPPORTED', 'This version or edition of the operating system doesn\'t support the needed functionality'),
        0x80240057: ('WU_E_NO_SUCH_HANDLER_PLUGIN', 'The requested update download or install handler, or update applicability expression evaluator, is not '
                                                    'provided by this Agent plugin'),
        0x80240058: ('WU_E_INVALID_SERIALIZATION_VERSION', 'The requested serialization version is not supported'),
        0x80240059: ('WU_E_NETWORK_COST_EXCEEDS_POLICY', 'The current network cost does not meet the conditions set by the network cost policy'),
        0x8024005A: ('WU_E_CALL_CANCELLED_BY_HIDE', 'The call is cancelled because it applies to an update that is hidden (no longer applicable to this '
                                                    'computer)'),
        0x8024005B: ('WU_E_CALL_CANCELLED_BY_INVALID', 'The call is cancelled because it applies to an update that is invalid (no longer applicable to this '
                                                       'computer)'),
        0x8024005C: ('WU_E_INVALID_VOLUMEID', 'The specified volume id is invalid'),
        0x8024005D: ('WU_E_UNRECOGNIZED_VOLUMEID', 'The specified volume id is unrecognized by the system'),
        0x8024005E: ('WU_E_EXTENDEDERROR_NOTSET', 'The installation extended error code is not specified'),
        0x8024005F: ('WU_E_EXTENDEDERROR_FAILED', 'The installation extended error code is set to general fail'),
        0x80240060: ('WU_E_IDLESHUTDOWN_OPCOUNT_SERVICEREGISTRATION', 'A service registration call contributed to a non-zero operation count at idle timer '
                                                                      'shutdown'),
        0x80240061: ('WU_E_FILETRUST_SHA2SIGNATURE_MISSING', 'Signature validation of the file fails to find valid SHA2+ signature on MS signed payload'),
        0x80240062: ('WU_E_UPDATE_NOT_APPROVED', 'The update is not in the servicing approval list'),
        0x80240063: ('WU_E_CALL_CANCELLED_BY_INTERACTIVE_SEARCH', 'The search call was cancelled by another interactive search against the same service'),
        0x80240064: ('WU_E_INSTALL_JOB_RESUME_NOT_ALLOWED', 'Resume of install job not allowed due to another installation in progress'),
        0x80240065: ('WU_E_INSTALL_JOB_NOT_SUSPENDED', 'Resume of install job not allowed because job is not suspended'),
        0x80240066: ('WU_E_INSTALL_USERCONTEXT_ACCESSDENIED', 'User context passed to installation from caller with insufficient privileges'),
        0x80240FFF: ('WU_E_UNEXPECTED', 'An operation failed due to reasons not covered by another error code'),
        0x80241001: ('WU_E_MSI_WRONG_VERSION', 'Search may have missed some updates because the Windows Installer is less than version 3.1'),
        0x80241002: ('WU_E_MSI_NOT_CONFIGURED', 'Search may have missed some updates because the Windows Installer is not configured'),
        0x80241003: ('WU_E_MSP_DISABLED', 'Search may have missed some updates because policy has disabled Windows Installer patching'),
        0x80241004: ('WU_E_MSI_WRONG_APP_CONTEXT', 'An update could not be applied because the application is installed per-user'),
        0x80241005: ('WU_E_MSI_NOT_PRESENT', 'Search may have missed some updates because the Windows Installer is less than version 3.1'),
        0x80241FFF: ('WU_E_MSP_UNEXPECTED', 'Search may have missed some updates because there was a failure of the Windows Installer'),
        0x80244000: ('WU_E_PT_SOAPCLIENT_BASE', 'WU_E_PT_SOAPCLIENT_* error codes map to the SOAPCLIENT_ERROR enum of the ATL Server Library'),
        0x80244001: ('WU_E_PT_SOAPCLIENT_INITIALIZE', 'Same as SOAPCLIENT_INITIALIZE_ERROR - initialization of the SOAP client failed, possibly because of '
                                                      'an MSXML installation failure'),
        0x80244002: ('WU_E_PT_SOAPCLIENT_OUTOFMEMORY', 'Same as SOAPCLIENT_OUTOFMEMORY - SOAP client failed because it ran out of memory'),
        0x80244003: ('WU_E_PT_SOAPCLIENT_GENERATE', 'Same as SOAPCLIENT_GENERATE_ERROR - SOAP client failed to generate the request'),
        0x80244004: ('WU_E_PT_SOAPCLIENT_CONNECT', 'Same as SOAPCLIENT_CONNECT_ERROR - SOAP client failed to connect to the server'),
        0x80244005: ('WU_E_PT_SOAPCLIENT_SEND', 'Same as SOAPCLIENT_SEND_ERROR - SOAP client failed to send a message for reasons of WU_E_WINHTTP_* error '
                                                'codes'),
        0x80244006: ('WU_E_PT_SOAPCLIENT_SERVER', 'Same as SOAPCLIENT_SERVER_ERROR - SOAP client failed because there was a server error'),
        0x80244007: ('WU_E_PT_SOAPCLIENT_SOAPFAULT', 'Same as SOAPCLIENT_SOAPFAULT - SOAP client failed because there was a SOAP fault for reasons of '
                                                     'WU_E_PT_SOAP_* error codes'),
        0x80244008: ('WU_E_PT_SOAPCLIENT_PARSEFAULT', 'Same as SOAPCLIENT_PARSEFAULT_ERROR - SOAP client failed to parse a SOAP fault'),
        0x80244009: ('WU_E_PT_SOAPCLIENT_READ', 'Same as SOAPCLIENT_READ_ERROR - SOAP client failed while reading the response from the server'),
        0x8024400A: ('WU_E_PT_SOAPCLIENT_PARSE', 'Same as SOAPCLIENT_PARSE_ERROR - SOAP client failed to parse the response from the server'),
        0x8024400B: ('WU_E_PT_SOAP_VERSION', 'Same as SOAP_E_VERSION_MISMATCH - SOAP client found an unrecognizable namespace for the SOAP envelope'),
        0x8024400C: ('WU_E_PT_SOAP_MUST_UNDERSTAND', 'Same as SOAP_E_MUST_UNDERSTAND - SOAP client was unable to understand a header'),
        0x8024400D: ('WU_E_PT_SOAP_CLIENT', 'Same as SOAP_E_CLIENT - SOAP client found the message was malformed; fix before resending'),
        0x8024400E: ('WU_E_PT_SOAP_SERVER', 'Same as SOAP_E_SERVER - The SOAP message could not be processed due to a server error; resend later'),
        0x8024400F: ('WU_E_PT_WMI_ERROR', 'There was an unspecified Windows Management Instrumentation (WMI) error'),
        0x80244010: ('WU_E_PT_EXCEEDED_MAX_SERVER_TRIPS', 'The number of round trips to the server exceeded the maximum limit'),
        0x80244011: ('WU_E_PT_SUS_SERVER_NOT_SET', 'WUServer policy value is missing in the registry'),
        0x80244012: ('WU_E_PT_DOUBLE_INITIALIZATION', 'Initialization failed because the object was already initialized'),
        0x80244013: ('WU_E_PT_INVALID_COMPUTER_NAME', 'The computer name could not be determined'),
        0x80244015: ('WU_E_PT_REFRESH_CACHE_REQUIRED', 'The reply from the server indicates that the server was changed or the cookie was invalid; refresh '
                                                       'the state of the internal cache and retry'),
        0x80244016: ('WU_E_PT_HTTP_STATUS_BAD_REQUEST', 'Same as HTTP status 400 - the server could not process the request due to invalid syntax'),
        0x80244017: ('WU_E_PT_HTTP_STATUS_DENIED', 'Same as HTTP status 401 - the requested resource requires user authentication'),
        0x80244018: ('WU_E_PT_HTTP_STATUS_FORBIDDEN', 'Same as HTTP status 403 - server understood the request, but declined to fulfill it'),
        0x80244019: ('WU_E_PT_HTTP_STATUS_NOT_FOUND', 'Same as HTTP status 404 - the server cannot find the requested URI (Uniform Resource Identifier)'),
        0x8024401A: ('WU_E_PT_HTTP_STATUS_BAD_METHOD', 'Same as HTTP status 405 - the HTTP method is not allowed'),
        0x8024401B: ('WU_E_PT_HTTP_STATUS_PROXY_AUTH_REQ', 'Same as HTTP status 407 - proxy authentication is required'),
        0x8024401C: ('WU_E_PT_HTTP_STATUS_REQUEST_TIMEOUT', 'Same as HTTP status 408 - the server timed out waiting for the request'),
        0x8024401D: ('WU_E_PT_HTTP_STATUS_CONFLICT', 'Same as HTTP status 409 - the request was not completed due to a conflict with the current state of '
                                                     'the resource'),
        0x8024401E: ('WU_E_PT_HTTP_STATUS_GONE', 'Same as HTTP status 410 - requested resource is no longer available at the server'),
        0x8024401F: ('WU_E_PT_HTTP_STATUS_SERVER_ERROR', 'Same as HTTP status 500 - an error internal to the server prevented fulfilling the request'),
        0x80244020: ('WU_E_PT_HTTP_STATUS_NOT_SUPPORTED', 'Same as HTTP status 500 - server does not support the functionality required to fulfill the '
                                                          'request'),
        0x80244021: ('WU_E_PT_HTTP_STATUS_BAD_GATEWAY', 'Same as HTTP status 502 - the server, while acting as a gateway or proxy, received an invalid '
                                                        'response from the upstream server it accessed in attempting to fulfill the request'),
        0x80244022: ('WU_E_PT_HTTP_STATUS_SERVICE_UNAVAIL', 'Same as HTTP status 503 - the service is temporarily overloaded'),
        0x80244023: ('WU_E_PT_HTTP_STATUS_GATEWAY_TIMEOUT', 'Same as HTTP status 503 - the request was timed out waiting for a gateway'),
        0x80244024: ('WU_E_PT_HTTP_STATUS_VERSION_NOT_SUP', 'Same as HTTP status 505 - the server does not support the HTTP protocol version used for the '
                                                            'request'),
        0x80244025: ('WU_E_PT_FILE_LOCATIONS_CHANGED', 'Operation failed due to a changed file location; refresh internal state and resend'),
        0x80244026: ('WU_E_PT_REGISTRATION_NOT_SUPPORTED', 'Operation failed because Windows Update Agent does not support registration with a non-WSUS '
                                                           'server'),
        0x80244027: ('WU_E_PT_NO_AUTH_PLUGINS_REQUESTED', 'The server returned an empty authentication information list'),
        0x80244028: ('WU_E_PT_NO_AUTH_COOKIES_CREATED', 'Windows Update Agent was unable to create any valid authentication cookies'),
        0x80244029: ('WU_E_PT_INVALID_CONFIG_PROP', 'A configuration property value was wrong'),
        0x8024402A: ('WU_E_PT_CONFIG_PROP_MISSING', 'A configuration property value was missing'),
        0x8024402B: ('WU_E_PT_HTTP_STATUS_NOT_MAPPED', 'The HTTP request could not be completed and the reason did not correspond to any of the '
                                                       'WU_E_PT_HTTP_* error codes'),
        0x8024402C: ('WU_E_PT_WINHTTP_NAME_NOT_RESOLVED', 'Same as ERROR_WINHTTP_NAME_NOT_RESOLVED - the proxy server or target server name cannot be '
                                                          'resolved'),
        0x8024402D: ('WU_E_PT_LOAD_SHEDDING', 'The server is shedding load'),
        0x8024502D: ('WU_E_PT_SAME_REDIR_ID', 'Windows Update Agent failed to download a redirector cabinet file with a new redirectorId value from the '
                                              'server during the recovery'),
        0x8024502E: ('WU_E_PT_NO_MANAGED_RECOVER', 'A redirector recovery action did not complete because the server is managed'),
        0x8024402F: ('WU_E_PT_ECP_SUCCEEDED_WITH_ERRORS', 'External cab file processing completed with some errors'),
        0x80244030: ('WU_E_PT_ECP_INIT_FAILED', 'The external cab processor initialization did not complete'),
        0x80244031: ('WU_E_PT_ECP_INVALID_FILE_FORMAT', 'The format of a metadata file was invalid'),
        0x80244032: ('WU_E_PT_ECP_INVALID_METADATA', 'External cab processor found invalid metadata'),
        0x80244033: ('WU_E_PT_ECP_FAILURE_TO_EXTRACT_DIGEST', 'The file digest could not be extracted from an external cab file'),
        0x80244034: ('WU_E_PT_ECP_FAILURE_TO_DECOMPRESS_CAB_FILE', 'An external cab file could not be decompressed'),
        0x80244035: ('WU_E_PT_ECP_FILE_LOCATION_ERROR', 'External cab processor was unable to get file locations'),
        0x80240436: ('WU_E_PT_CATALOG_SYNC_REQUIRED', 'The server does not support category-specific search; Full catalog search has to be issued instead'),
        0x80240437: ('WU_E_PT_SECURITY_VERIFICATION_FAILURE', 'There was a problem authorizing with the service'),
        0x80240438: ('WU_E_PT_ENDPOINT_UNREACHABLE', 'There is no route or network connectivity to the endpoint'),
        0x80240439: ('WU_E_PT_INVALID_FORMAT', 'The data received does not meet the data contract expectations'),
        0x8024043A: ('WU_E_PT_INVALID_URL', 'The url is invalid'),
        0x8024043B: ('WU_E_PT_NWS_NOT_LOADED', 'Unable to load NWS runtime'),
        0x8024043C: ('WU_E_PT_PROXY_AUTH_SCHEME_NOT_SUPPORTED', 'The proxy auth scheme is not supported'),
        0x8024043D: ('WU_E_SERVICEPROP_NOTAVAIL', 'The requested service property is not available'),
        0x8024043E: ('WU_E_PT_ENDPOINT_REFRESH_REQUIRED', 'The endpoint provider plugin requires online refresh'),
        0x8024043F: ('WU_E_PT_ENDPOINTURL_NOTAVAIL', 'A URL for the requested service endpoint is not available'),
        0x80240440: ('WU_E_PT_ENDPOINT_DISCONNECTED', 'The connection to the service endpoint died'),
        0x80240441: ('WU_E_PT_INVALID_OPERATION', 'The operation is invalid because protocol talker is in an inappropriate state'),
        0x80240442: ('WU_E_PT_OBJECT_FAULTED', 'The object is in a faulted state due to a previous error'),
        0x80240443: ('WU_E_PT_NUMERIC_OVERFLOW', 'The operation would lead to numeric overflow'),
        0x80240444: ('WU_E_PT_OPERATION_ABORTED', 'The operation was aborted'),
        0x80240445: ('WU_E_PT_OPERATION_ABANDONED', 'The operation was abandoned'),
        0x80240446: ('WU_E_PT_QUOTA_EXCEEDED', 'A quota was exceeded'),
        0x80240447: ('WU_E_PT_NO_TRANSLATION_AVAILABLE', 'The information was not available in the specified language'),
        0x80240448: ('WU_E_PT_ADDRESS_IN_USE', 'The address is already being used'),
        0x80240449: ('WU_E_PT_ADDRESS_NOT_AVAILABLE', 'The address is not valid for this context'),
        0x8024044A: ('WU_E_PT_OTHER', 'Unrecognized error occurred in the Windows Web Services framework'),
        0x8024044B: ('WU_E_PT_SECURITY_SYSTEM_FAILURE', 'A security operation failed in the Windows Web Services framework'),
        0x80244FFF: ('WU_E_PT_UNEXPECTED', 'A communication error not covered by another WU_E_PT_* error code'),
        0x80245001: ('WU_E_REDIRECTOR_LOAD_XML', 'The redirector XML document could not be loaded into the DOM class'),
        0x80245002: ('WU_E_REDIRECTOR_S_FALSE', 'The redirector XML document is missing some required information'),
        0x80245003: ('WU_E_REDIRECTOR_ID_SMALLER', 'The redirectorId in the downloaded redirector cab is less than in the cached cab'),
        0x80245004: ('WU_E_REDIRECTOR_UNKNOWN_SERVICE', 'The service ID is not supported in the service environment'),
        0x80245005: ('WU_E_REDIRECTOR_UNSUPPORTED_CONTENTTYPE', 'The response from the redirector server had an unsupported content type'),
        0x80245006: ('WU_E_REDIRECTOR_INVALID_RESPONSE', 'The response from the redirector server had an error status or was invalid'),
        0x80245008: ('WU_E_REDIRECTOR_ATTRPROVIDER_EXCEEDED_MAX_NAMEVALUE', 'The maximum number of name value pairs was exceeded by the attribute provider'),
        0x80245009: ('WU_E_REDIRECTOR_ATTRPROVIDER_INVALID_NAME', 'The name received from the attribute provider was invalid'),
        0x8024500A: ('WU_E_REDIRECTOR_ATTRPROVIDER_INVALID_VALUE', 'The value received from the attribute provider was invalid'),
        0x8024500B: ('WU_E_REDIRECTOR_SLS_GENERIC_ERROR', 'There was an error in connecting to or parsing the response from the Service Locator Service '
                                                          'redirector server'),
        0x8024500C: ('WU_E_REDIRECTOR_CONNECT_POLICY', 'Connections to the redirector server are disallowed by managed policy'),
        0x8024500D: ('WU_E_REDIRECTOR_ONLINE_DISALLOWED', 'The redirector would go online but is disallowed by caller configuration'),
        0x802450FF: ('WU_E_REDIRECTOR_UNEXPECTED', 'The redirector failed for reasons not covered by another WU_E_REDIRECTOR_* error code'),
        0x80245101: ('WU_E_SIH_VERIFY_DOWNLOAD_ENGINE', 'Verification of the servicing engine package failed'),
        0x80245102: ('WU_E_SIH_VERIFY_DOWNLOAD_PAYLOAD', 'Verification of a servicing package failed'),
        0x80245103: ('WU_E_SIH_VERIFY_STAGE_ENGINE', 'Verification of the staged engine failed'),
        0x80245104: ('WU_E_SIH_VERIFY_STAGE_PAYLOAD', 'Verification of a staged payload failed'),
        0x80245105: ('WU_E_SIH_ACTION_NOT_FOUND', 'An internal error occurred where the servicing action was not found'),
        0x80245106: ('WU_E_SIH_SLS_PARSE', 'There was a parse error in the service environment response'),
        0x80245107: ('WU_E_SIH_INVALIDHASH', 'A downloaded file failed an integrity check'),
        0x80245108: ('WU_E_SIH_NO_ENGINE', 'No engine was provided by the server-initiated healing server response'),
        0x80245109: ('WU_E_SIH_POST_REBOOT_INSTALL_FAILED', 'Post-reboot install failed'),
        0x8024510A: ('WU_E_SIH_POST_REBOOT_NO_CACHED_SLS_RESPONSE', 'There were pending reboot actions, but cached SLS response was not found post-reboot'),
        0x8024510B: ('WU_E_SIH_PARSE', 'Parsing command line arguments failed'),
        0x8024510C: ('WU_E_SIH_SECURITY', 'Security check failed'),
        0x8024510D: ('WU_E_SIH_PPL', 'PPL check failed'),
        0x8024510E: ('WU_E_SIH_POLICY', 'Execution was disabled by policy'),
        0x8024510F: ('WU_E_SIH_STDEXCEPTION', 'A standard exception was caught'),
        0x80245110: ('WU_E_SIH_NONSTDEXCEPTION', 'A non-standard exception was caught'),
        0x80245111: ('WU_E_SIH_ENGINE_EXCEPTION', 'The server-initiated healing engine encountered an exception not covered by another WU_E_SIH_* error code'),
        0x80245112: ('WU_E_SIH_BLOCKED_FOR_PLATFORM', 'You are running SIH Client with cmd not supported on your platform'),
        0x80245113: ('WU_E_SIH_ANOTHER_INSTANCE_RUNNING', 'Another SIH Client is already running'),
        0x80245114: ('WU_E_SIH_DNSRESILIENCY_OFF', 'Disable DNS resiliency feature per service configuration'),
        0x802451FF: ('WU_E_SIH_UNEXPECTED', 'There was a failure for reasons not covered by another WU_E_SIH_* error code'),
        0x8024C001: ('WU_E_DRV_PRUNED', 'A driver was skipped'),
        0x8024C002: ('WU_E_DRV_NOPROP_OR_LEGACY', 'A property for the driver could not be found. It may not conform with required specifications'),
        0x8024C003: ('WU_E_DRV_REG_MISMATCH', 'The registry type read for the driver does not match the expected type'),
        0x8024C004: ('WU_E_DRV_NO_METADATA', 'The driver update is missing metadata'),
        0x8024C005: ('WU_E_DRV_MISSING_ATTRIBUTE', 'The driver update is missing a required attribute'),
        0x8024C006: ('WU_E_DRV_SYNC_FAILED', 'Driver synchronization failed'),
        0x8024C007: ('WU_E_DRV_NO_PRINTER_CONTENT', 'Information required for the synchronization of applicable printers is missing'),
        0x8024C008: ('WU_E_DRV_DEVICE_PROBLEM', 'After installing a driver update, the updated device has reported a problem'),
        0x8024CFFF: ('WU_E_DRV_UNEXPECTED', 'A driver error not covered by another WU_E_DRV_* code'),
        0x80248000: ('WU_E_DS_SHUTDOWN', 'An operation failed because Windows Update Agent is shutting down'),
        0x80248001: ('WU_E_DS_INUSE', 'An operation failed because the data store was in use'),
        0x80248002: ('WU_E_DS_INVALID', 'The current and expected states of the data store do not match'),
        0x80248003: ('WU_E_DS_TABLEMISSING', 'The data store is missing a table'),
        0x80248004: ('WU_E_DS_TABLEINCORRECT', 'The data store contains a table with unexpected columns'),
        0x80248005: ('WU_E_DS_INVALIDTABLENAME', 'A table could not be opened because the table is not in the data store'),
        0x80248006: ('WU_E_DS_BADVERSION', 'The current and expected versions of the data store do not match'),
        0x80248007: ('WU_E_DS_NODATA', 'The information requested is not in the data store'),
        0x80248008: ('WU_E_DS_MISSINGDATA', 'The data store is missing required information or has a NULL in a table column that requires a non-null value'),
        0x80248009: ('WU_E_DS_MISSINGREF', 'The data store is missing required information or has a reference to missing license terms, file, localized '
                                           'property or linked row'),
        0x8024800A: ('WU_E_DS_UNKNOWNHANDLER', 'The update was not processed because its update handler could not be recognized'),
        0x8024800B: ('WU_E_DS_CANTDELETE', 'The update was not deleted because it is still referenced by one or more services'),
        0x8024800C: ('WU_E_DS_LOCKTIMEOUTEXPIRED', 'The data store section could not be locked within the allotted time'),
        0x8024800D: ('WU_E_DS_NOCATEGORIES', 'The category was not added because it contains no parent categories and is not a top-level category itself'),
        0x8024800E: ('WU_E_DS_ROWEXISTS', 'The row was not added because an existing row has the same primary key'),
        0x8024800F: ('WU_E_DS_STOREFILELOCKED', 'The data store could not be initialized because it was locked by another process'),
        0x80248010: ('WU_E_DS_CANNOTREGISTER', 'The data store is not allowed to be registered with COM in the current process'),
        0x80248011: ('WU_E_DS_UNABLETOSTART', 'Could not create a data store object in another process'),
        0x80248013: ('WU_E_DS_DUPLICATEUPDATEID', 'The server sent the same update to the client with two different revision IDs'),
        0x80248014: ('WU_E_DS_UNKNOWNSERVICE', 'An operation did not complete because the service is not in the data store'),
        0x80248015: ('WU_E_DS_SERVICEEXPIRED', 'An operation did not complete because the registration of the service has expired'),
        0x80248016: ('WU_E_DS_DECLINENOTALLOWED', 'A request to hide an update was declined because it is a mandatory update or because it was deployed with '
                                                  'a deadline'),
        0x80248017: ('WU_E_DS_TABLESESSIONMISMATCH', 'A table was not closed because it is not associated with the session'),
        0x80248018: ('WU_E_DS_SESSIONLOCKMISMATCH', 'A table was not closed because it is not associated with the session'),
        0x80248019: ('WU_E_DS_NEEDWINDOWSSERVICE', 'A request to remove the Windows Update service or to unregister it with Automatic Updates was declined '
                                                   'because it is a built-in service and/or Automatic Updates cannot fall back to another service'),
        0x8024801A: ('WU_E_DS_INVALIDOPERATION', 'A request was declined because the operation is not allowed'),
        0x8024801B: ('WU_E_DS_SCHEMAMISMATCH', 'The schema of the current data store and the schema of a table in a backup XML document do not match'),
        0x8024801C: ('WU_E_DS_RESETREQUIRED', 'The data store requires a session reset; release the session and retry with a new session'),
        0x8024801D: ('WU_E_DS_IMPERSONATED', 'A data store operation did not complete because it was requested with an impersonated identity'),
        0x8024801E: ('WU_E_DS_DATANOTAVAILABLE', 'An operation against update metadata did not complete because the data was never received from server'),
        0x8024801F: ('WU_E_DS_DATANOTLOADED', 'An operation against update metadata did not complete because the data was available but not loaded from '
                                              'datastore'),
        0x80248020: ('WU_E_DS_NODATA_NOSUCHREVISION', 'A data store operation did not complete because no such update revision is known'),
        0x80248021: ('WU_E_DS_NODATA_NOSUCHUPDATE', 'A data store operation did not complete because no such update is known'),
        0x80248022: ('WU_E_DS_NODATA_EULA', 'A data store operation did not complete because an update\'s EULA information is missing'),
        0x80248023: ('WU_E_DS_NODATA_SERVICE', 'A data store operation did not complete because a service\'s information is missing'),
        0x80248024: ('WU_E_DS_NODATA_COOKIE', 'A data store operation did not complete because a service\'s synchronization information is missing'),
        0x80248025: ('WU_E_DS_NODATA_TIMER', 'A data store operation did not complete because a timer\'s information is missing'),
        0x80248026: ('WU_E_DS_NODATA_CCR', 'A data store operation did not complete because a download\'s information is missing'),
        0x80248027: ('WU_E_DS_NODATA_FILE', 'A data store operation did not complete because a file\'s information is missing'),
        0x80248028: ('WU_E_DS_NODATA_DOWNLOADJOB', 'A data store operation did not complete because a download job\'s information is missing'),
        0x80248029: ('WU_E_DS_NODATA_TMI', 'A data store operation did not complete because a service\'s timestamp information is missing'),
        0x80248FFF: ('WU_E_DS_UNEXPECTED', 'A data store error not covered by another WU_E_DS_* code'),
        0x80249001: ('WU_E_INVENTORY_PARSEFAILED', 'Parsing of the rule file failed'),
        0x80249002: ('WU_E_INVENTORY_GET_INVENTORY_TYPE_FAILED', 'Failed to get the requested inventory type from the server'),
        0x80249003: ('WU_E_INVENTORY_RESULT_UPLOAD_FAILED', 'Failed to upload inventory result to the server'),
        0x80249004: ('WU_E_INVENTORY_UNEXPECTED', 'There was an inventory error not covered by another error code'),
        0x80249005: ('WU_E_INVENTORY_WMI_ERROR', 'A WMI error occurred when enumerating the instances for a particular class'),
        0x8024A000: ('WU_E_AU_NOSERVICE', 'Automatic Updates was unable to service incoming requests'),
        0x8024A002: ('WU_E_AU_NONLEGACYSERVER', 'The old version of the Automatic Updates client has stopped because the WSUS server has been upgraded'),
        0x8024A003: ('WU_E_AU_LEGACYCLIENTDISABLED', 'The old version of the Automatic Updates client was disabled'),
        0x8024A004: ('WU_E_AU_PAUSED', 'Automatic Updates was unable to process incoming requests because it was paused'),
        0x8024A005: ('WU_E_AU_NO_REGISTERED_SERVICE', 'No unmanaged service is registered with AU'),
        0x8024A006: ('WU_E_AU_DETECT_SVCID_MISMATCH', 'The default service registered with AU changed during the search'),
        0x8024A007: ('WU_E_REBOOT_IN_PROGRESS', 'A reboot is in progress'),
        0x8024A008: ('WU_E_AU_OOBE_IN_PROGRESS', 'Automatic Updates can\'t process incoming requests while Windows Welcome is running'),
        0x8024AFFF: ('WU_E_AU_UNEXPECTED', 'An Automatic Updates error not covered by another WU_E_AU * code'),
        0x80242000: ('WU_E_UH_REMOTEUNAVAILABLE', 'A request for a remote update handler could not be completed because no remote process is available'),
        0x80242001: ('WU_E_UH_LOCALONLY', 'A request for a remote update handler could not be completed because the handler is local only'),
        0x80242002: ('WU_E_UH_UNKNOWNHANDLER', 'A request for an update handler could not be completed because the handler could not be recognized'),
        0x80242003: ('WU_E_UH_REMOTEALREADYACTIVE', 'A remote update handler could not be created because one already exists'),
        0x80242004: ('WU_E_UH_DOESNOTSUPPORTACTION', 'A request for the handler to install (uninstall) an update could not be completed because the update '
                                                     'does not support install (uninstall)'),
        0x80242005: ('WU_E_UH_WRONGHANDLER', 'An operation did not complete because the wrong handler was specified'),
        0x80242006: ('WU_E_UH_INVALIDMETADATA', 'A handler operation could not be completed because the update contains invalid metadata'),
        0x80242007: ('WU_E_UH_INSTALLERHUNG', 'An operation could not be completed because the installer exceeded the time limit'),
        0x80242008: ('WU_E_UH_OPERATIONCANCELLED', 'An operation being done by the update handler was cancelled'),
        0x80242009: ('WU_E_UH_BADHANDLERXML', 'An operation could not be completed because the handler-specific metadata is invalid'),
        0x8024200A: ('WU_E_UH_CANREQUIREINPUT', 'A request to the handler to install an update could not be completed because the update requires user input'),
        0x8024200B: ('WU_E_UH_INSTALLERFAILURE', 'The installer failed to install (uninstall) one or more updates'),
        0x8024200C: ('WU_E_UH_FALLBACKTOSELFCONTAINED', 'The update handler should download self-contained content rather than delta-compressed content for '
                                                        'the update'),
        0x8024200D: ('WU_E_UH_NEEDANOTHERDOWNLOAD', 'The update handler did not install the update because it needs to be downloaded again'),
        0x8024200E: ('WU_E_UH_NOTIFYFAILURE', 'The update handler failed to send notification of the status of the install (uninstall) operation'),
        0x8024200F: ('WU_E_UH_INCONSISTENT_FILE_NAMES', 'The file names contained in the update metadata and in the update package are inconsistent'),
        0x80242010: ('WU_E_UH_FALLBACKERROR', 'The update handler failed to fall back to the self-contained content'),
        0x80242011: ('WU_E_UH_TOOMANYDOWNLOADREQUESTS', 'The update handler has exceeded the maximum number of download requests'),
        0x80242012: ('WU_E_UH_UNEXPECTEDCBSRESPONSE', 'The update handler has received an unexpected response from CBS'),
        0x80242013: ('WU_E_UH_BADCBSPACKAGEID', 'The update metadata contains an invalid CBS package identifier'),
        0x80242014: ('WU_E_UH_POSTREBOOTSTILLPENDING', 'The post-reboot operation for the update is still in progress'),
        0x80242015: ('WU_E_UH_POSTREBOOTRESULTUNKNOWN', 'The result of the post-reboot operation for the update could not be determined'),
        0x80242016: ('WU_E_UH_POSTREBOOTUNEXPECTEDSTATE', 'The state of the update after its post-reboot operation has completed is unexpected'),
        0x80242017: ('WU_E_UH_NEW_SERVICING_STACK_REQUIRED', 'The OS servicing stack must be updated before this update is downloaded or installed'),
        0x80242018: ('WU_E_UH_CALLED_BACK_FAILURE', 'A callback installer called back with an error'),
        0x80242019: ('WU_E_UH_CUSTOMINSTALLER_INVALID_SIGNATURE', 'The custom installer signature did not match the signature required by the update'),
        0x8024201A: ('WU_E_UH_UNSUPPORTED_INSTALLCONTEXT', 'The installer does not support the installation configuration'),
        0x8024201B: ('WU_E_UH_INVALID_TARGETSESSION', 'The targeted session for install is invalid'),
        0x8024201C: ('WU_E_UH_DECRYPTFAILURE', 'The handler failed to decrypt the update files'),
        0x8024201D: ('WU_E_UH_HANDLER_DISABLEDUNTILREBOOT', 'The update handler is disabled until the system reboots'),
        0x8024201E: ('WU_E_UH_APPX_NOT_PRESENT', 'The AppX infrastructure is not present on the system'),
        0x8024201F: ('WU_E_UH_NOTREADYTOCOMMIT', 'The update cannot be committed because it has not been previously installed or staged'),
        0x80242020: ('WU_E_UH_APPX_INVALID_PACKAGE_VOLUME', 'The specified volume is not a valid AppX package volume'),
        0x80242021: ('WU_E_UH_APPX_DEFAULT_PACKAGE_VOLUME_UNAVAILABLE', 'The configured default storage volume is unavailable'),
        0x80242022: ('WU_E_UH_APPX_INSTALLED_PACKAGE_VOLUME_UNAVAILABLE', 'The volume on which the application is installed is unavailable'),
        0x80242023: ('WU_E_UH_APPX_PACKAGE_FAMILY_NOT_FOUND', 'The specified package family is not present on the system'),
        0x80242024: ('WU_E_UH_APPX_SYSTEM_VOLUME_NOT_FOUND', 'Unable to find a package volume marked as system'),
        0x80242FFF: ('WU_E_UH_UNEXPECTED', 'An update handler error not covered by another WU_E_UH_* code'),
        0x80246001: ('WU_E_DM_URLNOTAVAILABLE', 'A download manager operation could not be completed because the requested file does not have a URL'),
        0x80246002: ('WU_E_DM_INCORRECTFILEHASH', 'A download manager operation could not be completed because the file digest was not recognized'),
        0x80246003: ('WU_E_DM_UNKNOWNALGORITHM', 'A download manager operation could not be completed because the file metadata requested an unrecognized '
                                                 'hash algorithm'),
        0x80246004: ('WU_E_DM_NEEDDOWNLOADREQUEST', 'An operation could not be completed because a download request is required from the download handler'),
        0x80246005: ('WU_E_DM_NONETWORK', 'A download manager operation could not be completed because the network connection was unavailable'),
        0x80246006: ('WU_E_DM_WRONGBITSVERSION', 'A download manager operation could not be completed because the version of Background Intelligent Transfer '
                                                 'Service (BITS) is incompatible'),
        0x80246007: ('WU_E_DM_NOTDOWNLOADED', 'The update has not been downloaded'),
        0x80246008: ('WU_E_DM_FAILTOCONNECTTOBITS', 'A download manager operation failed because the download manager was unable to connect the Background '
                                                    'Intelligent Transfer Service (BITS)'),
        0x80246009: ('WU_E_DM_BITSTRANSFERERROR', 'A download manager operation failed because there was an unspecified Background Intelligent Transfer '
                                                  'Service (BITS) transfer error'),
        0x8024600A: ('WU_E_DM_DOWNLOADLOCATIONCHANGED', 'A download must be restarted because the location of the source of the download has changed'),
        0x8024600B: ('WU_E_DM_CONTENTCHANGED', 'A download must be restarted because the update content changed in a new revision'),
        0x8024600C: ('WU_E_DM_DOWNLOADLIMITEDBYUPDATESIZE', 'A download failed because the current network limits downloads by update size for the '
                                                            'update service'),
        0x8024600E: ('WU_E_DM_UNAUTHORIZED', 'The download failed because the client was denied authorization to download the content'),
        0x8024600F: ('WU_E_DM_BG_ERROR_TOKEN_REQUIRED', 'The download failed because the user token associated with the BITS job no longer exists'),
        0x80246010: ('WU_E_DM_DOWNLOADSANDBOXNOTFOUND', 'The sandbox directory for the downloaded update was not found'),
        0x80246011: ('WU_E_DM_DOWNLOADFILEPATHUNKNOWN', 'The downloaded update has an unknown file path'),
        0x80246012: ('WU_E_DM_DOWNLOADFILEMISSING', 'One or more of the files for the downloaded update is missing'),
        0x80246013: ('WU_E_DM_UPDATEREMOVED', 'An attempt was made to access a downloaded update that has already been removed'),
        0x80246014: ('WU_E_DM_READRANGEFAILED', 'Windows Update couldn\'t find a needed portion of a downloaded update\'s file'),
        0x80246016: ('WU_E_DM_UNAUTHORIZED_NO_USER', 'The download failed because the client was denied authorization to download the content due to no user '
                                                     'logged on'),
        0x80246017: ('WU_E_DM_UNAUTHORIZED_LOCAL_USER', 'The download failed because the local user was denied authorization to download the content'),
        0x80246018: ('WU_E_DM_UNAUTHORIZED_DOMAIN_USER', 'The download failed because the domain user was denied authorization to download the content'),
        0x80246019: ('WU_E_DM_UNAUTHORIZED_MSA_USER', 'The download failed because the MSA account associated with the user was denied authorization to '
                                                      'download the content'),
        0x8024601A: ('WU_E_DM_FALLINGBACKTOBITS', 'The download will be continued by falling back to BITS to download the content'),
        0x8024601B: ('WU_E_DM_DOWNLOAD_VOLUME_CONFLICT', 'Another caller has requested download to a different volume'),
        0x8024601C: ('WU_E_DM_SANDBOX_HASH_MISMATCH', 'The hash of the update\'s sandbox does not match the expected value'),
        0x8024601D: ('WU_E_DM_HARDRESERVEID_CONFLICT', 'The hard reserve id specified conflicts with an id from another caller'),
        0x8024601E: ('WU_E_DM_DOSVC_REQUIRED', 'The update has to be downloaded via DO'),
        0x80246FFF: ('WU_E_DM_UNEXPECTED', 'There was a download manager error not covered by another WU_E_DM_* error code'),
        0x8024D001: ('WU_E_SETUP_INVALID_INFDATA', 'Windows Update Agent could not be updated because an INF file contains invalid information'),
        0x8024D002: ('WU_E_SETUP_INVALID_IDENTDATA', 'Windows Update Agent could not be updated because the wuident.cab file contains invalid information'),
        0x8024D003: ('WU_E_SETUP_ALREADY_INITIALIZED', 'Windows Update Agent could not be updated because of an internal error that caused setup '
                                                       'initialization to be performed twice'),
        0x8024D004: ('WU_E_SETUP_NOT_INITIALIZED', 'Windows Update Agent could not be updated because setup initialization never completed successfully'),
        0x8024D005: ('WU_E_SETUP_SOURCE_VERSION_MISMATCH', 'Windows Update Agent could not be updated because the versions specified in the INF do not match '
                                                           'the actual source file versions'),
        0x8024D006: ('WU_E_SETUP_TARGET_VERSION_GREATER', 'Windows Update Agent could not be updated because a WUA file on the target system is newer than '
                                                          'the corresponding source file'),
        0x8024D007: ('WU_E_SETUP_REGISTRATION_FAILED', 'Windows Update Agent could not be updated because regsvr32.exe returned an error'),
        0x8024D008: ('WU_E_SELFUPDATE_SKIP_ON_FAILURE', 'An update to the Windows Update Agent was skipped because previous attempts to update have failed'),
        0x8024D009: ('WU_E_SETUP_SKIP_UPDATE', 'An update to the Windows Update Agent was skipped due to a directive in the wuident.cab file'),
        0x8024D00A: ('WU_E_SETUP_UNSUPPORTED_CONFIGURATION', 'Windows Update Agent could not be updated because the current system configuration is not '
                                                             'supported'),
        0x8024D00B: ('WU_E_SETUP_BLOCKED_CONFIGURATION', 'Windows Update Agent could not be updated because the system is configured to block the update'),
        0x8024D00C: ('WU_E_SETUP_REBOOT_TO_FIX', 'Windows Update Agent could not be updated because a restart of the system is required'),
        0x8024D00D: ('WU_E_SETUP_ALREADYRUNNING', 'Windows Update Agent setup is already running'),
        0x8024D00E: ('WU_E_SETUP_REBOOTREQUIRED', 'Windows Update Agent setup package requires a reboot to complete installation'),
        0x8024D00F: ('WU_E_SETUP_HANDLER_EXEC_FAILURE', 'Windows Update Agent could not be updated because the setup handler failed during execution'),
        0x8024D010: ('WU_E_SETUP_INVALID_REGISTRY_DATA', 'Windows Update Agent could not be updated because the registry contains invalid information'),
        0x8024D011: ('WU_E_SELFUPDATE_REQUIRED', 'Windows Update Agent must be updated before search can continue'),
        0x8024D012: ('WU_E_SELFUPDATE_REQUIRED_ADMIN', 'Windows Update Agent must be updated before search can continue.  An administrator is required to '
                                                       'perform the operation'),
        0x8024D013: ('WU_E_SETUP_WRONG_SERVER_VERSION', 'Windows Update Agent could not be updated because the server does not contain update information '
                                                        'for this version'),
        0x8024D014: ('WU_E_SETUP_DEFERRABLE_REBOOT_PENDING', 'Windows Update Agent is successfully updated, but a reboot is required to complete the setup'),
        0x8024D015: ('WU_E_SETUP_NON_DEFERRABLE_REBOOT_PENDING', 'Windows Update Agent is successfully updated, but a reboot is required to complete the '
                                                                 'setup'),
        0x8024D016: ('WU_E_SETUP_FAIL', 'Windows Update Agent could not be updated because of an unknown error'),
        0x8024DFFF: ('WU_E_SETUP_UNEXPECTED', 'Windows Update Agent could not be updated because of an error not covered by another WU_E_SETUP_* error code'),
        0x8024E001: ('WU_E_EE_UNKNOWN_EXPRESSION', 'An expression evaluator operation could not be completed because an expression was unrecognized'),
        0x8024E002: ('WU_E_EE_INVALID_EXPRESSION', 'An expression evaluator operation could not be completed because an expression was invalid'),
        0x8024E003: ('WU_E_EE_MISSING_METADATA', 'An expression evaluator operation could not be completed because an expression contains an incorrect '
                                                 'number of metadata nodes'),
        0x8024E004: ('WU_E_EE_INVALID_VERSION', 'An expression evaluator operation could not be completed because the version of the serialized expression '
                                                'data is invalid'),
        0x8024E005: ('WU_E_EE_NOT_INITIALIZED', 'The expression evaluator could not be initialized'),
        0x8024E006: ('WU_E_EE_INVALID_ATTRIBUTEDATA', 'An expression evaluator operation could not be completed because there was an invalid attribute'),
        0x8024E007: ('WU_E_EE_CLUSTER_ERROR', 'An expression evaluator operation could not be completed because the cluster state of the computer could not '
                                              'be determined'),
        0x8024EFFF: ('WU_E_EE_UNEXPECTED', 'There was an expression evaluator error not covered by another WU_E_EE_* error code'),
        0x80243001: ('WU_E_INSTALLATION_RESULTS_UNKNOWN_VERSION', 'The results of download and installation could not be read from the registry due to an '
                                                                  'unrecognized data format version'),
        0x80243002: ('WU_E_INSTALLATION_RESULTS_INVALID_DATA', 'The results of download and installation could not be read from the registry due to an '
                                                               'invalid data format'),
        0x80243003: ('WU_E_INSTALLATION_RESULTS_NOT_FOUND', 'The results of download and installation are not available; the operation may have failed to '
                                                            'start'),
        0x80243004: ('WU_E_TRAYICON_FAILURE', 'A failure occurred when trying to create an icon in the taskbar notification area'),
        0x80243FFD: ('WU_E_NON_UI_MODE', 'Unable to show UI when in non-UI mode; WU client UI modules may not be installed'),
        0x80243FFE: ('WU_E_WUCLTUI_UNSUPPORTED_VERSION', 'Unsupported version of WU client UI exported functions'),
        0x80243FFF: ('WU_E_AUCLIENT_UNEXPECTED', 'There was a user interface error not covered by another WU_E_AUCLIENT_* error code'),
        0x8024F001: ('WU_E_REPORTER_EVENTCACHECORRUPT', 'The event cache file was defective'),
        0x8024F002: ('WU_E_REPORTER_EVENTNAMESPACEPARSEFAILED', 'The XML in the event namespace descriptor could not be parsed'),
        0x8024F003: ('WU_E_INVALID_EVENT', 'The XML in the event namespace descriptor could not be parsed'),
        0x8024F004: ('WU_E_SERVER_BUSY', 'The server rejected an event because the server was too busy'),
        0x8024F005: ('WU_E_CALLBACK_COOKIE_NOT_FOUND', 'The specified callback cookie is not found'),
        0x8024FFFF: ('WU_E_REPORTER_UNEXPECTED', 'There was a reporter error not covered by another error code'),
        0x80247001: ('WU_E_OL_INVALID_SCANFILE', 'An operation could not be completed because the scan package was invalid'),
        0x80247002: ('WU_E_OL_NEWCLIENT_REQUIRED', 'An operation could not be completed because the scan package requires a greater version of the Windows '
                                                   'Update Agent'),
        0x80247003: ('WU_E_INVALID_EVENT_PAYLOAD', 'An invalid event payload was specified'),
        0x80247004: ('WU_E_INVALID_EVENT_PAYLOADSIZE', 'The size of the event payload submitted is invalid'),
        0x80247005: ('WU_E_SERVICE_NOT_REGISTERED', 'The service is not registered'),
        0x80247FFF: ('WU_E_OL_UNEXPECTED', 'Search using the scan package failed'),
        0x80247100: ('WU_E_METADATA_NOOP', 'No operation was required by update metadata verification'),
        0x80247101: ('WU_E_METADATA_CONFIG_INVALID_BINARY_ENCODING', 'The binary encoding of metadata config data was invalid'),
        0x80247102: ('WU_E_METADATA_FETCH_CONFIG', 'Unable to fetch required configuration for metadata signature verification'),
        0x80247104: ('WU_E_METADATA_INVALID_PARAMETER', 'A metadata verification operation failed due to an invalid parameter'),
        0x80247105: ('WU_E_METADATA_UNEXPECTED', 'A metadata verification operation failed due to reasons not covered by another error code'),
        0x80247106: ('WU_E_METADATA_NO_VERIFICATION_DATA', 'None of the update metadata had verification data, which may be disabled on the update server'),
        0x80247107: ('WU_E_METADATA_BAD_FRAGMENTSIGNING_CONFIG', 'The fragment signing configuration used for verifying update metadata signatures was bad'),
        0x80247108: ('WU_E_METADATA_FAILURE_PROCESSING_FRAGMENTSIGNING_CONFIG', 'There was an unexpected operational failure while parsing fragment signing '
                                                                                'configuration'),
        0x80247120: ('WU_E_METADATA_XML_MISSING', 'Required xml data was missing from configuration'),
        0x80247121: ('WU_E_METADATA_XML_FRAGMENTSIGNING_MISSING', 'Required fragmentsigning data was missing from xml configuration'),
        0x80247122: ('WU_E_METADATA_XML_MODE_MISSING', 'Required mode data was missing from xml configuration'),
        0x80247123: ('WU_E_METADATA_XML_MODE_INVALID', 'An invalid metadata enforcement mode was detected'),
        0x80247124: ('WU_E_METADATA_XML_VALIDITY_INVALID', 'An invalid timestamp validity window configuration was detected'),
        0x80247125: ('WU_E_METADATA_XML_LEAFCERT_MISSING', 'Required leaf certificate data was missing from xml configuration'),
        0x80247126: ('WU_E_METADATA_XML_INTERMEDIATECERT_MISSING', 'Required intermediate certificate data was missing from xml configuration'),
        0x80247127: ('WU_E_METADATA_XML_LEAFCERT_ID_MISSING', 'Required leaf certificate id attribute was missing from xml configuration'),
        0x80247128: ('WU_E_METADATA_XML_BASE64CERDATA_MISSING', 'Required certificate base64CerData attribute was missing from xml configuration'),
        0x80247140: ('WU_E_METADATA_BAD_SIGNATURE', 'The metadata for an update was found to have a bad or invalid digital signature'),
        0x80247141: ('WU_E_METADATA_UNSUPPORTED_HASH_ALG', 'An unsupported hash algorithm for metadata verification was specified'),
        0x80247142: ('WU_E_METADATA_SIGNATURE_VERIFY_FAILED', 'An error occurred during an update\'s metadata signature verification'),
        0x80247150: ('WU_E_METADATATRUST_CERTIFICATECHAIN_VERIFICATION', 'An failure occurred while verifying trust for metadata signing certificate chains'),
        0x80247151: ('WU_E_METADATATRUST_UNTRUSTED_CERTIFICATECHAIN', 'A metadata signing certificate had an untrusted certificate chain'),
        0x80247160: ('WU_E_METADATA_TIMESTAMP_TOKEN_MISSING', 'An expected metadata timestamp token was missing'),
        0x80247161: ('WU_E_METADATA_TIMESTAMP_TOKEN_VERIFICATION_FAILED', 'A metadata Timestamp token failed verification'),
        0x80247162: ('WU_E_METADATA_TIMESTAMP_TOKEN_UNTRUSTED', 'A metadata timestamp token signer certificate chain was untrusted'),
        0x80247163: ('WU_E_METADATA_TIMESTAMP_TOKEN_VALIDITY_WINDOW', 'A metadata signature timestamp token was no longer within the validity window'),
        0x80247164: ('WU_E_METADATA_TIMESTAMP_TOKEN_SIGNATURE', 'A metadata timestamp token failed signature validation'),
        0x80247165: ('WU_E_METADATA_TIMESTAMP_TOKEN_CERTCHAIN', 'A metadata timestamp token certificate failed certificate chain verification'),
        0x80247166: ('WU_E_METADATA_TIMESTAMP_TOKEN_REFRESHONLINE', 'A failure occurred when refreshing a missing timestamp token from the network'),
        0x80247167: ('WU_E_METADATA_TIMESTAMP_TOKEN_ALL_BAD', 'All update metadata verification timestamp tokens from the timestamp token cache are invalid'),
        0x80247168: ('WU_E_METADATA_TIMESTAMP_TOKEN_NODATA', 'No update metadata verification timestamp tokens exist in the timestamp token cache'),
        0x80247169: ('WU_E_METADATA_TIMESTAMP_TOKEN_CACHELOOKUP', 'An error occurred during cache lookup of update metadata verification timestamp token'),
        0x8024717E: ('WU_E_METADATA_TIMESTAMP_TOKEN_VALIDITYWINDOW_UNEXPECTED', 'An metadata timestamp token validity window failed unexpectedly due to '
                                                                                'reasons not covered by another error code'),
        0x8024717F: ('WU_E_METADATA_TIMESTAMP_TOKEN_UNEXPECTED', 'An metadata timestamp token verification operation failed due to reasons not covered by '
                                                                 'another error code'),
        0x80247180: ('WU_E_METADATA_CERT_MISSING', 'An expected metadata signing certificate was missing'),
        0x80247181: ('WU_E_METADATA_LEAFCERT_BAD_TRANSPORT_ENCODING', 'The transport encoding of a metadata signing leaf certificate was malformed'),
        0x80247182: ('WU_E_METADATA_INTCERT_BAD_TRANSPORT_ENCODING', 'The transport encoding of a metadata signing intermediate certificate was malformed'),
        0x80247183: ('WU_E_METADATA_CERT_UNTRUSTED', 'A metadata certificate chain was untrusted'),
        0x8024B001: ('WU_E_WUTASK_INPROGRESS', 'The task is currently in progress'),
        0x8024B002: ('WU_E_WUTASK_STATUS_DISABLED', 'The operation cannot be completed since the task status is currently disabled'),
        0x8024B003: ('WU_E_WUTASK_NOT_STARTED', 'The operation cannot be completed since the task is not yet started'),
        0x8024B004: ('WU_E_WUTASK_RETRY', 'The task was stopped and needs to be run again to complete'),
        0x8024B005: ('WU_E_WUTASK_CANCELINSTALL_DISALLOWED', 'Cannot cancel a non-scheduled install'),
        0x8024B101: ('WU_E_UNKNOWN_HARDWARECAPABILITY', 'Hardware capability meta data was not found after a sync with the service'),
        0x8024B102: ('WU_E_BAD_XML_HARDWARECAPABILITY', 'Hardware capability meta data was malformed and/or failed to parse'),
        0x8024B103: ('WU_E_WMI_NOT_SUPPORTED', 'Unable to complete action due to WMI dependency, which isn\'t supported on this platform'),
        0x8024B104: ('WU_E_UPDATE_MERGE_NOT_ALLOWED', 'Merging of the update is not allowed'),
        0x8024B105: ('WU_E_SKIPPED_UPDATE_INSTALLATION', 'Installing merged updates only. So skipping non mergeable updates'),
        0x8024B201: ('WU_E_SLS_INVALID_REVISION', 'SLS response returned invalid revision number'),
        0x8024B301: ('WU_E_FILETRUST_DUALSIGNATURE_RSA', 'File signature validation fails to find valid RSA signature on infrastructure payload'),
        0x8024B302: ('WU_E_FILETRUST_DUALSIGNATURE_ECC', 'File signature validation fails to find valid ECC signature on infrastructure payload'),
        0x8024B303: ('WU_E_TRUST_SUBJECT_NOT_TRUSTED', 'The subject is not trusted by WU for the specified action'),
        0x8024B304: ('WU_E_TRUST_PROVIDER_UNKNOWN', 'Unknown trust provider for WU'),
        0x8024B901: ('WU_E_RUXIM_EXCEPTION', 'An unexpected exception occurred during RUXIM processing'),
        0x8024B902: ('WU_E_RUXIM_LOGGINGCVERROR', 'An error occurred while processing the correlation vector during RUXIM logging'),
        0x8024B903: ('WU_E_RUXIM_UNEXPECTEDINTERACTIONRESPONSE', 'The RUXIM Interaction Handler returned an unexpected response while processing an '
                                                                 'interaction campaign'),
        0x8024B904: ('WU_E_RUXIM_INTERACTIONALREADYCOMPLETED', 'An attempt was made to present a RUXIM interaction campaign that is already completed'),
        0x8024B905: ('WU_E_RUXIM_STOREDSTATENOTAVAILABLE', 'RUXIM was unable to create or retrieve the stored state for an interaction campaign'),
        0x8024B906: ('WU_E_RUXIM_NOSUCHINTERACTIONCAMPAIGN', 'RUXIM was unable to retrieve the requested interaction campaign'),
        0x8024B91F: ('WU_E_RUXIM_UNEXPECTED', 'An unexpected failure occurred during RUXIM processing'),
        0x8024B920: ('WU_E_RUXIM_ICSPEC_INVALIDFORMAT', 'The RUXIM interaction campaign specification does not have the expected XML format'),
        0x8024B921: ('WU_E_RUXIM_ICSPEC_MISSINGCONTROLCUSTOMIZATION', 'The RUXIM interaction campaign specification does not have a control customization '
                                                                      'for one or more controls in the interaction'),
        0x8024B922: ('WU_E_RUXIM_ICSPEC_NOSUITABLELOCALIZATION', 'The RUXIM interaction campaign specification does not have localized resources that match '
                                                                 'the user\'s preferred languages'),
        0x8024B923: ('WU_E_RUXIM_ICSPEC_COMMANDLINETOOLONG', 'The RUXIM interaction campaign specification specifies an immediate action, and the command '
                                                             'line set for that immediate action is too long'),
        0x8024B924: ('WU_E_RUXIM_ICSPEC_DIRECTORYPATHTOOLONG', 'The RUXIM interaction campaign specification specifies an immediate action, and the current '
                                                               'directory set for that immediate action is too long'),
        0x8024B925: ('WU_E_RUXIM_ICSPEC_PARAMETEROUTOFRANGE', 'The RUXIM interaction campaign specification includes a parameter that is too large or too '
                                                              'small'),
        0x8024B93F: ('WU_E_RUXIM_ICSPEC_UNEXPECTED', 'An unexpected problem occurred while processing an interaction campaign specification'),
        0x8024B940: ('WU_E_RUXIM_ICO_NOREMAININGCAMPAIGNS', 'There are no more interaction campaigns remaining to evaluate'),
        0x8024B950: ('WU_E_RUXIM_ICS_IHRESULTUNKNOWN', 'Interaction Campaign Scheduler launched Interaction Handler to process a campaign, but Interaction '
                                                       'Handler did not report its result'),
        0x8024B9C0: ('WU_E_EVALUATOR_UNKNOWNCHECKHANDLERNAME', 'The evaluation request includes a check handler name which the Evaluator DLL does not '
                                                               'support'),
        0x8024B9C1: ('WU_E_EVALUATOR_UNKNOWNCHECKNAME', 'The evaluation request includes a check name which the Evaluator DLL does not support'),
        0x8024B9C2: ('WU_E_EVALUATOR_UNKNOWNCOMPARISON', 'The evaluation request includes a comparison which the Evaluator DLL does not support'),
        0x8024B9C3: ('WU_E_EVALUATOR_MISFORMATTEDCHECKNAME', 'The evaluation request includes a check node whose check node is not in the format '
                                                             '\'checkhandlername:checkname\''),
        0x8024B9C4: ('WU_E_EVALUATOR_INVALIDCHECKPARAMETERS', 'The evaluation request includes a check which requires parameters, and one of those '
                                                              'parameters is missing or in an unexpected format'),
        0x8024B9C5: ('WU_E_EVALUATOR_INVALIDNOT', 'The evaluation request includes a \'not\' attribute on a check which does not return a Boolean value'),
        0x8024B9FF: ('WU_E_EVALUATOR_UNEXPECTED', 'An unexpected error occurred while processing an evaluation request'),
    }.get(hresult, ('UNKNOWN', 'Unknown WUA HRESULT %s' % hresult))

    return '%s (%s %08X)' % (error_msg, error_id, hresult)


class _ReturnResultException(Exception):
    """Used to sneak results back to the return dict from an exception"""

    def __init__(self, msg, **result):
        super(_ReturnResultException, self).__init__(msg)
        self.result = result


class _RecreateTempPathException(Exception):
    pass


class ActionModule(ActionBase):

    _VALID_ARGS = [
        'accept_list', 'whitelist',
        'category_names',
        'log_path',
        'reboot',
        'skip_optional',
        'reboot_timeout',
        'reject_list', 'blacklist',
        'server_selection',
        'state',
        'use_scheduled_task',
    ]

    DEFAULT_REBOOT_TIMEOUT = 1200

    def __init__(self, *args, **kwargs):
        super(ActionModule, self).__init__(*args, **kwargs)
        self._invocation = None
        # Raw information on all the updates found in the current result. The key is the update_id (GUID).
        self._updates = {}

        # Key for the following is the update_id.
        self._selected_updates = set()  # Updates that passed the selection criteria
        self._filtered_updates = {}  # Updates that were filtered and the reasons why it was filtered
        self._download_results = {}  # Updates that were downloaded and the result
        self._install_results = {}  # Updates that were installed and the result

    def run(self, tmp=None, task_vars=None):
        self._supports_check_mode = True
        self._supports_async = True

        super(ActionModule, self).run(tmp, task_vars)
        del tmp  # tmp no longer has any effect
        task_vars = task_vars or {}

        for dep_arg in ['whitelist', 'blacklist', 'use_scheduled_task']:
            if dep_arg in self._task.args:
                dep_msg = "'%s' is deprecated. See the module docs for more information" % dep_arg
                display.deprecated(dep_msg, date="2023-06-01", collection_name="ansible.windows")

        try:
            reboot = check_type_bool(self._task.args.get('reboot', False))
        except TypeError as e:
            raise AnsibleActionFail("Invalid value given for 'reboot': %s." % to_native(e))

        try:
            reboot_timeout = check_type_int(self._task.args.get('reboot_timeout', self.DEFAULT_REBOOT_TIMEOUT))
        except TypeError as e:
            raise AnsibleActionFail("Invalid value given for 'reboot_timeout': %s." % to_native(e))

        module_options = self._task.args.copy()

        if self._task.async_val > 0:
            if reboot:
                raise AnsibleActionFail("async is not supported for this task when reboot=yes")

            # When running in async the module itself waits for the result and formats the results.
            module_options['_wait'] = True
            module_options['_output_path'] = None
            result = self._execute_module(
                module_name='ansible.windows.win_updates',
                module_args=module_options,
                task_vars=task_vars,
            )

        else:
            module_options['_wait'] = False

            try:
                result = self._run_sync(task_vars, module_options, reboot, reboot_timeout)
            except Exception as e:
                result = {}
                if isinstance(e, _ReturnResultException):
                    result.update(e.result)

                if isinstance(e, AnsibleConnectionFailure):
                    result['unreachable'] = True
                else:
                    result['failed'] = True

                result['msg'] = to_text(e)
                if not result.get('exception', None):
                    result['exception'] = traceback.format_exc()

            # Build the final results to return to the caller.
            result['found_update_count'] = 0
            result['failed_update_count'] = 0
            result['installed_update_count'] = 0
            result['updates'] = {}
            result['filtered_updates'] = {}
            for update_id in self._selected_updates:
                update_info = self._get_update_info(update_id)
                result['updates'][update_id] = update_info
                result['found_update_count'] += 1

                if 'failure_hresult_code' in update_info:
                    result['failed_update_count'] += 1

                elif update_info['installed']:
                    result['installed_update_count'] += 1

            for update_id, reasons in self._filtered_updates.items():
                update_info = self._get_update_info(update_id)

                # filtered_reason is deprecated in favour of filtered_reasons, we also need to use whitelist/blacklist
                # for backwards compatibility - remove after 2023-06-01.
                dep_reason = reasons[0]
                if dep_reason == 'accept_list':
                    dep_reason = 'whitelist'
                elif dep_reason == 'reject_list':
                    dep_reason = 'blacklist'
                update_info['filtered_reason'] = dep_reason

                update_info['filtered_reasons'] = reasons

                result['filtered_updates'][update_id] = update_info

        if self._invocation and 'invocation' not in result:
            result['invocation'] = self._invocation

        # Remove _wait in the invocation args to avoid confusing users
        if 'invocation' in result and 'module_args' in result['invocation']:
            result['invocation']['module_args'].pop('_wait', None)
            result['invocation']['module_args'].pop('_output_path', None)

        return result

    def _run_sync(self, task_vars, module_options, reboot, reboot_timeout):  # type: (Dict, Dict, bool, int) -> Dict
        """Installs the updates in a synchronous fashion with multiple update invocations if needed."""
        # In case we are running with become we need to make sure the module uses the correct dir
        module_options['_output_path'], poll_script_path, cancel_script_path = self._setup_updates_tmpdir()

        result = {
            'changed': False,
            'reboot_required': False,
            'rebooted': False,
        }
        has_rebooted_on_failure = False
        round = 0
        while True:
            round += 1
            display.v("Running win_updates - round %s" % round, host=task_vars.get('inventory_hostname', None))

            try:
                update_result = self._run_updates(task_vars, module_options, poll_script_path, cancel_script_path)
            except _RecreateTempPathException:
                display.vv("Failure when running win_updates module with existing tempdir, retrying with new dir")
                self._connection._shell.tmpdir = None
                module_options['_output_path'], poll_script_path, cancel_script_path = self._setup_updates_tmpdir()

                continue

            self._updates.update(update_result.updates)
            self._filtered_updates.update(update_result.filtered_updates)
            self._selected_updates.update(update_result.selected_updates)
            self._download_results.update(update_result.download_results)
            self._install_results.update(update_result.install_results)

            reboot_required = result['reboot_required'] = update_result.reboot_required
            if update_result.changed:
                result['changed'] = True

            if update_result.failed:
                msg = update_result.msg
                if update_result.hresult:
                    msg += " - " + _get_hresult_error(update_result.hresult)

                # A failure could indicate a reboot was required from a previous install or just a faulty WUA. When
                # reboot=True we should at least attempt to reboot once before considering it a failure.
                if reboot and not has_rebooted_on_failure:
                    display.vv("Failure when running win_updates module (Will retry after reboot): %s" % msg,
                               host=task_vars.get('inventory_hostname', None))
                    reboot_required = True
                    has_rebooted_on_failure = True

                else:
                    result['failed'] = True
                    result['msg'] = msg
                    result['exception'] = update_result.exception
                    break

            elif reboot:
                # Clear the previous failure flag as the last update was successful.
                has_rebooted_on_failure = False

            if reboot_required and reboot:
                display.v("Rebooting host after installing updates", host=task_vars.get('inventory_hostname', None))
                if self._play_context.check_mode:
                    reboot_res = {'failed': False}

                else:
                    reboot_res = reboot_host(self._task.action, self._connection, reboot_timeout=reboot_timeout)

                result['rebooted'] = True

                if reboot_res['failed']:
                    msg = 'Failed to reboot host'
                    if 'msg' in reboot_res:
                        msg += ': ' + str(reboot_res['msg'])
                    reboot_res['msg'] = msg

                    result.update(reboot_res)
                    break

                result['changed'] = True
                result['reboot_required'] = False

            if (
                not reboot or
                self._play_context.check_mode or
                module_options.get('state', 'installed') != 'installed' or
                (not reboot_required and len(update_result.selected_updates) == 0)
            ):
                # If reboot=False, in check mode, not installing, and no further updates were found on the last round,
                # then break from the loop as we are done.
                break

        return result

    def _setup_updates_tmpdir(self):
        """Sets up a remote tmpdir if needed and copies the files used by the action plugin."""
        if not self._connection._shell.tmpdir:
            self._make_tmp_path()  # Stores the update scheduled task script/progress

        poll_script_path = self._copy_script(_POLL_SCRIPT, 'poll.ps1')
        cancel_script_path = self._copy_script(_CANCEL_SCRIPT, 'cancel.ps1')

        return self._connection._shell.tmpdir, poll_script_path, cancel_script_path

    def _run_updates(self, task_vars, module_options, poll_script_path, cancel_script_path):
        # type: (Dict, Dict, str, str) -> UpdateResult
        """Runs the win_updates module and returns the raw results from that task."""
        inventory_hostname = task_vars.get('inventory_hostname', None)

        display.vv("Starting update task", host=inventory_hostname)
        output_path, task_pid, cancel_id = self._start_updates(task_vars, module_options)

        display.vv("Starting polling for update results", host=inventory_hostname)
        update_result = UpdateResult()
        offset = 0

        try:
            while offset != -1:
                entries, offset = self._poll_result(poll_script_path, output_path, offset)

                for progress in entries:
                    task = progress['task']
                    update_result.process_result(task, progress['result'], inventory_hostname)

                    if task == 'exit':
                        offset = -1

        except Exception as e:
            # Try our best to cancel the update task on an unknown failure.
            display.warning("Unknown failure when polling update result - attempting to cancel task: %s" % to_text(e))
            self._execute_script(cancel_script_path, {"CancelId": cancel_id, "TaskPid": task_pid})

            raise

        return update_result

    def _start_updates(self, task_vars, module_options):  # type: (Dict, Dict) -> Tuple[str, int, str]
        """Starts the win_updates scheduled task and returns the output results path."""
        result = self._execute_module(
            module_name='ansible.windows.win_updates',
            module_args=module_options,
            task_vars=task_vars,
        )

        if 'invocation' in result and not self._invocation:
            # First run through we want to update the invocation value in the final results
            self._invocation = result['invocation']

        failed = result.get('failed', False)
        if failed and result.get('recreate_tmpdir', False):
            # Might have been deleted across a reboot, try to recreate for the next run.
            # https://github.com/ansible-collections/ansible.windows/issues/417
            raise _RecreateTempPathException()

        if (
            failed or
            'output_path' not in result or
            'task_pid' not in result or
            'cancel_id' not in result
        ):
            msg = result.get('msg', 'Unknown failure when running win_updates')

            extra_result = {}
            if 'rc' in result:
                extra_result['rc'] = result['rc']
            if 'stdout' in result:
                extra_result['stdout'] = result['stdout']
            if 'stderr' in result:
                extra_result['stderr'] = result['stderr']
            raise _ReturnResultException(msg, exception=result.get('exception', None), **extra_result)

        return result['output_path'], result['task_pid'], result['cancel_id']

    def _poll_result(self, script_path, output_path, offset):  # type: (str, str, int) -> Tuple[List[Dict], int]
        """Reads the update scheduled task output results path and returns any new results."""
        rc, stdout, stderr = self._execute_script(script_path, {'OutputPath': output_path, 'Offset': offset})

        if rc != 0:
            msg = "Failed to poll update task, see rc, stdout, stderr for more info"
            raise _ReturnResultException(msg, rc=rc, stdout=stdout, stderr=stderr)

        # https://github.com/ansible-collections/ansible.windows/issues/477
        # We can't rely on the output containing newlines so use JSONDecoder to
        # stream the JSON objects until there is nothing left
        stdout = stdout.lstrip()
        decoder = json.JSONDecoder()

        entries = []
        offset = 0
        while stdout:
            try:
                entry, pos = decoder.raw_decode(stdout)
            except getattr(json.decoder, 'JSONDecodeError', ValueError) as e:
                msg = 'Failed to decode poll result json: %s' % to_native(e)
                raise _ReturnResultException(msg, rc=rc, stdout=stdout, stderr=stderr)

            if list(entry.keys()) == ["position"]:
                offset = int(entry["position"])
            else:
                entries.append(entry)

            stdout = stdout[pos:].lstrip()

        return entries, offset

    def _execute_script(self, script, parameters):  # typing: (str, typing.Dict) -> Tuple[int, str, str]
        # The script is read from a file and executed as a scriptblock to avoid any execution policy shenanigans
        encoded_parameters = ' '.join(
            '-%s %s' % (k, v if isinstance(v, int) else quote_pwsh(v))
            for k, v in parameters.items()
        )
        cmd = '$cmd = Get-Content -LiteralPath %s -Raw; &([ScriptBlock]::Create($cmd)) %s' \
              % (quote_pwsh(script), encoded_parameters)
        return self._execute_command(cmd)

    def _execute_command(self, command):  # type: (str) -> Tuple[int, str, str]
        """Runs a command on the Windows host and returned the result"""
        # Need to wrap the command in our PowerShell encoded wrapper. This is done to align the command input to a
        # common shell and to allow the psrp connection plugin to report the correct exit code without manually setting
        # $LASTEXITCODE for just that plugin.
        command = self._connection._shell._encode_script(command)

        # FUTURE: Should we have a retry on a connection failure just in case an update brings the network down?
        rc, stdout, stderr = self._connection.exec_command(command, in_data=None, sudoable=False)
        rc = rc or 0
        stdout = to_text(stdout, errors='surrogate_or_strict').strip()
        stderr = to_text(stderr, errors='surrogate_or_strict').strip()

        return rc, stdout, stderr

    def _get_update_info(self, update_id):  # type: (str) -> Dict
        """Gets the update results info value to return."""
        raw_info = self._updates[update_id]
        info = {
            'title': raw_info['title'],
            'kb': [(v[2:] if v.startswith("KB") else v) for v in raw_info['kb']],
            'categories': raw_info['categories'],
            'id': update_id,
            'downloaded': False,
            'installed': False,
        }

        for action, results in [
            ('downloaded', self._download_results),
            ('installed', self._install_results),
        ]:
            action_info = results.get(update_id, None)
            if action_info:
                if action_info['result_code'] == 2:
                    info[action] = True

                else:
                    info['failure_hresult_code'] = action_info['hresult']
                    info['failure_msg'] = _get_hresult_error(action_info['hresult'])

        return info

    def _copy_script(self, script, name):  # type: (str, str) -> str
        """Copes the script specified to the remote host"""
        remote_path = self._connection._shell.join_path(self._connection._shell.tmpdir, name)
        b_local_tempdir = tempfile.mkdtemp(dir=to_bytes(C.DEFAULT_LOCAL_TMP, errors='surrogate_or_strict'))
        try:
            b_local_script = os.path.join(b_local_tempdir, to_bytes(name))
            with open(b_local_script, 'wb') as f:
                f.write(to_bytes(script, errors='surrogate_or_strict'))

            self._transfer_file(to_text(b_local_script, errors='surrogate_or_strict'), remote_path)
        finally:
            shutil.rmtree(b_local_tempdir)

        return remote_path


class UpdateResult:

    def __init__(self):
        self.updates = {}
        self.filtered_updates = {}
        self.selected_updates = set()
        self.download_results = {}
        self.install_results = {}
        self.changed = False
        self.reboot_required = False
        self.failed = False
        self.msg = None
        self.exception = None
        self.hresult = None

        self._update_display_fired = 25

    def process_result(self, task, result, inventory_hostname):  # type: (str, Dict, Optional[str]) -> None
        """ Process the progress result and store it in a structured object. """
        if task == 'search_result':
            self._process_search_result(result)

        elif task in ['download', 'install']:
            self._process_download_install_progress(task, result, inventory_hostname)

        elif task in ['download_result', 'install_result']:
            self._process_download_install_result(task, result, inventory_hostname)

        elif task == 'exit':
            self._process_exit(result, inventory_hostname)

    def _process_search_result(self, result):
        self.updates = dict((u['id'], u) for u in result['updates'])
        self.filtered_updates = dict((u['id'], u['reasons']) for u in result['filtered'])

        for update in result['updates']:
            update_id = update['id']

            if update_id not in self.filtered_updates:
                self.selected_updates.add(update_id)

    def _process_download_install_progress(self, task, result, inventory_hostname):
        update_id = result['progress']['CurrentUpdateId']
        update = self.updates[update_id]
        total_percentage = result['progress']['PercentComplete']

        if task == 'download':
            current_phase = result['progress']['CurrentUpdateDownloadPhase']
            download_phase = {
                1: 'Initializing',
                2: 'Downloading',
                3: 'Verifying',
            }.get(current_phase, current_phase)

            msg = "Downlad progress - Total: {0}/{1} {2}%, Update ({3}): {4}/{5} {6}%, Phase: {7}".format(
                result['progress']['TotalBytesDownloaded'],
                result['progress']['TotalBytesToDownload'],
                total_percentage,
                update['title'],
                result['progress']['CurrentUpdateBytesDownloaded'],
                result['progress']['CurrentUpdateBytesToDownload'],
                result['progress']['CurrentUpdatePercentComplete'],
                download_phase,
            )

        else:
            msg = "Install progress - Total: {0}%, Update ({1}): {2}%".format(
                total_percentage,
                update['title'],
                result['progress']['CurrentUpdatePercentComplete'],
            )

        # This is very chatty, only display every 25% of the total completion - rest goes to debug.
        # FUTURE: Always display once we can do host specific progress updates
        if total_percentage >= self._update_display_fired:
            display.vv(msg, host=inventory_hostname)
            while self._update_display_fired <= total_percentage:
                self._update_display_fired += 25

        display.debug(msg, host=inventory_hostname)

    def _process_download_install_result(self, task, result, inventory_hostname):
        phase = task[:-7]
        display.vv("Update phase %s completed" % phase, host=inventory_hostname)
        self._update_display_fired = 25  # Reset for the install phase

        total_results = self.download_results if phase == 'download' else self.install_results
        for result_info in result['info']:
            # HRESULT values returned from pwsh are signed, we compare with unsigned ints in Python.
            result_info['hresult'] = result_info['hresult'] & 0xFFFFFFFF
            total_results[result_info.pop('id')] = result_info

    def _process_exit(self, result, inventory_hostname):
        display.vv("Received final progress result from update task", host=inventory_hostname)

        self.changed = result['changed']
        self.reboot_required = result['reboot_required']
        self.failed = result['failed']

        if result.get('exception', None):
            self.msg = result['exception']['message']
            self.exception = result['exception'].get('exception', None)
            if 'hresult' in result['exception']:
                self.hresult = result['exception']['hresult'] & 0xFFFFFFFF
