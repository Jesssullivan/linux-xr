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
SECURITY_PREFLIGHT_ONLY=0
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_DIR="${XR_DIR}/patches"
SERIES_FILE="${PATCH_DIR}/series"
SECURITY_DIR="${XR_DIR}/security"
SECURITY_CONFIG_CHECK="${XR_DIR}/scripts/check-security-config.sh"
CVE_2026_31431_PATCH="cve-2026-31431-algif-aead.patch"
DIRTYFRAG_ESP_PATCH="dirtyfrag-esp-shared-frag.patch"
DIRTYFRAG_RXRPC_PATCH="dirtyfrag-rxrpc-linearize.patch"
APPLY_CVE_2026_31431_PATCH=0
APPLY_DIRTYFRAG_ESP_PATCH=0
APPLY_DIRTYFRAG_RXRPC_PATCH=0

usage() {
    echo "Usage: $0 --kernel-version VER --xr-release REL [--rt-version RT_VER]"
    echo ""
    echo "Options:"
    echo "  --kernel-version  Kernel version (default: 6.19.5)"
    echo "  --xr-release      XR release number (default: 1)"
    echo "  --rt-version      RT patch version (e.g., 6.19.3-rt1; empty to skip)"
    echo "  --security-preflight-only"
    echo "                    Check security gates and exit before staging/building"
    echo "  --help            Show this help"
    echo ""
    echo "Security:"
    echo "  Vulnerable 6.19.x kernels use the repo-managed CVE-2026-31431 backport."
    echo "  Other vulnerable or unknown kernels are refused unless"
    echo "  LINUX_XR_ALLOW_CVE_2026_31431=1 is set for explicit validation."
    echo "  Dirty Frag ESP/RxRPC page-cache write hardening is required for"
    echo "  supported vulnerable bases; unsupported vulnerable or unknown bases"
    echo "  are refused unless LINUX_XR_ALLOW_DIRTYFRAG=1 is set."
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --kernel-version) KERNEL_VERSION="$2"; shift 2 ;;
        --xr-release)     XR_RELEASE="$2"; shift 2 ;;
        --rt-version)     RT_VERSION="$2"; shift 2 ;;
        --security-preflight-only) SECURITY_PREFLIGHT_ONLY=1; shift ;;
        --help)           usage ;;
        *)                echo "Unknown option: $1"; usage ;;
    esac
done

KRELEASE="${XR_RELEASE}.xr.el10"
KMAJOR="${KERNEL_VERSION%%.*}"

kernel_version_triplet() {
    local version="$1"
    local core major minor patch

    core="${version%%-*}"
    IFS=. read -r major minor patch _ <<< "${core}"
    patch="${patch:-0}"

    [[ "${major}" =~ ^[0-9]+$ && "${minor}" =~ ^[0-9]+$ && "${patch}" =~ ^[0-9]+$ ]] || return 1
    echo "${major} ${minor} ${patch}"
}

