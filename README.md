# linux-xr

XR-optimized kernel builds for Bigscreen Beyond 2e on AMD GPUs (Rocky Linux 10).

Builds are run on tinyland-inc/GloriousFlywheel infrastructure, including machines running kernel built from this tree.

Fork of `torvalds/linux` with CI-built RPMs carrying VR/XR patches.

## Current State

As of 2026-04-11:

| Area | Status | Notes |
| --- | --- | --- |
| Release artifacts | Proven | Latest public release ships generic and RT RPMs. |
| `honey` rollout | Proven (generic) | `honey` is currently running `6.19.5-5.xr.el10`. |
| `honey` RT default boot | Gated | RT artifacts exist, but RT is not yet the default documented lane. |
| `yoga` rollout | Pending | `yoga` is still on the stock Rocky 10 kernel. |
| Install surface | In progress | GitHub Pages and stable installer paths live in `site/`. |
| Patch carry set | Localized | Kernel-owned carry patches live under `xr/patches/`. |

## Public Surfaces

- Releases: <https://github.com/tinyland-inc/linux-xr/releases>
- Stable install docs: `https://tinyland-inc.github.io/linux-xr/`
- Generic installer: `https://tinyland-inc.github.io/linux-xr/install/rocky10-generic.sh`
- RT installer: `https://tinyland-inc.github.io/linux-xr/install/rocky10-rt.sh`
- Carry patches: [`xr/patches`](xr/patches)

## What's patched

| Patch | Purpose |
|-------|---------|
| `0007-vesa-dsc-bpp.patch` | VESA DisplayID DSC BPP parser, QP table + RC offset fixes for 8bpc 4:4:4 @ 8 BPP |
| `bigscreen-beyond-edid.patch` | EDID non-desktop quirk for Beyond (BIG/0x1234 + 0x5095) |
| `patch-6.19.3-rt1.patch` | PREEMPT_RT real-time scheduling (RT variant only, downloaded from kernel.org) |

Patches are maintained in this repository under [`xr/patches`](xr/patches).

RT opinions come primarily from very large AD/DA and related busses used for sensors on BCI server (~100:100 channels of carefully clocked I/O; uses external C777 sample wordclock).

## Variants

Each release includes two kernel variants:

| Variant | Package | Use case |
|---------|---------|----------|
| **Generic** | `kernel-xr` | Standard XR workloads, desktop compositing |
| **RT** | `kernel-xr-rt` | Sub-ms VR frame scheduling, BCI/AD-DA I/O |

Both variants include the DSC and EDID patches. The RT variant additionally
applies PREEMPT_RT for deterministic scheduling.

## Target hardware

| Component | Detail |
|-----------|--------|
| Machine | Dell Precision Tower 7810 (0GWHMW) |
| CPU | Dual Xeon E5-2630 v3 (Haswell-EP, 16 cores) |
| Chipset | Intel C610/C612 (Wellsburg PCH) |
| GPU | AMD Radeon 9070 XT (Navi 48 / RDNA4) |
| NIC | Intel 82599ES 10GbE (dual SFP+) |
| Storage | NVMe (CT2000P310SSD8) |
| BIOS | A02 (2014-09-05) → needs A34 (see below) |
| VR | Bigscreen Beyond 2e (3840x1920, DSC required for 90Hz) |

## Deployment checklist

Order of operations for first deployment on a Dell T7810:

### Phase 0: BIOS update (required for RT)

