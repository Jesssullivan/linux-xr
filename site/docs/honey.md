---
title: honey
---

# honey

Role: primary XR validation host.

Current known state from the 2026-04-11 audit:

- running kernel: `6.19.5-5.xr.el10`
- installed generic XR kernels: `6.19.5-4`, `6.19.5-5`, and `6.19.5-6`
- installed RT RPMs: present, but not the documented default lane
- OpenXR userspace present
- Monado unit files present but disabled
- sudo requires an interactive password on this host

Current rollout stance:

- generic XR kernel: active and documented
- RT XR kernel: still gated pending repeatable boot and latency validation
