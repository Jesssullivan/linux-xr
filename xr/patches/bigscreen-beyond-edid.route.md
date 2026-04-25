# Bigscreen Beyond EDID Upstream Route

This note is the submission route for `bigscreen-beyond-edid.patch`.
It keeps the public upstream path separate from the release carry path.

## Tracker

- Public issue: <https://github.com/tinyland-inc/linux-xr/issues/24>
- Internal execution ticket: `TIN-612`
- Patch file: `xr/patches/bigscreen-beyond-edid.patch`
- Target subsystem: DRM EDID quirk table in `drivers/gpu/drm/drm_edid.c`
- Kernel process refs: `Documentation/process/submitting-patches.rst` and
  `Documentation/dev-tools/checkpatch.rst`

## Current State

As of 2026-04-25:

- Current upstream `drivers/gpu/drm/drm_edid.c` has no `BIG`, `0x1234`, or
  `0x5095` quirk.
- `honey` exposes the live headset path as `/sys/class/drm/card0-DP-2` on
  `6.19.5-7.xr.el10`.
- The live EDID header starts with
  `00 ff ff ff ff ff ff 00 09 27 34 12 d2 04 00 00`, which supports
  `BIG/0x1234` on the connected headset path.
- The current carry patch is release-usable with GNU `patch`, but it is not
  submission-ready: `git apply --check xr/patches/bigscreen-beyond-edid.patch`
  fails at `drivers/gpu/drm/drm_edid.c:220`.
- `scripts/checkpatch.pl --no-tree xr/patches/bigscreen-beyond-edid.patch`
  reports a reference warning; replace the `mail-archive.com` URL with a
  `lore.kernel.org` URL if possible.

## Submission Gates

Do not send v1 until all of these are true:

1. A fresh `honey` capture proves the connected headset DRM property resolves
   to `non-desktop=1` with this carry applied.
2. The evidence bundle includes EDID identity from the same connected path:
   connector name, status, raw EDID bytes or saved `edid.bin`, decoded
   manufacturer `BIG`, and product `0x1234` or `0x5095`.
3. The patch is regenerated against current upstream or `drm-misc-next` using
   normal kernel patch flow, not copied directly from the release carry file.
4. `scripts/checkpatch.pl` is clean or any warning is explicitly justified.
5. Recipients are regenerated with a bounded `scripts/get_maintainer.pl`
   command.
6. The mailed patch carries a human `Signed-off-by`.

## Evidence Capture Route

The minimum useful host packet is:

```sh
hostname
uname -r
for c in /sys/class/drm/card*-DP-*; do
  [ -e "$c/status" ] || continue
  status="$(cat "$c/status")"
  enabled="$(cat "$c/enabled" 2>/dev/null || true)"
  printf '%s status=%s enabled=%s\n' "$c" "$status" "$enabled"
  [ -r "$c/edid" ] && od -An -tx1 -N16 "$c/edid"
done
```

That packet only proves identity. For the upstream gate, also capture the DRM
connector property that reports non-desktop. On `honey` as observed on
2026-04-25, `/sys/class/drm/card0-DP-2/non_desktop` was absent, `drm_info`,
`modetest`, and `edid-decode` were not installed, unprivileged DRM debugfs was
not readable, and `sudo -n` was unavailable. The next capture therefore needs
one of:

- a repo-managed read-only DRM property tool installed on the host
- sops-backed sudo for a read-only debugfs capture from
  `/sys/kernel/debug/dri/*/state`
- a packaged host evidence script in the Dell-7810 authority surface

Do not restart services, reboot the machine, or touch `rke2` for this evidence
capture.

## Patch Preparation Route

Use a clean topic branch from current upstream or `drm-misc-next`, then add the
quirk directly in `drivers/gpu/drm/drm_edid.c` near the existing headset
quirks.

Suggested subject:

```text
drm/edid: Add non-desktop quirk for Bigscreen Beyond HMDs
```

Keep v1 narrow. If only `BIG/0x1234` has local evidence, submit only that ID or
explicitly call out why `BIG/0x5095` is included without local proof.

Local checks before sending:

```sh
git diff --check
scripts/checkpatch.pl 0001-*.patch
perl scripts/get_maintainer.pl --no-rolestats --no-git --no-git-fallback -f drivers/gpu/drm/drm_edid.c
```

The bounded maintainer route observed on 2026-04-25 was:

- Maarten Lankhorst `<maarten.lankhorst@linux.intel.com>`
- Maxime Ripard `<mripard@kernel.org>`
- Thomas Zimmermann `<tzimmermann@suse.de>`
- David Airlie `<airlied@gmail.com>`
- Simona Vetter `<simona@ffwll.ch>`
- `dri-devel@lists.freedesktop.org`
- `linux-kernel@vger.kernel.org`

After sending, link the lore thread back to GitHub issue #24 and `TIN-612`.
