#!/usr/bin/env bash

set -euo pipefail

export DB_USER="ordersUser"
export DB_PASS="ordersPass"
export DB_NAME="orders"

SCRIPT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_ROOT}/lib/helpers.sh"

deploy(){
    helpers::create_db
    helpers::create_users
    helpers::create_order_tables
}

main(){
    deploy
}

main "$@"