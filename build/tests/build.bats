#!/usr/bin/env bats

setup() {
    TEST_REPO="${BATS_TEST_TMPDIR}/repo with spaces"
    TEST_BIN="${BATS_TEST_TMPDIR}/bin"
    BUILD_LOG="${BATS_TEST_TMPDIR}/build.log"
    GITHUB_OUTPUT="${BATS_TEST_TMPDIR}/github output"
    export BUILD_LOG GITHUB_OUTPUT
    export BUILD_DATE=2026-09-08T00:00:00Z LOCAL=0 IMAGE_NAME=example/orders
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
    export GIT_AUTHOR_NAME='Test Author' GIT_AUTHOR_EMAIL=test@example.invalid
    export GIT_COMMITTER_NAME='Test Author' GIT_COMMITTER_EMAIL=test@example.invalid
    unset BUILD_VER BUILD_COMMIT MOCK_BUILD_STATUS MOCK_RUNNER_STATUS MOCK_INSPECT_STATUS ORDERS_API_IMAGE
    unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE

    mkdir -p "${TEST_REPO}/build" "${TEST_BIN}"
    cp "${BATS_TEST_DIRNAME}/../build.sh" "${BATS_TEST_DIRNAME}/../Dockerfile" "${TEST_REPO}/build/"
    touch "${BUILD_LOG}"
    printf '%s\n' 'existing=preserved' > "${GITHUB_OUTPUT}"
    git init -q "${TEST_REPO}"
    git -C "${TEST_REPO}" -c commit.gpgsign=false commit -q --allow-empty -m initial
    HEAD_SHA=$(git -C "${TEST_REPO}" rev-parse HEAD)

    cat > "${TEST_BIN}/docker" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '<%s>' "$@" >> "${BUILD_LOG}"
printf '\n' >> "${BUILD_LOG}"
case "${1}" in
    build) exit "${MOCK_BUILD_STATUS:-0}" ;;
    image)
        printf '%s\n' 'sha256:built-image'
        exit "${MOCK_INSPECT_STATUS:-0}"
        ;;
    *) exit 99 ;;
esac
MOCK

    cat > "${TEST_REPO}/build/test-black-box.sh" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
[ "$#" -eq 0 ] || exit 98
[ "$(cat "${GITHUB_OUTPUT}")" = 'existing=preserved' ] || exit 97
printf 'runner image=<%s>\n' "${ORDERS_API_IMAGE:-}" >> "${BUILD_LOG}"
exit "${MOCK_RUNNER_STATUS:-0}"
MOCK

    chmod +x "${TEST_BIN}/docker" "${TEST_REPO}/build/test-black-box.sh"
    export PATH="${TEST_BIN}:${PATH}"
    cd "${BATS_TEST_TMPDIR}" || return
}

teardown() {
    rm -rf "${TEST_REPO}" "${TEST_BIN}" "${BUILD_LOG}" "${GITHUB_OUTPUT}"
}

expected_build() {
    local version="${1}" commit="${2}"
    shift 2
    printf '%s' "<build><--file><${TEST_REPO}/build/Dockerfile><--rm><--no-cache><--build-arg><VERSION=${version}><--build-arg><DATE=2026-09-08T00:00:00Z><--build-arg><COMMIT=${commit}><--target><final>"
    local tag
    for tag in "$@"; do
        printf '<--tag><example/orders:%s>' "${tag}"
    done
    printf '<%s>\n' "${TEST_REPO}"
}

assert_success() {
    local version="${1}" commit="${2}" inspected_tag="${3}"
    shift 2
    local expected
    expected="$(expected_build "${version}" "${commit}" "$@"
        printf '%s\n' "<image><inspect><--format><{{.Id}}><example/orders:${inspected_tag}>" 'runner image=<sha256:built-image>')"
    [ "$(cat "${BUILD_LOG}")" = "${expected}" ]
    expected="$(printf '%s\n' 'existing=preserved' 'image_tags<<ORDERS_IMAGE_TAGS'
        printf 'example/orders:%s\n' "$@"
        printf '%s\n' 'ORDERS_IMAGE_TAGS' 'image_id=sha256:built-image')"
    [ "$(cat "${GITHUB_OUTPUT}")" = "${expected}" ]
}

@test "untagged HEAD builds only commit and latest refs from an unrelated directory with spaces in repo path" {
    run "${TEST_REPO}/build/build.sh"

    [ "${status}" -eq 0 ]
    assert_success "sha-${HEAD_SHA}" "${HEAD_SHA}" "sha-${HEAD_SHA}" latest
}

@test "exact lightweight release tag is included between commit and latest outputs" {
    git -C "${TEST_REPO}" tag v1.2.3

    run "${TEST_REPO}/build/build.sh"

    [ "${status}" -eq 0 ]
    assert_success v1.2.3 "${HEAD_SHA}" "sha-${HEAD_SHA}" v1.2.3 latest
}

