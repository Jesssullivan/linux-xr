---
title: yoga
---

# yoga

Role: secondary Rocky 10 rollout and desktop/dev validation host.

Current known state from the 2026-04-12 rollout:

- running kernel: `6.12.0-124.45.1.el10_1.x86_64`
- saved default boot kernel: `/boot/vmlinuz-6.12.0-124.45.1.el10_1.x86_64`
- installed generic XR runtime RPM: `kernel-xr-6.19.5-8.xr.el10`
- one-time boot into `6.19.5-8.xr.el10` succeeded
- normal reboot after the XR validation returned the host to the saved stock default as expected
- DRM nodes present on the XR validation boot: `card0`, `card1`, `renderD128`, `renderD129`
- `/boot` remains tight after the install, so stale stock kernels should be managed deliberately
- sudo requires an interactive password on this host

Current rollout stance:

- generic XR runtime install and one-time boot validation are complete
- stock Rocky default remains the persistent fallback
- not yet a documented RT target
