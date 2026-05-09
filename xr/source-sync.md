# linux-xr source-sync runbook

This runbook is for syncing the checked-out kernel source tree to a selected
upstream stable target. It is separate from the RPM proof-build path.

## Current target

As of 2026-05-09:

- Current lab release line: `v6.19.5-xr10` is published and boot-proven on
  `mbp-13` and `honey`
- Bounded EOL compatibility proof target: `v6.19.14`
- Maintained generic candidate targets: `v7.0.5` stable and `v6.18.28` longterm
- Longterm fallback watch: `v6.12.87`, still pending a successful RPM proof.
  `6.12.87` has `CVE-2026-43284` ESP fixed natively and now has a
  repo-managed reserved-`CVE-2026-43500` RxRPC build route. The zero-fuzz DSC
  carry conflict is fixed; the next proof gate is preserving the
  `CONFIG_FW_LOADER_USER_HELPER=n` systemd/Rocky boot contract on this older
  Kconfig while allowing hardening symbols that do not exist yet in `6.12.y` to
  be absent rather than disabled.
- RT candidate floor: `v7.0.1` with `patch-7.0.1-rt2`
- RT blockers: newest stable `v7.0.5` has no matching RT patch yet; `v6.18.13-rt4` fails the CVE-2026-31431 gate because the repo does not carry a 6.18.13 backport

Do not merge `torvalds/linux:master` into an active lab release branch. For the
current lab line, source sync should target the selected maintained stable or
longterm base. Use `v6.19.14` only as a bounded compatibility proof because
kernel.org now marks the `6.19.y` line EOL.

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
# Discover current maintained candidates and optionally run bounded preflights:
./xr/scripts/triage-upstream-targets.sh
./xr/scripts/triage-upstream-targets.sh --run-preflight

# Bounded EOL proof only:
./xr/scripts/check-kernel-carry.sh --kernel-version 6.19.14
./xr/scripts/build-rpm.sh --kernel-version 6.19.14 --xr-release 1 --security-preflight-only

# Maintained candidate checks:
./xr/scripts/check-kernel-carry.sh --kernel-version 6.18.28
./xr/scripts/build-rpm.sh --kernel-version 6.18.28 --xr-release 1 --security-preflight-only
./xr/scripts/check-kernel-carry.sh --kernel-version 7.0.5
./xr/scripts/build-rpm.sh --kernel-version 7.0.5 --xr-release 1 --security-preflight-only
```

The `6.12.87` tarball contains the `CVE-2026-43284` ESP shared-frag hardening,
but the `rxkad.c` tree does not contain the reserved-`CVE-2026-43500` Dirty
Frag RxRPC linearize/COW hardening. Do not promote `6.12.87` as a linux-xr
fallback until a real RPM proof succeeds with the RxRPC security route and the
systemd/Rocky firmware-loader helper guard intact.

RT remains separate until a compatible RT patch is proven:

```bash
./xr/scripts/check-kernel-carry.sh --kernel-version 6.19.14 --rt-version 6.19.3-rt1
./xr/scripts/check-kernel-carry.sh --kernel-version 7.0.1 --rt-version 7.0.1-rt2
./xr/scripts/build-rpm.sh --kernel-version 7.0.1 --xr-release 1 --rt-version 7.0.1-rt2 --security-preflight-only
```

The `6.19.14` RT command is expected to fail with the current `6.19.3-rt1`
patchset. The `7.0.1-rt2` lane passed carry and security preflights on
2026-05-08, but it is behind latest stable `7.0.5`; treat it as an RT floor
candidate, not the generic SOTA target.

## Source-sync procedure

1. Start from a clean, case-sensitive checkout with kernel history available.
2. Fetch the selected stable or longterm target from the Linux stable tree.
3. Create a dedicated branch from the selected target, for example
   `codex/source-sync-v7.0.3` or `codex/source-sync-v6.18.26`.
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
