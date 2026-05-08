#!/usr/bin/env bash
# triage-upstream-targets.sh - Discover maintained kernel targets and optionally
# run linux-xr carry/security preflights against them.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CHECK_CARRY="${XR_DIR}/scripts/check-kernel-carry.sh"
BUILD_RPM="${XR_DIR}/scripts/build-rpm.sh"

STABLE_URL="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"
RT_BASE_URL="https://cdn.kernel.org/pub/linux/kernel/projects/rt"
STABLE_FAMILIES=("7.0" "6.18" "6.12")
RT_FAMILIES=("7.0" "6.18" "6.19")
RUN_PREFLIGHT=0
OUTPUT="-"

usage() {
    cat <<'EOF'
Usage: triage-upstream-targets.sh [options]

Options:
  --run-preflight       Run carry and security preflights for discovered targets
  --stable-family X.Y   Stable family to inspect; repeatable (default: 7.0, 6.18, 6.12)
  --rt-family X.Y       RT patch family to inspect; repeatable (default: 7.0, 6.18, 6.19)
  --output PATH         Output markdown file ('-' for stdout)
  --help                Show this help

The default mode is a network-backed report only. With --run-preflight, this
script downloads source tarballs through check-kernel-carry.sh and may take
several minutes per target.
EOF
}

custom_stable_families=()
custom_rt_families=()

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run-preflight)
            RUN_PREFLIGHT=1
            shift
            ;;
        --stable-family)
            custom_stable_families+=("$2")
            shift 2
            ;;
        --rt-family)
            custom_rt_families+=("$2")
            shift 2
            ;;
        --output)
            OUTPUT="$2"
            shift 2
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

if [[ "${#custom_stable_families[@]}" -gt 0 ]]; then
    STABLE_FAMILIES=("${custom_stable_families[@]}")
fi

if [[ "${#custom_rt_families[@]}" -gt 0 ]]; then
    RT_FAMILIES=("${custom_rt_families[@]}")
fi

require_command() {
    local command="$1"

    if ! command -v "${command}" >/dev/null 2>&1; then
        echo "ERROR: required command not found: ${command}" >&2
        exit 1
    fi
}

markdown_cell() {
    local value="$1"

    value="${value//$'\n'/ }"
    value="${value//|/\\|}"
    echo "${value}"
}

latest_stable_tag() {
    local family="$1"

    git ls-remote --tags "${STABLE_URL}" "refs/tags/v${family}.*" |
        awk '{print $2}' |
        sed 's#refs/tags/##; s/\^{}//' |
        sort -Vu |
        tail -n 1
}

latest_rt_patch() {
    local family="$1"

    curl -fsSL "${RT_BASE_URL}/${family}/" |
        grep -Eo 'patch-[0-9][^"<> ]+\.patch\.xz' |
        sort -Vu |
        tail -n 1
}

rt_version_from_patch() {
    local patch="$1"

    patch="${patch#patch-}"
    patch="${patch%.patch.xz}"
    echo "${patch}"
}

kernel_version_from_rt_version() {
    local rt_version="$1"

    echo "${rt_version%-rt*}"
}

run_preflight() {
    local log_file="$1"
    shift

    if "$@" >"${log_file}" 2>&1; then
        echo "pass"
    else
        echo "fail"
    fi
}

preflight_detail() {
    local log_file="$1"

    if [[ ! -s "${log_file}" ]]; then
        echo "no output"
        return
    fi

    tail -n 8 "${log_file}" |
        sed -n '/^ERROR:/p; /^===/p; /^>>> Security preflight complete/p; /^patch: \*\*\*\*/p' |
        tail -n 2 |
        paste -sd ' ' -
}

require_command git
require_command curl
require_command awk
require_command sed
require_command sort
require_command tail
require_command paste

if [[ "${RUN_PREFLIGHT}" == "1" ]]; then
    require_command patch
    require_command tar
    [[ -x "${CHECK_CARRY}" ]] || chmod +x "${CHECK_CARRY}"
    [[ -x "${BUILD_RPM}" ]] || chmod +x "${BUILD_RPM}"
fi

