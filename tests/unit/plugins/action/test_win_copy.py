# -*- coding: utf-8 -*-
# Copyright: Contributors to the Ansible project
# GNU General Public License v3.0+ (see COPYING or https://www.gnu.org/licenses/gpl-3.0.txt)

from ansible_collections.ansible.windows.plugins.action import win_copy


def test_walk_dirs_with_symlink(mocker):
    mocker.patch("os.path.islink", return_value=True)
    mocker.patch("os.readlink", return_value="/path/to/real/file.txt")
    mocker.patch("os.path.basename", return_value="file.txt")

    ret = win_copy._walk_dirs("/path/to/symlink", loader=None, local_follow=False)
    expected = {
        "directories": [],
        "files": [],
        "symlinks": [
            {
                "dest": "file.txt",
                "src": "/path/to/real/file.txt",
            }
        ],
    }
    assert ret == expected
