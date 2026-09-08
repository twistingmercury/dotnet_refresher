#!/usr/bin/env bats

setup() {
    TEST_REPO="${BATS_TEST_TMPDIR}/repo with spaces"
    TEST_BIN="${BATS_TEST_TMPDIR}/bin"
    DOCKER_LOG="${BATS_TEST_TMPDIR}/docker.log"
    BASH_BIN="$(command -v bash)"
    IMAGE_LOG="${BATS_TEST_TMPDIR}/images.log"
    CLEANUP_CONFIG="${BATS_TEST_TMPDIR}/cleanup.yaml"
    export DOCKER_LOG IMAGE_LOG CLEANUP_CONFIG

    mkdir -p "${TEST_REPO}/build" "${TEST_REPO}/src/Tests/BlackBox" "${TEST_BIN}"
    cp "${BATS_TEST_DIRNAME}/../test-black-box.sh" "${TEST_REPO}/build/"
    COMPOSE_FILE="${TEST_REPO}/src/Tests/BlackBox/docker-compose.tests.yaml"
    touch "${COMPOSE_FILE}" "${DOCKER_LOG}" "${IMAGE_LOG}"

    cat > "${TEST_BIN}/docker" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '<%s>' "$@" >> "${DOCKER_LOG}"
printf '\n' >> "${DOCKER_LOG}"
if [ "${1}" = image ]; then
    if [ "${2}" = rm ]; then
        exit "${MOCK_RM_STATUS:-0}"
    fi
    if [ "${3}" = orders-api:blackbox ]; then
        exit "${MOCK_LOCAL_INSPECT_STATUS:-0}"
    fi
    printf '%s\n' 'sha256:resolved-image'
    exit "${MOCK_INSPECT_STATUS:-0}"
fi
printf 'image=<%s>\n' "${ORDERS_API_IMAGE:-}" >> "${IMAGE_LOG}"
case "${6}" in
    build) exit "${MOCK_BUILD_STATUS:-0}" ;;
    up|run)
        if [ -n "${MOCK_SIGNAL:-}" ] && [ "${6}" = "${MOCK_SIGNAL_PHASE:-run}" ]; then
            kill -s "${MOCK_SIGNAL}" "${PPID}"
        fi
        if [ "${6}" = up ]; then
            exit "${MOCK_UP_STATUS:-0}"
        fi
        exit "${MOCK_RUN_STATUS:-0}"
        ;;
    down)
        if [ "${5}" = - ]; then
            cat > "${CLEANUP_CONFIG}"
            exit "${MOCK_IMAGE_DOWN_STATUS:-0}"
        fi
        exit "${MOCK_DOWN_STATUS:-0}"
        ;;
    *) exit 99 ;;
esac
MOCK
    chmod +x "${TEST_BIN}/docker"
    export PATH="${TEST_BIN}:${PATH}"
    unset MOCK_RM_STATUS MOCK_LOCAL_INSPECT_STATUS MOCK_IMAGE_DOWN_STATUS
    unset MOCK_RUN_STATUS MOCK_SIGNAL_PHASE MOCK_UP_STATUS MOCK_DOWN_STATUS MOCK_SIGNAL MOCK_BUILD_STATUS MOCK_INSPECT_STATUS ORDERS_API_IMAGE
    cd "${BATS_TEST_TMPDIR}" || return
}

teardown() {
    rm -rf "${TEST_REPO}" "${TEST_BIN}" "${DOCKER_LOG}" "${IMAGE_LOG}" "${BATS_TEST_TMPDIR}/no-docker" "${CLEANUP_CONFIG}"
}