- [ ] Download T7810A34.exe from [Dell Support](https://www.dell.com/support/home/en-us/drivers/driversdetails?driverid=8h1nw) (9.54 MB)
- [ ] Prepare FreeDOS USB: write FD13-LiteUSB.img, copy T7810A34.exe
- [ ] Prepare recovery USB: FAT32, copy T7810A34.exe renamed to `BIOS_IMG.rcv`
- [ ] Boot honey from FreeDOS USB (F12 → USB Storage → "Boot to DOS")
- [ ] Run `T7810A34.EXE` from DOS prompt, let it complete
- [ ] Verify BIOS version in F2 setup: should show A34
- [ ] Configure BIOS settings for RT (see below)

#### What A34 gets us (critical for RT)

| Fix | Impact |
|-----|--------|
| **Microcode updates** | Fixes TSC-deadline errata on Haswell-EP — prevents timer misfires with PREEMPT_RT |
| **ACPI table fixes** | 6 years of improvements — fixes HPET exposure, power management, DSDT accuracy |
| **SMI behavior** | Modern SMI handling — reduces USB Legacy + TCO watchdog interrupt storms |
| **Security** | Spectre/Meltdown/MDS/TAA mitigations (INTEL-SA-00075, SA-00219, SA-00220) |
| **F12 BIOS Flash** | Adds one-click BIOS update from boot menu — makes future updates trivial |

#### BIOS settings for RT (after flashing A34)

- [ ] Disable **USB Legacy Support** (prevents SMI storms from EHCI/xHCI emulation)
- [ ] Disable **C-States beyond C1** (prevents APIC timer wakeup latency)
- [ ] Disable **Intel SpeedStep / Turbo Boost** (prevents TSC calibration interference)
- [ ] Enable **HPET** (fallback reference clocksource)
- [ ] Verify **Boot List Option** = UEFI

#### BIOS update methods (ranked)

| Method | Works on A02? | Risk | Notes |
|--------|--------------|------|-------|
| FreeDOS USB | **Yes** | Low | Primary method — boot DOS, run .exe |
| UEFI Shell + Flash64W.efi | Maybe | Medium | Extract from .exe via `7z x`, boot UEFI shell |
| F12 BIOS Flash | **No** | N/A | Not available until a newer BIOS is installed |
| flashrom internal | Possible | Medium | `flashrom -p internal --ifd -i bios -w bios.bin` (ME locked) |
| SPI hardware flash | Yes | High | CH341A/RPi Pico + SOIC clip — nuclear option |
| Ctrl+Esc recovery | Emergency | Low | `BIOS_IMG.rcv` on FAT32 USB, hold Ctrl+Esc at power-on |

### Phase 1: Install kernel

- [ ] Install from [Releases](https://github.com/tinyland-inc/linux-xr/releases) or the stable Pages installer surface
- [ ] Generic: `curl -fsSL https://tinyland-inc.github.io/linux-xr/install/rocky10-generic.sh | bash`
- [ ] RT: `curl -fsSL https://tinyland-inc.github.io/linux-xr/install/rocky10-rt.sh | bash`
- [ ] `sudo dnf install ./kernel-xr-6.19.5-*.xr.el10.x86_64.rpm`
- [ ] Generate initramfs: `sudo dracut --force /boot/initramfs-6.19.5-rt1-1.xr.el10.img 6.19.5-rt1-1.xr.el10`
- [ ] Create BLS boot entry (see [Boot entry setup](#boot-entry-setup))
- [ ] Set as default: `sudo grubby --set-default /boot/vmlinuz-6.19.5-rt1-1.xr.el10`
- [ ] Reboot and verify: `uname -r` shows `6.19.5-rt1-1.xr.el10`

### Phase 2: Verify display + DSC

- [ ] `dmesg | grep "VESA.*DSC.*BPP"` — parser finds BPP=128
- [ ] `cat /sys/class/drm/card1-DP-2/non_desktop` — shows `1`
- [ ] `zcat /proc/config.gz | grep PREEMPT_RT` — shows `CONFIG_PREEMPT_RT=y`
- [ ] Power on Beyond via HID, check link training in dmesg
- [ ] Verify DSC BPP=8.0 selected by VESA DisplayID parser
- [ ] Confirm 90Hz output (DTN log: OTG active, no underflow)

### Phase 3: Deploy compositor stack

- [ ] `just deploy honey all` (compositor + sway-beyond + monado-beyond via nix copy)
- [ ] `just deploy-verify honey`

## Boot entry setup

The RPM's `%post` scriptlet uses `grubby --set-default` which requires the kernel to already have a BLS entry. On Rocky 10 with BLS, create the entry manually:

```bash
# Generate initramfs
sudo dracut --force /boot/initramfs-6.19.5-rt1-1.xr.el10.img 6.19.5-rt1-1.xr.el10

# Create BLS entry (machine-id from /etc/machine-id)
MACHINE_ID=$(cat /etc/machine-id)
sudo tee /boot/loader/entries/${MACHINE_ID}-6.19.5-rt1-1.xr.el10.conf << 'EOF'
title Rocky Linux (6.19.5-rt1-1.xr.el10) XR Kernel
version 6.19.5-rt1-1.xr.el10
linux /vmlinuz-6.19.5-rt1-1.xr.el10
initrd /initramfs-6.19.5-rt1-1.xr.el10.img
options ro tsc=nowatchdog clocksource=tsc nosoftlockup intel_pstate=disable processor.max_cstate=1 intel_idle.max_cstate=0 crashkernel=2G-64G:256M,64G-:512M resume=UUID=<your-swap-uuid> rd.lvm.lv=rl00/root rd.lvm.lv=rl00/swap amdgpu.modeset=1 amdgpu.dc=1 amdgpu.dcdebugmask=0x10
grub_users $grub_users
grub_arg --unrestricted
grub_class kernel
EOF

# Set as default
sudo grubby --set-default /boot/vmlinuz-6.19.5-rt1-1.xr.el10
```

## RT boot parameters

Required for PREEMPT_RT on Dell T7810 (Haswell-EP / C610):

| Parameter | Purpose |
|-----------|---------|
| `tsc=nowatchdog` | Prevent clocksource watchdog from falsely marking TSC unstable under RT load |
| `clocksource=tsc` | Use TSC (20ns access) instead of HPET (1us access) |
| `nosoftlockup` | Disable soft lockup detector (false positives during RT scheduling) |
| `intel_pstate=disable` | Prevent frequency scaling from interfering with TSC calibration |
| `processor.max_cstate=1` | Prevent deep C-states that add APIC timer wakeup latency |
| `intel_idle.max_cstate=0` | Disable intel_idle driver's C-state management |

### Debug parameters (for boot failures)

If the RT kernel fails to boot silently (PREEMPT_RT uses nbcon console threading — no output before kthreads are created):

```
earlyprintk=vga,keep ignore_loglevel debug initcall_debug nosmp nosoftlockup
```

| Parameter | Purpose |
|-----------|---------|
| `earlyprintk=vga,keep` | Write directly to VGA memory, bypassing nbcon — shows output during early hang |
| `initcall_debug` | Print every init function with timestamps — last line before hang = culprit |
| `nosmp` | Boot with 1 CPU only — eliminates dual-socket TSC sync as a variable |
| `ignore_loglevel` | Show all kernel messages regardless of log level |

Progressive debug: if `nosmp` works, try `maxcpus=1`, then `maxcpus=2`, `maxcpus=4`, etc. to find where it breaks.

If timers are suspected: `clocksource=jiffies nohpet notsc` forces PIT-based jiffies (most basic timer).

Serial console (T7810 has internal 9-pin "SERIAL1" header): `earlyprintk=serial,ttyS0,115200 console=ttyS0,115200n8`

### RT fallback (if PREEMPT_RT cannot boot)

Rebuild without `CONFIG_PREEMPT_RT`. Use `PREEMPT_DYNAMIC` with boot params:

```
preempt=full threadirqs
```

This gives ~90% of RT latency benefit:
- Threaded IRQ handlers (same mechanism as RT)
- Full kernel preemption at all preemption points
- No sleeping spinlock conversion (the part that causes boot issues)

## RT kernel failure analysis (Dell T7810)

### Root causes (ranked by likelihood)

1. **nbcon console threading**: PREEMPT_RT 6.x creates per-console kthreads for printk. Before these exist, only emergency/panic output displays. A hang during early init produces a completely dark screen — not a crash, just invisible.

2. **BIOS A02 deficiencies**: Factory BIOS from 2014 has incomplete ACPI tables, old microcode with TSC-deadline errata, and possibly broken HPET exposure. 32 revisions of fixes in A34 address these.

3. **SMI storms**: C610 PCH generates SMIs from USB Legacy emulation (`LEGACY_USB_EN`, `LEGACY_USB2_EN` bits in `SMI_EN` register at `ACPI_BASE+0x30`) and TCO watchdog (`TCO_EN`). SMIs last ~100us+ and stall RT's converted sleeping locks during handoff.

4. **Dual-socket TSC sync**: `check_tsc_sync_target()` runs a tight spin-loop between sockets. Under RT, the spin_lock is converted to a sleeping RT-mutex, which may deadlock if the timer subsystem isn't fully initialized.

5. **TSC-deadline timer errata**: Haswell-EP with old microcode has known bugs where TSC-deadline mode fires spurious interrupts. Fix: `clearcpuid=tsc_deadline_timer` boot param, or microcode update (BIOS A34).

### SMI investigation (run on stock kernel)

```bash
# Measure hardware-induced latency (SMIs)
sudo hwlatdetect --duration=60 --threshold=10

# Count SMIs
sudo rdmsr -p 0 0x34   # MSR_SMI_COUNT (before)
sleep 10
sudo rdmsr -p 0 0x34   # MSR_SMI_COUNT (after)

# Check timer health
dmesg | grep -i hpet
dmesg | grep -i tsc
cat /sys/devices/system/clocksource/clocksource0/available_clocksource
```

### C610 SMI_EN register map (ACPI_BASE + 0x30)

| Bit | Name | Description |
|-----|------|-------------|
| 0 | GBL_SMI_EN | Global SMI enable (master switch — do NOT clear) |
| 3 | LEGACY_USB_EN | USB 1.1 legacy emulation SMI |
| 5 | APMC_EN | Software SMI via APM port |
| 13 | TCO_EN | TCO watchdog SMI |
| 14 | PERIODIC_EN | Periodic SMI |
| 17 | LEGACY_USB2_EN | USB 2.0 legacy emulation SMI |

## Build locally

```bash
# Extract base config from target machine first:
ssh jess@honey "cat /boot/config-$(uname -r)" > xr/config/base.config

# Build generic kernel:
./xr/scripts/build-rpm.sh \
  --kernel-version 6.19.5 \
  --xr-release 2

# Build RT kernel:
./xr/scripts/build-rpm.sh \
  --kernel-version 6.19.5 \
  --xr-release 2 \
  --rt-version 6.19.3-rt1
```

## CI

Tag push (`v6.19.5-xr2`) or manual dispatch triggers RPM builds on
[tinyland-docker](https://github.com/tinyland-inc/GloriousFlywheel) ARC runners (4 CPU / 16Gi).

Both variants are built sequentially (sharing ccache) and attached to a single
GitHub Release.

Manual dispatch supports building a single variant:
```bash
gh workflow run build-kernel.yml -f variant=generic  # generic only
gh workflow run build-kernel.yml -f variant=rt       # RT only
gh workflow run build-kernel.yml -f variant=both     # both (default)
```

Build optimizations:
- `CONFIG_DEBUG_INFO=n` — reduces link-time memory from ~8GB to ~2GB
- Parallelism capped at `-j4` — prevents OOM on memory-constrained runners
- ccache with `save-always: true` — warm builds ~1h vs cold ~2h
- `weekly-cadence.yml` — fetches upstream refs, renders a markdown report from `xr/patches/series`, and opens a weekly cadence issue

## Version scheme

`6.19.5-2.xr.el10` → `uname -r` outputs `6.19.5-rt1-2.xr.el10`

## Kernel upgrade workflow

1. Review the weekly cadence issue opened by `.github/workflows/weekly-cadence.yml`
2. Merge or rebase onto the latest upstream Linux commit that still keeps the carry set clean
3. Update `xr/config/base.config` if `honey`'s running base kernel changes
4. Tag: `git tag -a v6.20.1-xr1 -m "XR kernel 6.20.1"`
5. CI builds + publishes RPMs
6. Promote only after `honey` and `yoga` validation

## Upstream status

| Patch | Upstream status | ETA |
|-------|----------------|-----|
| VESA DisplayID DSC BPP (Bolyukin v7) | Reviewed, NOT merged — missed 7.0 window | ~7.1 (June 2026) |
| QP table + RC offset (raika-xino) | Never submitted | Needs amd-gfx submission |
| EDID non_desktop quirk (BIG/0x1234) | Not submitted | Submit to drm-misc |
| PREEMPT_RT | Mainline since 6.12 | N/A |

Carry patch order is defined in `xr/patches/series`.
