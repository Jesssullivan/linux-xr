#!/usr/bin/env bash
# Verify that every XR carry patch listed in series is wired into kernel-xr.spec.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_DIR="${XR_DIR}/patches"
SERIES_FILE="${PATCH_DIR}/series"
SPEC_FILE="${XR_DIR}/specs/kernel-xr.spec"

usage() {
    cat <<'EOF'
Usage: check-rpm-patch-wiring.sh

Checks that every non-comment entry in xr/patches/series:
  1. exists in xr/patches/
  2. has a PatchN declaration in xr/specs/kernel-xr.spec
  3. is applied in %prep by either %patch -PN or an explicit patch command

This is a static guard only; use check-kernel-carry.sh for kernel tarball
application checks.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
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

if [[ ! -f "${SERIES_FILE}" ]]; then
    echo "ERROR: ${SERIES_FILE} not found." >&2
    exit 1
fi

if [[ ! -f "${SPEC_FILE}" ]]; then
    echo "ERROR: ${SPEC_FILE} not found." >&2
    exit 1
fi

status=0

while IFS= read -r patch_file; do
    case "${patch_file}" in
        ""|\#*)
            continue
            ;;
    esac

    if [[ ! -f "${PATCH_DIR}/${patch_file}" ]]; then
        echo "ERROR: missing carry patch ${PATCH_DIR}/${patch_file}" >&2
        status=1
        continue
    fi

    patch_number="$(
        awk -v patch="${patch_file}" '
            $1 ~ /^Patch[0-9]+:/ && $2 == patch {
                sub(/^Patch/, "", $1)
                sub(/:$/, "", $1)
                print $1
                exit
            }
        ' "${SPEC_FILE}"
    )"

    if [[ -z "${patch_number}" ]]; then
        echo "ERROR: ${patch_file} is in series but has no PatchN declaration in ${SPEC_FILE}." >&2
        status=1
        continue
    fi

    if grep -Eq "%patch[[:space:]]+-P${patch_number}([[:space:]]|$)" "${SPEC_FILE}" ||
        grep -Fq "_sourcedir}/${patch_file}" "${SPEC_FILE}"; then
        echo "OK: ${patch_file} -> Patch${patch_number}"
    else
        echo "ERROR: ${patch_file} is Patch${patch_number} but is not applied in %prep." >&2
        status=1
    fi
done < "${SERIES_FILE}"

exit "${status}"
