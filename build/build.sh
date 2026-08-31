#!/usr/bin/env bash

set -euo pipefail

LOCAL=${LOCAL:-0}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SRC_ROOT="$(cd "${PROJ_ROOT}/src/Orders" && pwd)"

BUILD_VER="${BUILD_VER:-$(git -C "${PROJ_ROOT}" describe --tags --abbrev=0 2>/dev/null || echo 'dev')}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
BUILD_COMMIT="${BUILD_COMMIT:-$(git -C "${PROJ_ROOT}" rev-parse --short HEAD 2>/dev/null || echo 'unknown')}"

IMAGE_NAME="${IMAGE_NAME:-ghcr.io/twistingmercury/orders}"
IMAGE_TAG="${BUILD_VER}"

if [ ${LOCAL} = 1 ]; then
    IMAGE_TAG="${IMAGE_TAG}-local"
fi

clean_up(){
    # if [ ${LOCAL} = 1 ]; then
    #     docker rmi "${IMAGE_NAME}":latest -f > /dev/null 2>&1 || true
    # fi
    return 0
}

build(){
    docker build \
        --file "${SCRIPT_DIR}/Dockerfile" \
        --rm --no-cache \
        --build-arg BUILD_VER="${BUILD_VER}" \
        --build-arg BUILD_DATE="${BUILD_DATE}" \
        --build-arg BUILD_COMMIT="${BUILD_COMMIT}" \
        --target final \
        --tag "${IMAGE_NAME}:latest" \
        --tag "${IMAGE_NAME}:${BUILD_VER}" .

        return 0
}

main(){
    if [ ! -f "${SCRIPT_DIR}/Dockerfile" ]; then
        printf "The Dockerfile %s does not exist\n" "${SCRIPT_DIR}/Dockerfile"
        return 1
    fi

    trap clean_up EXIT

    build

    return 0
}

main "@$"