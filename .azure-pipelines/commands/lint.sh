#!/usr/bin/env bash

set -o pipefail -eux

# This is aligned with the galaxy-importer used by AH.
# Need to pin to the released tag at.
# https://github.com/ansible/galaxy_ng/blob/master/requirements/requirements.common.txt
#
# The galaxy_ng_commit from can be used to find the specific commit to check.
# https://galaxy.ansible.com/api/
python -m pip install \
    'ansible-lint==24.7.0' \
    'ansible-compat==24.10.0'

ansible-lint
