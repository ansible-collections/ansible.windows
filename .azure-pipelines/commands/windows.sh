#!/usr/bin/env bash

set -o pipefail -eux

declare -a args
IFS='/:' read -ra args <<< "$1"

version="${args[1]}"
connection="${args[2]}"
connection_setting="${args[3]}"
powershell="${args[4]}"

if [ "${#args[0]}" -gt 5 ]; then
    target="shippable/windows/group${args[5]}/"
else
    target="shippable/windows/"
fi

# powershell=... was added in 2.21, we need to only set it if the default
# of 5.1 was not specified. This can be removed once we drop support for 2.20
# and older.
powershell_opt=""
if [ "${powershell}" != "5.1" ]; then
    powershell_opt=",powershell=${powershell}"
fi

stage="${S:-prod}"
provider="${P:-default}"

# shellcheck disable=SC2086
ansible-test windows-integration --color -v --retry-on-error "${target}" ${COVERAGE:+"$COVERAGE"} ${CHANGED:+"$CHANGED"} ${UNSTABLE:+"$UNSTABLE"} \
    --controller "docker:default" \
    --target "remote:windows/${version},connection=${connection}+${connection_setting},provider=${provider}${powershell_opt}" \
    --remote-terminate always --remote-stage "${stage}"
