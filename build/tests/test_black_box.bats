#!/usr/bin/env bats

setup() {
    TEST_REPO="${BATS_TEST_TMPDIR}/repo with spaces"
    TEST_BIN="${BATS_TEST_TMPDIR}/bin"
    DOCKER_LOG="${BATS_TEST_TMPDIR}/docker.log"
    BASH_BIN="$(command -v bash)"
    IMAGE_LOG="${BATS_TEST_TMPDIR}/images.log"
    export DOCKER_LOG IMAGE_LOG

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
    printf '%s\n' 'sha256:resolved-image'
    exit "${MOCK_INSPECT_STATUS:-0}"
fi
printf 'image=<%s>\n' "${ORDERS_API_IMAGE:-}" >> "${IMAGE_LOG}"
case "${6}" in
    build) exit "${MOCK_BUILD_STATUS:-0}" ;;
    up)
        if [ -n "${MOCK_SIGNAL:-}" ]; then
            kill -s "${MOCK_SIGNAL}" "${PPID}"
        fi
        exit "${MOCK_UP_STATUS:-0}"
        ;;
    down) exit "${MOCK_DOWN_STATUS:-0}" ;;
    *) exit 99 ;;
esac
MOCK
    chmod +x "${TEST_BIN}/docker"
    export PATH="${TEST_BIN}:${PATH}"
    unset MOCK_UP_STATUS MOCK_DOWN_STATUS MOCK_SIGNAL MOCK_BUILD_STATUS MOCK_INSPECT_STATUS ORDERS_API_IMAGE
    cd "${BATS_TEST_TMPDIR}" || return
}

teardown() {
    rm -rf "${TEST_REPO}" "${TEST_BIN}" "${DOCKER_LOG}" "${IMAGE_LOG}" "${BATS_TEST_TMPDIR}/no-docker"
}

assert_up_then_down() {
    local expected
    expected="$(printf '%s\n' \
        "<compose><-p><orders-blackbox><-f><${COMPOSE_FILE}><up><--build><--abort-on-container-exit><--exit-code-from><orders_api_tests>" \
        "<compose><-p><orders-blackbox><-f><${COMPOSE_FILE}><down><--volumes><--remove-orphans>")"
    [ "$(cat "${DOCKER_LOG}")" = "${expected}" ]
}

@test "builds and runs tests then cleans up from an unrelated directory with spaces in the repo path" {
    run "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 0 ]
    assert_up_then_down
}

@test "cleans up and preserves the test failure status" {
    run env MOCK_UP_STATUS=17 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 17 ]
    assert_up_then_down
}

@test "reports cleanup failure after successful tests" {
    run env MOCK_DOWN_STATUS=23 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 23 ]
    assert_up_then_down
}

@test "preserves the test failure when cleanup also fails" {
    run env MOCK_UP_STATUS=17 MOCK_DOWN_STATUS=23 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 17 ]
    assert_up_then_down
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
    assert_up_then_down
}

assert_prebuilt_calls() {
    local selected_image="${1}"
    local include_up="${2:-yes}"
    local expected
    expected="$(printf '%s\n' \
        "<image><inspect><--format><{{.Id}}><${selected_image}>" \
        "<compose><-p><orders-blackbox><-f><${COMPOSE_FILE}><build><orders_test_pg_db><orders_api_tests>"
        if [ "${include_up}" = yes ]; then
            printf '%s\n' "<compose><-p><orders-blackbox><-f><${COMPOSE_FILE}><up><--no-build><--pull><never><--abort-on-container-exit><--exit-code-from><orders_api_tests>"
        fi
        printf '%s\n' "<compose><-p><orders-blackbox><-f><${COMPOSE_FILE}><down><--volumes><--remove-orphans>")"
    [ "$(cat "${DOCKER_LOG}")" = "${expected}" ]
    local expected_images
    expected_images="$(printf '%s\n' 'image=<sha256:resolved-image>' 'image=<sha256:resolved-image>'
        if [ "${include_up}" = yes ]; then
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
    assert_prebuilt_calls example/orders:1.2.3 no
}

@test "prebuilt test failure is preserved when cleanup also fails" {
    run env ORDERS_API_IMAGE=example/orders:1.2.3 MOCK_UP_STATUS=17 MOCK_DOWN_STATUS=23 "${TEST_REPO}/build/test-black-box.sh"

    [ "${status}" -eq 17 ]
    assert_prebuilt_calls example/orders:1.2.3
}
