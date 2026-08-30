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

## Compatibility Notes

Observed on 2026-05-09:

- `6.12.y` does not carry the DisplayID formula timing parser blocks that newer
  stable branches carry, so this patch intentionally does not include the
  formula-timing `DISPLAYID_BLOCK_DESCRIPTOR_PAYLOAD_BYTES` cleanup from the
  upstream-overlap series.
- The Type VII `dsc_passthrough_timings_support` flag is set in
  `add_displayid_detailed_1_modes()` instead of changing
  `drm_mode_displayid_detailed()`'s signature. That keeps the carry compatible
  with `6.12.y`, where the helper still takes non-const timing descriptors,
  while preserving the same behavior on newer stable branches.
- The bounded carry dry-run must pass with RPM-compatible zero-fuzz matching
  for `6.12.87`, `6.18.28`, `6.19.14`, and `7.0.5` before this carry can gate
  a source-sync or fallback release.

Observed on 2026-08-29 (`TIN-611` / `TIN-4065`):

- This carry applies to the maintained candidate base **`v7.1.12`** with zero
  rejects and zero fuzz, both via `git apply --check -p1` and via
  `patch -p1 --fuzz=0` (rpm's `%patch` default), including a cumulative
  replication of the real `%prep` ordering against a sha256-verified
  `linux-7.1.12.tar.xz`. Every moved hunk moved by pure line offset
  (`amdgpu_dm.c` +127; `drm_edid.c` +32 and +73; `drm_connector.h` +2);
  `qp_tables.h`, `rc_calc_fpu.c`, `drm_displayid_internal.h`, and
  `drm_modes.h` matched at their recorded lines. **No context refresh was
  needed and none was made.** The compatibility list above predates the
  `7.0.y` -> `7.1.y` re-home; `7.1.12` is now the primary proven base.

## Split Plan

**Status: NOT STARTED as of 2026-08-29.** This is `TIN-611`'s actual acceptance
criteria and it is a code-reduction / upstream-trackability goal. It does
**not** block an RPM build — the combined carry applies cleanly at `v7.1.12`
(see above). Do not conflate "the carries need a context refresh" (retired,
false since 2026-07-09) with "the carry has not been split" (true, below).

1. Split parser and DRM propagation into `0007a-vesa-displayid-dsc-bpp-parser.patch`.
2. Split AMDGPU fixed-BPP use into `0007b-amdgpu-use-fixed-dsc-bpp.patch`.
3. Split QP and RC offsets into `0007c-amdgpu-dsc-qp-rc-local-risk.patch`.
4. Keep `bigscreen-beyond-edid.patch` independent and after the DSC parser group unless dry-run patch application proves a safer order.
5. Before changing `xr/patches/series`, run `nix flake check` and a real RPM build lane.

The local-risk group should not be described as upstreamable until the repo
links measured evidence for the DSC QP/RC path, such as headset or display-link
capture, and a concrete upstream discussion or drop decision.
