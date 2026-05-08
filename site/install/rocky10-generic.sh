#!/usr/bin/env bash
set -euo pipefail

PAGES_BASE="${PAGES_BASE:-https://tinyland-inc.github.io/linux-xr}"
API_URL="${API_URL:-https://api.github.com/repos/tinyland-inc/linux-xr/releases?per_page=30}"
MANIFEST_URL="${PAGES_BASE}/releases/latest.json"
DOWNLOAD_ONLY=0
PRINT_ASSETS=0
SET_DEFAULT=1
INSTALL_DEVEL=0
INSTALL_HEADERS=0
TARGET_DIR=""

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

usage() {
    cat <<'EOF'
Usage: rocky10-generic.sh [options]

Options:
  --print-assets      Print the selected release tag and RPM URLs, then exit
  --download-only     Download RPMs without installing them
  --target-dir DIR    Directory to place downloaded RPMs in
  --no-set-default    Skip grubby default-kernel update after install
  --with-devel        Install the matching kernel-xr-devel RPM too
  --with-headers      Install kernel-xr-headers too; conflicts with stock kernel-headers
  --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --print-assets) PRINT_ASSETS=1; shift ;;
        --download-only) DOWNLOAD_ONLY=1; shift ;;
        --target-dir) TARGET_DIR="$2"; shift 2 ;;
        --no-set-default) SET_DEFAULT=0; shift ;;
        --with-devel) INSTALL_DEVEL=1; shift ;;
        --with-headers) INSTALL_HEADERS=1; shift ;;
        --help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

need_cmd curl
need_cmd python3

if (( PRINT_ASSETS == 0 && DOWNLOAD_ONLY == 0 )); then
    need_cmd sudo
    need_cmd dnf
    need_cmd rpm
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if curl -fsSL "$MANIFEST_URL" -o "$WORKDIR/releases.json"; then
    if ! python3 - "$WORKDIR/releases.json" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
raise SystemExit(0 if isinstance(data, dict) and data.get("manifest_schema_version") == 2 else 1)
PY
    then
        curl -fsSL "$API_URL" -o "$WORKDIR/releases.json"
    fi
else
    curl -fsSL "$API_URL" -o "$WORKDIR/releases.json"
fi

mapfile -t RELEASE_LINES < <(python3 - "$WORKDIR/releases.json" <<'PY'
import json
import re
import sys

with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)

lab_tag = re.compile(r"^v\d+\.\d+\.\d+-xr\d+$")
generic_runtime = re.compile(r"kernel-xr-[0-9].*\.rpm$")
rt_runtime = re.compile(r"kernel-xr-rt-[0-9].*\.rpm$")
generic_asset = re.compile(r"kernel-xr(?:-(?:devel|headers))?-[^/]+\.rpm$")


def published_key(release):
    return release.get("published_at") or release.get("created_at") or ""


def is_installable(release):
    if release.get("draft"):
        return False
    if not lab_tag.fullmatch(release.get("tag_name", "")):
        return False
    names = [asset.get("name", "") for asset in release.get("assets", [])]
    return (
        any(generic_runtime.fullmatch(name) for name in names)
        and any(rt_runtime.fullmatch(name) for name in names)
    )


if isinstance(data, list):
    candidates = sorted(
        (release for release in data if is_installable(release)),
        key=published_key,
        reverse=True,
    )
    if not candidates:
        raise SystemExit("No installable linux-xr lab release found.")
    data = candidates[0]

print(data["tag_name"])
for asset in data.get("assets", []):
    name = asset.get("name", "")
    url = asset.get("browser_download_url", "")
    if not url:
        continue
    if name.startswith("kernel-xr-rt-"):
        continue
    if generic_asset.fullmatch(name):
        print(url)
PY
)

TAG="${RELEASE_LINES[0]:-}"
URLS=("${RELEASE_LINES[@]:1}")

if [ "${#URLS[@]}" -eq 0 ]; then
    echo "No generic RPM assets found in latest installable release." >&2
    exit 1
fi

if (( PRINT_ASSETS == 1 )); then
    echo "linux-xr generic release ${TAG}"
    printf '%s\n' "${URLS[@]}"
    exit 0
fi

if [[ -n "${TARGET_DIR}" ]]; then
    mkdir -p "${TARGET_DIR}"
    DOWNLOAD_DIR="$(cd "${TARGET_DIR}" && pwd)"
elif (( DOWNLOAD_ONLY == 1 )); then
    DOWNLOAD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/linux-xr-generic.XXXXXX")"
else
    DOWNLOAD_DIR="${WORKDIR}"
fi

cd "$DOWNLOAD_DIR"
for url in "${URLS[@]}"; do
    curl -fL -O "$url"
done

if (( DOWNLOAD_ONLY == 1 )); then
    echo "Downloaded linux-xr generic release ${TAG} to ${DOWNLOAD_DIR}"
    exit 0
fi

mapfile -t INSTALL_RPMS < <(find . -maxdepth 1 -type f -name 'kernel-xr-[0-9]*.rpm' | sort)

if (( INSTALL_DEVEL == 1 )); then
    mapfile -t DEVEL_RPMS < <(find . -maxdepth 1 -type f -name 'kernel-xr-devel-*.rpm' | sort)
    INSTALL_RPMS+=("${DEVEL_RPMS[@]}")
fi

if (( INSTALL_HEADERS == 1 )); then
    mapfile -t HEADER_RPMS < <(find . -maxdepth 1 -type f -name 'kernel-xr-headers-*.rpm' | sort)
    INSTALL_RPMS+=("${HEADER_RPMS[@]}")
fi

if [ "${#INSTALL_RPMS[@]}" -eq 0 ]; then
    echo "No installable generic RPMs found in ${DOWNLOAD_DIR}." >&2
    exit 1
fi

if (( INSTALL_HEADERS == 1 )) && rpm -q kernel-headers >/dev/null 2>&1; then
    echo "Refusing --with-headers because stock kernel-headers is installed." >&2
    echo "kernel-xr-headers installs the same UAPI paths under /usr/include." >&2
    echo "Remove or swap kernel-headers first, or rerun without --with-headers." >&2
    exit 1
fi

ORIGINAL_DEFAULT=""
if (( SET_DEFAULT == 0 )) && command -v grubby >/dev/null 2>&1; then
    ORIGINAL_DEFAULT="$(sudo grubby --default-kernel 2>/dev/null || true)"
fi

echo "Installing runtime kernel package(s) from ${DOWNLOAD_DIR}."
if (( INSTALL_DEVEL == 1 || INSTALL_HEADERS == 1 )); then
    echo "Optional development/header packages requested."
fi
sudo dnf install -y "${INSTALL_RPMS[@]}"

if command -v grubby >/dev/null 2>&1; then
    if (( SET_DEFAULT == 1 )); then
        kernel_path="$(ls -1 /boot/vmlinuz-*xr.el10* 2>/dev/null | grep -v 'rt' | sort -V | tail -1 || true)"
        if [ -n "${kernel_path:-}" ]; then
            sudo grubby --set-default "$kernel_path" || true
        fi
    elif [ -n "${ORIGINAL_DEFAULT}" ]; then
        current_default="$(sudo grubby --default-kernel 2>/dev/null || true)"
        if [ -n "${current_default}" ] && [ "${current_default}" != "${ORIGINAL_DEFAULT}" ]; then
            echo "Restoring previous default boot entry: ${ORIGINAL_DEFAULT}"
            sudo grubby --set-default "${ORIGINAL_DEFAULT}" || true
        fi
    fi
fi

echo "Installed linux-xr generic release ${TAG}."
echo "Reboot, then verify with: uname -r"
