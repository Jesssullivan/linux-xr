# Weekly upstream-watch cadence — dark-stack triage (2026-07-08)

Anchor: **TIN-2318** (revive the weekly upstream-watch cadence).
Provenance: `[cordillera-2026-07-08]`.

## Why this exists

The weekly cadence workflow (`.github/workflows/weekly-cadence.yml`) kept firing
on schedule, but its generated watch issues went unactioned and stacked, and the
workflow was watching the **now-EOL `linux-7.0.y`** stable line. This lane does
two things:

1. **Retargets the mechanism** — the fetch line and `--stable-ref` move from
   `linux-7.0.y` to the live `linux-7.1.y` stable line (the `6.18.y` longterm
   ref is unchanged). This is the operational tail of the 7.0.y -> 7.1.y re-home
   (D3 amendment, operator ruling 2026-07-06, `linux-xr` #82, `rockies` #249,
   TIN-2317). The `7.0.y` line is EOL at `v7.0.14`; `7.1.y` head is `v7.1.3`
   (re-verified live against kernel.org releases.json, 2026-07-08 — no `v7.1.4`).
2. **Triages the dark stack** — disposition every open weekly-watch issue below.

## Recount (authoritative, REST — not the search index)

The `TIN-2318` description cited `#44, #74–#80` (8) and the operator cited ~9;
the F72 lane brief cited 9 (`#44, #74–#81`). Live REST truth on 2026-07-08 is
**11 open** weekly-watch auto-issues — the GitHub *search* index under-reports
(it omits `#74`/`#75`), so this triage uses `gh issue view`/`list` (REST), not
search:

| Issue | Week (Mon) | Disposition |
| ----- | ---------- | ----------- |
| #33 | 2026-04-27 | Superseded — close (folded into 7.1.y re-home) |
| #44 | 2026-05-04 | Superseded — close |
| #72 | 2026-05-11 | Superseded — close |
| #74 | 2026-05-18 | Superseded — close |
| #75 | 2026-05-25 | Superseded — close |
| #76 | 2026-06-01 | Superseded — close |
| #77 | 2026-06-08 | Superseded — close |
| #78 | 2026-06-15 | Superseded — close |
| #79 | 2026-06-22 | Superseded — close |
| #80 | 2026-06-29 | Superseded — close |
| #81 | 2026-07-06 | **Keep open** — current-period anchor; generated against the old 7.0.y target, will be superseded by the first retargeted 7.1.y weekly issue |

## Disposition rationale (why "superseded" is safe)

Every issue #33–#80 is a weekly diff against the maintained stable/longterm
lines. The single consolidating action that absorbs all of that stable-line
churn is the base re-home itself:

- **Security churn is covered at the new base.** All three tracked Dirty-Frag
  CVEs (CVE-2026-31431, CVE-2026-43284, CVE-2026-43500) are fixed **natively**
  at `v7.1.3`, so none of the `xr/security/*` backports apply on this base
  (`xr/source-sync.md`; proven by the `--security-preflight-only` gate — see the
  Base Anchor CI). The security-patch files are retained for the longterm
  fallbacks (`6.18.y`/`6.12.y`), which stay below the fixed floors.
- **Carry churn is covered.** All three carries
  (`0007-vesa-dsc-bpp.patch`, `bigscreen-beyond-edid.patch`,
  `amdgpu-dsc-pps-debugfs.patch`) dry-run zero-fuzz against `v7.1.3` (tarball
  path) and are re-proven zero-fuzz against the real git tree by the Base Anchor
  workflow (`git apply --check`).
- No open watch issue carries an un-actioned, base-independent finding that the
  re-home does not already consolidate.

Each closed issue gets a one-line, sanitized disposition comment pointing at the
re-home (`#82`) + the cadence retarget PR + `TIN-2318`. Cadence detail stays on
internal surfaces per TIN-223; the public tracker keeps only the terse pointer.

## Go-forward cadence

- The retarget takes effect only once this PR merges to `xr/main` (the schedule
  runs from the default branch). Until merge, the Monday cadence still emits a
  `7.0.y`-targeted issue; the first correct `7.1.y` watch issue lands on the next
  Monday cadence after merge (`0 13 * * 1`).
- Sustainable habit: each new weekly watch issue gets a dated disposition within
  one cadence period (triaged or closed-with-note), so the stack never goes dark
  again. Agent-drafted summaries are acceptable; carry/CVE/host decisions stay
  operator-gated.

## Scope guards honored

- **RT is parked** — no proven `7.1.x` PREEMPT_RT patchset exists; RT stays
  pinned at `v7.0.1-rt2` per `xr/source-sync.md`. Not revived here.
- **No host mutation** — any deploy of the re-homed base is a D13 operator-window
  packet with a fresh preflight capture; `honey` default stays GENERIC (D5) and
  `rke2` is never touched. Per operator ruling R2 (2026-07-08), **STING** — not
  `honey` — is the XR-candidate/boot-validation host; first boot-validation of a
  candidate kernel happens on `sting`.
- **No upstream sends** (D14); the Bigscreen Beyond EDID lane is DECIDED HOLD
  (D15).
