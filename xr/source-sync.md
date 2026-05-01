# linux-xr source-sync runbook

This runbook is for syncing the checked-out kernel source tree to a selected
upstream stable target. It is separate from the RPM proof-build path.

## Current target

As of 2026-05-01:

- Current lab release line: `v6.19.5-xr9`
- Next generic proof target: `v6.19.14`
- Stable branch tip checked externally: `linux-6.19.y` at `v6.19.14`
- RT blocker: `patch-6.19.3-rt1` does not apply to `v6.19.14`

Do not merge `torvalds/linux:master` into an active lab release branch. For the
current lab line, source sync should target `linux-6.19.y` / `v6.19.14`.

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
./xr/scripts/check-kernel-carry.sh --kernel-version 6.19.14
./xr/scripts/build-rpm.sh --kernel-version 6.19.14 --xr-release 1 --security-preflight-only
```

RT remains separate until a compatible RT patch is proven:

```bash
./xr/scripts/check-kernel-carry.sh --kernel-version 6.19.14 --rt-version 6.19.3-rt1
```

That RT command is expected to fail with the current RT patchset.

## Source-sync procedure

1. Start from a clean, case-sensitive checkout with kernel history available.
2. Fetch the stable target from the Linux stable tree.
3. Create a dedicated branch from `v6.19.14`, for example
   `codex/source-sync-v6.19.14`.
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
