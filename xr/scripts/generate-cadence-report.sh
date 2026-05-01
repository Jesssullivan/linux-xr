#!/bin/bash
# generate-cadence-report.sh — Render a markdown report for the weekly upstream watch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_DIR="${XR_DIR}/patches"
SERIES_FILE="${PATCH_DIR}/series"
BUILD_SCRIPT="${XR_DIR}/scripts/build-rpm.sh"
SECURITY_DIR="${XR_DIR}/security"

CVE_2026_31431_MAINLINE_FIX="a664bf3d603dc3bdcf9ae47cc21e0daec706d7a5"
CVE_2026_31431_6_19_FIX="ce42ee423e58dffa5ec03524054c9d8bfd4f6237"
CVE_2026_31431_6_18_FIX="fafe0fa2995a0f7073c1c358d7d3145bcc9aedd8"
CVE_2026_31431_PATCH="cve-2026-31431-algif-aead.patch"

BASE_REF="HEAD"
UPSTREAM_REF=""
STABLE_REF=""
OUTPUT="-"
MAX_COMMITS=10

usage() {
    cat <<'EOF'
Usage: generate-cadence-report.sh [options]

Options:
  --base-ref REF       Base branch or commit to inspect (default: HEAD)
  --upstream-ref REF   Upstream Linux ref to compare against
  --stable-ref REF     Stable Linux ref to compare against
  --output PATH        Output markdown file ('-' for stdout)
  --max-commits N      Number of commits to show per section (default: 10)
  --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base-ref) BASE_REF="$2"; shift 2 ;;
        --upstream-ref) UPSTREAM_REF="$2"; shift 2 ;;
        --stable-ref) STABLE_REF="$2"; shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --max-commits) MAX_COMMITS="$2"; shift 2 ;;
        --help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

has_ref() {
    git rev-parse --verify -q "$1^{commit}" >/dev/null 2>&1
}

short_ref() {
    git rev-parse --short "$1" 2>/dev/null || echo "unavailable"
}

describe_ref() {
    git describe --tags --abbrev=0 "$1" 2>/dev/null || echo "unavailable"
}

commit_list() {
    local range="$1"
    git log --format='- `%h` %s' --no-merges -n "${MAX_COMMITS}" "${range}" 2>/dev/null || true
}

carry_rows() {
    local idx=1

    if [[ ! -f "${SERIES_FILE}" ]]; then
        echo "| n/a | `series missing` |"
        return
    fi

    while IFS= read -r patch; do
        [[ -z "${patch}" || "${patch}" =~ ^[[:space:]]*# ]] && continue
        echo "| ${idx} | \`${patch}\` |"
        idx=$((idx + 1))
    done < "${SERIES_FILE}"
}

default_kernel_version() {
    sed -nE 's/^KERNEL_VERSION="([^"]+)"/\1/p' "${BUILD_SCRIPT}" | head -n 1
}

cve_2026_31431_version_status() {
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

cve_2026_31431_repo_backport_status() {
    if [[ -f "${SECURITY_DIR}/${CVE_2026_31431_PATCH}" ]]; then
        echo "present"
    else
        echo "missing"
    fi
}

cve_2026_31431_build_route_status() {
    local version="$1"
    local version_status

    version_status="$(cve_2026_31431_version_status "${version}")"
    case "${version_status}" in
        fixed|fixed-or-newer)
            echo "fixed-base"
            ;;
        vulnerable)
            if cve_2026_31431_repo_backport_applies "${version}"; then
                if [[ "$(cve_2026_31431_repo_backport_status)" == "present" ]]; then
                    echo "repo-backport-applied-by-build"
                else
                    echo "backport-missing"
                fi
            else
                echo "vulnerable"
            fi
            ;;
        *)
            echo "${version_status}"
            ;;
    esac
}

ref_contains_commit() {
    local ref="$1"
    local commit="$2"

    if [[ -z "${ref}" ]] || ! has_ref "${ref}"; then
        echo "unavailable"
        return
    fi

    if ! git cat-file -e "${commit}^{commit}" >/dev/null 2>&1; then
        echo "unavailable"
        return
    fi

    if git merge-base --is-ancestor "${commit}" "${ref}" >/dev/null 2>&1; then
        echo "yes"
    else
        echo "no"
    fi
}

BASE_SHA="$(short_ref "${BASE_REF}")"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
DEFAULT_KERNEL_VERSION="$(default_kernel_version)"

tmp_report="$(mktemp)"
trap 'rm -f "${tmp_report}"' EXIT

