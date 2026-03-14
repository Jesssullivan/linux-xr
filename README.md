# linux-xr

XR-optimized kernel builds for Bigscreen Beyond 2e on AMD GPUs (Rocky Linux 10).

Builds are run on tinyland-inc/GloriousFlywheel infrastructure, including machines running kernel built from this tree.



Fork of `torvalds/linux` with CI-built RPMs carrying VR/XR patches.

## What's patched

| Patch | Purpose |
|-------|---------|
| `0007-vesa-dsc-bpp.patch` | VESA DisplayID DSC BPP parser, QP table + RC offset fixes for 8bpc 4:4:4 @ 8 BPP |
| `bigscreen-beyond-edid.patch` | EDID non-desktop quirk for Beyond (BIG/0x1234) |
| `patch-6.19.3-rt1.patch` | PREEMPT_RT real-time scheduling (optional) |

Patches are maintained in the Tinyland.inc Gitlab instance for the time being (ideally not for much longer 🚧) and [XoxdWM/patches](https://github.com/Jesssullivan/XoxdWM/tree/main/patches) which get fetched at build time — not always committed here. 

RT opinions come primarily from very large AD/DA and related busses used for sensors on BCI server (~100:100 channels of carefully clocked I/O; uses externall C777 sample wordclock) 

## Install

Download RPMs from [Releases](https://github.com/Jesssullivan/linux-xr/releases):

```bash
sudo dnf install ./kernel-xr-6.19.5-1.xr.el10.x86_64.rpm
sudo reboot
```

## Verify

```bash
uname -r                                    # 6.19.5-1.xr.el10
dmesg | grep "VESA.*DSC.*BPP"              # parser finds BPP=128
cat /sys/class/drm/card1-DP-2/non_desktop  # 1
zcat /proc/config.gz | grep PREEMPT_RT     # CONFIG_PREEMPT_RT=y
```

## Build locally

```bash
# Extract base config from target machine first:
ssh jess@honey "cat /boot/config-$(uname -r)" > xr/config/base.config

# Build RPMs (requires Rocky Linux 10 or compatible):
./xr/scripts/build-rpm.sh \
  --kernel-version 6.19.5 \
  --xr-release 1 \
  --rt-version 6.19.3-rt1
```

## CI

Tag push (`v6.19.5-xr1`) or manual dispatch triggers RPM build on
[tinyland-docker](https://github.com/tinyland-inc/GloriousFlywheel) ARC runners.

## Version scheme

`6.19.5-1.xr.el10` → `uname -r` outputs `6.19.5-1.xr.el10`

## Kernel upgrade workflow

1. `git fetch upstream && git merge upstream/master`
2. Rebase `xr/main` onto new master
3. Update `xr/config/base.config` if honey's base kernel changes
4. Tag: `git tag -a v6.20.1-xr1 -m "XR kernel 6.20.1"`
5. CI builds + publishes RPMs
