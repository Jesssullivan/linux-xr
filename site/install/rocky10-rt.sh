#!/usr/bin/env bash
set -euo pipefail

PAGES_BASE="${PAGES_BASE:-https://tinyland-inc.github.io/linux-xr}"
API_URL="${API_URL:-https://api.github.com/repos/tinyland-inc/linux-xr/releases/latest}"
MANIFEST_URL="${PAGES_BASE}/releases/latest.json"

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || {
        echo "Missing required command: $1" >&2
        exit 1
    }
}

need_cmd curl
need_cmd python3
need_cmd sudo
need_cmd dnf

TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

if ! curl -fsSL "$MANIFEST_URL" -o "$TMPDIR/latest.json"; then
    curl -fsSL "$API_URL" -o "$TMPDIR/latest.json"
fi

mapfile -t URLS < <(python3 - "$TMPDIR/latest.json" <<'PY'
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

TAG="$(python3 - "$TMPDIR/latest.json" <<'PY'
import json, sys
with open(sys.argv[1], "r", encoding="utf-8") as fh:
    print(json.load(fh)["tag_name"])
PY
)"

if [ "${#URLS[@]}" -eq 0 ]; then
    echo "No RT RPM assets found in latest release." >&2
    exit 1
fi

cd "$TMPDIR"
for url in "${URLS[@]}"; do
    curl -fL -O "$url"
done

sudo dnf install -y ./*.rpm

if command -v grubby >/dev/null 2>&1; then
    kernel_path="$(ls -1 /boot/vmlinuz-*rt*.xr.el10* 2>/dev/null | sort -V | tail -1 || true)"
    if [ -n "${kernel_path:-}" ]; then
        sudo grubby --set-default "$kernel_path" || true
    fi
fi

echo "Installed linux-xr RT release ${TAG}."
echo "Reboot, then verify with: uname -r"
