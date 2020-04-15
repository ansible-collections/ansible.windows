# Copyright (c) 2020 Ansible Project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)
# -*- coding: utf-8 -*-

from __future__ import absolute_import, division, print_function
__metaclass__ = type

import pytest
import re

from ansible.errors import AnsibleFilterError
from ansible_collections.ansible.windows.plugins.filter.quote import quote


def test_invalid_shell_type():
    expected = "Invalid shell specified, valid shell are None, 'cmd', or 'powershell'"
    with pytest.raises(AnsibleFilterError, match=re.escape(expected)):
        quote('abc', shell='fake')


@pytest.mark.parametrize('value, expected', [
    # https://docs.microsoft.com/en-us/cpp/c-language/parsing-c-command-line-arguments?view=vs-2019
    (['a b c', 'd', 'e'], r'"a b c" d e'),
    (['ab"c', '\\', 'd'], r'"ab\"c" \ d'),
    ([r'a\\\b', 'de fg', 'h'], r'a\\\b "de fg" h'),
    ([r'a\\b c', 'd', 'e'], r'"a\\b c" d e'),
    # http://daviddeley.com/autohotkey/parameters/parameters.htm#WINCREATE
    ('CallMeIshmael', r'CallMeIshmael'),
    ('Call Me Ishmael', r'"Call Me Ishmael"'),
    ('CallMe"Ishmael', r'"CallMe\"Ishmael"'),
    ('Call Me Ishmael\\', r'"Call Me Ishmael\\"'),
    (r'CallMe\"Ishmael', r'"CallMe\\\"Ishmael"'),
    (r'a\\\b', r'a\\\b'),
    ('C:\\TEST A\\', r'"C:\TEST A\\"'),
    (r'"C:\TEST A\"', r'"\"C:\TEST A\\\""'),
    # Other tests
    (['C:\\Program Files\\file\\', 'arg with " quote'], r'"C:\Program Files\file\\" "arg with \" quote"'),
    ({'key': 'abc'}, r'key=abc'),
    ({'KEY2': 'a b c'}, r'KEY2="a b c"'),
    ({'Key3': r'a\\b c \" def "'}, r'Key3="a\\b c \\\" def \""'),
    ('{"a": ["b", "c' + "'" + ' d", "d\\"e"], "f": "g\\\\\\"g\\\\i\\""}',
     '"{\\"a\\": [\\"b\\", \\"c' + "'" + ' d\\", \\"d\\\\\\"e\\"], \\"f\\": \\"g\\\\\\\\\\\\\\"g\\\\i\\\\\\"\\"}"'),
    (None, '""'),
    ('', '""'),
    (['', None, ''], '"" "" ""'),
])
def test_quote_c(value, expected):
    actual = quote(value)
    assert expected == actual


@pytest.mark.parametrize('value, expected', [
    ('arg1', 'arg1'),
    (None, '""'),
    ('', '""'),
    ('arg1 and 2', '^"arg1 and 2^"'),
    ('malicious argument\\"&whoami', '^"malicious argument\\\\^"^&whoami^"'),
    ('C:\\temp\\some ^%file% > nul', '^"C:\\temp\\some ^^^%file^% ^> nul^"'),
])
def test_quote_cmd(value, expected):
    actual = quote(value, shell='cmd')
    assert expected == actual


@pytest.mark.parametrize('value, expected', [
    ('arg1', "'arg1'"),
    (None, "''"),
    ('', "''"),
    ('Double " quotes', "'Double \" quotes'"),
    ("Single ' quotes", "'Single '' quotes'"),
    ("'Multiple '''' single '' quotes '", "'''Multiple '''''''' single '''' quotes '''"),
    (u"a'b\u2018c\u2019d\u201ae\u201bf", u"'a''b\u2018\u2018c\u2019\u2019d\u201a\u201ae\u201b\u201bf'")
])
def test_quote_powershell(value, expected):
    actual = quote(value, shell='powershell')
    assert expected == actual
