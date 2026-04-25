# `0007-vesa-dsc-bpp.patch` Carry Map

This file decomposes the combined DSC carry into upstream-trackable and
local-risk groups. Keep it current until the patch is split in `series`.

## Upstream Watch

Observed on 2026-04-25:

- Current public series: Yaroslav Bolyukin's `[PATCH v7 0/7] VESA DisplayID
  fixed DSC BPP value support`.
- Series cover letter: <https://patchew.org/linux/20251202110218.9212-1-iam%40lach.pw/>
- EDID parser patch: <https://patchew.org/linux/20251202110218.9212-1-iam%40lach.pw/20251202110218.9212-7-iam%40lach.pw/>
- AMDGPU usage patch: <https://patchew.org/linux/20251202110218.9212-1-iam%40lach.pw/20251202110218.9212-8-iam%40lach.pw/>

The v7 thread is more current than the older v6 references. Treat the
DisplayID parser, DRM connector/mode propagation, and amdgpu fixed-BPP usage
as the upstream-overlap path. Treat QP table and RC offset changes separately
until measured evidence justifies submitting or retaining them.

## Hunk Groups

| Group | Files | Classification | Notes |
| --- | --- | --- | --- |
| DisplayID parser and DRM propagation | `drivers/gpu/drm/drm_displayid_internal.h`, `drivers/gpu/drm/drm_edid.c`, `include/drm/drm_connector.h`, `include/drm/drm_modes.h` | upstream-overlap | Maps to the v7 EDID/DisplayID parser series. This carries `DISPLAYID_VESA_DSC_BPP_*`, `dp_dsc_bpp_x16`, and `dsc_passthrough_timings_support`. |
| AMDGPU fixed-BPP use | `drivers/gpu/drm/amd/display/amdgpu_dm/amdgpu_dm.c` | upstream-overlap | Maps to v7 `drm/amd: use fixed dsc bits-per-pixel from edid`. |
| QP table correction | `drivers/gpu/drm/amd/display/dc/dml/dsc/qp_tables.h` | local-risk carry | Changes min/max QP table entries for 8bpc 4:4:4. This is not part of the v7 upstream DSC-BPP series. |
| RC offset correction | `drivers/gpu/drm/amd/display/dc/dml/dsc/rc_calc_fpu.c` | local-risk carry | Changes the 8 BPP 4:4:4 RC offset path. This needs headset/display-link evidence before upstream treatment. |

## Split Plan

1. Split parser and DRM propagation into `0007a-vesa-displayid-dsc-bpp-parser.patch`.
2. Split AMDGPU fixed-BPP use into `0007b-amdgpu-use-fixed-dsc-bpp.patch`.
3. Split QP and RC offsets into `0007c-amdgpu-dsc-qp-rc-local-risk.patch`.
4. Keep `bigscreen-beyond-edid.patch` independent and after the DSC parser group unless dry-run patch application proves a safer order.
5. Before changing `xr/patches/series`, run `nix flake check` and a real RPM build lane.

The local-risk group should not be described as upstreamable until the repo
links measured evidence for the Beyond path and a concrete upstream discussion
or drop decision.