cve_2026_31431_status() {
    local version="$1"
    local core major minor patch

    core="${version%%-*}"
    IFS=. read -r major minor patch _ <<< "${core}"
    patch="${patch:-0}"

    if [[ ! "${major}" =~ ^[0-9]+$ || ! "${minor}" =~ ^[0-9]+$ || ! "${patch}" =~ ^[0-9]+$ ]]; then
        echo "unknown"
        return
    fi

    if [[ "${version}" == *-rc* ]]; then
        echo "vulnerable"
        return
    fi

    if (( major > 7 )); then
        echo "fixed-or-newer"
        return
    fi

    if (( major == 7 )); then
        echo "fixed"
        return
    fi

    if (( major == 6 && minor == 19 )); then
        if (( patch >= 12 )); then
            echo "fixed"
        else
            echo "vulnerable"
        fi
        return
    fi

    if (( major == 6 && minor == 18 )); then
        if (( patch >= 22 )); then
            echo "fixed"
        else
            echo "vulnerable"
        fi
        return
    fi

    if (( major == 6 && minor >= 13 && minor <= 17 )); then
        echo "vulnerable"
        return
    fi

    if (( major == 6 && minor == 12 )); then
        if (( patch >= 85 )); then
            echo "fixed"
        else
            echo "vulnerable"
        fi
        return
    fi

    if (( major == 6 && minor >= 7 && minor <= 11 )); then
        echo "vulnerable"
        return
    fi

    if (( major == 6 && minor == 6 )); then
        if (( patch >= 137 )); then
            echo "fixed"
        else
            echo "vulnerable"
        fi
        return
    fi

    if (( major == 6 && minor >= 2 && minor <= 5 )); then
        echo "vulnerable"
        return
    fi

    if (( major == 6 && minor == 1 )); then
        if (( patch >= 170 )); then
            echo "fixed"
        else
            echo "vulnerable"
        fi
        return
    fi

    if (( major == 6 && minor == 0 )); then
        echo "vulnerable"
        return
    fi

    if (( major == 5 && minor >= 16 )); then
        echo "vulnerable"
        return
    fi

    if (( major == 5 && minor == 15 )); then
        if (( patch >= 204 )); then
            echo "fixed"
        else
            echo "vulnerable"
        fi
        return
    fi

    if (( major == 5 && minor >= 11 && minor <= 14 )); then
        echo "vulnerable"
        return
    fi

    if (( major == 5 && minor == 10 )); then
        if (( patch >= 254 )); then
            echo "fixed"
        else
            echo "vulnerable"
        fi
        return
    fi

    if (( (major == 4 && minor >= 14) || (major == 5 && minor <= 9) )); then
        echo "vulnerable"
        return
    fi

    echo "unknown"
}

cve_2026_31431_repo_backport_applies() {
    local version="$1"
    local core major minor patch

    [[ "${version}" != *-rc* ]] || return 1

    core="${version%%-*}"
    IFS=. read -r major minor patch _ <<< "${core}"
    patch="${patch:-0}"

    [[ "${major}" =~ ^[0-9]+$ && "${minor}" =~ ^[0-9]+$ && "${patch}" =~ ^[0-9]+$ ]] || return 1
    (( major == 6 && minor == 19 && patch < 12 ))
}

dirtyfrag_esp_status() {
    local version="$1"
    local major minor patch

    if [[ "${version}" == *-rc* ]]; then
        echo "vulnerable"
        return
    fi

    if ! read -r major minor patch < <(kernel_version_triplet "${version}"); then
        echo "unknown"
        return
    fi

    if (( major > 7 )); then
        echo "unknown"
        return
    fi

    if (( major == 7 && minor == 0 )); then
        if (( patch >= 5 )); then
            echo "fixed"
        else
            echo "vulnerable"
        fi
        return
    fi

    if (( major == 6 && minor == 12 )); then
        if (( patch >= 87 )); then
            echo "fixed"
        else
            echo "vulnerable"
        fi
        return
    fi

    if (( major == 6 && (minor == 18 || minor == 19) )); then
        echo "vulnerable"
        return
    fi

    echo "unknown"
}

dirtyfrag_esp_repo_backport_applies() {
    local version="$1"
    local major minor patch

    [[ "${version}" != *-rc* ]] || return 1

    if ! read -r major minor patch < <(kernel_version_triplet "${version}"); then
        return 1
    fi

    (( major == 6 && (minor == 18 || minor == 19) )) ||
        (( major == 7 && minor == 0 && patch < 5 ))
}

dirtyfrag_rxrpc_status() {
    local version="$1"
    local major minor patch

    if [[ "${version}" == *-rc* ]]; then
        echo "vulnerable"
        return
    fi

    if ! read -r major minor patch < <(kernel_version_triplet "${version}"); then
        echo "unknown"
        return
    fi

    if (( major > 7 )); then
        echo "unknown"
        return
    fi

    if (( major == 7 && minor == 0 )); then
        echo "vulnerable"
        return
    fi

    if (( major == 6 && minor == 12 )); then
        echo "vulnerable"
        return
    fi

    if (( major == 6 && (minor == 18 || minor == 19) )); then
        echo "vulnerable"
        return
    fi

    echo "unknown"
}

