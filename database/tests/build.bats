#!/usr/bin/env bats

setup() {
    local database_dir
    database_dir="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export BUILD_TEST_ROOT="$BATS_TEST_TMPDIR/build test"
    export BUILD_DIR="$BUILD_TEST_ROOT/database with spaces"
    export DOCKER_LOG_DIR="$BUILD_TEST_ROOT/log"
    mkdir -p "$BUILD_DIR" "$DOCKER_LOG_DIR" "$BUILD_TEST_ROOT/bin" "$BUILD_TEST_ROOT/unrelated" "$BUILD_TEST_ROOT/tmp"
    cp "$database_dir/build.sh" "$database_dir/Dockerfile" "$BUILD_DIR/"
    export TMPDIR="$BUILD_TEST_ROOT/tmp"
    export PATH="$BUILD_TEST_ROOT/bin:$PATH"
    export GITHUB_GHRC_PAT="fake-test-token-\$with spaces"
    unset DOCKER_FAIL_STEP DOCKER_FAIL_IMAGE
    cat > "$BUILD_TEST_ROOT/bin/date" <<'STUB'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$@" >> "$DOCKER_LOG_DIR/date.args"
printf '%s\n' 2026-09-08
STUB
    cat > "$BUILD_TEST_ROOT/bin/docker" <<'STUB'
#!/usr/bin/env bash
set -eu
config_dir=''
if [ "$1" = --config ]; then
    config_dir="$2"
    test -d "$config_dir"
    shift 2
fi
step="$1"
printf '%s\n' "$step" >> "$DOCKER_LOG_DIR/steps"
printf '%s\n' "$@" >> "$DOCKER_LOG_DIR/$step.args"
if [ -n "$config_dir" ]; then
    printf '%s\n' "$config_dir" >> "$DOCKER_LOG_DIR/$step.config"
    printf '%s\n' 'fake credentials' > "$config_dir/config.json"
fi
if [ "$step" = login ]; then
    cat > "$DOCKER_LOG_DIR/token"
fi
if [ "$step" = "${DOCKER_FAIL_STEP:-}" ]; then
    exit 19
fi
if [ "$step" = push ] && [ "$2" = "${DOCKER_FAIL_IMAGE:-}" ]; then
    exit 23
fi
STUB
    chmod +x "$BUILD_TEST_ROOT/bin/docker" "$BUILD_TEST_ROOT/bin/date"
    cd "$BUILD_TEST_ROOT/unrelated" || return
}

teardown() {
    rm -rf "${BUILD_TEST_ROOT:?}"
}

assert_config_cleaned() {
    local config_dir
    config_dir="$(cat "$DOCKER_LOG_DIR/login.config")"
    [ ! -e "$config_dir" ]
}

@test "missing or empty token fails before Docker runs" {
    unset GITHUB_GHRC_PAT
    run bash "$BUILD_DIR/build.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *'GITHUB_GHRC_PAT must be set'* ]]
    [ ! -e "$DOCKER_LOG_DIR/steps" ]
    run env GITHUB_GHRC_PAT= bash "$BUILD_DIR/build.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *'GITHUB_GHRC_PAT must be set'* ]]
    [ ! -e "$DOCKER_LOG_DIR/steps" ]
}

@test "build then authenticate and push from unrelated cwd without exposing token" {
    run bash -x "$BUILD_DIR/build.sh"
    [ "$status" -eq 0 ]
    [ "$(cat "$DOCKER_LOG_DIR/steps")" = $'build\nlogin\npush\npush' ]
    [ "$(cat "$DOCKER_LOG_DIR/date.args")" = $'-u\n+%Y-%m-%d' ]
    grep -Fx "$BUILD_DIR/Dockerfile" "$DOCKER_LOG_DIR/build.args"
    grep -Fx "$BUILD_DIR" "$DOCKER_LOG_DIR/build.args"
    grep -Fx 'ghcr.io/twistingmercury/orders-postgres:test' "$DOCKER_LOG_DIR/build.args"
    grep -Fx 'ghcr.io/twistingmercury/orders-postgres:2026-09-08' "$DOCKER_LOG_DIR/build.args"
    [ "$(cat "$DOCKER_LOG_DIR/login.args")" = $'login\nghcr.io\n--username\ntwistingmercury\n--password-stdin' ]
    [ "$(cat "$DOCKER_LOG_DIR/token")" = "$GITHUB_GHRC_PAT" ]
    [[ "$output" != *"$GITHUB_GHRC_PAT"* ]]
    run grep -F -- "$GITHUB_GHRC_PAT" "$DOCKER_LOG_DIR"/*.args
    [ "$status" -eq 1 ]
    [ "$(cat "$DOCKER_LOG_DIR/push.args")" = $'push\nghcr.io/twistingmercury/orders-postgres:test\npush\nghcr.io/twistingmercury/orders-postgres:2026-09-08' ]
    local config_dir
    config_dir="$(cat "$DOCKER_LOG_DIR/login.config")"
    [ "$(grep -Fxc "$config_dir" "$DOCKER_LOG_DIR/push.config")" -eq 2 ]
    assert_config_cleaned
}

@test "build failure stops authentication and push" {
    run env DOCKER_FAIL_STEP=build bash "$BUILD_DIR/build.sh"
    [ "$status" -eq 19 ]
    [ "$(cat "$DOCKER_LOG_DIR/steps")" = build ]
}

@test "login failure stops push and cleans credentials" {
    run env DOCKER_FAIL_STEP=login bash "$BUILD_DIR/build.sh"
    [ "$status" -eq 19 ]
    [ "$(cat "$DOCKER_LOG_DIR/steps")" = $'build\nlogin' ]
    assert_config_cleaned
}

@test "first push failure stops second push and cleans credentials" {
    run env DOCKER_FAIL_STEP=push bash "$BUILD_DIR/build.sh"
    [ "$status" -eq 19 ]
    [ "$(cat "$DOCKER_LOG_DIR/steps")" = $'build\nlogin\npush' ]
    assert_config_cleaned
}

@test "second push failure propagates and cleans credentials" {
    run env DOCKER_FAIL_IMAGE=ghcr.io/twistingmercury/orders-postgres:2026-09-08 bash "$BUILD_DIR/build.sh"
    [ "$status" -eq 23 ]
    [ "$(cat "$DOCKER_LOG_DIR/steps")" = $'build\nlogin\npush\npush' ]
    assert_config_cleaned
}
