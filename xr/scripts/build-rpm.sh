#!/bin/bash
# build-rpm.sh — Download kernel source, fetch patches, build RPMs
#
# Usage:
#   ./build-rpm.sh --kernel-version 6.19.5 --xr-release 1 [--rt-version 6.19.3-rt1]
#
# Can be run locally or in CI. Produces RPMs in ~/rpmbuild/RPMS/x86_64/.

set -euo pipefail

# Defaults
KERNEL_VERSION="6.19.5"
XR_RELEASE="1"
RT_VERSION=""
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
EXWM_REPO="Jesssullivan/XoxdWM"
EXWM_BRANCH="main"

usage() {
    echo "Usage: $0 --kernel-version VER --xr-release REL [--rt-version RT_VER]"
    echo ""
    echo "Options:"
    echo "  --kernel-version  Kernel version (default: 6.19.5)"
    echo "  --xr-release      XR release number (default: 1)"
    echo "  --rt-version      RT patch version (e.g., 6.19.3-rt1; empty to skip)"
    echo "  --help            Show this help"
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernel-version) KERNEL_VERSION="$2"; shift 2 ;;
        --xr-release)     XR_RELEASE="$2"; shift 2 ;;
        --rt-version)     RT_VERSION="$2"; shift 2 ;;
        --help)           usage ;;
        *)                echo "Unknown option: $1"; usage ;;
    esac
done

KRELEASE="${XR_RELEASE}.xr.el10"
KMAJOR="${KERNEL_VERSION%%.*}"

echo "=== linux-xr kernel build ==="
echo "  Kernel:  ${KERNEL_VERSION}"
echo "  Release: ${KRELEASE}"
echo "  RT:      ${RT_VERSION:-disabled}"
echo ""

# Setup rpmbuild tree
RPMBUILD="${HOME}/rpmbuild"
mkdir -p "${RPMBUILD}"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}

# --- Step 1: Download kernel tarball ---
TARBALL="linux-${KERNEL_VERSION}.tar.xz"
TARBALL_URL="https://cdn.kernel.org/pub/linux/kernel/v${KMAJOR}.x/${TARBALL}"

if [[ ! -f "${RPMBUILD}/SOURCES/${TARBALL}" ]]; then
    echo ">>> Downloading kernel tarball..."
    curl -fSL -o "${RPMBUILD}/SOURCES/${TARBALL}" "${TARBALL_URL}"
else
    echo ">>> Kernel tarball already cached."
fi

# Verify SHA256 if available
SHA_URL="${TARBALL_URL}.sha256"
if curl -fsSL -o /tmp/kernel-sha256.txt "${SHA_URL}" 2>/dev/null; then
    echo ">>> Verifying SHA256..."
    cd "${RPMBUILD}/SOURCES"
    if ! sha256sum -c /tmp/kernel-sha256.txt; then
        echo "ERROR: SHA256 mismatch for ${TARBALL}"
        exit 1
    fi
    cd -
else
    echo ">>> SHA256 not available, skipping verification."
fi

# --- Step 2: Fetch RT patches (optional) ---
if [[ -n "${RT_VERSION}" ]]; then
    RT_MAJOR="${RT_VERSION%%-*}"
    RT_KMAJOR="${RT_MAJOR%%.*}"
    RT_KMINOR="${RT_MAJOR#*.}"
    RT_KMINOR="${RT_KMINOR%%.*}"
    RT_PATCH="patch-${RT_VERSION}.patch.xz"
    RT_URL="https://cdn.kernel.org/pub/linux/kernel/projects/rt/${RT_KMAJOR}.${RT_KMINOR}/${RT_PATCH}"

    if [[ ! -f "${RPMBUILD}/SOURCES/patch-${RT_VERSION}.patch" ]]; then
        echo ">>> Downloading RT patch..."
        curl -fSL -o "/tmp/${RT_PATCH}" "${RT_URL}"
        xz -d -k "/tmp/${RT_PATCH}"
        mv "/tmp/patch-${RT_VERSION}.patch" "${RPMBUILD}/SOURCES/"
    else
        echo ">>> RT patch already cached."
    fi
fi

# --- Step 3: Fetch XR patches from exwm repo ---
echo ">>> Fetching XR patches from ${EXWM_REPO}..."

PATCHES=(
    "0007-vesa-dsc-bpp.patch"
    "bigscreen-beyond-edid.patch"
)

for patch in "${PATCHES[@]}"; do
    PATCH_URL="https://raw.githubusercontent.com/${EXWM_REPO}/${EXWM_BRANCH}/patches/${patch}"
    echo "    ${patch}"
    curl -fSL -o "${RPMBUILD}/SOURCES/${patch}" "${PATCH_URL}"
done

# --- Step 4: Copy base config ---
echo ">>> Copying base config..."
if [[ -f "${XR_DIR}/config/base.config" ]]; then
    cp "${XR_DIR}/config/base.config" "${RPMBUILD}/SOURCES/base.config"
else
    echo "ERROR: ${XR_DIR}/config/base.config not found."
    echo "Extract from honey: ssh jess@honey 'cat /boot/config-\$(uname -r)' > xr/config/base.config"
    exit 1
fi

# --- Step 5: Copy spec ---
cp "${XR_DIR}/specs/kernel-xr.spec" "${RPMBUILD}/SPECS/"

# --- Step 6: Skip separate patch test (rpmbuild applies patches in %prep) ---
echo ">>> Skipping separate patch test (rpmbuild handles patch application)."
echo ">>> If patches fail to apply, rpmbuild will exit with an error."

# --- Step 7: Build RPMs ---
echo ">>> Building RPMs..."
DEFINES=(
    --define "kversion ${KERNEL_VERSION}"
    --define "xr_release ${XR_RELEASE}"
)

if [[ -n "${RT_VERSION}" ]]; then
    DEFINES+=(--define "rt_version ${RT_VERSION}")
fi

rpmbuild -bb --nodeps "${DEFINES[@]}" "${RPMBUILD}/SPECS/kernel-xr.spec"

# --- Step 8: Report ---
echo ""
echo "=== Build complete ==="
echo "RPMs:"
find "${RPMBUILD}/RPMS" -name "kernel-xr*.rpm" -type f | while read -r rpm; do
    echo "  ${rpm}"
done
