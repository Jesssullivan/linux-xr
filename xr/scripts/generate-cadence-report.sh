#!/bin/bash
# generate-cadence-report.sh — Render a markdown report for the weekly upstream watch.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
XR_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PATCH_DIR="${XR_DIR}/patches"
SERIES_FILE="${PATCH_DIR}/series"
BUILD_SCRIPT="${XR_DIR}/scripts/build-rpm.sh"
SECURITY_DIR="${XR_DIR}/security"
STABLE_URL="https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git"

CVE_2026_31431_MAINLINE_FIX="a664bf3d603dc3bdcf9ae47cc21e0daec706d7a5"
CVE_2026_31431_6_19_FIX="ce42ee423e58dffa5ec03524054c9d8bfd4f6237"
CVE_2026_31431_6_18_FIX="fafe0fa2995a0f7073c1c358d7d3145bcc9aedd8"
CVE_2026_31431_PATCH="cve-2026-31431-algif-aead.patch"
DIRTYFRAG_ESP_FIX="f4c50a4034e62ab75f1d5cdd191dd5f9c77fdff4"
DIRTYFRAG_ESP_PATCH="dirtyfrag-esp-shared-frag.patch"
DIRTYFRAG_RXRPC_PATCH="dirtyfrag-rxrpc-linearize.patch"

BASE_REF="HEAD"
UPSTREAM_REF=""
STABLE_REFS=()
OUTPUT="-"
MAX_COMMITS=10
PATCH_TRIAGE=1

usage() {
    cat <<'EOF'
Usage: generate-cadence-report.sh [options]

Options:
  --base-ref REF       Base branch or commit to inspect (default: HEAD)
  --upstream-ref REF   Upstream Linux ref to compare against
  --stable-ref REF     Stable or longterm Linux ref to compare against; repeatable
  --output PATH        Output markdown file ('-' for stdout)
  --max-commits N      Number of commits to show per section (default: 10)
  --skip-patch-triage  Do not create temporary worktrees to test patch application
  --help               Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --base-ref) BASE_REF="$2"; shift 2 ;;
        --upstream-ref) UPSTREAM_REF="$2"; shift 2 ;;
        --stable-ref) STABLE_REFS+=("$2"); shift 2 ;;
        --output) OUTPUT="$2"; shift 2 ;;
        --max-commits) MAX_COMMITS="$2"; shift 2 ;;
        --skip-patch-triage) PATCH_TRIAGE=0; shift ;;
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

