---
title: Upstream Status
---

# Upstream Status

Baseline date: 2026-04-25

## Carry Set

Carry order is defined in `xr/patches/series`.

- `xr/patches/0007-vesa-dsc-bpp.patch`
  - state: carry
  - reason: DSC fixed-BPP parsing/passthrough work remains absent from the current upstream checkout
  - reduction path: split the in-flight DisplayID/amdgpu series from local QP table and RC offset adjustments
- `xr/patches/bigscreen-beyond-edid.patch`
  - state: upstream candidate
  - reason: Bigscreen Beyond non-desktop quirk remains absent from upstream `drm_edid.c`

## Current Upstream Snapshot

- linux-xr `xr/main`: `55f63ebff7df`
- upstream `master` observed from kernel.org: `27d128c1cff6`
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

## Kernel Cadence

The weekly maintenance intent is:

1. inspect upstream stable and longterm movement
2. classify whether the carry set still applies cleanly
3. build generic and RT variants
4. promote only after host validation

After merge, `.github/workflows/weekly-cadence.yml` is the repo's scheduled mechanism for producing that weekly report and opening a cadence issue.
