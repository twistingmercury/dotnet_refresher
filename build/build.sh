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
IMAGE_TAG="${IMAGE_TAG:-$BUILD_VER}"

if [ ${LOCAL} = 1 ]; then
    IMAGE_TAG="${IMAGE_TAG}-local"
fi

clean_up(){
    return 0
}

build(){
    docker build --no-cache \
        -t "${IMAGE_NAME}:latest" \
        -t "${IMAGE_NAME}:BUILD_VER" .
}

main(){
    trap clean_up EXIT

    printf "%s\n" "${BUILD_VER}"
    printf "%s\n" "${BUILD_DATE}" 
    printf "%s\n" "${BUILD_COMMIT}"
    printf "%s\n" "${IMAGE_TAG}"
}

main "@$"