@test "exact annotated release tag is included" {
    git -C "${TEST_REPO}" -c tag.gpgsign=false tag -a v2.0.0 -m release

    run "${TEST_REPO}/build/build.sh"

    [ "${status}" -eq 0 ]
    assert_success v2.0.0 "${HEAD_SHA}" "sha-${HEAD_SHA}" v2.0.0 latest
}

@test "a commit after a release does not reuse the ancestor release tag" {
    git -C "${TEST_REPO}" tag v1.2.3
    git -C "${TEST_REPO}" -c commit.gpgsign=false commit -q --allow-empty -m next
    local next_sha
    next_sha=$(git -C "${TEST_REPO}" rev-parse HEAD)

    run "${TEST_REPO}/build/build.sh"

    [ "${status}" -eq 0 ]
    assert_success "sha-${next_sha}" "${next_sha}" "sha-${next_sha}" latest
}

@test "local release builds suffix every ref while retaining unsuffixed version metadata" {
    git -C "${TEST_REPO}" tag v1.2.3

    run env LOCAL=1 "${TEST_REPO}/build/build.sh"

    [ "${status}" -eq 0 ]
    assert_success v1.2.3 "${HEAD_SHA}" "sha-${HEAD_SHA}-local" v1.2.3-local latest-local
}

@test "local untagged builds suffix commit and latest refs" {
    run env LOCAL=1 "${TEST_REPO}/build/build.sh"

    [ "${status}" -eq 0 ]
    assert_success "sha-${HEAD_SHA}" "${HEAD_SHA}" "sha-${HEAD_SHA}-local" latest-local
}

@test "build metadata overrides do not change refs or permit an external image selection" {
    git -C "${TEST_REPO}" tag v1.2.3

    run env BUILD_VER=custom-version BUILD_COMMIT=custom-commit ORDERS_API_IMAGE=other/image:old "${TEST_REPO}/build/build.sh"

    [ "${status}" -eq 0 ]
    assert_success custom-version custom-commit "sha-${HEAD_SHA}" v1.2.3 latest
}

@test "runner failure propagates and leaves GitHub outputs untouched" {
    run env MOCK_RUNNER_STATUS=27 "${TEST_REPO}/build/build.sh"

    [ "${status}" -eq 27 ]
    local expected
    expected="$(expected_build "sha-${HEAD_SHA}" "${HEAD_SHA}" "sha-${HEAD_SHA}" latest
        printf '%s\n' "<image><inspect><--format><{{.Id}}><example/orders:sha-${HEAD_SHA}>" 'runner image=<sha256:built-image>')"
    [ "$(cat "${BUILD_LOG}")" = "${expected}" ]
    [ "$(cat "${GITHUB_OUTPUT}")" = 'existing=preserved' ]
}

@test "image build failure prevents inspection and tests and leaves outputs untouched" {
    run env MOCK_BUILD_STATUS=19 "${TEST_REPO}/build/build.sh"

    [ "${status}" -eq 19 ]
    [ "$(cat "${BUILD_LOG}")" = "$(expected_build "sha-${HEAD_SHA}" "${HEAD_SHA}" "sha-${HEAD_SHA}" latest)" ]
    [ "$(cat "${GITHUB_OUTPUT}")" = 'existing=preserved' ]
}

@test "inspection failure prevents tests and leaves outputs untouched" {
    run env MOCK_INSPECT_STATUS=31 "${TEST_REPO}/build/build.sh"

    [ "${status}" -eq 31 ]
    local expected
    expected="$(expected_build "sha-${HEAD_SHA}" "${HEAD_SHA}" "sha-${HEAD_SHA}" latest
        printf '%s\n' "<image><inspect><--format><{{.Id}}><example/orders:sha-${HEAD_SHA}>")"
    [ "$(cat "${BUILD_LOG}")" = "${expected}" ]
    [ "$(cat "${GITHUB_OUTPUT}")" = 'existing=preserved' ]
}

@test "an exact Git tag that is invalid for Docker fails before Docker runs" {
    git -C "${TEST_REPO}" tag release/v1

    run "${TEST_REPO}/build/build.sh"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *'not a valid Docker tag: release/v1'* ]]
    [ ! -s "${BUILD_LOG}" ]
    [ "$(cat "${GITHUB_OUTPUT}")" = 'existing=preserved' ]
}

@test "missing Git HEAD fails before Docker runs" {
    rm -rf "${TEST_REPO}/.git"
    git init -q "${TEST_REPO}"

    run "${TEST_REPO}/build/build.sh"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *'repository with a valid HEAD are required'* ]]
    [ ! -s "${BUILD_LOG}" ]
    [ "$(cat "${GITHUB_OUTPUT}")" = 'existing=preserved' ]
}
