#!/usr/bin/env bash

set +x
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE_NAME='ghcr.io/twistingmercury/orders-postgres'
DATE_TAG="$(date -u +%Y-%m-%d)"
PUSH="${PUSH:-0}"

docker build --file "${SCRIPT_DIR}/Dockerfile" \
    --tag "${IMAGE_NAME}:test" \
    --tag "${IMAGE_NAME}:${DATE_TAG}" \
    "${SCRIPT_DIR}"

DOCKER_CONFIG_DIR="$(mktemp -d)"
trap 'rm -rf "${DOCKER_CONFIG_DIR}"' EXIT

if (( PUSH == 1 )); then
    printf '%s\n' "Attempting to push images"

    if [ -z "${GITHUB_GHRC_PAT:-}" ]; then
        printf '%s\n' 'GITHUB_GHRC_PAT must be set to publish the database image.' >&2
        exit 1
    fi

    printf '%s' "${GITHUB_GHRC_PAT}" |
    docker --config "${DOCKER_CONFIG_DIR}" login ghcr.io \
        --username twistingmercury --password-stdin

    docker --config "${DOCKER_CONFIG_DIR}" push "${IMAGE_NAME}:test"
    docker --config "${DOCKER_CONFIG_DIR}" push "${IMAGE_NAME}:${DATE_TAG}"
fi
