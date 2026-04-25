---
title: honey
---

# honey

Role: primary XR validation host.

This page owns shipped-kernel rollout context and downstream-consumer framing.
It does not own the current Dell workstation validation ledger for `honey`.

Use the companion `Dell-7810` repo for the current host-side RT claim ladder:

- C1: RT boot proved
- C2: RT host posture validated
- C3: RT operational acceptability

This repo owns C0 supplier facts: the generic and RT kernel RPMs, install
surface, carry patch set, and release cadence. It does not own SMI, NUMA,
Chapel, C-state, reset, or workstation acceptance evidence.

Historical rollout evidence from the 2026-04-12 validation:

Current known supplier-side state:

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

For live `honey` host state and current RT acceptance, see:

- <https://github.com/Jesssullivan/Dell-7810/blob/main/docs/platform/rt-research-contract.md>
- <https://github.com/Jesssullivan/Dell-7810/blob/main/docs/platform/honey-rt-validation-2026-04-23.md>
- <https://github.com/Jesssullivan/Dell-7810/blob/main/docs/tracking/rt-smi-numa-chapel-focus-2026-04-25.md>
