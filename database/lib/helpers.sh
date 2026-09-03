#!/usr/bin/env bash

set -o pipefail

readonly DATABASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

exec_psql_file() {
    local dbname="$1"
    local sql_file="$2"

    docker compose exec -T orders_pg_db \
        psql -v ON_ERROR_STOP=1 \
        -v "db_name=${DB_NAME}" \
        -v "db_user=${DB_USER}" \
        -v "db_pass=${DB_PASS}" \
        -U "${DB_USER}" -d "${dbname}" -f - < "${sql_file}"
}

helpers::create_db() {
    exec_psql_file "postgres" "${DATABASE_DIR}/sql/create_database.sql"
}

helpers::create_users(){
    exec_psql_file "postgres" "${DATABASE_DIR}/sql/create_user.sql"
}

helpers::create_order_tables(){
    exec_psql_file "${DB_NAME}" "${DATABASE_DIR}/sql/create_tables.sql"
}