dirtyfrag_rxrpc_repo_backport_applies() {
    local version="$1"
    local major minor patch

    [[ "${version}" != *-rc* ]] || return 1

    if ! read -r major minor patch < <(kernel_version_triplet "${version}"); then
        return 1
    fi

    (( major == 6 && (minor == 12 || minor == 18 || minor == 19) )) ||
        (( major == 7 && minor == 0 ))
}

enforce_cve_2026_31431_gate() {
    local status

    status="$(cve_2026_31431_status "${KERNEL_VERSION}")"
    case "${status}" in
        vulnerable)
            if cve_2026_31431_repo_backport_applies "${KERNEL_VERSION}" \
                && [[ -f "${SECURITY_DIR}/${CVE_2026_31431_PATCH}" ]]; then
                APPLY_CVE_2026_31431_PATCH=1
                echo ">>> CVE-2026-31431: ${KERNEL_VERSION} is vulnerable; applying ${CVE_2026_31431_PATCH}."
            elif [[ "${LINUX_XR_ALLOW_CVE_2026_31431:-}" == "1" ]]; then
                echo "WARNING: building ${KERNEL_VERSION} despite CVE-2026-31431 vulnerable range."
                echo "WARNING: this must be limited to explicit forensic or backport-validation work."
            else
                echo "ERROR: refusing to build ${KERNEL_VERSION}; it is in the known CVE-2026-31431 vulnerable range." >&2
                echo "ERROR: use a known fixed upstream floor or add a repo-managed backport for this base." >&2
                echo "ERROR: known fixed floors include 5.10.254+, 5.15.204+, 6.1.170+, 6.6.137+, 6.12.85+, 6.18.22+, 6.19.12+, and 7.0+." >&2
                echo "ERROR: set LINUX_XR_ALLOW_CVE_2026_31431=1 only for explicit validation." >&2
                exit 1
            fi
            ;;
        unknown)
            if [[ "${LINUX_XR_ALLOW_CVE_2026_31431:-}" == "1" ]]; then
                echo "WARNING: CVE-2026-31431 fixed status is unknown for ${KERNEL_VERSION}; override accepted."
            else
                echo "ERROR: CVE-2026-31431 fixed status is unknown for ${KERNEL_VERSION}." >&2
                echo "ERROR: update the security gate or set LINUX_XR_ALLOW_CVE_2026_31431=1 for an explicit validation build." >&2
                exit 1
            fi
            ;;
    esac
}

enforce_dirtyfrag_gate() {
    local esp_status rxrpc_status

    esp_status="$(dirtyfrag_esp_status "${KERNEL_VERSION}")"
    case "${esp_status}" in
        vulnerable)
            if dirtyfrag_esp_repo_backport_applies "${KERNEL_VERSION}" \
                && [[ -f "${SECURITY_DIR}/${DIRTYFRAG_ESP_PATCH}" ]]; then
                APPLY_DIRTYFRAG_ESP_PATCH=1
                echo ">>> Dirty Frag ESP: ${KERNEL_VERSION} is vulnerable; applying ${DIRTYFRAG_ESP_PATCH}."
            elif [[ "${LINUX_XR_ALLOW_DIRTYFRAG:-}" == "1" ]]; then
                echo "WARNING: building ${KERNEL_VERSION} despite Dirty Frag ESP vulnerable range."
            else
                echo "ERROR: refusing to build ${KERNEL_VERSION}; Dirty Frag ESP status is vulnerable and no repo-managed backport route is enabled." >&2
                echo "ERROR: use a fixed upstream floor, port ${DIRTYFRAG_ESP_PATCH}, or set LINUX_XR_ALLOW_DIRTYFRAG=1 only for explicit validation." >&2
                exit 1
            fi
            ;;
        unknown)
            if [[ "${LINUX_XR_ALLOW_DIRTYFRAG:-}" == "1" ]]; then
                echo "WARNING: Dirty Frag ESP fixed status is unknown for ${KERNEL_VERSION}; override accepted."
            else
                echo "ERROR: Dirty Frag ESP fixed status is unknown for ${KERNEL_VERSION}." >&2
                echo "ERROR: update the security gate or set LINUX_XR_ALLOW_DIRTYFRAG=1 for an explicit validation build." >&2
                exit 1
            fi
            ;;
    esac

    rxrpc_status="$(dirtyfrag_rxrpc_status "${KERNEL_VERSION}")"
    case "${rxrpc_status}" in
        vulnerable)
            if dirtyfrag_rxrpc_repo_backport_applies "${KERNEL_VERSION}" \
                && [[ -f "${SECURITY_DIR}/${DIRTYFRAG_RXRPC_PATCH}" ]]; then
                APPLY_DIRTYFRAG_RXRPC_PATCH=1
                echo ">>> Dirty Frag RxRPC: ${KERNEL_VERSION} is vulnerable; applying ${DIRTYFRAG_RXRPC_PATCH}."
            elif [[ "${LINUX_XR_ALLOW_DIRTYFRAG:-}" == "1" ]]; then
                echo "WARNING: building ${KERNEL_VERSION} despite Dirty Frag RxRPC vulnerable range."
            else
                echo "ERROR: refusing to build ${KERNEL_VERSION}; Dirty Frag RxRPC status is vulnerable and no repo-managed backport route is enabled." >&2
                echo "ERROR: use a fixed upstream floor, port ${DIRTYFRAG_RXRPC_PATCH}, or set LINUX_XR_ALLOW_DIRTYFRAG=1 only for explicit validation." >&2
                exit 1
            fi
            ;;
        unknown)
            if [[ "${LINUX_XR_ALLOW_DIRTYFRAG:-}" == "1" ]]; then
                echo "WARNING: Dirty Frag RxRPC fixed status is unknown for ${KERNEL_VERSION}; override accepted."
            else
                echo "ERROR: Dirty Frag RxRPC fixed status is unknown for ${KERNEL_VERSION}." >&2
                echo "ERROR: update the security gate or set LINUX_XR_ALLOW_DIRTYFRAG=1 for an explicit validation build." >&2
                exit 1
            fi
            ;;
    esac
}

