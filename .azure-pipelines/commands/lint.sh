#!/usr/bin/env bash

set -o pipefail -eux

# This is aligned with the galaxy-importer used by AH.
# Use this script to get the galaxy-importer setup.cfg URL.
# VERSION=$( curl -s https://galaxy.ansible.com/api/ | jq -r '.galaxy_importer_version' )
# echo "https://github.com/ansible/galaxy-importer/blob/v${VERSION}/setup.cfg"
# Then check the ansible-lint upper bound to specify here.

python -m pip install \
    'ansible-lint==25.5.0'

ansible-lint
