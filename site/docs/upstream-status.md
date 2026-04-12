---
title: Upstream Status
---

# Upstream Status

Baseline date: 2026-04-11

## Carry Set

Carry order is defined in `xr/patches/series`.

- `xr/patches/0007-vesa-dsc-bpp.patch`
  - state: carry
  - reason: DSC fixed-BPP parsing/passthrough work remains unmerged upstream
- `xr/patches/bigscreen-beyond-edid.patch`
  - state: upstream candidate
  - reason: Bigscreen Beyond non-desktop quirk still absent from upstream `drm_edid.c`

## Kernel Cadence

The weekly maintenance intent is:

1. inspect upstream stable and longterm movement
2. classify whether the carry set still applies cleanly
3. build generic and RT variants
4. promote only after host validation

After merge, `.github/workflows/weekly-cadence.yml` is the repo's scheduled mechanism for producing that weekly report and opening a cadence issue.