{
    echo "# linux-xr Weekly Cadence Report"
    echo
    echo "- Generated: ${GENERATED_AT}"
    echo "- Base ref: \`${BASE_REF}\` (\`${BASE_SHA}\`)"
    echo
    echo "## Carry Set"
    echo
    echo "| Order | Patch |"
    echo "| --- | --- |"
    carry_rows
    echo
    echo "## Upstream Summary"
    echo

    if [[ -n "${UPSTREAM_REF}" ]] && has_ref "${UPSTREAM_REF}"; then
        MERGE_BASE="$(git merge-base "${BASE_REF}" "${UPSTREAM_REF}")"
        UPSTREAM_ONLY="$(git rev-list --count "${MERGE_BASE}..${UPSTREAM_REF}")"
        FORK_ONLY="$(git rev-list --count "${MERGE_BASE}..${BASE_REF}")"

        echo "- Upstream ref: \`${UPSTREAM_REF}\` (\`$(short_ref "${UPSTREAM_REF}")\`)"
        echo "- Latest upstream tag: \`$(describe_ref "${UPSTREAM_REF}")\`"
        echo "- Merge base: \`$(git rev-parse --short "${MERGE_BASE}")\`"
        echo "- Upstream-only commits since merge base: ${UPSTREAM_ONLY}"
        echo "- Fork-only commits since merge base: ${FORK_ONLY}"
        echo
        echo "### Recent Upstream Commits"
        echo
        commits="$(commit_list "${MERGE_BASE}..${UPSTREAM_REF}")"
        if [[ -n "${commits}" ]]; then
            echo "${commits}"
        else
            echo "- none"
        fi
        echo
        echo "### Recent Fork Commits"
        echo
        commits="$(commit_list "${MERGE_BASE}..${BASE_REF}")"
        if [[ -n "${commits}" ]]; then
            echo "${commits}"
        else
            echo "- none"
        fi
    else
        echo "- Upstream ref unavailable in this checkout."
    fi

    echo
    echo "## Security Watch"
    echo
    echo "| Item | Status |"
    echo "| --- | --- |"
    echo "| CVE-2026-31431 default base kernel \`${DEFAULT_KERNEL_VERSION:-unavailable}\` | \`$(cve_2026_31431_version_status "${DEFAULT_KERNEL_VERSION:-unknown}")\` |"
    echo "| CVE-2026-31431 repo backport \`${CVE_2026_31431_PATCH}\` | \`$(cve_2026_31431_repo_backport_status)\` |"
    echo "| CVE-2026-31431 default build route | \`$(cve_2026_31431_build_route_status "${DEFAULT_KERNEL_VERSION:-unknown}")\` |"
    echo "| CVE-2026-31431 upstream/mainline fix \`${CVE_2026_31431_MAINLINE_FIX:0:12}\` in upstream ref | \`$(ref_contains_commit "${UPSTREAM_REF}" "${CVE_2026_31431_MAINLINE_FIX}")\` |"
    echo "| CVE-2026-31431 6.19.y fix \`${CVE_2026_31431_6_19_FIX:0:12}\` in stable ref | \`$(ref_contains_commit "${STABLE_REF}" "${CVE_2026_31431_6_19_FIX}")\` |"
    echo
    echo "Known fixed floors for this gate: \`6.19.12+\`, \`6.18.22+\`, and \`7.0+\`."
    echo "For vulnerable \`6.19.x\` bases, \`build-rpm.sh\` applies the repo backport when present."
    echo
    echo "## Stable Summary"
    echo

    if [[ -n "${STABLE_REF}" ]] && has_ref "${STABLE_REF}"; then
        echo "- Stable ref: \`${STABLE_REF}\` (\`$(short_ref "${STABLE_REF}")\`)"
        echo "- Latest stable tag: \`$(describe_ref "${STABLE_REF}")\`"
    else
        echo "- Stable ref unavailable in this checkout."
    fi

    echo
    echo "## Next Actions"
    echo
    echo "1. Resolve any \`vulnerable\`, \`backport-missing\`, or \`unknown\` default build route before release work."
    echo "2. Inspect the upstream-only commit list for merge candidates or conflicts."
    echo "3. Check whether every patch in \`xr/patches/series\` still applies cleanly."
    echo "4. Build both generic and RT variants if the carry set is unchanged."
    echo "5. Promote only after named-host validation on \`honey\` and \`yoga\`."
} > "${tmp_report}"

if [[ "${OUTPUT}" == "-" ]]; then
    cat "${tmp_report}"
else
    install -m 0644 "${tmp_report}" "${OUTPUT}"
fi
