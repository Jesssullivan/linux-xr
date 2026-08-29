# linux-xr source-sync runbook

This runbook is for syncing the checked-out kernel source tree to a selected
upstream stable target. It is separate from the RPM proof-build path.

## Current target

As of 2026-08-29 (pin moved from `v7.1.3`; ruling record below unchanged):

- **xr12 base re-home (D3 amendment, operator ruling 2026-07-06, `TIN-2317`).**
  The maintained generic candidate re-homes off the `7.0.x` line onto the live
  `7.1.y` stable line. When the ruling was taken, the `7.1.y` head was `v7.1.3`
  (released 2026-07-04) and mainline was `7.2-rc2`. The `7.0.y` line's final
  point release is `v7.0.14` (2026-06-27; no `v7.0.15`), and `7.1.y` is the
  primary stable line that the ROCm/display-driver ingestion for the Bigscreen
  Beyond path wants. The D3 principle is unchanged (stable base + our carries +
  weekly upstream-watch); only the pinned line moves. The fork is ours; the
  rebase cadence is accepted.
- **Maintained generic candidate target: `v7.1.12` stable** (released
  2026-08-28; current `7.1.y` head per kernel.org `releases.json`, `iseol:
  false`, verified live 2026-08-29). This advances the pin from `v7.1.3`, which
  was nine point releases stale. Tarball
  `linux-7.1.12.tar.xz` sha256
  `389716b3ed27e4cd520b903eea04acc33b9804c4282cb7a918f05ff14e9b5ae1`, matched
  against kernel.org `sha256sums.asc`; `Makefile` triplet confirmed
  `VERSION=7 PATCHLEVEL=1 SUBLEVEL=12`.
- **Carry verification at `v7.1.12` (2026-08-29, `TIN-611` / `TIN-4065`).** All
  three carries (`0007-vesa-dsc-bpp.patch`, `bigscreen-beyond-edid.patch`,
  `amdgpu-dsc-pps-debugfs.patch`) apply with **zero rejects and zero fuzz**
  against `v7.1.12`, under every path that matters:
  - `git apply --check -p1`, cumulative in `series` order — clean (this is the
    `base-anchor.yml` `git-tree-anchor` authoritative proof);
  - `patch --batch -p1 --fuzz=0 --dry-run` against a pristine tree, per patch —
    clean (this is the `check-kernel-carry.sh` / `rpm-carry-dryrun` path);
  - **cumulative `%prep` replication** in real spec order and with each patch's
    real invocation (`%patch -P0` → `--fuzz=0`, then the raw
    `patch -p1 --fuzz=3` for `bigscreen-beyond-edid.patch`, then `%patch -P20`
    → `--fuzz=0`) — clean. `rpm`'s `%_default_patch_fuzz` is `0` and
    `%__scm_apply_patch` embeds `--fuzz=%{_default_patch_fuzz}` (verified in
    `rpm-software-management/rpm` `macros.in`, branches `rpm-4.19.x`,
    `rpm-4.20.x`, `master`), so `%patch -PN -p1` *is* the zero-fuzz path on the
    `rockylinux/rockylinux:10` build image.
  - A stricter-than-spec variant (cumulative, `--fuzz=0` for **all three**,
    including `bigscreen-beyond-edid.patch`) is also clean, so the spec's
    `--fuzz=3` override for that one patch is currently unnecessary headroom
    rather than a load-bearing crutch.

  Every hunk that moved did so by **pure line offset** (amdgpu_dm.c +127,
  drm_edid.c +32/+73, drm_connector.h +2, drm_edid.c +25/+26 for the bigscreen
  quirk); `amdgpu_dm_debugfs.c` needed no offset at all. Offset is not fuzz —
  context matched exactly in every case. **No carry needed a line-context
  refresh and none was made.**
- **The "carries need a line-context refresh before a 7.1.x RPM builds" claim
  is retired.** It was true before 2026-07-09, when
  `amdgpu-dsc-pps-debugfs.patch` was still stamped against `7.0.x` context; PR
  #85 regenerated it against `v7.1.3` and closed that half of `TIN-611`. The
  claim survived only as prose in `base-anchor.yml` and in ticket summaries.
  The advisory `rpm-carry-dryrun` job has in fact been **green** on `xr/main`
  (run `33237032107`, 2026-08-29).