enforce_cve_2026_31431_gate
enforce_dirtyfrag_gate

echo "=== linux-xr kernel build ==="
echo "  Kernel:  ${KERNEL_VERSION}"
echo "  Release: ${KRELEASE}"
echo "  RT:      ${RT_VERSION:-disabled}"
echo "  CVE-2026-31431 backport: ${APPLY_CVE_2026_31431_PATCH}"
echo "  Dirty Frag ESP backport: ${APPLY_DIRTYFRAG_ESP_PATCH}"
echo "  Dirty Frag RxRPC backport: ${APPLY_DIRTYFRAG_RXRPC_PATCH}"
echo ""

if [[ "${SECURITY_PREFLIGHT_ONLY}" == "1" ]]; then
    echo ">>> Security preflight complete; exiting before rpmbuild staging."
    exit 0
fi

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

# --- Step 3: Stage XR carry patches from this repo ---
echo ">>> Staging XR patches from ${PATCH_DIR}..."

if [[ ! -f "${SERIES_FILE}" ]]; then
    echo "ERROR: ${SERIES_FILE} not found."
    exit 1
fi

mapfile -t PATCHES < <(grep -vE '^[[:space:]]*(#|$)' "${SERIES_FILE}")

if [[ "${#PATCHES[@]}" -eq 0 ]]; then
    echo "ERROR: ${SERIES_FILE} does not list any carry patches."
    exit 1
fi

for patch in "${PATCHES[@]}"; do
    echo "    ${patch}"
    if [[ ! -f "${PATCH_DIR}/${patch}" ]]; then
        echo "ERROR: missing carry patch ${PATCH_DIR}/${patch}"
        exit 1
    fi
    install -m 0644 "${PATCH_DIR}/${patch}" "${RPMBUILD}/SOURCES/${patch}"
done

# --- Step 4: Stage security backports from this repo ---
if [[ "${APPLY_CVE_2026_31431_PATCH}" == "1" ]]; then
    echo ">>> Staging CVE-2026-31431 backport from ${SECURITY_DIR}..."
    if [[ ! -f "${SECURITY_DIR}/${CVE_2026_31431_PATCH}" ]]; then
        echo "ERROR: missing security patch ${SECURITY_DIR}/${CVE_2026_31431_PATCH}"
        exit 1
    fi
    install -m 0644 \
        "${SECURITY_DIR}/${CVE_2026_31431_PATCH}" \
        "${RPMBUILD}/SOURCES/${CVE_2026_31431_PATCH}"
