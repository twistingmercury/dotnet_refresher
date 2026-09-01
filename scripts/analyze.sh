#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_ROOT="$(cd "${PROJ_ROOT}/src/Orders" && pwd)"

printf "%s\n" "Running formatters..."
dotnet format "${SRC_ROOT}"/Orders.csproj \
    --verbosity detailed


printf "\n%s\n" "Checking for published vulnerabilities..."
dotnet package list \
    --project ${SRC_ROOT}/Orders.csproj \
    --no-restore \
    --vulnerable \
    --include-transitive \
    --verbosity detailed

printf "\n%s\n"  "Checking for compiler warnings..."
dotnet build "${SRC_ROOT}" \
    --no-restore \
    --configuration Release \
    -warnaserror