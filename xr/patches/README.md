# Carry Patches

This directory is the kernel repo's source of truth for the private carry set.

Patch application order is defined in `series`.

Current carry classification:

- `0007-vesa-dsc-bpp.patch`: carry with partial upstream overlap; upstream has AMD DSC passthrough plumbing, but this tree still carries the DisplayID/VESA DSC fixed-BPP parser and DRM connector/mode propagation path. Split that parser/connector path from local QP/RC offset adjustments before submission.
- `bigscreen-beyond-edid.patch`: upstream candidate for the Bigscreen Beyond non-desktop quirk. Keep the release carry separate from the upstream submission route; the current carry is GNU-patch usable but must be regenerated before v1 submission.
- `amdgpu-dsc-pps-debugfs.patch`: local Honey lab diagnostic carry. It adds a read-only connector debugfs file for the packed DSC PPS cached by AMD DC; treat this as observability for black-screen proof work, not as a product fix or upstream-ready behavior change.

Detailed split map:

- [`0007-vesa-dsc-bpp.map.md`](0007-vesa-dsc-bpp.map.md)
- [`bigscreen-beyond-edid.route.md`](bigscreen-beyond-edid.route.md)

The build and release workflows should source patches from here rather than another repo.
Run `xr/scripts/check-rpm-patch-wiring.sh` after changing `series` or
`xr/specs/kernel-xr.spec`; it verifies that each carry patch is declared and
applied by the RPM prep path.
