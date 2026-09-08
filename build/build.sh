#!/usr/bin/env bash

set -euo pipefail

LOCAL=${LOCAL:-0}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJ_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

if ! GIT_COMMIT=$(git -C "${PROJ_ROOT}" rev-parse --verify 'HEAD^{commit}' 2>/dev/null); then
    printf '%s\n' 'Error: git and a repository with a valid HEAD are required.' >&2
    exit 1
fi

RELEASE_TAG=$(git -C "${PROJ_ROOT}" describe --tags --exact-match HEAD 2>/dev/null || true)
COMMIT_TAG="sha-${GIT_COMMIT}"
LATEST_TAG="latest"
BUILD_VER="${BUILD_VER:-${RELEASE_TAG:-${COMMIT_TAG}}}"
BUILD_DATE="${BUILD_DATE:-$(date -u +%Y-%m-%dT%H:%M:%SZ)}"
BUILD_COMMIT="${BUILD_COMMIT:-${GIT_COMMIT}}"

IMAGE_NAME="${IMAGE_NAME:-ghcr.io/twistingmercury/orders}"

if [ "${LOCAL}" = 1 ]; then
    COMMIT_TAG="${COMMIT_TAG}-local"
    LATEST_TAG="${LATEST_TAG}-local"
    if [ -n "${RELEASE_TAG}" ]; then
        RELEASE_TAG="${RELEASE_TAG}-local"
    fi
fi

IMAGE_TAGS=("${IMAGE_NAME}:${COMMIT_TAG}")
if [ -n "${RELEASE_TAG}" ]; then
    if [[ ! "${RELEASE_TAG}" =~ ^[a-zA-Z0-9_][a-zA-Z0-9_.-]{0,127}$ ]]; then
        printf 'Error: exact Git release tag is not a valid Docker tag: %s\n' "${RELEASE_TAG}" >&2
        exit 1
    fi
    IMAGE_TAGS+=("${IMAGE_NAME}:${RELEASE_TAG}")
fi
IMAGE_TAGS+=("${IMAGE_NAME}:${LATEST_TAG}")
IMAGE_ID=""

clean_up(){
    # if [ ${LOCAL} = 1 ]; then
    #     docker rmi "${IMAGE_NAME}":latest -f > /dev/null 2>&1 || true
    # fi
    return 0
}

build(){
    local image_tag
    local tag_args=()
    for image_tag in "${IMAGE_TAGS[@]}"; do
        tag_args+=(--tag "${image_tag}")
    done

    docker build \
        --file "${SCRIPT_DIR}/Dockerfile" \
        --rm --no-cache \
        --build-arg VERSION="${BUILD_VER}" \
        --build-arg DATE="${BUILD_DATE}" \
        --build-arg COMMIT="${BUILD_COMMIT}" \
        --target final \
        "${tag_args[@]}" "${PROJ_ROOT}"

        return 0
}

exec_black_box_test(){
    IMAGE_ID=$(docker image inspect --format '{{.Id}}' "${IMAGE_TAGS[0]}")
    ORDERS_API_IMAGE="${IMAGE_ID}" "${SCRIPT_DIR}/test-black-box.sh"
}

write_github_outputs(){
    if [ -z "${GITHUB_OUTPUT:-}" ]; then
        return 0
    fi

    {
        printf '%s\n' 'image_tags<<ORDERS_IMAGE_TAGS'
        printf '%s\n' "${IMAGE_TAGS[@]}"
        printf '%s\n' 'ORDERS_IMAGE_TAGS'
        printf 'image_id=%s\n' "${IMAGE_ID}"
    } >> "${GITHUB_OUTPUT}"
}

main(){
    if [ ! -f "${SCRIPT_DIR}/Dockerfile" ]; then
        printf "The Dockerfile %s does not exist\n" "${SCRIPT_DIR}/Dockerfile"
        return 1
    fi

    trap clean_up EXIT

    build

    exec_black_box_test

    write_github_outputs

    return 0
}

main "$@"