assert_compose_calls() {
    local phase="${1:-run}"
    local selected_image="${2:-}"
    local local_image="${3:-present}"
    local prefix="<compose><-p><orders-blackbox><-f><${COMPOSE_FILE}>"
    local expected
    expected="$(
        if [ -n "${selected_image}" ]; then
            printf '%s\n' "<image><inspect><--format><{{.Id}}><${selected_image}>"
            printf '%s\n' "${prefix}<build><orders_test_pg_db><orders_api_tests>"
        else
            printf '%s\n' "${prefix}<build>"
        fi
        if [ "${phase}" != build ]; then
            printf '%s\n' "${prefix}<up><--detach><--no-build><--pull><never><orders_test_pg_db><orders_test_api>"
        fi
        if [ "${phase}" = run ]; then
            printf '%s\n' "${prefix}<run><--rm><--no-deps><--pull><never><-T><orders_api_tests>"
        fi
        printf '%s\n' "${prefix}<down><--volumes><--remove-orphans>"
        printf '%s\n' '<compose><-p><orders-blackbox><-f><-><down><--rmi><local>'
        if [ -z "${selected_image}" ]; then
            printf '%s\n' '<image><inspect><orders-api:blackbox>'
            if [ "${local_image}" = present ]; then
                printf '%s\n' '<image><rm><orders-api:blackbox>'
            fi
        fi
    )"
    [ "$(cat "${DOCKER_LOG}")" = "${expected}" ]
    local expected_config
    expected_config="$(printf '%s\n' 'services:' '  orders_test_pg_db:' '    build: .' '  orders_api_tests:' '    build: .')"
    [ "$(cat "${CLEANUP_CONFIG}")" = "${expected_config}" ]
}

@test "builds and runs tests then cleans up from an unrelated directory with spaces in the repo path" {
    run "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 0 ]
    assert_compose_calls
}

@test "successful dependency startup cannot hide a failing test client" {
    run env MOCK_RUN_STATUS=17 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 17 ]
    assert_compose_calls
}

@test "reports cleanup failure after successful tests" {
    run env MOCK_DOWN_STATUS=23 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 23 ]
    assert_compose_calls
}

@test "preserves the test failure when cleanup also fails" {
    run env MOCK_RUN_STATUS=17 MOCK_DOWN_STATUS=23 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 17 ]
    assert_compose_calls
}

@test "rejects arguments without calling Docker" {
    run "${TEST_REPO}/build/test-black-box.sh" --unexpected

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Usage:"* ]]
    [ ! -s "${DOCKER_LOG}" ]
}

@test "rejects an empty argument without calling Docker" {
    run "${TEST_REPO}/build/test-black-box.sh" ""

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"Usage:"* ]]
    [ ! -s "${DOCKER_LOG}" ]
}

@test "reports missing Docker before attempting to run tests" {
    local minimal_bin="${BATS_TEST_TMPDIR}/no-docker"
    mkdir -p "${minimal_bin}"
    ln -s "$(command -v dirname)" "${minimal_bin}/dirname"

    run env PATH="${minimal_bin}" "${BASH_BIN}" "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Error: docker is required"* ]]
    [ ! -s "${DOCKER_LOG}" ]
}

@test "reports missing Compose file without calling Docker" {
    rm "${COMPOSE_FILE}"

    run "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Error: Compose file not found: ${COMPOSE_FILE}"* ]]
    [ ! -s "${DOCKER_LOG}" ]
}

@test "cleans up on termination and returns the signal exit status" {
    run env MOCK_SIGNAL=TERM "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 143 ]
    assert_compose_calls
}

assert_prebuilt_calls() {
    local selected_image="${1}"
    local phase="${2:-run}"
    assert_compose_calls "${phase}" "${selected_image}"
    local expected_images
    expected_images="$(printf '%s\n' 'image=<sha256:resolved-image>' 'image=<sha256:resolved-image>' 'image=<sha256:resolved-image>'
        if [ "${phase}" != build ]; then
            printf '%s\n' 'image=<sha256:resolved-image>'
        fi
        if [ "${phase}" = run ]; then
            printf '%s\n' 'image=<sha256:resolved-image>'
        fi)"
    [ "$(cat "${IMAGE_LOG}")" = "${expected_images}" ]
}

@test "prebuilt image tag resolves locally and only supporting services build" {
    run env ORDERS_API_IMAGE=example/orders:1.2.3 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Running black-box tests against API image: sha256:resolved-image"* ]]
    assert_prebuilt_calls example/orders:1.2.3
}

@test "prebuilt image ID is accepted without API rebuild or pull" {
    run env ORDERS_API_IMAGE=sha256:selected-image "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 0 ]
    assert_prebuilt_calls sha256:selected-image
}

