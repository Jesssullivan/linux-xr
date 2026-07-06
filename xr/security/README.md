# linux-xr security backports

This directory is for release-blocking security fixes that are not part of the
normal XR carry in `xr/patches/series`.

`xr/scripts/build-rpm.sh` decides when a security backport is required and
passes the matching RPM spec macro. Do not add files here as general kernel
feature carry; use `xr/patches/` for that path.

| Patch | Source | Build behavior |
| --- | --- | --- |
| `cve-2026-31431-algif-aead.patch` | Linux stable `6.19.y` commit `ce42ee423e58`, backporting mainline `a664bf3d603d` | Applied automatically for vulnerable `6.19.x` bases before RT and XR carry patches |
| `dirtyfrag-esp-shared-frag.patch` | `CVE-2026-43284` Dirty Frag ESP mitigation from netdev/net commit `f4c50a4034e6` | Applied automatically for supported vulnerable `6.18.x`, `6.19.x`, and pre-`7.0.5` `7.0.x` bases before RT and XR carry patches; fixed maintained bases such as `6.12.89`, `6.18.31`, `7.0.8`, and all `7.1.y` (fixed natively at the 7.1 branch cut per NVD) do not need this backport |
| `dirtyfrag-rxrpc-linearize.patch` | `CVE-2026-43500` linux-xr RXKAD backport adapted from the public Dirty Frag RxRPC patch route; NVD records fixed floors at `6.18.29+`, `7.0.6+`, and `7.1+` (fixed at the 7.1 branch cut) | Applied automatically for supported vulnerable `6.12.x`, `6.19.x`, pre-`6.18.29` `6.18.x`, and pre-`7.0.6` `7.0.x` bases before RT and XR carry patches; `7.1.y+` bases need no backport |
| `dirtyfrag-rxrpc-rxgk-linearize.patch` | `CVE-2026-43500` linux-xr RXGK backport for DATA/RESPONSE in-place decrypt paths; published `v6.19.5-xr11` is the first release with RXKAD plus RXGK coverage on the EOL `6.19.5` lab base | Applied automatically with the RXKAD backport for supported vulnerable `6.18.x`, `6.19.x`, and `7.0.x` bases that carry RXGK and are below a fixed floor |

Other affected kernel lines remain guarded by `xr/scripts/build-rpm.sh`, but do
not have repo-managed backports here. Use a fixed upstream floor, vendor-fixed
kernel, or explicit validation override for those bases.

On the `v7.1.3` re-home base (D3 amendment, `TIN-2317`) all three tracked CVEs
(`CVE-2026-31431`, `CVE-2026-43284`, `CVE-2026-43500`) are fixed natively, so
`build-rpm.sh --kernel-version 7.1.3 --security-preflight-only` applies none of
these backports. The patch files are retained because the `6.18.31`/`6.12.89`
longterm fallback bases still sit below their fixed floors.
