# linux-xr

XR-optimized kernel builds for Bigscreen Beyond 2e on AMD GPUs (Rocky Linux 10).

Builds are run on tinyland-inc/GloriousFlywheel infrastructure, including machines running kernel built from this tree.

Fork of `torvalds/linux` with CI-built RPMs carrying VR/XR patches.

## Current State

As of 2026-05-10:

| Area | Status | Notes |
| --- | --- | --- |
| Release artifacts | Published, host validation pending | `v6.19.5-xr11` is the latest published/downloadable secured lab release with generic RPMs, RT RPMs, and `SHA256SUMS`. `v6.19.5-xr10` remains the latest host boot-proven secured line until an approved lab boot validates `6.19.5-11.xr.el10`. |
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
- `nix run .#upstream-triage -- --run-preflight` discovers current stable/RT candidate floors and runs carry/security preflights.
- `.github/workflows/determinate-ci.yml` pushes those lightweight flake outputs through Determinate CI / FlakeHub Cache.

The real RPM release lane remains [`build-kernel.yml`](.github/workflows/build-kernel.yml) plus [`xr/scripts/build-rpm.sh`](xr/scripts/build-rpm.sh) on Linux. Modeling the full kernel RPM build itself as a flake output is a separate, larger piece of work that should stay explicitly tracked.

## What's patched

| Patch | Purpose |
|-------|---------|
| `0007-vesa-dsc-bpp.patch` | VESA DisplayID DSC BPP parser, QP table + RC offset fixes for 8bpc 4:4:4 @ 8 BPP |
| `bigscreen-beyond-edid.patch` | EDID non-desktop quirk for Beyond (BIG/0x1234 + 0x5095) |
| `cve-2026-31431-algif-aead.patch` | CVE-2026-31431 stable `6.19.y` security backport, applied automatically for vulnerable 6.19.x bases |
| `dirtyfrag-esp-shared-frag.patch` | CVE-2026-43284 Dirty Frag ESP page-cache write hardening, applied automatically for supported vulnerable bases |
| `dirtyfrag-rxrpc-linearize.patch` | CVE-2026-43500 Dirty Frag RxRPC RXKAD in-place decrypt hardening, applied automatically for supported vulnerable bases |
| `dirtyfrag-rxrpc-rxgk-linearize.patch` | CVE-2026-43500 Dirty Frag RxRPC RXGK in-place decrypt hardening, applied automatically for supported RXGK-capable vulnerable bases |
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

A tag build builds both variants and attaches them to a single GitHub Release.
`max-parallel` is 1, so the two variants build sequentially, but they do **not**
share a ccache: the cache directory and cache key are both per-variant.

Manual dispatch supports building a single variant:
```bash
gh workflow run build-kernel.yml -f kernel_version=6.19.14 -f xr_release=1 -f variant=generic
gh workflow run build-kernel.yml -f kernel_version=6.19.5 -f xr_release=10 -f variant=rt -f rt_version=6.19.3-rt1
gh workflow run build-kernel.yml -f kernel_version=6.19.5 -f xr_release=10 -f variant=both -f rt_version=6.19.3-rt1
```

Build optimizations:
- `CONFIG_DEBUG_INFO=n` — reduces link-time memory from ~8GB to ~2GB
- Parallelism capped at `-j4` — prevents OOM on memory-constrained runners
- ccache, restored and saved by explicit `actions/cache` steps (the save runs
  `if: always()`, so a cancelled build still banks its cache) — a warm build ran
  43m40s against 4h06m cold for the same tag (run `32764070756`); a cold build
  has ranged 3.5–6h
- `use_ccache` defaults to `true` on manual dispatch; pass `-f use_ccache=false`
  for a deliberately cold build. Cache scope means a dispatch on `xr/main`
  cannot read a tag build's ccache, so the first build on a new base is cold
  regardless
- `weekly-cadence.yml` — fetches upstream plus maintained `linux-7.0.y` stable and `linux-6.18.y` longterm refs, renders a markdown report from `xr/patches/series`, checks carry patch application when full source paths are available, includes the current security watch, and opens a weekly cadence issue
- `xr/scripts/triage-upstream-targets.sh` — discovers latest maintained generic and RT candidate floors from kernel.org and can run the bounded carry/security preflights used before source-sync promotion

## Version scheme

`6.19.5-2.xr.el10` → `uname -r` outputs `6.19.5-rt1-2.xr.el10`

## Security gate