@test "missing prebuilt image preserves inspection failure without Compose side effects" {
    run env ORDERS_API_IMAGE=missing/image MOCK_INSPECT_STATUS=31 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 31 ]
    [ "$(cat "${DOCKER_LOG}")" = '<image><inspect><--format><{{.Id}}><missing/image>' ]
    [ ! -s "${IMAGE_LOG}" ]
}

@test "supporting service build failure cleans up and prevents starting services" {
    run env ORDERS_API_IMAGE=example/orders:1.2.3 MOCK_BUILD_STATUS=37 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 37 ]
    assert_prebuilt_calls example/orders:1.2.3 build
}

@test "prebuilt test failure is preserved when cleanup also fails" {
    run env ORDERS_API_IMAGE=example/orders:1.2.3 MOCK_RUN_STATUS=17 MOCK_DOWN_STATUS=23 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 17 ]
    assert_prebuilt_calls example/orders:1.2.3
}

@test "standalone build failure prevents service startup and still cleans up" {
    run env MOCK_BUILD_STATUS=37 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 37 ]
    assert_compose_calls build
}

@test "build failure is preserved when cleanup also fails" {
    run env MOCK_BUILD_STATUS=37 MOCK_DOWN_STATUS=23 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 37 ]
    assert_compose_calls build
}

@test "dependency startup failure prevents tests and still cleans up" {
    run env MOCK_UP_STATUS=19 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 19 ]
    assert_compose_calls up
}

@test "dependency startup failure is preserved when cleanup also fails" {
    run env MOCK_UP_STATUS=19 MOCK_DOWN_STATUS=23 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 19 ]
    assert_compose_calls up
}

@test "interrupting the test client cleans up and returns the signal status" {
    run env MOCK_SIGNAL=INT "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 130 ]
    assert_compose_calls
}

@test "termination during dependency startup prevents tests and cleans up" {
    run env MOCK_SIGNAL=TERM MOCK_SIGNAL_PHASE=up "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 143 ]
    assert_compose_calls up
}

@test "termination status is preserved when cleanup also fails" {
    run env MOCK_SIGNAL=TERM MOCK_DOWN_STATUS=23 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 143 ]
    assert_compose_calls
}

@test "supplied standalone image tag is preserved during image cleanup" {
    run env ORDERS_API_IMAGE=orders-api:blackbox "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 0 ]
    assert_prebuilt_calls orders-api:blackbox
}

@test "missing standalone API image skips removal without failing cleanup" {
    run env MOCK_LOCAL_INSPECT_STATUS=1 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 0 ]
    assert_compose_calls run "" missing
}

@test "failed build with no API image skips removal and preserves build failure" {
    run env MOCK_BUILD_STATUS=37 MOCK_LOCAL_INSPECT_STATUS=1 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 37 ]
    assert_compose_calls build "" missing
}

@test "supporting image cleanup failure is reported after successful tests" {
    run env MOCK_IMAGE_DOWN_STATUS=29 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 29 ]
    assert_compose_calls
}

@test "API image removal failure is reported after successful tests" {
    run env MOCK_RM_STATUS=31 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 31 ]
    assert_compose_calls
}

@test "container cleanup failure takes precedence over both image cleanup failures" {
    run env MOCK_DOWN_STATUS=23 MOCK_IMAGE_DOWN_STATUS=29 MOCK_RM_STATUS=31 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 23 ]
    assert_compose_calls
}

@test "supporting image cleanup failure takes precedence over API image removal failure" {
    run env MOCK_IMAGE_DOWN_STATUS=29 MOCK_RM_STATUS=31 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 29 ]
    assert_compose_calls
}

@test "test failure takes precedence over all cleanup failures" {
    run env MOCK_RUN_STATUS=17 MOCK_DOWN_STATUS=23 MOCK_IMAGE_DOWN_STATUS=29 MOCK_RM_STATUS=31 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 17 ]
    assert_compose_calls
}

@test "termination takes precedence over image cleanup failures" {
    run env MOCK_SIGNAL=TERM MOCK_IMAGE_DOWN_STATUS=29 MOCK_RM_STATUS=31 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 143 ]
    assert_compose_calls
}
