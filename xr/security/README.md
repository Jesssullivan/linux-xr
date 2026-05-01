# linux-xr security backports

This directory is for release-blocking security fixes that are not part of the
normal XR carry in `xr/patches/series`.

`xr/scripts/build-rpm.sh` decides when a security backport is required and
passes the matching RPM spec macro. Do not add files here as general kernel
feature carry; use `xr/patches/` for that path.

| Patch | Source | Build behavior |
| --- | --- | --- |
| `cve-2026-31431-algif-aead.patch` | Linux stable `6.19.y` commit `ce42ee423e58`, backporting mainline `a664bf3d603d` | Applied automatically for vulnerable `6.19.x` bases before RT and XR carry patches |
