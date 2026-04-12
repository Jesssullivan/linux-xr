---
title: Install
---

# Install

Stable script entrypoints:

```bash
curl -fsSL https://tinyland-inc.github.io/linux-xr/install/rocky10-generic.sh | bash
curl -fsSL https://tinyland-inc.github.io/linux-xr/install/rocky10-rt.sh | bash
```

The scripts download the latest release assets, install the runtime kernel RPM by default, try to set the newest matching XR kernel as default, and print the expected post-reboot verification command.

The public `latest.json` manifest is regenerated from the latest published GitHub release and drives the Pages install surface.

For non-root validation or staged rollout work, both scripts also support:

- `--print-assets` to show the selected release and RPM URLs without downloading
- `--download-only` to fetch RPMs without installing them
- `--target-dir <dir>` to control where downloaded RPMs are staged
- `--no-set-default` to install without changing the default boot entry
- `--with-devel` to also install the matching `kernel-xr-devel` or `kernel-xr-rt-devel` RPM
- `--with-headers` to also install the matching `kernel-xr-headers` or `kernel-xr-rt-headers` RPM

## Variants

- `generic`: default documented rollout lane for Rocky 10 hosts
- `rt`: gated lane for hosts that have passed the RT boot and latency checklist

## Notes

- The default runtime-only install avoids conflicts with Rocky's stock `kernel-headers` package on existing hosts.
- The `--with-headers` flag is for development hosts that need UAPI headers and may require removing or replacing the stock `kernel-headers` package first.
