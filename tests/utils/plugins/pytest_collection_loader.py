"""Enable unit testing of Ansible collections. PYTEST_DONT_REWRITE"""
from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

import os
import os.path
import sys


ANSIBLE_COLLECTIONS_PATH = os.path.abspath(os.path.join(__file__, '..', '..', '..', '..', '..', '..'))


# this monkeypatch to _pytest.pathlib.resolve_package_path fixes PEP420 resolution for collections in pytest >= 6.0.0
def collection_resolve_package_path(path):
    """Configure the Python package path so that pytest can find our collections."""
    for parent in path.parents:
        if str(parent) == ANSIBLE_COLLECTIONS_PATH:
            return parent

    raise Exception('File "%s" not found in collection path "%s".' % (path, ANSIBLE_COLLECTIONS_PATH))


def pytest_configure():
    """Configure this pytest plugin."""

    try:
        if pytest_configure.executed:
            return
    except AttributeError:
        pytest_configure.executed = True

    # If ANSIBLE_HOME is set make sure we add it to the PYTHONPATH to ensure it is picked up. Not all env vars are
    # picked up by vscode (.bashrc is a notable one) so a user can define it manually in their .env file.
    ansible_home = os.environ.get('ANSIBLE_HOME', None)
    if ansible_home:
        sys.path.insert(0, os.path.join(ansible_home, 'lib'))

    from ansible.utils.collection_loader._collection_finder import _AnsibleCollectionFinder

    # allow unit tests to import code from collections

    # noinspection PyProtectedMember
    _AnsibleCollectionFinder(paths=[os.path.dirname(ANSIBLE_COLLECTIONS_PATH)])._install()  # pylint: disable=protected-access

    # noinspection PyProtectedMember
    from _pytest import pathlib as pytest_pathlib
    pytest_pathlib.resolve_package_path = collection_resolve_package_path


pytest_configure()
