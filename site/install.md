---
title: Install
---

# Install

Stable script entrypoints:

```bash
curl -fsSL https://tinyland-inc.github.io/linux-xr/install/rocky10-generic.sh | bash
curl -fsSL https://tinyland-inc.github.io/linux-xr/install/rocky10-rt.sh | bash
```

The scripts download the latest installable lab release assets, install the runtime kernel RPM by default, try to set the newest matching XR kernel as default, and print the expected post-reboot verification command.

The public `latest.json` manifest is regenerated from the newest non-draft installable `vX.Y.Z-xrN` release with both generic and RT runtime RPMs. This intentionally includes secured lab prereleases such as `v6.19.5-xr9`, while excluding proof-only releases such as `proof-6.19.14-xr1-generic` and `proof-7.0.3-xr1-generic`.

For non-root validation or staged rollout work, both scripts also support:

- `--print-assets` to show the selected release and RPM URLs without downloading
- `--download-only` to fetch RPMs without installing them
- `--target-dir <dir>` to control where downloaded RPMs are staged
- `--no-set-default` to install without leaving the new kernel as the default boot entry
- `--with-devel` to also install the matching `kernel-xr-devel` or `kernel-xr-rt-devel` RPM
- `--with-headers` to also install the matching `kernel-xr-headers` or `kernel-xr-rt-headers` RPM

## Variants

- `generic`: default documented rollout lane for Rocky 10 hosts
- `rt`: gated lane for hosts that have passed the RT boot checklist and have a
  specific downstream deadline hypothesis to test

## Notes

- The default runtime-only install avoids conflicts with Rocky's stock `kernel-headers` package on existing hosts.
- `--no-set-default` captures the current default kernel and restores it after install if the package scriptlets change it.
- The `--with-headers` flag is for development hosts that need UAPI headers and may require removing or replacing the stock `kernel-headers` package first.
