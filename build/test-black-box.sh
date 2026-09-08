#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
COMPOSE_FILE="${PROJ_ROOT}/src/Tests/BlackBox/docker-compose.tests.yaml"

cleanup() {
    local status=$?
    local cleanup_status=0
    local image_cleanup_status=0
    trap - EXIT

    docker compose -p orders-blackbox -f "${COMPOSE_FILE}" \
        down --volumes --remove-orphans || cleanup_status=$?

    # Restrict image cleanup to supporting services so supplied API images survive.
    docker compose -p orders-blackbox -f - down --rmi local <<'COMPOSE' || image_cleanup_status=$?
services:
  orders_test_pg_db:
    build: .
  orders_api_tests:
    build: .
COMPOSE

    if [ "${cleanup_status}" -eq 0 ]; then
        cleanup_status=${image_cleanup_status}
    fi

    # A failed build may never have produced the standalone API image.
    if [ -z "${ORDERS_API_IMAGE:-}" ] && docker image inspect orders-api:blackbox >/dev/null 2>&1; then
        image_cleanup_status=0
        docker image rm orders-api:blackbox || image_cleanup_status=$?
        if [ "${cleanup_status}" -eq 0 ]; then
            cleanup_status=${image_cleanup_status}
        fi
    fi

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
    else
        docker compose -p orders-blackbox -f "${COMPOSE_FILE}" \
            build
    fi

    docker compose -p orders-blackbox -f "${COMPOSE_FILE}" \
        up --detach --no-build --pull never orders_test_pg_db orders_test_api

    # Let the test client finish and report its own status even if the API exits.
    docker compose -p orders-blackbox -f "${COMPOSE_FILE}" \
        run --rm --no-deps --pull never -T orders_api_tests
}

main "$@"
