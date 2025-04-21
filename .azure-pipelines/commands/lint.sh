#!/usr/bin/env bash

set -o pipefail -eux

# This is aligned with the galaxy-importer used by AH.
# Check what galaxy_importer_version is used in the galaxy project at
# https://galaxy.ansible.com/api/

# Then check the ansible-lint upper bound at
# https://github.com/ansible/galaxy-importer/blob/v${VERSION}/setup.cfg

python -m pip install \
    'ansible-lint==25.1.2'

ansible-lint
