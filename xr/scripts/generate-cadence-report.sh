#!/bin/bash
# generate-cadence-report.sh — Render a markdown report for the weekly upstream watch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_DIR="${XR_DIR}/patches"
SERIES_FILE="${PATCH_DIR}/series"

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

BASE_SHA="$(short_ref "${BASE_REF}")"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

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
    echo "1. Inspect the upstream-only commit list for merge candidates or conflicts."
    echo "2. Check whether every patch in \`xr/patches/series\` still applies cleanly."
    echo "3. Build both generic and RT variants if the carry set is unchanged."
    echo "4. Promote only after named-host validation on \`honey\` and \`yoga\`."
} > "${tmp_report}"

if [[ "${OUTPUT}" == "-" ]]; then
    cat "${tmp_report}"
else
    install -m 0644 "${tmp_report}" "${OUTPUT}"
fi
