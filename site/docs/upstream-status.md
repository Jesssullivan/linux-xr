---
title: Upstream Status
---

# Upstream Status

Baseline date: 2026-04-25

## Carry Set

Carry order is defined in `xr/patches/series`.

- `xr/patches/0007-vesa-dsc-bpp.patch`
  - state: carry with partial upstream overlap
  - reason: current upstream has AMD DSC passthrough plumbing, but the DisplayID
    VESA fixed-BPP parser and DRM connector/mode propagation carried here remain
    absent from the current upstream checkout
  - reduction path: split the DisplayID/parser/connector path from local QP
    table and RC offset adjustments before deciding what still needs submission
- `xr/patches/bigscreen-beyond-edid.patch`
  - state: upstream candidate
  - reason: Bigscreen Beyond non-desktop quirk remains absent from upstream `drm_edid.c`

## Current Upstream Snapshot

- linux-xr `xr/main`: `55f63ebff7df`
- upstream `master` observed from kernel.org: `897d54018cc9`
- latest upstream tag observed locally: `v7.0`
- latest `6.19.y` stable tag observed locally: `v6.19.14`

The current RPM lane still builds the configured `6.19.5` tarball. Moving the
release lane forward should be a deliberate cadence item, not an incidental
merge.

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

## Kernel Cadence

The weekly maintenance intent is:

1. inspect upstream stable and longterm movement
2. classify whether the carry set still applies cleanly
3. build generic and RT variants
4. promote only after host validation

After merge, `.github/workflows/weekly-cadence.yml` is the repo's scheduled mechanism for producing that weekly report and opening a cadence issue.
