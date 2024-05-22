#!/usr/bin/env bash

set -o pipefail -eux

# This is aligned with the galaxy-importer used by AH
# https://github.com/ansible/galaxy-importer/blob/d4b5e6d12088ba452f129f4824bd049be5543358/setup.cfg#L22C4-L22C33
python -m pip install \
    'ansible-lint>=6.2.2,<=6.22.1'

ansible-lint
