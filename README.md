# linux-xr

XR-optimized kernel builds for Bigscreen Beyond 2e on AMD GPUs (Rocky Linux 10).

Builds are run on tinyland-inc/GloriousFlywheel infrastructure, including machines running kernel built from this tree.

Fork of `torvalds/linux` with CI-built RPMs carrying VR/XR patches.

## Current State

As of 2026-04-25:

| Area | Status | Notes |
| --- | --- | --- |
| Release artifacts | Proven | Latest public release ships generic and RT RPMs. |
| `honey` rollout | Proven (generic) | `honey` is persistently defaulted to the generic XR kernel lane. |
| `honey` RT boot | Reboot-valid, gated | RT boot and `/sys/kernel/realtime=1` verification succeeded; Dell's repeated host packet is cautionary, so regular use still needs downstream deadline evidence. |
| `yoga` rollout | Proven one-time generic boot | Generic XR RPM install and one-time boot succeeded; stock Rocky remains the persistent fallback. |
| Install surface | Active | GitHub Pages and stable installer paths live in `site/`. |
| Patch carry set | Localized | Kernel-owned carry patches live under `xr/patches/`. |
| Build source | Tarball-based | RPMs are built from kernel.org `linux-${KERNEL_VERSION}.tar.xz` plus this repo's config, spec, carry patches, and security backports; the checked-out kernel source tree is not currently the RPM source input. |
| Local checkout requirement | Case-sensitive | Linux source checkouts must be on Linux or a case-sensitive filesystem; macOS case-insensitive checkouts corrupt case-distinct kernel paths. |

## Public Surfaces

- Releases: <https://github.com/tinyland-inc/linux-xr/releases>
- Stable install docs: `https://tinyland-inc.github.io/linux-xr/`
- Generic installer: `https://tinyland-inc.github.io/linux-xr/install/rocky10-generic.sh`
- RT installer: `https://tinyland-inc.github.io/linux-xr/install/rocky10-rt.sh`
- Carry patches: [`xr/patches`](xr/patches)

## Host Authority Boundary

This repo owns the kernel carry, RPM build, release, installer, and upstream
watch surfaces. It does not own live workstation evidence for `honey`.

For the Dell Precision 7810 host lane, keep BIOS, SMI, C-state, NUMA, tuned,
rollback, and RT acceptance records in the companion `Jesssullivan/Dell-7810`
repo. `linux-xr` may state which kernel features the RPMs ship, but Dell-owned
captures decide whether `honey` is prepared for RT, BCI, or downstream XR
validation.

## Build Source Boundary

`linux-xr` currently has two source surfaces:

- Release builds use [`xr/scripts/build-rpm.sh`](xr/scripts/build-rpm.sh) to
  download the selected kernel.org tarball, apply repo-managed security
  backports, apply [`xr/patches/series`](xr/patches/series), apply optional RT,
  and build RPMs from the resulting source tree.
- The checked-out kernel source tree remains useful for upstream comparison and
  patch development, but it is not the source tree compiled by the RPM workflow
  until a source-sync branch explicitly makes it so.