tmp_dir="$(mktemp -d)"
tmp_report="$(mktemp)"
trap 'rm -rf "${tmp_dir}" "${tmp_report}"' EXIT

{
    echo "# linux-xr Upstream Target Triage"
    echo
    echo "- Generated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "- Stable source: \`${STABLE_URL}\`"
    echo "- RT source: \`${RT_BASE_URL}\`"
    echo "- Preflights: \`${RUN_PREFLIGHT}\`"
    echo
    echo "## Maintained Generic Candidates"
    echo
    echo "| Family | Latest tag | Kernel version | Carry dry-run | Security preflight | Detail |"
    echo "| --- | --- | --- | --- | --- | --- |"

    for family in "${STABLE_FAMILIES[@]}"; do
        tag="$(latest_stable_tag "${family}" || true)"
        version="${tag#v}"
        carry_status="not-run"
        security_status="not-run"
        detail="run with --run-preflight"

        if [[ -z "${tag}" ]]; then
            version="unavailable"
            detail="no matching stable tag found"
        elif [[ "${RUN_PREFLIGHT}" == "1" ]]; then
            carry_log="${tmp_dir}/generic-${version}-carry.log"
            security_log="${tmp_dir}/generic-${version}-security.log"
            carry_status="$(run_preflight "${carry_log}" "${CHECK_CARRY}" --kernel-version "${version}")"
            security_status="$(run_preflight "${security_log}" "${BUILD_RPM}" --kernel-version "${version}" --xr-release 1 --security-preflight-only)"
            detail="$(preflight_detail "${security_log}")"
            if [[ -z "${detail}" ]]; then
                detail="$(preflight_detail "${carry_log}")"
            fi
        fi

        echo "| \`${family}.x\` | \`${tag:-unavailable}\` | \`${version}\` | \`${carry_status}\` | \`${security_status}\` | $(markdown_cell "${detail}") |"
    done

    echo
    echo "## RT Patch Floors"
    echo
    echo "| Family | Latest RT patch | Kernel version | Carry + RT dry-run | Security preflight | Detail |"
    echo "| --- | --- | --- | --- | --- | --- |"

    for family in "${RT_FAMILIES[@]}"; do
        patch_name="$(latest_rt_patch "${family}" || true)"
        rt_version="unavailable"
        version="unavailable"
        carry_status="not-run"
        security_status="not-run"
        detail="run with --run-preflight"

        if [[ -z "${patch_name}" ]]; then
            patch_name="unavailable"
            detail="no matching RT patch found"
        else
            rt_version="$(rt_version_from_patch "${patch_name}")"
            version="$(kernel_version_from_rt_version "${rt_version}")"

            if [[ "${RUN_PREFLIGHT}" == "1" ]]; then
                carry_log="${tmp_dir}/rt-${rt_version}-carry.log"
                security_log="${tmp_dir}/rt-${rt_version}-security.log"
                carry_status="$(run_preflight "${carry_log}" "${CHECK_CARRY}" --kernel-version "${version}" --rt-version "${rt_version}")"
                security_status="$(run_preflight "${security_log}" "${BUILD_RPM}" --kernel-version "${version}" --xr-release 1 --rt-version "${rt_version}" --security-preflight-only)"
                detail="$(preflight_detail "${security_log}")"
                if [[ -z "${detail}" ]]; then
                    detail="$(preflight_detail "${carry_log}")"
                fi
            fi
        fi

        echo "| \`${family}.x\` | \`${patch_name}\` | \`${version}\` | \`${carry_status}\` | \`${security_status}\` | $(markdown_cell "${detail}") |"
    done

    echo
    echo "## Next Actions"
    echo
    echo "1. Prefer the newest maintained generic candidate whose carry and security preflights pass."
    echo "2. Treat RT as a separate lane when the newest stable tag and newest RT patch floor differ."
    echo "3. Do not promote an older RT floor if the security preflight fails; port the missing security backport or keep RT pinned."
} > "${tmp_report}"

if [[ "${OUTPUT}" == "-" ]]; then
    cat "${tmp_report}"
else
    install -m 0644 "${tmp_report}" "${OUTPUT}"
fi