`xr/scripts/build-rpm.sh` guards CVE-2026-31431 and Dirty Frag builds. The
CVE-2026-31431 gate follows the NVD affected floors, including `5.10.x` before
`5.10.254`, `5.15.x` before `5.15.204`, `6.1.x` before `6.1.170`, `6.6.x`
before `6.6.137`, `6.12.x` before `6.12.85`, `6.18.x` before `6.18.22`,
`6.19.x` before `6.19.12`, and release candidates before `7.0` as unsafe
bases. Vulnerable `6.19.x` builds continue only by applying the repo-managed
backport in
[`xr/security/cve-2026-31431-algif-aead.patch`](xr/security/cve-2026-31431-algif-aead.patch).
Other vulnerable or unknown bases are refused unless
`LINUX_XR_ALLOW_CVE_2026_31431=1` is set for explicit validation.

The Dirty Frag gate tracks `CVE-2026-43284` for the ESP shared-frag fix and
the separate `CVE-2026-43500` RxRPC in-place decrypt sinks.
Supported vulnerable bases apply
[`xr/security/dirtyfrag-esp-shared-frag.patch`](xr/security/dirtyfrag-esp-shared-frag.patch)
and/or
[`xr/security/dirtyfrag-rxrpc-linearize.patch`](xr/security/dirtyfrag-rxrpc-linearize.patch)
plus
[`xr/security/dirtyfrag-rxrpc-rxgk-linearize.patch`](xr/security/dirtyfrag-rxrpc-rxgk-linearize.patch)
as needed. Unsupported vulnerable or unknown bases are refused unless
`LINUX_XR_ALLOW_DIRTYFRAG=1` is set for explicit validation.

For a no-build check of the active route:

```bash
./xr/scripts/build-rpm.sh --kernel-version 6.19.5 --xr-release 11 --security-preflight-only
```

For a read-only check of a running host:

```bash
./xr/scripts/check-cve-2026-31431-live.sh
ssh honey 'bash -s' < ./xr/scripts/check-cve-2026-31431-live.sh
```

The live checker treats `initcall_blacklist=algif_aead_init` as the narrow
preferred boot mitigation and also recognizes the broader Red Hat-documented
`af_alg_init` and `crypto_authenc_esn_module_init` initcall blacklists.

## Known Patched CVEs And Security Backports

Release-blocking security backports live in
[`xr/security`](xr/security), with source and build-route details in
[`xr/security/README.md`](xr/security/README.md). Keep this table in sync when
adding, dropping, or upstreaming a repo-managed CVE or public security backport.

