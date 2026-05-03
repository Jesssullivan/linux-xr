---
title: Upstream Status
---

# Upstream Status

Baseline date: 2026-05-03

## Carry Set

Carry order is defined in `xr/patches/series`.

- `xr/patches/0007-vesa-dsc-bpp.patch`
  - state: carry with partial upstream overlap
  - reason: current upstream has AMD DSC passthrough plumbing, but the DisplayID
    VESA fixed-BPP parser and DRM connector/mode propagation carried here remain
    absent from the current upstream checkout
  - reduction path: split the DisplayID/parser/connector path from local QP
    table and RC offset adjustments before deciding what still needs submission
  - current public thread: `[PATCH v7 0/7] VESA DisplayID fixed DSC BPP value support`
    at <https://patchew.org/linux/20251202110218.9212-1-iam%40lach.pw/>
  - local split map: `xr/patches/0007-vesa-dsc-bpp.map.md`
- `xr/patches/bigscreen-beyond-edid.patch`
  - state: upstream candidate
  - reason: Bigscreen Beyond non-desktop quirk remains absent from upstream `drm_edid.c`
  - route: `xr/patches/bigscreen-beyond-edid.route.md`
  - current evidence: live `honey` EDID identity and DRM connector property are
    captured for `BIG/0x1234`; `DP-2` reports `non-desktop=1`
  - patch gate: the carry is now `git apply --check` clean against current
    `xr/main`; v1 still needs a normal upstream/drm-misc topic branch

## Current Upstream Snapshot

- linux-xr `xr/main`: `a5aef68c0ff1`
- upstream `master` observed from kernel.org: `f377d0025eb0`
- current mainline release candidate observed on kernel.org: `v7.1-rc1`
- current stable observed on kernel.org: `v7.0.3`
- current longterm candidates observed on kernel.org: `v6.18.26`, `v6.12.85`
- latest `6.19.y` stable tag observed on kernel.org: `v6.19.14` `[EOL]`

The current RPM lane still builds the configured `6.19.5` tarball. Moving the
release lane forward should be a deliberate cadence item, not an incidental
merge.

`v6.19.14` remains a useful bounded compatibility proof because the generic
linux-xr carry applies cleanly and the CVE security preflight passes, but it
should not become the durable lab target now that kernel.org marks the line
EOL. The maintained generic candidates checked on 2026-05-03 are `v7.0.3`
stable and `v6.18.26` longterm; the carry dry-run and CVE security preflight
passed for both. Keep RT pinned to the current `v6.19.5-xr9` line until a
compatible RT patchset or local RT refresh is proven.

## Boundary Notes

SMI, NUMA, and tuned-profile work are platform/runtime validation surfaces.
linux-xr should keep kernel config support for those lanes, but host validators,
tuned profiles, captures, and rollback procedures belong in Dell-7810 and
XoxdWM operator surfaces.

The current DSC carry should not be summarized as "wholly absent upstream."
After refreshing `upstream/master` on 2026-04-25, upstream already contains
AMD-side DSC passthrough fields such as `dsc_fixed_bits_per_pixel_x16` and
`is_dsc_passthrough_supported`. What still appears absent in the checked
upstream tree is this carry's DisplayID VESA DSC BPP parser and the public DRM
connector/mode propagation names `dp_dsc_bpp_x16`,
`DISPLAYID_VESA_DSC_BPP_*`, and `dsc_passthrough_timings_support`. Keep QP/RC
table changes separate until measured evidence justifies them.

The latest public DSC-BPP thread found during the 2026-04-25 refresh is v7, not
the older v6 thread. v7 keeps the same strategic implication for linux-xr:
parser/connector/amdgpu fixed-BPP handling is upstream-overlap work; QP table
and RC offset hunks are local-risk carry until separately evidenced.

## Bigscreen Beyond EDID Route

The EDID non-desktop quirk is the first small upstream candidate because it is
isolated to the DRM EDID quirk table. The current route is:

1. keep GitHub issue #24 and Linear `TIN-612` as the public/internal trackers
2. capture `honey` headset identity and DRM `non-desktop=1` evidence without
   restarting services, rebooting, or touching `rke2`
3. regenerate a clean patch from current upstream or `drm-misc-next`
4. run `git diff --check`, `scripts/checkpatch.pl`, and a bounded
   `scripts/get_maintainer.pl --no-git`
5. send to the DRM EDID/DRM misc route with a human `Signed-off-by`
6. link the lore thread back to GitHub issue #24 and `TIN-612`

The 2026-04-25 read-only honey probe established `/sys/class/drm/card0-DP-2`
as connected with a 256-byte EDID whose first 16 bytes include
`09 27 34 12`, supporting `BIG/0x1234`. A follow-up Dell-owned libdrm capture
then proved the connector property: `DP-2` reports `non-desktop=1`. The
evidence is saved in `Jesssullivan/Dell-7810` at
`data/captures/honey/drm-connector-properties-2026-04-25.txt`.

## Kernel Cadence

The weekly maintenance intent is:

1. inspect upstream stable and longterm movement
2. classify whether the carry set still applies cleanly
3. build generic and RT variants
4. promote only after host validation

After merge, `.github/workflows/weekly-cadence.yml` is the repo's scheduled mechanism for producing that weekly report and opening a cadence issue.