- Security preflight at this base: `CVE-2026-31431`, `CVE-2026-43284`, and
  `CVE-2026-43500` are all fixed natively at `7.1.12` — the `build-rpm.sh`
  version gates return `fixed` and every `*_repo_backport_applies` helper
  returns false, so **none** of the `xr/security/*` backports are applied on a
  `7.1.x` base (see `xr/security/README.md`). Retiring those files is a
  separate reviewed change and is **not** done here: the `6.18.x` / `6.12.x`
  longterm fallbacks still select them.
- Current published/downloadable lab release line: `v6.19.5-xr11` from
  `xr/main` commit `e25a1a77`, with generic RPMs, RT RPMs, and `SHA256SUMS`
  published on GitHub. It carries `CVE-2026-31431`, `CVE-2026-43284`, and both
  `CVE-2026-43500` RxRPC RXKAD/RXGK backports. This stays the last published
  line until a `7.1.12` generic RPM proof is built and host-validated.
- **Known remaining risk for a green `7.1.12` RPM (not a carry problem).**
  `xr/config/base.config` is a scraped ElRepo **6.19.5** config (its own header
  says `Linux/x86_64 6.19.5-1.el10.elrepo.x86_64`). `%prep` copies it to
  `.config`, applies the XR overrides, runs `make olddefconfig` twice, and then
  gates on `bash %{SOURCE2} .config` (`check-security-config.sh`). Kconfig
  symbols renamed, removed, or newly dependency-gated between `6.19.y` and
  `7.1.y` would surface there, not in the carries. That step has never been
  exercised on a `7.1.x` tree. Likewise, the carries are proven to *apply* at
  `7.1.12` but have never been *compiled* on a `7.1.x` base.
- Current host boot-proven line: `v6.19.5-xr10` is boot-proven on `mbp-13` and
  `honey`. No `7.1.x` kernel is host boot-proven yet; promotion into any host
  rollout doc still requires the exact `*-xr.el10` kernel to boot and record
  SELinux, RPM, rollback, and default-boot evidence.
- Maintained longterm fallback targets: `v6.18.31` and `v6.12.89`, both with
  passing carry and security preflights. These stay below the `CVE-2026-43284`
  and `CVE-2026-43500` fixed floors, so they keep the gated `xr/security/*`
  backports; do not remove the security patch files when re-homing to `7.1.y`.
- Longterm fallback watch: `v6.12.89` still needs a successful RPM proof before
  promotion. The zero-fuzz DSC carry conflict is fixed; the next proof gate is
  preserving the `CONFIG_FW_LOADER_USER_HELPER=n` systemd/Rocky boot contract
  on this older Kconfig while allowing hardening symbols that do not exist yet
  in `6.12.y` to be absent rather than disabled.
- Bounded EOL compatibility proof target: `v6.19.14` (the `6.19.y` line is EOL).
- RT candidate floor: `v7.0.1` with `patch-7.0.1-rt2` (last proven RT line).
- RT blockers: no `7.1.x` PREEMPT_RT patchset has been proven against this base
  yet, so RT stays pinned at `v7.0.1-rt2` until a compatible `7.1.x` RT patch or
  refreshed local RT carry passes carry and security preflights. `v6.18.13-rt4`
  still fails the CVE-2026-31431 gate because the repo does not carry a 6.18.13
  backport.

Do not merge `torvalds/linux:master` into an active lab release branch. Mainline
is `7.2` (released 2026-08-16, current stable head `v7.2.2`); any `-rc` base is
refused outright by the security gate, and a just-cut `7.2.y` line is not a
maintained candidate here. For the current lab
line, source sync should target the selected maintained stable or longterm base.
Use `v6.19.14` only as a bounded compatibility proof because kernel.org marks
the `6.19.y` line EOL.

## Boundary

The RPM workflow builds from kernel.org tarballs selected by
`--kernel-version`, then layers repo-owned config, spec, carry patches, and
security backports. The checked-out source tree is useful for patch development
and upstream comparison, but it is not currently the source tree compiled by the
RPM workflow.

Treat GitHub ahead/behind counts against `torvalds/linux:master` as source-sync
debt. Do not treat them as evidence that a published RPM skipped its configured
tarball input.

## Preflight

Run source-sync work from Linux or a case-sensitive filesystem. Avoid default
macOS case-insensitive checkouts for Linux source truth.

Required checks before moving build defaults or release tags:

