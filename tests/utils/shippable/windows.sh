#!/usr/bin/env bash

set -o pipefail -eux

declare -a args
IFS='/:' read -ra args <<< "$1"

version="${args[1]}"

if [ "${#args[0]}" -gt 2 ]; then
    target="shippable/windows/group${args[2]}/"
else
    target="shippable/windows/"
fi

stage="${S:-prod}"
provider="${P:-default}"

# shellcheck disable=SC2086
ansible-test windows-integration --color -v --retry-on-error "${target}" ${COVERAGE:+"$COVERAGE"} ${CHANGED:+"$CHANGED"} ${UNSTABLE:+"$UNSTABLE"} \
    --windows "${version}" --docker default --remote-terminate always --remote-stage "${stage}" --remote-provider "${provider}"
