#!/bin/bash -xe
set -o pipefail

prep_suite () {
    render_jinja_templates
}

setup_ipv6() {
    export IPV6_ONLY=True
    export IPV6_SUBNET=$(python "${OST_REPO_ROOT}/he-basic-ipv6-suite-master/find_ipv6_subnet.py" \
    "$PREFIX" "lago-${SUITE##*/}-net-mgmt-ipv6")
}

run_suite(){
    local suite="${SUITE?}"
    local curdir="${PWD?}"
    declare failed=false
    env_init \
        "$1" \
        "$suite/LagoInitFile"
    env_start
    cd "$OST_REPO_ROOT"

    if [[ ${suite} == *"ipv6"* ]]; then
        setup_ipv6
    fi

    declare test_scenarios="${SUITE}/test-scenarios"

    "${PYTHON}" -m tox -e deps
    source "${OST_REPO_ROOT}/.tox/deps/bin/activate"

    env_run_pytest_bulk "$test_scenarios" || failed=true
    env_collect "$curdir/test_logs/${suite##*/}"
    if $failed; then
        echo "@@@@ ERROR: Failed running ${suite}"
        return 1
    fi
}