As of 2026-05-01, `xr/main`'s checked-out kernel `Makefile` reports `7.0-rc3`
while the active lab RPM line is `6.19.x`. GitHub also reports `xr/main` as
diverged from `torvalds/linux:master` by `82` local commits and `16414`
upstream commits. Treat that as source-sync debt, not as evidence that a
published RPM skipped its configured tarball input. For the current lab line,
use issue [#37](https://github.com/tinyland-inc/linux-xr/issues/37) to rebase a
dedicated source-sync branch to the selected stable target, replay linux-xr
carry, and only then change build defaults or release tags. The operator runbook
for that work is [`xr/source-sync.md`](xr/source-sync.md).

## Nix / FlakeHub

This repo now carries a thin flake surface in [`flake.nix`](flake.nix) for
developer tooling and cacheable checks. It is intentionally not the canonical
kernel release build.

- `nix develop` provides a shell with the core patch/report tooling.
- `nix flake check` validates the patch series and shell-script syntax.
- `nix run .#cadence-report -- --upstream-ref <ref> --stable-ref <ref>` runs the weekly cadence report helper from a repo checkout.
- `.github/workflows/determinate-ci.yml` pushes those lightweight flake outputs through Determinate CI / FlakeHub Cache.

The real RPM release lane remains [`build-kernel.yml`](.github/workflows/build-kernel.yml) plus [`xr/scripts/build-rpm.sh`](xr/scripts/build-rpm.sh) on Linux. Modeling the full kernel RPM build itself as a flake output is a separate, larger piece of work that should stay explicitly tracked.

## What's patched

| Patch | Purpose |
|-------|---------|
| `0007-vesa-dsc-bpp.patch` | VESA DisplayID DSC BPP parser, QP table + RC offset fixes for 8bpc 4:4:4 @ 8 BPP |
| `bigscreen-beyond-edid.patch` | EDID non-desktop quirk for Beyond (BIG/0x1234 + 0x5095) |
| `cve-2026-31431-algif-aead.patch` | CVE-2026-31431 stable `6.19.y` security backport, applied automatically for vulnerable 6.19.x bases |
| `patch-6.19.3-rt1.patch` | PREEMPT_RT real-time scheduling (RT variant only, downloaded from kernel.org) |

XR carry patches are maintained in this repository under [`xr/patches`](xr/patches).
Security backports that are not part of the normal XR carry live under
[`xr/security`](xr/security).

RT motivation comes from possible deadline-sensitive workloads: AD/DA and
sensor I/O for the BCI server, audio periods/xruns, and XR compositor frame
timing. Those are hypotheses, not supplier-side claims. Dell-7810 currently
owns the measured host stance: generic remains the default operating lane, and
RT remains gated until a downstream packet proves a concrete benefit.

## Variants

Each release includes two kernel variants:

| Variant | Package | Use case |
|---------|---------|----------|
| **Generic** | `kernel-xr` | Standard XR workloads, desktop compositing |
| **RT** | `kernel-xr-rt` | Experimental lane for measured scheduler, IRQ, audio, BCI, or XR deadline tests |

Both variants include the DSC and EDID patches. The RT variant additionally
applies PREEMPT_RT to expose realtime preemption semantics. Do not describe it
as a proven performance or latency improvement for `honey` until Dell and the
downstream consumer repo have matching evidence.

## Target hardware

| Component | Detail |
|-----------|--------|
| Machine | Dell Precision Tower 7810 (0GWHMW) |
| CPU | Dual Xeon E5-2630 v3 (Haswell-EP, 16 cores) |
| Chipset | Intel C610/C612 (Wellsburg PCH) |
| GPU | AMD Radeon 9070 XT (Navi 48 / RDNA4) |
| NIC | Intel 82599ES 10GbE (dual SFP+) |
| Storage | NVMe (CT2000P310SSD8) |
| BIOS | Host-specific; `honey` BIOS evidence is tracked in `Dell-7810` |
| VR | Bigscreen Beyond 2e (3840x1920, DSC required for 90Hz) |

## Deployment checklist

Order of operations for first kernel deployment on a Dell T7810:

This checklist is supplier-side bootstrap guidance for the kernel package. It
does not replace the current Dell workstation validation ledger. Current BIOS,
SMI, C-state, PREEMPT_RT acceptance, NUMA, and rollback evidence for `honey`
lives in `Jesssullivan/Dell-7810`; this repo should only claim package
availability, install flow, and kernel carry status.

### Phase 0: Host preflight

- [ ] Confirm the Dell-owned host runbook says the target is ready for this
      kernel lane.
- [ ] Confirm the intended fallback kernel remains bootable.
- [ ] For `honey`, treat RT as gated until the Dell RT contract says C3 is
      acceptable for regular workstation use and a downstream C4 packet proves
      an actual benefit.
- [ ] Keep BIOS, SMI, C-state, NUMA, and tuned validation in `Dell-7810`; do
      not update this README as the host evidence ledger.

### Phase 1: Install kernel

- [ ] Install from [Releases](https://github.com/tinyland-inc/linux-xr/releases) or the Pages installer surface for the latest installable lab release
- [ ] Generic: `curl -fsSL https://tinyland-inc.github.io/linux-xr/install/rocky10-generic.sh | bash`
- [ ] RT: `curl -fsSL https://tinyland-inc.github.io/linux-xr/install/rocky10-rt.sh | bash`
- [ ] `sudo dnf install ./kernel-xr-6.19.5-*.xr.el10.x86_64.rpm`
- [ ] Let `kernel-install` create the initramfs and BLS entry, or use the
      manual fallback below if needed.
- [ ] Reboot through the host runbook's rollback-safe path.
- [ ] Verify `uname -r` shows the intended `kernel-xr` lane.

### Phase 2: Verify display + DSC

- [ ] `dmesg | grep "VESA.*DSC.*BPP"` — parser finds BPP=128
- [ ] Capture the headset DRM connector property showing `non-desktop=1`;
      use `drm_info`, `modetest`, DRM debugfs, or sysfs if the host exposes it.
- [ ] `zcat /proc/config.gz | grep PREEMPT_RT` — shows `CONFIG_PREEMPT_RT=y`
- [ ] Power on Beyond via HID, check link training in dmesg
- [ ] Verify DSC BPP=8.0 selected by VESA DisplayID parser
- [ ] Confirm 90Hz output (DTN log: OTG active, no underflow)

### Phase 3: Deploy compositor stack

- [ ] `just deploy honey all` (compositor + sway-beyond + monado-beyond via nix copy)
- [ ] `just deploy-verify honey`

## Boot entry setup fallback

The RPM normally uses `kernel-install` to orchestrate `depmod`, `dracut`, and
BLS entry creation. If a target system lacks that path or a recovery procedure
needs a manual entry, use a host-runbook-reviewed fallback like:

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

# Set as default only when the host runbook says this lane is safe to promote.
sudo grubby --set-default /boot/vmlinuz-6.19.5-rt1-1.xr.el10
```

## Host RT posture and troubleshooting

This repo owns the kernel package and installer surface, not the live Dell
workstation acceptance ledger.

For `honey`, the Dell-owned host runbook defines the RT cmdline posture, early
boot debug parameters, T7810 SMI/timer checks, C610 register landmarks, and the
generic-lane fallback rule:

- <https://github.com/Jesssullivan/Dell-7810/blob/main/docs/platform/linux-xr-install-and-rollback.md>
- <https://github.com/Jesssullivan/Dell-7810/blob/main/docs/platform/t7810-rt-boot-troubleshooting.md>
- <https://github.com/Jesssullivan/Dell-7810/blob/main/docs/platform/rt-research-contract.md>

`linux-xr` should not claim that `honey` is RT-acceptable because an RT package
exists or because a historical boot succeeded. It may claim C0 supplier facts:
the package was built, the installer exists, and the kernel feature set is
available for Dell-owned validation.

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

Use a Linux or case-sensitive checkout for source truth. On macOS, do not treat a default case-insensitive checkout as authoritative for kernel files because Linux carries case-distinct paths such as `xt_DSCP.c` and `xt_dscp.c`.

## CI

Tag push (`v6.19.5-xr2`) or manual dispatch triggers RPM builds on
[tinyland-docker](https://github.com/tinyland-inc/GloriousFlywheel) ARC runners (4 CPU / 16Gi).

Both variants are built sequentially (sharing ccache) and attached to a single
GitHub Release.

Manual dispatch supports building a single variant:
```bash
gh workflow run build-kernel.yml -f kernel_version=6.19.14 -f xr_release=1 -f variant=generic
gh workflow run build-kernel.yml -f kernel_version=6.19.5 -f xr_release=9 -f variant=rt -f rt_version=6.19.3-rt1
gh workflow run build-kernel.yml -f kernel_version=6.19.5 -f xr_release=9 -f variant=both -f rt_version=6.19.3-rt1
```

Build optimizations:
- `CONFIG_DEBUG_INFO=n` — reduces link-time memory from ~8GB to ~2GB
- Parallelism capped at `-j4` — prevents OOM on memory-constrained runners
- ccache with `save-always: true` — warm builds ~1h vs cold ~2h
- `weekly-cadence.yml` — fetches upstream plus maintained `linux-7.0.y` stable and `linux-6.18.y` longterm refs, renders a markdown report from `xr/patches/series`, checks carry patch application when full source paths are available, includes the current security watch, and opens a weekly cadence issue

## Version scheme

`6.19.5-2.xr.el10` → `uname -r` outputs `6.19.5-rt1-2.xr.el10`

## Security gate

`xr/scripts/build-rpm.sh` guards CVE-2026-31431 builds. The current gate follows
the NVD affected floors, including `5.10.x` before `5.10.254`, `5.15.x` before
`5.15.204`, `6.1.x` before `6.1.170`, `6.6.x` before `6.6.137`, `6.12.x`
before `6.12.85`, `6.18.x` before `6.18.22`, `6.19.x` before `6.19.12`, and
release candidates before `7.0` as unsafe bases. Vulnerable `6.19.x` builds
continue only by applying the repo-managed backport in
[`xr/security/cve-2026-31431-algif-aead.patch`](xr/security/cve-2026-31431-algif-aead.patch).
Other vulnerable or unknown bases are refused unless
`LINUX_XR_ALLOW_CVE_2026_31431=1` is set for explicit validation.

For a no-build check of the active route:

```bash
./xr/scripts/build-rpm.sh --kernel-version 6.19.5 --xr-release 9 --security-preflight-only
```

For a read-only check of a running host:

```bash
./xr/scripts/check-cve-2026-31431-live.sh
ssh honey 'bash -s' < ./xr/scripts/check-cve-2026-31431-live.sh
```

The live checker treats `initcall_blacklist=algif_aead_init` as the narrow
preferred boot mitigation and also recognizes the broader Red Hat-documented
`af_alg_init` and `crypto_authenc_esn_module_init` initcall blacklists.

## Known Patched CVEs

Release-blocking security backports live in
[`xr/security`](xr/security), with source and build-route details in
[`xr/security/README.md`](xr/security/README.md). Keep this table in sync when
adding, dropping, or upstreaming a repo-managed CVE patch.

| CVE | Public name | linux-xr status | Repo links | External references |
| --- | --- | --- | --- | --- |
| CVE-2026-31431 | Copy Fail / `algif_aead` AF_ALG local privilege escalation | Patched in `v6.19.5-xr9` by carrying the stable `6.19.y` backport on top of the vulnerable `6.19.5` base; fixed natively by upstream affected-range floors such as `6.19.12+`, `6.18.22+`, `6.12.85+`, `6.6.137+`, `6.1.170+`, `5.15.204+`, `5.10.254+`, and `7.0+` bases | [`xr/security/cve-2026-31431-algif-aead.patch`](xr/security/cve-2026-31431-algif-aead.patch), [`xr/scripts/build-rpm.sh`](xr/scripts/build-rpm.sh), [`xr/scripts/check-cve-2026-31431-live.sh`](xr/scripts/check-cve-2026-31431-live.sh), [`v6.19.5-xr9`](https://github.com/tinyland-inc/linux-xr/releases/tag/v6.19.5-xr9) | [NVD](https://nvd.nist.gov/vuln/detail/CVE-2026-31431), [Red Hat RHSB-2026-02](https://access.redhat.com/security/vulnerabilities/RHSB-2026-02), [CISA KEV](https://www.cisa.gov/known-exploited-vulnerabilities-catalog?field_cve=CVE-2026-31431), [Copy Fail](https://copy.fail/) |

## SELinux and Security Config

`linux-xr` is expected to preserve the Rocky/RHEL SELinux security contract:
SELinux is built in, selected as the default security module, backed by audit
and filesystem security-label support, and accompanied by lockdown, Yama,
Landlock, BPF LSM, IMA, EVM, module signatures, and the existing hardening
defaults.

The reusable guard is [`xr/scripts/check-security-config.sh`](xr/scripts/check-security-config.sh).
It is run by `nix flake check` against [`xr/config/base.config`](xr/config/base.config)
and by the RPM build against the post-`olddefconfig` `.config`, so kernel config
drift fails before an RPM can be accepted.

## Kernel upgrade workflow

1. Review the weekly cadence issue opened by `.github/workflows/weekly-cadence.yml`
2. Compare against current upstream, maintained stable/longterm refs, and any
   bounded EOL proof target before choosing a merge target
3. Confirm the cadence security watch is fixed or explicitly waived for validation-only work
4. Update `xr/config/base.config` if `honey`'s running base kernel changes
5. Tag: `git tag -a v6.20.1-xr1 -m "XR kernel 6.20.1"`
6. CI builds + publishes RPMs
7. Promote only after `honey` and `yoga` validation

## Upstream status

As of 2026-05-03, the latest published secured linux-xr lab release is
[`v6.19.5-xr9`](https://github.com/tinyland-inc/linux-xr/releases/tag/v6.19.5-xr9).
It keeps the `6.19.5` lab base but carries the repo-managed
[`CVE-2026-31431`](#known-patched-cves) backport. Kernel.org now lists
`6.19.14` as EOL; it remains useful as a bounded compatibility proof, but it
should not become the long-lived lab target. Issue
[#37](https://github.com/tinyland-inc/linux-xr/issues/37) tracks rebasing the
lab line to a selected maintained stable or longterm base and triaging all
carry patches.

Current ingestion checkpoint:

- Generic `6.19.14` is a viable EOL compatibility proof target: the XR carry
  patches in [`xr/patches/series`](xr/patches/series) dry-run cleanly against
  the `linux-6.19.14` tarball, and the CVE security preflight passes without
  the repo-managed backport.
- Generic `6.18.26` longterm and `7.0.3` stable are maintained-base candidates:
  the XR carry patches dry-run cleanly against both tarballs, and the CVE
  security preflight passes for both.
- RT cannot move to `6.19.14` with the current `6.19.3-rt1` patchset: that RT
  patch fails to dry-run against `6.19.14` in the `8250_port.c` serial driver
  path. Keep the current RT artifact line on `v6.19.5-xr9` until a compatible
  RT patchset or local RT refresh is proven. The visible kernel.org 6.19 RT
  directory still only exposes `patch-6.19.3-rt1`.
- Use [`xr/scripts/check-kernel-carry.sh`](xr/scripts/check-kernel-carry.sh) to
  repeat this check before bumping build defaults or tagging a release.

```bash
./xr/scripts/check-kernel-carry.sh --kernel-version 6.19.14
./xr/scripts/check-kernel-carry.sh --kernel-version 6.18.26
./xr/scripts/check-kernel-carry.sh --kernel-version 7.0.3
./xr/scripts/check-kernel-carry.sh --kernel-version 6.19.14 --rt-version 6.19.3-rt1
```

| Patch/workstream | Upstream status | Next action |
|-------|----------------|-----|
| CVE-2026-31431 / Copy Fail / `algif_aead` | Fixed upstream in `7.0` and stable affected-range floors including `6.19.12`, `6.18.22`, `6.12.85`, `6.6.137`, `6.1.170`, `5.15.204`, and `5.10.254`; `v6.19.5-xr9` carries the `6.19.y` backport on the current `6.19.5` lab base | Boot/install validate `xr9` on lab hosts, then rebase the generic lane to a maintained target such as `7.0.3` stable or `6.18.26` longterm under issue #37. Treat 6.12-class stock hosts as exposed unless a vendor backport or mitigation is proven. |
| VESA DisplayID DSC BPP parser / amdgpu handling | In-flight upstream series; not present in current upstream checkout | Track Bolyukin v7 fixed-DSC-BPP series and drop this part when it lands. |
| QP table + RC offset adjustments | Local carry; not submitted as a standalone upstream series | Split from the DisplayID parser carry using `xr/patches/0007-vesa-dsc-bpp.map.md` and decide whether this is evidence-backed upstream material or host-only risk. |
| EDID non-desktop quirk for `BIG/0x1234` and `BIG/0x5095` | Absent from current upstream checkout | Follow `xr/patches/bigscreen-beyond-edid.route.md`: local `BIG/0x1234` evidence now proves `non-desktop=1`; next regenerate an upstream/drm-misc topic patch and send via the DRM route. |
| SMI and NUMA posture | Platform/runtime validation, not a linux-xr source patch | Keep kernel config support here; keep validators, tuned profiles, and host captures in Dell-7810/XoxdWM surfaces. |
| PREEMPT_RT | Mainline since 6.12; this repo still downloads RT patches for the configured 6.19.x RT build lane | Re-evaluate when the RPM lane moves to a kernel whose RT posture is fully mainline for our target release. |

Carry patch order is defined in `xr/patches/series`.