| CVE | Public name | linux-xr status | Repo links | External references |
| --- | --- | --- | --- | --- |
| CVE-2026-31431 | Copy Fail / `algif_aead` AF_ALG local privilege escalation | Patched in `v6.19.5-xr9` and carried forward in `v6.19.5-xr10` and published `v6.19.5-xr11`; xr11 keeps the same stable `6.19.y` backport on top of the vulnerable `6.19.5` base. Fixed natively by upstream affected-range floors such as `6.19.12+`, `6.18.22+`, `6.12.85+`, `6.6.137+`, `6.1.170+`, `5.15.204+`, `5.10.254+`, and `7.0+` bases. | [`xr/security/cve-2026-31431-algif-aead.patch`](xr/security/cve-2026-31431-algif-aead.patch), [`xr/scripts/build-rpm.sh`](xr/scripts/build-rpm.sh), [`xr/scripts/check-cve-2026-31431-live.sh`](xr/scripts/check-cve-2026-31431-live.sh), [`v6.19.5-xr10`](https://github.com/tinyland-inc/linux-xr/releases/tag/v6.19.5-xr10), [`v6.19.5-xr11`](https://github.com/tinyland-inc/linux-xr/releases/tag/v6.19.5-xr11), [`xr11` release run](https://github.com/tinyland-inc/linux-xr/actions/runs/25615643270) | [NVD](https://nvd.nist.gov/vuln/detail/CVE-2026-31431), [Red Hat RHSB-2026-02](https://access.redhat.com/security/vulnerabilities/RHSB-2026-02), [CISA KEV](https://www.cisa.gov/known-exploited-vulnerabilities-catalog?field_cve=CVE-2026-31431), [Copy Fail](https://copy.fail/) |
| CVE-2026-43284 | Dirty Frag / ESP page-cache write | `v6.19.5-xr10` carries the repo-managed ESP backport on the vulnerable `6.19.5` base, and published `v6.19.5-xr11` carries it forward with generic and RT RPMs plus `SHA256SUMS`. Published fixed floors include `5.10.255+`, `5.15.205+`, `6.1.171+`, `6.6.138+`, `6.12.87+`, `6.18.28+`, and `7.0.5+`; EOL `6.19.x` stays conservative and uses the repo backport. | [`xr/security/dirtyfrag-esp-shared-frag.patch`](xr/security/dirtyfrag-esp-shared-frag.patch), [`xr/scripts/build-rpm.sh`](xr/scripts/build-rpm.sh), [`v6.19.5-xr10`](https://github.com/tinyland-inc/linux-xr/releases/tag/v6.19.5-xr10), [`v6.19.5-xr11`](https://github.com/tinyland-inc/linux-xr/releases/tag/v6.19.5-xr11), [`xr11` release run](https://github.com/tinyland-inc/linux-xr/actions/runs/25615643270) | [NVD](https://nvd.nist.gov/vuln/detail/CVE-2026-43284), [CVE record](https://www.cve.org/CVERecord?id=CVE-2026-43284), [Dirty Frag](https://github.com/Jesssullivan/dirtyfrag), [ESP netdev fix f4c50a4034e6](https://git.kernel.org/pub/scm/linux/kernel/git/netdev/net.git/commit/?id=f4c50a4034e6) |
| CVE-2026-43500 | Dirty Frag / RxRPC page-cache write | `v6.19.5-xr10` carried the first repo-managed RxRPC RXKAD linearize/COW hardening on the vulnerable `6.19.5` base. Published `v6.19.5-xr11` is the first release with RXKAD plus RXGK coverage on the lab base. NVD now records affected ranges ending before `6.18.29` and before `7.0.6`; `7.0.8` and `6.18.31` are fixed natively, while `6.19.x` and `6.12.x` linux-xr proof/fallback builds continue to rely on the repo backport route unless a vendor or upstream fixed floor is proven. | [`xr/security/dirtyfrag-rxrpc-linearize.patch`](xr/security/dirtyfrag-rxrpc-linearize.patch), [`xr/security/dirtyfrag-rxrpc-rxgk-linearize.patch`](xr/security/dirtyfrag-rxrpc-rxgk-linearize.patch), [`xr/scripts/build-rpm.sh`](xr/scripts/build-rpm.sh), [`v6.19.5-xr10`](https://github.com/tinyland-inc/linux-xr/releases/tag/v6.19.5-xr10), [`v6.19.5-xr11`](https://github.com/tinyland-inc/linux-xr/releases/tag/v6.19.5-xr11), [`xr11` release run](https://github.com/tinyland-inc/linux-xr/actions/runs/25615643270) | [NVD](https://nvd.nist.gov/vuln/detail/CVE-2026-43500), [CVE record](https://www.cve.org/CVERecord?id=CVE-2026-43500), [Dirty Frag](https://github.com/Jesssullivan/dirtyfrag), [Debian CVE tracker](https://security-tracker.debian.org/tracker/CVE-2026-43500), [RxRPC stable fix](https://git.kernel.org/stable/c/3eae0f4f9f7206a4801efa5e0235c25bbd5a412c) |

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

As of 2026-05-16, the latest published/downloadable secured linux-xr lab release
is [`v6.19.5-xr11`](https://github.com/tinyland-inc/linux-xr/releases/tag/v6.19.5-xr11).
It keeps the `6.19.5` lab base but carries repo-managed
[`CVE-2026-31431`](#known-patched-cves-and-security-backports),
`CVE-2026-43284` Dirty Frag ESP, and `CVE-2026-43500` Dirty Frag
RxRPC RXKAD/RXGK backports. Generic and RT RPMs plus `SHA256SUMS` are
published. The generic `xr10` runtime remains boot-proven on `mbp-13` and
`honey`; xr11 still needs explicit lab host boot validation before it becomes
the host-proven rollout line. Kernel.org now lists
`6.19.14` as EOL; it remains useful as a bounded compatibility proof, but it
should not become the long-lived lab target. Issue
[#37](https://github.com/tinyland-inc/linux-xr/issues/37) tracks rebasing the
lab line to a selected maintained stable or longterm base and triaging all
carry patches.

The published `v6.19.5-xr11` release comes from `xr/main` commit
`e25a1a77`. The tag-backed run
[`25615643270`](https://github.com/tinyland-inc/linux-xr/actions/runs/25615643270)
completed generic, RT, and release jobs. `xr11` should supersede `xr10` for
lab rollout only after target hosts boot the exact `6.19.5-11.xr.el10` kernel
and record SELinux, RPM, rollback, and default-boot evidence.

Current ingestion checkpoint:

- Generic `6.19.14` is a viable EOL compatibility proof target: the XR carry
  patches in [`xr/patches/series`](xr/patches/series) dry-run cleanly against
  the `linux-6.19.14` tarball, and the security preflight passes by applying
  the repo-managed Dirty Frag backports.
- Generic `7.0.8` stable is the newest maintained-base candidate with passing
  carry and security preflights.
- Generic `6.18.31` and `6.12.89` longterm are clean fallback candidates with
  passing carry and security preflights. `6.12.89` still needs a real RPM proof
  before promotion; that proof must preserve the Rocky/systemd
  `CONFIG_FW_LOADER_USER_HELPER=n` boot contract while allowing newer hardening
  symbols that do not exist in `6.12.y` to be absent rather than disabled.
- Fixed `7.0.8` and `6.18.31` bases have `CVE-2026-31431`,
  `CVE-2026-43284`, and `CVE-2026-43500` coverage natively at their fixed
  floors. `6.12.89` still needs the repo-managed `CVE-2026-43500` RxRPC route
  until a 6.12 fixed floor is proven.
- RT `7.0.1-rt2` and `6.19.3-rt1` pass the bounded carry/security preflights;
  RT `6.18.13-rt4` applies the carry but still fails the CVE-2026-31431 gate.
  Keep RT promotion separate from the generic SOTA target until a same-base RT
  patchset or local RT refresh is proven.
- Use [`xr/scripts/check-kernel-carry.sh`](xr/scripts/check-kernel-carry.sh) to
  repeat this check before bumping build defaults or tagging a release.

```bash
./xr/scripts/check-kernel-carry.sh --kernel-version 6.19.14
./xr/scripts/check-kernel-carry.sh --kernel-version 7.0.8
./xr/scripts/check-kernel-carry.sh --kernel-version 6.18.31
./xr/scripts/check-kernel-carry.sh --kernel-version 6.12.89
./xr/scripts/check-kernel-carry.sh --kernel-version 7.0.1 --rt-version 7.0.1-rt2
```

| Patch/workstream | Upstream status | Next action |
|-------|----------------|-----|
| CVE-2026-31431 / Copy Fail / `algif_aead` | Fixed upstream in `7.0` and stable affected-range floors including `6.19.12`, `6.18.22`, `6.12.85`, `6.6.137`, `6.1.170`, `5.15.204`, and `5.10.254`; `v6.19.5-xr11` carries the `6.19.y` backport on the current `6.19.5` lab base | Keep fleet rollout on the host-proven `xr10` boot line until xr11 host boot evidence exists, then rebase the generic lane to a maintained target such as `7.0.8` stable or `6.18.31` longterm under issue #37. Treat stock 6.12-class hosts as exposed to Dirty Frag RxRPC unless a vendor backport, mitigation, or linux-xr route is proven and installed. |
| CVE-2026-43284 / Dirty Frag ESP page-cache write | ESP shared-frag fix is in netdev/net commit `f4c50a4034e6` and published in stable floors including `6.12.87`, `6.18.28`, and `7.0.5`; the EOL `6.19.5` lab base remains protected by the repo backport in published `xr11` | Keep `v6.19.5-xr11` as the published secured lab release while boot-validating it, stop treating fixed maintained bases as needing the ESP backport, and keep `6.12.89` as a fallback candidate only after an RPM proof succeeds. |
| CVE-2026-43500 / Dirty Frag RxRPC page-cache write | NVD and CVE.org now publish the CVE; stable fixed floors include `6.18.29+` and `7.0.6+`, while the published `xr11` lab line carries RXKAD and RXGK linearize/COW backports on `6.19.5` | Boot-validate `xr11` for the EOL `6.19.5` lab line, stop applying the RxRPC backport on fixed `7.0.8`/`6.18.31` candidates, and keep carrying RxRPC on `6.12.x` fallback builds until a 6.12 fixed floor is proven. |
| VESA DisplayID DSC BPP parser / amdgpu handling | In-flight upstream series; not present in current upstream checkout | Track Bolyukin v7 fixed-DSC-BPP series and drop this part when it lands. |
| QP table + RC offset adjustments | Local carry; not submitted as a standalone upstream series | Split from the DisplayID parser carry using `xr/patches/0007-vesa-dsc-bpp.map.md` and decide whether this is evidence-backed upstream material or host-only risk. |
| EDID non-desktop quirk for `BIG/0x1234` and `BIG/0x5095` | Absent from current upstream checkout | Follow `xr/patches/bigscreen-beyond-edid.route.md`: local `BIG/0x1234` evidence now proves `non-desktop=1`; next regenerate an upstream/drm-misc topic patch and send via the DRM route. |
| SMI and NUMA posture | Platform/runtime validation, not a linux-xr source patch | Keep kernel config support here; keep validators, tuned profiles, and host captures in Dell-7810/XoxdWM surfaces. |
| PREEMPT_RT | Mainline since 6.12; this repo still downloads RT patches for the configured 6.19.x RT build lane | Re-evaluate when the RPM lane moves to a kernel whose RT posture is fully mainline for our target release. |

Carry patch order is defined in `xr/patches/series`.
