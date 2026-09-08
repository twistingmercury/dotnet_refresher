#!/usr/bin/env bats

setup() {
    local database_dir
    database_dir="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
    export MIGRATION_DIR="$BATS_TEST_TMPDIR/database with spaces"
    mkdir -p "$MIGRATION_DIR/sql" "$BATS_TEST_TMPDIR/bin" "$BATS_TEST_TMPDIR/unrelated"
    cp "$database_dir/docker-migrate.sh" "$MIGRATION_DIR/"
    cp "$database_dir"/sql/*.sql "$MIGRATION_DIR/sql/"
    export PSQL_LOG="$BATS_TEST_TMPDIR/psql.log"
    export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
    unset DB_NAME DB_USER DB_PASS POSTGRES_USER PSQL_EXIT_CODE PSQL_FAIL_FILE
    cat > "$BATS_TEST_TMPDIR/bin/psql" <<'STUB'
#!/usr/bin/env bash
set -eu
printf '%s\n' CALL "$@" >> "$PSQL_LOG"
if [ "${PSQL_EXIT_CODE:-0}" -ne 0 ]; then
    exit "$PSQL_EXIT_CODE"
fi
while [ "$#" -gt 0 ]; do
    if [ "$1" = -f ]; then
        shift
        test -s "$1"
        if [ "$1" = "${PSQL_FAIL_FILE:-}" ]; then
            exit 23
        fi
        exit
    fi
    shift
done
cat >> "$PSQL_LOG"
STUB
    chmod +x "$BATS_TEST_TMPDIR/bin/psql"
    cd "$BATS_TEST_TMPDIR/unrelated" || return
}

teardown() {
    rm -rf "$MIGRATION_DIR" "${BATS_TEST_TMPDIR:?}/bin" "$BATS_TEST_TMPDIR/unrelated"
    rm -f "$PSQL_LOG"
}

@test "explicitly empty database settings fail before psql runs" {
    local setting
    for setting in DB_NAME DB_USER DB_PASS POSTGRES_USER; do
        run env "$setting=" bash "$MIGRATION_DIR/docker-migrate.sh"
        [ "$status" -ne 0 ]
        [[ "$output" == *"$setting must not be empty"* ]]
        [ ! -e "$PSQL_LOG" ]
    done
}

@test "psql failure preserves its exit status and stops migration" {
    export PSQL_EXIT_CODE=17
    run bash "$MIGRATION_DIR/docker-migrate.sh"
    [ "$status" -eq 17 ]
    [ "$(grep -c '^CALL$' "$PSQL_LOG")" -eq 1 ]
}

@test "defaults migrate all SQL files independently of cwd and spaces in path" {
    run bash "$MIGRATION_DIR/docker-migrate.sh"
    [ "$status" -eq 0 ]
    grep -Fx 'db_name=orders' "$PSQL_LOG"
    grep -Fx 'db_user=ordersUser' "$PSQL_LOG"
    grep -Fx 'db_pass=ordersPass' "$PSQL_LOG"
    grep -Fx 'postgres' "$PSQL_LOG"
    local sql_file
    for sql_file in create_user.sql create_database.sql create_tables.sql seed_orders.sql; do
        grep -Fx "$MIGRATION_DIR/sql/$sql_file" "$PSQL_LOG"
    done
    grep -F 'ALTER DATABASE' "$PSQL_LOG"
    local table_line seed_line
    table_line="$(grep -nFx "$MIGRATION_DIR/sql/create_tables.sql" "$PSQL_LOG")"
    seed_line="$(grep -nFx "$MIGRATION_DIR/sql/seed_orders.sql" "$PSQL_LOG")"
    [ "${table_line%%:*}" -lt "${seed_line%%:*}" ]
}

@test "seed SQL failure propagates to the caller" {
    export PSQL_FAIL_FILE="$MIGRATION_DIR/sql/seed_orders.sql"
    run bash "$MIGRATION_DIR/docker-migrate.sh"
    [ "$status" -eq 23 ]
    grep -Fx "$PSQL_FAIL_FILE" "$PSQL_LOG"
}
