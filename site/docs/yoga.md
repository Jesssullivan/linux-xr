---
title: yoga
---

# yoga

Role: secondary Rocky 10 rollout and desktop/dev validation host.

Current known state from the 2026-04-11 audit:

- running kernel: `6.12.0-124.45.1.el10_1.x86_64`
- installed kernels are still stock Rocky 10 builds
- no XR kernel install detected
- generic XR runtime RPMs are staged in `~/linux-xr-staging/generic`
- no local `linux-xr` or `XoxdWM` checkout detected in `~/git`
- sudo requires an interactive password on this host

Current rollout stance:

- next target for generic XR runtime install and reboot validation
- not yet a documented RT target
