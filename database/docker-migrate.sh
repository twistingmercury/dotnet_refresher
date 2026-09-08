#!/usr/bin/env bash

set -euo pipefail

DATABASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
readonly DATABASE_DIR

DB_NAME="${DB_NAME-orders}"
DB_USER="${DB_USER-ordersUser}"
DB_PASS="${DB_PASS-ordersPass}"
POSTGRES_USER="${POSTGRES_USER-postgres}"

: "${DB_NAME:?DB_NAME must not be empty}"
: "${DB_USER:?DB_USER must not be empty}"
: "${DB_PASS:?DB_PASS must not be empty}"
: "${POSTGRES_USER:?POSTGRES_USER must not be empty}"

exec_psql_file() {
    local username="$1"
    local dbname="$2"
    local sql_file="$3"

    psql -X -v ON_ERROR_STOP=1 \
        -v "db_name=${DB_NAME}" \
        -v "db_user=${DB_USER}" \
        -v "db_pass=${DB_PASS}" \
        -U "${username}" -d "${dbname}" -f "${sql_file}"
}

create_db() {
    exec_psql_file "${POSTGRES_USER}" "postgres" "${DATABASE_DIR}/sql/create_database.sql"
}

create_users() {
    exec_psql_file "${POSTGRES_USER}" "postgres" "${DATABASE_DIR}/sql/create_user.sql"
}

assign_database_owner() {
    psql -X -v ON_ERROR_STOP=1 \
        -v "db_name=${DB_NAME}" \
        -v "db_user=${DB_USER}" \
        -U "${POSTGRES_USER}" -d postgres <<'SQL'
ALTER DATABASE :"db_name" OWNER TO :"db_user";
SQL
}

create_order_tables() {
    exec_psql_file "${DB_USER}" "${DB_NAME}" "${DATABASE_DIR}/sql/create_tables.sql"
}

seed_orders() {
    exec_psql_file "${DB_USER}" "${DB_NAME}" "${DATABASE_DIR}/sql/seed_orders.sql"
}

main() {
    create_users
    create_db
    assign_database_owner
    create_order_tables
    seed_orders
}

main "$@"
