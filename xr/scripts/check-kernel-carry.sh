#!/usr/bin/env bash
# Dry-run linux-xr carry patches against a kernel.org source tarball.

set -euo pipefail

KERNEL_VERSION=""
RT_VERSION=""
WORK_DIR=""
KEEP_WORK=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_DIR="${XR_DIR}/patches"
SERIES_FILE="${PATCH_DIR}/series"
PATCH_WIRING_CHECK="${XR_DIR}/scripts/check-rpm-patch-wiring.sh"

usage() {
    cat <<'EOF'
Usage: check-kernel-carry.sh --kernel-version VER [--rt-version RT_VER] [--work-dir DIR] [--keep-work]

Downloads a kernel.org tarball, optionally dry-runs the matching PREEMPT_RT
patch first, then dry-runs every patch listed in xr/patches/series with
RPM-compatible zero-fuzz matching.

Examples:
  ./xr/scripts/check-kernel-carry.sh --kernel-version 6.19.14
  ./xr/scripts/check-kernel-carry.sh --kernel-version 6.19.14 --rt-version 6.19.3-rt1
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernel-version)
            KERNEL_VERSION="$2"
            shift 2
            ;;
        --rt-version)
            RT_VERSION="$2"
            shift 2
            ;;
        --work-dir)
            WORK_DIR="$2"
            shift 2
            ;;
        --keep-work)
            KEEP_WORK=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

require_command() {
    local command="$1"

    if ! command -v "${command}" >/dev/null 2>&1; then
        echo "ERROR: required command not found: ${command}" >&2
        exit 1
    fi
}

if [[ -z "${KERNEL_VERSION}" ]]; then
    echo "ERROR: --kernel-version is required." >&2
    usage >&2
    exit 1
fi

if [[ ! -f "${SERIES_FILE}" ]]; then
    echo "ERROR: ${SERIES_FILE} not found." >&2
    exit 1
fi

require_command curl
require_command patch
require_command tar

if [[ ! -x "${PATCH_WIRING_CHECK}" ]]; then
    echo "ERROR: ${PATCH_WIRING_CHECK} not found or not executable." >&2
    exit 1
fi
"${PATCH_WIRING_CHECK}"

if [[ -z "${WORK_DIR}" ]]; then
    WORK_DIR="${TMPDIR:-/tmp}/linux-xr-carry-${KERNEL_VERSION}${RT_VERSION:+-${RT_VERSION}}"
fi

mkdir -p "${WORK_DIR}"

KMAJOR="${KERNEL_VERSION%%.*}"
TARBALL="linux-${KERNEL_VERSION}.tar.xz"
TARBALL_URL="https://cdn.kernel.org/pub/linux/kernel/v${KMAJOR}.x/${TARBALL}"
SOURCE_DIR="${WORK_DIR}/linux-${KERNEL_VERSION}"

if [[ ! -f "${WORK_DIR}/${TARBALL}" ]]; then
    echo ">>> Downloading ${TARBALL_URL}"
    curl -fSL -o "${WORK_DIR}/${TARBALL}" "${TARBALL_URL}"
fi

rm -rf "${SOURCE_DIR}"
tar -C "${WORK_DIR}" -xf "${WORK_DIR}/${TARBALL}"

if [[ -n "${RT_VERSION}" ]]; then
    require_command xz

    RT_MAJOR="${RT_VERSION%%-*}"
    RT_KMAJOR="${RT_MAJOR%%.*}"
    RT_KMINOR="${RT_MAJOR#*.}"
    RT_KMINOR="${RT_KMINOR%%.*}"
    RT_PATCH_XZ="patch-${RT_VERSION}.patch.xz"
    RT_PATCH="patch-${RT_VERSION}.patch"
    RT_URL="https://cdn.kernel.org/pub/linux/kernel/projects/rt/${RT_KMAJOR}.${RT_KMINOR}/${RT_PATCH_XZ}"

    if [[ ! -f "${WORK_DIR}/${RT_PATCH_XZ}" ]]; then
        echo ">>> Downloading ${RT_URL}"
        curl -fSL -o "${WORK_DIR}/${RT_PATCH_XZ}" "${RT_URL}"
    fi
    if [[ ! -f "${WORK_DIR}/${RT_PATCH}" ]]; then
        xz -dk "${WORK_DIR}/${RT_PATCH_XZ}"
    fi

    echo ">>> Dry-running PREEMPT_RT ${RT_VERSION}"
    patch --batch -d "${SOURCE_DIR}" -p1 --dry-run < "${WORK_DIR}/${RT_PATCH}"
fi

echo ">>> Dry-running linux-xr carry patches against ${KERNEL_VERSION}"
while IFS= read -r patch_file; do
    case "${patch_file}" in
        ""|\#*)
            continue
            ;;
    esac

    if [[ ! -f "${PATCH_DIR}/${patch_file}" ]]; then
        echo "ERROR: missing carry patch ${PATCH_DIR}/${patch_file}" >&2
        exit 1
    fi

    echo "    ${patch_file}"
    patch --batch -d "${SOURCE_DIR}" -p1 --fuzz=0 --dry-run < "${PATCH_DIR}/${patch_file}"
done < "${SERIES_FILE}"

echo "=== linux-xr carry dry-run passed for ${KERNEL_VERSION}${RT_VERSION:+ with ${RT_VERSION}} ==="

if [[ "${KEEP_WORK}" == "0" ]]; then
    rm -rf "${SOURCE_DIR}"
else
    echo "Work tree kept at ${SOURCE_DIR}"
fi
