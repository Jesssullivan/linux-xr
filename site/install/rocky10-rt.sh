#!/usr/bin/env bash
set -euo pipefail

PAGES_BASE="${PAGES_BASE:-https://tinyland-inc.github.io/linux-xr}"
API_URL="${API_URL:-https://api.github.com/repos/tinyland-inc/linux-xr/releases/latest}"
MANIFEST_URL="${PAGES_BASE}/releases/latest.json"
DOWNLOAD_ONLY=0
PRINT_ASSETS=0
SET_DEFAULT=1
TARGET_DIR=""

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

usage() {
    cat <<'EOF'
Usage: rocky10-rt.sh [options]

Options:
  --print-assets      Print the selected release tag and RPM URLs, then exit
  --download-only     Download RPMs without installing them
  --target-dir DIR    Directory to place downloaded RPMs in
  --no-set-default    Skip grubby default-kernel update after install
  --help              Show this help
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --print-assets) PRINT_ASSETS=1; shift ;;
        --download-only) DOWNLOAD_ONLY=1; shift ;;
        --target-dir) TARGET_DIR="$2"; shift 2 ;;
        --no-set-default) SET_DEFAULT=0; shift ;;
        --help) usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
    esac
done

need_cmd curl
need_cmd python3

if (( PRINT_ASSETS == 0 && DOWNLOAD_ONLY == 0 )); then
    need_cmd sudo
    need_cmd dnf
fi

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

if ! curl -fsSL "$MANIFEST_URL" -o "$WORKDIR/latest.json"; then
    curl -fsSL "$API_URL" -o "$WORKDIR/latest.json"
fi

mapfile -t URLS < <(python3 - "$WORKDIR/latest.json" <<'PY'
import json, re, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    data = json.load(fh)
for asset in data.get("assets", []):
    name = asset.get("name", "")
    url = asset.get("browser_download_url", "")
    if not url:
        continue
    if re.fullmatch(r"kernel-xr-rt(?:-(?:devel|headers))?-[^/]+\.rpm", name):
        print(url)
PY
)

TAG="$(python3 - "$WORKDIR/latest.json" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    print(json.load(fh)["tag_name"])
PY
)"

if [ "${#URLS[@]}" -eq 0 ]; then
    echo "No RT RPM assets found in latest release." >&2
    exit 1
fi

if (( PRINT_ASSETS == 1 )); then
    echo "linux-xr RT release ${TAG}"
    printf '%s\n' "${URLS[@]}"
    exit 0
fi

if [[ -n "${TARGET_DIR}" ]]; then
    mkdir -p "${TARGET_DIR}"
    DOWNLOAD_DIR="$(cd "${TARGET_DIR}" && pwd)"
elif (( DOWNLOAD_ONLY == 1 )); then
    DOWNLOAD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/linux-xr-rt.XXXXXX")"
else
    DOWNLOAD_DIR="${WORKDIR}"
fi

cd "$DOWNLOAD_DIR"
for url in "${URLS[@]}"; do
    curl -fL -O "$url"
done

if (( DOWNLOAD_ONLY == 1 )); then
    echo "Downloaded linux-xr RT release ${TAG} to ${DOWNLOAD_DIR}"
    exit 0
fi

sudo dnf install -y ./*.rpm

if (( SET_DEFAULT == 1 )) && command -v grubby >/dev/null 2>&1; then
    kernel_path="$(ls -1 /boot/vmlinuz-*rt*.xr.el10* 2>/dev/null | sort -V | tail -1 || true)"
    if [ -n "${kernel_path:-}" ]; then
        sudo grubby --set-default "$kernel_path" || true
    fi
fi

echo "Installed linux-xr RT release ${TAG}."
echo "Reboot, then verify with: uname -r"