stable_family_from_ref() {
    local ref="$1"

    if [[ "${ref}" =~ linux-([0-9]+\.[0-9]+)\.y ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi

    if [[ "${ref}" =~ v([0-9]+\.[0-9]+)\. ]]; then
        echo "${BASH_REMATCH[1]}"
        return
    fi

    return 1
}

latest_stable_tag_for_ref() {
    local ref="$1"
    local described
    local family
    local tag

    if family="$(stable_family_from_ref "${ref}")"; then
        tag="$(
            { git ls-remote --tags "${STABLE_URL}" "refs/tags/v${family}.*" 2>/dev/null || true; } |
                awk '{print $2}' |
                sed 's#refs/tags/##; s/\^{}//' |
                sort -Vu |
                tail -n 1
        )"

        if [[ -n "${tag}" ]]; then
            echo "${tag}"
            return
        fi
    fi

    described="$(describe_ref "${ref}")"
    echo "${described}"
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

markdown_cell() {
    local value="$1"

    value="${value//$'\n'/ }"
    value="${value//|/\\|}"
    echo "${value}"
}

series_patch_count() {
    if [[ ! -f "${SERIES_FILE}" ]]; then
        echo 0
        return
    fi

    grep -Ev '^[[:space:]]*($|#)' "${SERIES_FILE}" | wc -l | tr -d ' '
}

series_apply_status() {
    local label="$1"
    local ref="$2"
    local worktree
    local err_file
    local patch
    local count=0
    local status="clean"
    local detail

    if [[ -z "${ref}" ]] || ! has_ref "${ref}"; then
        echo "| ${label} | \`${ref:-unavailable}\` | \`unavailable\` | ref unavailable |"
        return
    fi

    if [[ ! -f "${SERIES_FILE}" ]]; then
        echo "| ${label} | \`${ref}\` | \`unavailable\` | series missing |"
        return
    fi

    worktree="$(mktemp -d)"
    err_file="$(mktemp)"

    if ! git worktree add --detach --quiet "${worktree}" "${ref}" >"${err_file}" 2>&1; then
        detail="$(head -n 1 "${err_file}")"
        rm -rf "${worktree}" "${err_file}"
        echo "| ${label} | \`${ref}\` | \`unavailable\` | $(markdown_cell "${detail:-worktree checkout failed}") |"
        return
    fi

    if [[ "$(git -C "${worktree}" config --bool core.sparseCheckout || true)" == "true" ]]; then
        detail="checkout is sparse; kernel source paths are unavailable"
        git worktree remove --force "${worktree}" >/dev/null 2>&1 || rm -rf "${worktree}"
        rm -f "${err_file}"
        echo "| ${label} | \`${ref}\` | \`unavailable\` | $(markdown_cell "${detail}") |"
        return
    fi

    while IFS= read -r patch; do
        [[ -z "${patch}" || "${patch}" =~ ^[[:space:]]*# ]] && continue
        count=$((count + 1))
        if ! git -C "${worktree}" apply --check "${PATCH_DIR}/${patch}" >"${err_file}" 2>&1; then
            status="conflict"
            detail="${patch}: $(head -n 1 "${err_file}")"
            break
        fi
        if ! git -C "${worktree}" apply "${PATCH_DIR}/${patch}" >"${err_file}" 2>&1; then
            status="conflict"
            detail="${patch}: $(head -n 1 "${err_file}")"
            break
        fi
    done < "${SERIES_FILE}"

    if [[ "${status}" == "clean" ]]; then
        detail="${count}/$(series_patch_count) patches apply in series order"
    fi

    git worktree remove --force "${worktree}" >/dev/null 2>&1 || rm -rf "${worktree}"
    rm -f "${err_file}"

    echo "| ${label} | \`${ref}\` | \`${status}\` | $(markdown_cell "${detail}") |"
}

default_kernel_version() {
    sed -nE 's/^KERNEL_VERSION="([^"]+)"/\1/p' "${BUILD_SCRIPT}" | head -n 1
}

kernel_version_triplet() {
    local version="$1"
    local core major minor patch

    core="${version%%-*}"
    IFS=. read -r major minor patch _ <<< "${core}"
    patch="${patch:-0}"

    [[ "${major}" =~ ^[0-9]+$ && "${minor}" =~ ^[0-9]+$ && "${patch}" =~ ^[0-9]+$ ]] || return 1
    echo "${major} ${minor} ${patch}"
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

security_patch_status() {
    local patch="$1"

    if [[ -f "${SECURITY_DIR}/${patch}" ]]; then
        echo "present"
    else
        echo "missing"
    fi
}

dirtyfrag_esp_version_status() {
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

dirtyfrag_esp_build_route_status() {
    local version="$1"
    local version_status

    version_status="$(dirtyfrag_esp_version_status "${version}")"
    case "${version_status}" in
        fixed)
            echo "fixed-base"
            ;;
        vulnerable)
            if dirtyfrag_esp_repo_backport_applies "${version}"; then
                if [[ "$(security_patch_status "${DIRTYFRAG_ESP_PATCH}")" == "present" ]]; then
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

dirtyfrag_rxrpc_version_status() {
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

    (( major == 6 && (minor == 18 || minor == 19) )) ||
        (( major == 7 && minor == 0 ))
}

dirtyfrag_rxrpc_build_route_status() {
    local version="$1"
    local version_status

    version_status="$(dirtyfrag_rxrpc_version_status "${version}")"
    case "${version_status}" in
        vulnerable)
            if dirtyfrag_rxrpc_repo_backport_applies "${version}"; then
                if [[ "$(security_patch_status "${DIRTYFRAG_RXRPC_PATCH}")" == "present" ]]; then
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

cve_2026_31431_ref_fix_status() {
    local ref="$1"
    local commit=""

    case "${ref}" in
        *linux-7.0.y*|*v7.0*)
            commit="${CVE_2026_31431_MAINLINE_FIX}"
            ;;
        *linux-6.19.y*|*v6.19*)
            commit="${CVE_2026_31431_6_19_FIX}"
            ;;
        *linux-6.18.y*|*v6.18*)
            commit="${CVE_2026_31431_6_18_FIX}"
            ;;
        *)
            echo "unknown-ref-family"
            return
            ;;
    esac

    ref_contains_commit "${ref}" "${commit}"
}

ref_label() {
    local ref="$1"

    basename "${ref}"
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
    echo "| Dirty Frag ESP default base kernel \`${DEFAULT_KERNEL_VERSION:-unavailable}\` | \`$(dirtyfrag_esp_version_status "${DEFAULT_KERNEL_VERSION:-unknown}")\` |"
    echo "| Dirty Frag ESP repo backport \`${DIRTYFRAG_ESP_PATCH}\` | \`$(security_patch_status "${DIRTYFRAG_ESP_PATCH}")\` |"
    echo "| Dirty Frag ESP default build route | \`$(dirtyfrag_esp_build_route_status "${DEFAULT_KERNEL_VERSION:-unknown}")\` |"
    echo "| Dirty Frag ESP upstream fix \`${DIRTYFRAG_ESP_FIX:0:12}\` in upstream ref | \`$(ref_contains_commit "${UPSTREAM_REF}" "${DIRTYFRAG_ESP_FIX}")\` |"
    echo "| Dirty Frag RxRPC default base kernel \`${DEFAULT_KERNEL_VERSION:-unavailable}\` | \`$(dirtyfrag_rxrpc_version_status "${DEFAULT_KERNEL_VERSION:-unknown}")\` |"
    echo "| Dirty Frag RxRPC repo backport \`${DIRTYFRAG_RXRPC_PATCH}\` | \`$(security_patch_status "${DIRTYFRAG_RXRPC_PATCH}")\` |"
    echo "| Dirty Frag RxRPC default build route | \`$(dirtyfrag_rxrpc_build_route_status "${DEFAULT_KERNEL_VERSION:-unknown}")\` |"
    if [[ "${#STABLE_REFS[@]}" -gt 0 ]]; then
        for stable_ref in "${STABLE_REFS[@]}"; do
            echo "| CVE-2026-31431 fix in candidate ref \`${stable_ref}\` | \`$(cve_2026_31431_ref_fix_status "${stable_ref}")\` |"
        done
    else
        echo "| CVE-2026-31431 fix in candidate refs | \`unavailable\` |"
    fi
    echo
    echo "Known fixed floors for this gate include: \`5.10.254+\`, \`5.15.204+\`, \`6.1.170+\`, \`6.6.137+\`, \`6.12.85+\`, \`6.18.22+\`, \`6.19.12+\`, and \`7.0+\`."
    echo "For vulnerable \`6.19.x\` bases, \`build-rpm.sh\` applies the repo backport when present."
    echo "Dirty Frag ESP is tracked as fixed in \`7.0.5+\` for the \`7.0.x\` lane; Dirty Frag RxRPC has no upstream fixed floor recorded here yet, so supported bases rely on the repo backport."
    echo
    echo "## Carry Apply Triage"
    echo
    echo "| Target | Ref | Status | Detail |"
    echo "| --- | --- | --- | --- |"
    if [[ "${PATCH_TRIAGE}" == "1" ]]; then
        series_apply_status "base" "${BASE_REF}"
        series_apply_status "upstream" "${UPSTREAM_REF}"
        if [[ "${#STABLE_REFS[@]}" -gt 0 ]]; then
            for stable_ref in "${STABLE_REFS[@]}"; do
                series_apply_status "$(ref_label "${stable_ref}")" "${stable_ref}"
            done
        else
            series_apply_status "stable" ""
        fi
    else
        echo "| all | n/a | \`skipped\` | patch triage disabled |"
    fi
    echo
    echo "## Stable Summary"
    echo

    if [[ "${#STABLE_REFS[@]}" -gt 0 ]]; then
        for stable_ref in "${STABLE_REFS[@]}"; do
            if has_ref "${stable_ref}"; then
                echo "- Candidate ref: \`${stable_ref}\` (\`$(short_ref "${stable_ref}")\`), latest tag \`$(latest_stable_tag_for_ref "${stable_ref}")\`"
            else
                echo "- Candidate ref unavailable: \`${stable_ref}\`"
            fi
        done
    else
        echo "- Stable refs unavailable in this checkout."
    fi

    echo
    echo "## Next Actions"
    echo
    echo "1. Resolve any \`vulnerable\`, \`backport-missing\`, or \`unknown\` security build route before release work."
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