```bash
# Fast static guard after changing xr/patches/series or kernel-xr.spec:
./xr/scripts/check-rpm-patch-wiring.sh

# Discover current maintained candidates and optionally run bounded preflights:
./xr/scripts/triage-upstream-targets.sh
./xr/scripts/triage-upstream-targets.sh --run-preflight

# Bounded EOL proof only:
./xr/scripts/check-kernel-carry.sh --kernel-version 6.19.14
./xr/scripts/build-rpm.sh --kernel-version 6.19.14 --xr-release 1 --security-preflight-only

# Maintained candidate checks:
# Primary re-home target (D3 amendment, TIN-2317), pinned at the current
# 7.1.y head as of 2026-08-29:
./xr/scripts/check-kernel-carry.sh --kernel-version 7.1.12
./xr/scripts/build-rpm.sh --kernel-version 7.1.12 --xr-release 1 --security-preflight-only
# Prior 7.1.x pin (superseded 2026-08-29; kept for comparison):
./xr/scripts/check-kernel-carry.sh --kernel-version 7.1.3
# Prior 7.0.x candidate (superseded; kept for fallback comparison):
./xr/scripts/check-kernel-carry.sh --kernel-version 7.0.8
./xr/scripts/build-rpm.sh --kernel-version 7.0.8 --xr-release 1 --security-preflight-only
./xr/scripts/check-kernel-carry.sh --kernel-version 6.18.31
./xr/scripts/build-rpm.sh --kernel-version 6.18.31 --xr-release 1 --security-preflight-only
./xr/scripts/check-kernel-carry.sh --kernel-version 6.12.89
./xr/scripts/build-rpm.sh --kernel-version 6.12.89 --xr-release 1 --security-preflight-only
```

The `6.12.89` tarball contains the `CVE-2026-43284` ESP shared-frag hardening,
but the current public `CVE-2026-43500` fixed-floor evidence covers `6.18.29+`
and `7.0.6+`, not a 6.12 fixed floor. Keep applying the linux-xr RXKAD/RXGK
response/DATA hardening on `6.12.x` fallback builds until a 6.12 upstream or
vendor fixed floor is proven.
Do not promote `6.12.89` as a linux-xr fallback until a real RPM proof succeeds
with the RxRPC security route and the systemd/Rocky firmware-loader helper
guard intact.

RT remains separate until a compatible RT patch is proven:

```bash
./xr/scripts/check-kernel-carry.sh --kernel-version 6.19.14 --rt-version 6.19.3-rt1
./xr/scripts/check-kernel-carry.sh --kernel-version 7.0.1 --rt-version 7.0.1-rt2
./xr/scripts/build-rpm.sh --kernel-version 7.0.1 --xr-release 1 --rt-version 7.0.1-rt2 --security-preflight-only
./xr/scripts/check-kernel-carry.sh --kernel-version 6.18.13 --rt-version 6.18.13-rt4
./xr/scripts/build-rpm.sh --kernel-version 6.18.13 --xr-release 1 --rt-version 6.18.13-rt4 --security-preflight-only
```

The `6.19.14` RT command is expected to fail with the current `6.19.3-rt1`
patchset. The `7.0.1-rt2` lane passed carry and security preflights on
2026-05-16, but it is behind latest stable `7.0.8`; treat it as an RT floor
candidate, not the generic SOTA target. The `6.18.13-rt4` lane applies the
carry but fails the CVE-2026-31431 fixed-floor gate, so it must not be promoted
without a backport or explicit validation-only override.

## Source-sync procedure

1. Start from a clean, case-sensitive checkout with kernel history available.
2. Fetch the selected stable or longterm target from the Linux stable tree.
3. Create a dedicated branch from the selected target, for example
   `codex/source-sync-v7.0.8` or `codex/source-sync-v6.18.31`.
4. Replay linux-xr-owned overlay files from the active control branch:
   `.github/`, `README.md`, `flake.nix`, `flake.lock`, `site/`, and `xr/`.
5. Confirm the top-level `Makefile` reports the intended upstream base.
6. Run the carry and security preflights above.
7. Run a generic RPM proof build before changing defaults or tagging.
8. Keep RT pinned to the last proven RT line until a compatible RT patch or
   refreshed local RT carry passes.

## Acceptance

A source-sync branch is ready for review when:

- the source tree is based on the selected stable target,
- linux-xr overlay files are present and reviewed,
- generic carry dry-run passes,
- security preflight passes,
- generic RPM proof artifacts are uploaded,
- RT is either proven on the same base or explicitly kept on the previous RT
  line.