fi

if [[ "${APPLY_DIRTYFRAG_ESP_PATCH}" == "1" ]]; then
    echo ">>> Staging Dirty Frag ESP backport from ${SECURITY_DIR}..."
    if [[ ! -f "${SECURITY_DIR}/${DIRTYFRAG_ESP_PATCH}" ]]; then
        echo "ERROR: missing security patch ${SECURITY_DIR}/${DIRTYFRAG_ESP_PATCH}"
        exit 1
    fi
    install -m 0644 \
        "${SECURITY_DIR}/${DIRTYFRAG_ESP_PATCH}" \
        "${RPMBUILD}/SOURCES/${DIRTYFRAG_ESP_PATCH}"
fi

if [[ "${APPLY_DIRTYFRAG_RXRPC_PATCH}" == "1" ]]; then
    echo ">>> Staging Dirty Frag RxRPC backport from ${SECURITY_DIR}..."
    if [[ ! -f "${SECURITY_DIR}/${DIRTYFRAG_RXRPC_PATCH}" ]]; then
        echo "ERROR: missing security patch ${SECURITY_DIR}/${DIRTYFRAG_RXRPC_PATCH}"
        exit 1
    fi
    install -m 0644 \
        "${SECURITY_DIR}/${DIRTYFRAG_RXRPC_PATCH}" \
        "${RPMBUILD}/SOURCES/${DIRTYFRAG_RXRPC_PATCH}"
fi

# --- Step 5: Copy base config ---
echo ">>> Copying base config..."
if [[ -f "${XR_DIR}/config/base.config" ]]; then
    cp "${XR_DIR}/config/base.config" "${RPMBUILD}/SOURCES/base.config"
else
    echo "ERROR: ${XR_DIR}/config/base.config not found."
    echo "Extract from honey: ssh jess@honey 'cat /boot/config-\$(uname -r)' > xr/config/base.config"
    exit 1
fi

# --- Step 6: Copy spec ---
if [[ ! -f "${SECURITY_CONFIG_CHECK}" ]]; then
    echo "ERROR: ${SECURITY_CONFIG_CHECK} not found."
    exit 1
fi
install -m 0755 "${SECURITY_CONFIG_CHECK}" "${RPMBUILD}/SOURCES/check-security-config.sh"
cp "${XR_DIR}/specs/kernel-xr.spec" "${RPMBUILD}/SPECS/"

# --- Step 7: Skip separate patch test (rpmbuild applies patches in %prep) ---
echo ">>> Skipping separate patch test (rpmbuild handles patch application)."
echo ">>> If patches fail to apply, rpmbuild will exit with an error."

# --- Step 8: Build RPMs ---
echo ">>> Building RPMs..."
DEFINES=(
    --define "kversion ${KERNEL_VERSION}"
    --define "xr_release ${XR_RELEASE}"
    --define "apply_cve_2026_31431_patch ${APPLY_CVE_2026_31431_PATCH}"
    --define "apply_dirtyfrag_esp_patch ${APPLY_DIRTYFRAG_ESP_PATCH}"
    --define "apply_dirtyfrag_rxrpc_patch ${APPLY_DIRTYFRAG_RXRPC_PATCH}"
)

if [[ -n "${RT_VERSION}" ]]; then
    DEFINES+=(--define "rt_version ${RT_VERSION}")
    DEFINES+=(--define "variant -rt")
fi

# Pass CC through for ccache support
if [[ -n "${CC:-}" ]]; then
    DEFINES+=(--define "_cc ${CC}")
    echo ">>> Using CC=${CC}"
fi

rpmbuild -bb --nodeps "${DEFINES[@]}" "${RPMBUILD}/SPECS/kernel-xr.spec"

# --- Step 9: Report ---
echo ""
echo "=== Build complete ==="
echo "RPMs:"
find "${RPMBUILD}/RPMS" -name "kernel-xr*.rpm" -type f | while read -r rpm; do
    echo "  ${rpm}"
done
