---
title: Install
---

# Install

Stable script entrypoints:

```bash
curl -fsSL https://tinyland-inc.github.io/linux-xr/install/rocky10-generic.sh | bash
curl -fsSL https://tinyland-inc.github.io/linux-xr/install/rocky10-rt.sh | bash
```

The scripts download the latest release assets, install the matching RPM set, try to set the newest matching XR kernel as default, and print the expected post-reboot verification command.

For non-root validation or staged rollout work, both scripts also support:

- `--print-assets` to show the selected release and RPM URLs without downloading
- `--download-only` to fetch RPMs without installing them
- `--target-dir <dir>` to control where downloaded RPMs are staged
- `--no-set-default` to install without changing the default boot entry

## Variants

- `generic`: default documented rollout lane for Rocky 10 hosts
- `rt`: gated lane for hosts that have passed the RT boot and latency checklist
