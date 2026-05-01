#!/usr/bin/env bash
# Validate linux-xr kernel security posture after Kconfig resolution.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIG_FILE="${1:-${XR_DIR}/config/base.config}"

usage() {
    cat <<'EOF'
Usage: check-security-config.sh [CONFIG]

Validate the linux-xr SELinux-first kernel security contract.
When CONFIG is omitted, xr/config/base.config is checked.
EOF
}

case "${CONFIG_FILE}" in
    -h|--help)
        usage
        exit 0
        ;;
esac

if [[ ! -f "${CONFIG_FILE}" ]]; then
    echo "ERROR: config file not found: ${CONFIG_FILE}" >&2
    exit 1
fi

fail=0

config_line() {
    local key="$1"

    grep -E "^${key}=|^# ${key} is not set" "${CONFIG_FILE}" 2>/dev/null || true
}

fail_key() {
    local key="$1"
    local expected="$2"
    local actual="$3"

    echo "  FAIL: ${key} expected ${expected}, got ${actual:-MISSING}" >&2
    fail=1
}

expect_value() {
    local key="$1"
    local expected="$2"
    local actual

    actual="$(config_line "${key}")"
    if [[ "${actual}" == "${key}=${expected}" ]]; then
        echo "  OK: ${key}=${expected}"
    else
        fail_key "${key}" "${expected}" "${actual}"
    fi
}

expect_disabled_or_absent() {
    local key="$1"
    local actual

    actual="$(config_line "${key}")"
    case "${actual}" in
        ""|"# ${key} is not set"|"$key=n")
            echo "  OK: ${key} disabled or absent"
            ;;
        *)
            fail_key "${key}" "disabled or absent" "${actual}"
            ;;
    esac
}

expect_lsm() {
    local required="$1"
    local actual
    local lsm

    actual="$(config_line CONFIG_LSM)"
    lsm="${actual#CONFIG_LSM=}"
    lsm="${lsm%\"}"
    lsm="${lsm#\"}"

    if [[ ",${lsm}," == *",${required},"* ]]; then
        echo "  OK: CONFIG_LSM includes ${required}"
    else
        fail_key CONFIG_LSM "contains ${required}" "${actual}"
    fi
}

echo "=== Validating linux-xr SELinux/security config: ${CONFIG_FILE} ==="

# SELinux must be present and the default LSM for Rocky/RHEL-style operation.
expect_value CONFIG_SECURITY y
expect_value CONFIG_SECURITYFS y
expect_value CONFIG_SECURITY_NETWORK y
expect_value CONFIG_SECURITY_NETWORK_XFRM y
expect_value CONFIG_SECURITY_PATH y
expect_value CONFIG_SECURITY_SELINUX y
expect_value CONFIG_DEFAULT_SECURITY_SELINUX y
expect_value CONFIG_SECURITY_SELINUX_BOOTPARAM y
expect_disabled_or_absent CONFIG_SECURITY_SELINUX_DISABLE
expect_disabled_or_absent CONFIG_SECURITY_WRITABLE_HOOKS
expect_lsm selinux

# SELinux depends on audit and xattr/security-label support being available.
expect_value CONFIG_AUDIT y
expect_value CONFIG_AUDITSYSCALL y
expect_value CONFIG_TMPFS_XATTR y
expect_value CONFIG_TMPFS_POSIX_ACL y
expect_value CONFIG_EXT4_FS_SECURITY y
expect_value CONFIG_NFS_V4_SECURITY_LABEL y
expect_value CONFIG_NFSD_V4_SECURITY_LABEL y

# Keep companion LSM and integrity hooks available for lab hardening work.
expect_value CONFIG_SECURITY_LOCKDOWN_LSM y
expect_value CONFIG_SECURITY_LOCKDOWN_LSM_EARLY y
expect_value CONFIG_SECURITY_YAMA y
expect_value CONFIG_SECURITY_LANDLOCK y
expect_value CONFIG_BPF_LSM y
expect_lsm lockdown
expect_lsm yama
expect_lsm bpf
expect_value CONFIG_IMA y
expect_value CONFIG_IMA_APPRAISE y
expect_value CONFIG_IMA_LSM_RULES y
expect_value CONFIG_EVM y

# General hardening options that should not regress in this kernel lane.
expect_value CONFIG_BPF_UNPRIV_DEFAULT_OFF y
expect_value CONFIG_HARDENED_USERCOPY y
expect_value CONFIG_HARDENED_USERCOPY_DEFAULT_ON y
expect_value CONFIG_SLAB_FREELIST_HARDENED y
expect_value CONFIG_STRICT_DEVMEM y
expect_value CONFIG_LSM_MMAP_MIN_ADDR 65535
expect_value CONFIG_MODULE_SIG y
expect_value CONFIG_MODULE_SIG_ALL y
expect_value CONFIG_SYSTEM_TRUSTED_KEYRING y
expect_value CONFIG_INTEGRITY_TRUSTED_KEYRING y

if [[ "${fail}" -ne 0 ]]; then
    echo "FATAL: linux-xr security config validation failed." >&2
    exit 1
fi

echo "=== linux-xr security config validation passed ==="
