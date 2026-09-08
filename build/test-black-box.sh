#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJ_ROOT}/src/Tests/BlackBox/docker-compose.tests.yaml"

cleanup() {
    local status=$?
    local cleanup_status=0
    trap - EXIT

    docker compose -p orders-blackbox -f "${COMPOSE_FILE}" \
        down --volumes --remove-orphans || cleanup_status=$?

    if [ "${status}" -eq 0 ]; then
        status=${cleanup_status}
    fi

    exit "${status}"
}

main() {
    if [ "$#" -ne 0 ]; then
        printf '%s\n' 'Usage: test-black-box.sh (no arguments)' >&2
        return 2
    fi

    if ! command -v docker >/dev/null 2>&1; then
        printf '%s\n' 'Error: docker is required to run black-box tests.' >&2
        return 1
    fi

    if [ ! -f "${COMPOSE_FILE}" ]; then
        printf 'Error: Compose file not found: %s\n' "${COMPOSE_FILE}" >&2
        return 1
    fi

    if [ -n "${ORDERS_API_IMAGE:-}" ]; then
        ORDERS_API_IMAGE=$(docker image inspect --format '{{.Id}}' "${ORDERS_API_IMAGE}")
        export ORDERS_API_IMAGE
        printf 'Running black-box tests against API image: %s\n' "${ORDERS_API_IMAGE}"
    fi

    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    if [ -n "${ORDERS_API_IMAGE:-}" ]; then
        docker compose -p orders-blackbox -f "${COMPOSE_FILE}" \
            build orders_test_pg_db orders_api_tests
        docker compose -p orders-blackbox -f "${COMPOSE_FILE}" \
            up --no-build --pull never --abort-on-container-exit --exit-code-from orders_api_tests
        return 0
    fi

    docker compose -p orders-blackbox -f "${COMPOSE_FILE}" \
        up --build --abort-on-container-exit --exit-code-from orders_api_tests
}

main "$@"
