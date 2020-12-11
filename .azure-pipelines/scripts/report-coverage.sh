#!/usr/bin/env bash
# Generate code coverage reports for uploading to Azure Pipelines and codecov.io.

set -o pipefail -eu

PATH="${PWD}/bin:${PATH}"

pip install https://github.com/ansible/ansible/archive/devel.tar.gz --disable-pip-version-check

ansible-test coverage xml --stub --venv --venv-system-site-packages --color -v
