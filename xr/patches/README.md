# Carry Patches

This directory is the kernel repo's source of truth for the private carry set.

Patch application order is defined in `series`.

Current carry classification:

- `0007-vesa-dsc-bpp.patch`: carry while the DSC fixed-BPP series remains unmerged upstream
- `bigscreen-beyond-edid.patch`: upstream candidate for the Bigscreen Beyond non-desktop quirk

The build and release workflows should source patches from here rather than another repo.
