# Carry Patches

This directory is the kernel repo's source of truth for the private carry set.

Patch application order is defined in `series`.

Current carry classification:

- `0007-vesa-dsc-bpp.patch`: carry with partial upstream overlap; upstream has AMD DSC passthrough plumbing, but this tree still carries the DisplayID/VESA DSC fixed-BPP parser and DRM connector/mode propagation path. Split that parser/connector path from local QP/RC offset adjustments before submission.
- `bigscreen-beyond-edid.patch`: upstream candidate for the Bigscreen Beyond non-desktop quirk. Keep the release carry separate from the upstream submission route; the current carry is GNU-patch usable but must be regenerated before v1 submission.

Detailed split map:

- [`0007-vesa-dsc-bpp.map.md`](0007-vesa-dsc-bpp.map.md)
- [`bigscreen-beyond-edid.route.md`](bigscreen-beyond-edid.route.md)

The build and release workflows should source patches from here rather than another repo.
