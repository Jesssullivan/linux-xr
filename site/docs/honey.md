---
title: honey
---

# honey

Role: primary XR validation host.

Historical rollout evidence from the 2026-04-12 validation:

- running kernel: `6.19.5-7.xr.el10`
- saved default boot kernel: `/boot/vmlinuz-6.19.5-7.xr.el10`
- installed generic XR runtime RPM: `kernel-xr-6.19.5-7.xr.el10`
- installed RT XR runtime RPM: `kernel-xr-rt-6.19.5-8.xr.el10`
- one-time RT boot into `6.19.5-rt1-8.xr.el10` succeeded
- live RT verification on `honey` confirmed `uname -v` contains `PREEMPT_RT` and `/sys/kernel/realtime` is `1`
- normal reboot after the RT test returned the host to the saved generic default as expected
- OpenXR userspace present
- Monado unit files present but disabled
- DRM nodes present on both the generic and RT validation boots
- sudo requires an interactive password on this host

Current live host posture is not owned by this page. Dell-7810 is the authority
for `honey`'s current booted kernel, BIOS/SMI state, tuned profile, and reset
evidence. Treat the RT bullets above as historical smoke evidence, not as a
claim that `honey` is currently running RT or has a validated low-latency
posture.

Rollout stance:

- generic XR kernel: active, documented, and the persistent default
- RT XR kernel: one-time reboot-valid and functionally verified, but still gated for regular use pending latency tooling and deeper XR smoke
