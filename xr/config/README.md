# `xr/config/base.config` — provenance and debug-flag classification

**Status: W1 working sheet (draft).** This is the pre-staged classification for
`TIN-4064`. It classifies; it does not change any flag. Encoding the verdicts into
`xr/specs/kernel-xr.spec` and adding `xr/scripts/check-production-config.sh` is W1's
implementation step and is deliberately not done here.

Dated 2026-08-27, derived at `xr/main` head `e31b29f` ("xr: stop shipping an XFS
test-harness kernel (#92)", 2026-08-23).

## What this file is

`base.config` is not a hand-authored Kconfig fragment. It is a scraped `.config`.
Line 3 says so verbatim:

```
# Linux/x86_64 6.19.5-1.el10.elrepo.x86_64 Kernel Configuration
```

The donor is an ELRepo `kernel-ml` build — not Rocky, and not an XR kernel. It has
been committed exactly once on the mainline (`ec426e5`, 2026-03-18, inside a
93,017-file initial import — a repo-wide import, not a config-specific one; an
unmerged commit `4952f88` from 2026-03-09, "feat: XR kernel build infrastructure,"
carries a byte-identical blob of the same file, so no content history is hidden, but
"exactly once" needs that qualifier). 11,630 lines deciding what boots on the one
RKE2 etcd voter that actually runs this kernel — `honey`. `bumble` and `sting` are
etcd voters too, but both boot stock `6.12.0-211.37.1.el10_2`, so the blast radius of
a bad flag here is one node's kernel, not the quorum's. Never reviewed in a diff.

`README.md:223-224` and `README.md:339` still instruct an operator to re-scrape it
from a running host. That instruction is what makes the problem self-perpetuating and
is scheduled for deletion in the same wave.

## How the numbers below were produced

Three configs, all read-only, all dated:

| Column | Source | Collected |
| --- | --- | --- |
| `base` | `xr/config/base.config` at `e31b29f` | in-repo |
| `xr12` | `honey:/boot/config-6.19.5-12.xr.el10` (built 2026-08-24, the first build after #92) | read-only `ssh`, 2026-08-27 |
| `rocky` | `sting:/boot/config-6.12.0-211.37.1.el10_2.x86_64` (Rocky 10.2 stock) | read-only `ssh`, 2026-08-27 |

Values are normalized to `y` / `m` / `n` / `-`, where **`n` means the config file
explicitly carries `# CONFIG_X is not set`** and **`-` means the symbol is absent from
that file entirely**. The distinction matters: against Rocky's 6.12 kernel, `-` is
usually cross-version noise (the symbol does not exist in the 6.12 Kconfig at all), not
a Rocky policy choice. Only an explicit `n` in the `rocky` column is evidence that
Rocky declined a symbol it could have shipped. Any classification that reads `-` as
"Rocky says no" is wrong.

Kconfig help text is quoted from upstream `v6.19` (`git show v6.19:<path>`), not
paraphrased.

Reproduction scripts and the three captured configs are kept beside this worktree in
`.w1-evidence/` (untracked; `classify.py`, `final.py`, `kunit.py`, `mutate-proof.py`,
`enumerate.py`).

The parser those scripts share is mutation-proven **on the value axis**
(`.w1-evidence/mutate-proof.py`, green 2026-08-27): against throwaway copies of
`base.config` it is shown to report a flipped-on symbol as `y`, a flipped-off symbol
as `n`, a newly introduced symbol as present, and — the distinction every "verified
absent" claim below rests on — to report a deleted symbol as absent rather than as
`n`. An oracle that has never been observed reporting a positive is not evidence of
absence.

That proof covers `y`/`n`/absent and nothing else — it says nothing about *name*
coverage. The line parser those same scripts share (`CONFIG_[A-Za-z0-9_]+=…`)
originally read `CONFIG_[A-Z0-9_]+=…`, silently dropping any symbol whose name
contains lowercase; no value-axis mutation test could have caught that, because the
bug is about which symbols the parser sees at all, not what value it reports for a
symbol it does see (see "Scale" below for the fallout and the fix). `mutate-proof.py`
now also carries a lowercase-name case (`CONFIG_FONT_8x16`) so the two axes are both
exercised, but "mutation-proven" in this doc should be read as "proven not to lie
about a value it reports," not "proven to see every symbol."

**Method note — one oracle is not enough.** The "hard findings" universe in the
tables below starts from a name regex (`classify.py`'s `PAT`: `DEBUG`, `KASAN`,
`ASSERT`, `KUNIT`, `WARN`, `_TEST`, and so on). That regex structurally cannot see
`CONFIG_VALIDATE_FS_PARSER`, `CONFIG_WQ_WATCHDOG`, or
`CONFIG_FUNCTION_ERROR_INJECTION` — none of those names contains a watched keyword.
The oracle that *did* catch those three — reading upstream Kconfig files directly for
debug/test-adjacent declarations — has the mirror-image blind spot: it misses
`CONFIG_XFS_DEBUG`, `CONFIG_XFS_ONLINE_SCRUB_STATS`, and `CONFIG_AFS_DEBUG_CURSOR`,
because those live in `fs/xfs/Kconfig` and `fs/afs/Kconfig`, not in the small set of
debug-labelled Kconfig files a Kconfig-file sweep naturally starts from. Neither
oracle alone supports a closure claim; the classification below is the **union** of
both, 10 symbols rather than 7. W1's own sweep has to run the union too — running
whichever single oracle is easiest to script and calling the result closed is exactly
the mistake this revision fixes.

## Scale — read this before believing any alarming summary

**Parser fix (2026-08-27):** the shared line-parser regex in
`.w1-evidence/{classify,final,mutate-proof,enumerate,kunit}.py` was
`CONFIG_[A-Z0-9_]+=…`, which silently drops any symbol whose name contains a
lowercase run. 29 such symbols exist in `base.config` (`CRYPTO_DEV_QAT_DH895xCC`,
`SND_SOC_PCM512x*`, `MT76x02_LIB`, `SENSORS_SHT3x`/`SHT4x`, `SCSI_DC395x`,
`LEDS_LM355x`, `FONT_8x8`/`FONT_8x16`, `I2C_MUX_PCA954x`, `DVB_STV090x`, …: 2 `=y`,
27 `=m`). None is debug-class, so this bug corrupted the scale table below, not any
verdict. Fixed to `CONFIG_[A-Za-z0-9_]+=…` in every copy and every script re-run; the
numbers below are post-fix.

| Measure | Count |
| --- | --- |
| `base.config` lines | 11,630 |
| symbols `=y` | 2,769 |
| symbols `=m` | 4,196 |
| debug/assert/test-class symbols present at any value | 511 |
| …of those, `=y` | 86 |
| …of those, `=m` | 113 |
| …of those, enabled in `base` and explicitly `n` in Rocky stock | **10 (union-of-oracles; see method note above)** |
| symbols differing between `base.config` and the shipped `xr12` kernel | 28 |

The parser fix moved exactly two numbers in this table (`=y` 2,767→2,769, `=m`
4,169→4,196) plus the base-vs-Rocky diff count quoted further down (3,768→3,778 — the
gap traces to the 29 dropped symbols, of which 10 actually differ base-vs-Rocky). It
did **not** move the debug-scoped counts: 511 / 86 / 113 present-at-any-value, the
72-symbol matches-Rocky-stock count, and the 28-symbol `xr12` delta all reproduce
exactly under the fixed regex, because none of the 29 dropped symbols is debug-class.
The 7→10 change on the row above is unrelated to the parser fix — it is the
oracle-completeness fix from the method note.

Read that row scoped, the same way its two siblings are: 10 is a count **within the
511-symbol debug-class universe**, not a fleet-wide number. Taken unscoped — any
symbol at all, not just debug-class, that is `=y`/`=m` in `base` and explicitly `n`
in Rocky — the true count is **1,329**, and 1,179 of those are ordinary `=m` drivers
Rocky simply doesn't build. Do not quote 1,329 as a debug-flag count, and do not
quote 10 as a fleet-wide diff count — they answer different questions.

**This is not a `kernel-debug` config.** It is a stock-ish config with a small family
of genuinely wrong production flags. A deliverable that implies otherwise is wrong.

The heavy machinery is verified off in `base.config`, `xr12`, and Rocky alike:
`KASAN`, `KCSAN`, `UBSAN`, `DEBUG_KMEMLEAK`, `PROVE_LOCKING`, `DEBUG_LOCK_ALLOC`,
`LOCK_STAT`, `DEBUG_ATOMIC_SLEEP`, `DEBUG_MUTEXES`, `DEBUG_SPINLOCK`, `DEBUG_RWSEMS`,
`DEBUG_OBJECTS`, `DEBUG_PAGEALLOC`, `DEBUG_VM`, `SLUB_DEBUG_ON`, `FAULT_INJECTION`,
`KCOV`, `GCOV_KERNEL`, `EXT4_DEBUG`, `BTRFS_DEBUG`, `BTRFS_ASSERT`,
`XFS_DEBUG_EXPENSIVE`, `XFS_WARN`, `DEBUG_STACK_USAGE`, `DEBUG_VIRTUAL`,
`DEBUG_PER_CPU_MAPS`, `DEBUG_SG`, `DEBUG_NOTIFIERS`, `DEBUG_KOBJECT`, `RCU_EQS_DEBUG`,
`LATENCYTOP`. `CONFIG_LOCKDEP` and `CONFIG_PROVE_RCU` are absent (they are selected
symbols with no selector enabled).

## Classification

Classes:

- **behavior-risk** — changes what the kernel *does*, not just what it logs. This is
  the `CONFIG_XFS_DEBUG` class.
- **perf-cost** — no behavioural change, measurable steady-state overhead.
- **harmless** — log-only, module-gated, or matching Rocky stock.

Verdicts are proposals for W1 to encode; `disable` means "add to the `%prep` override
block *with* a matching `check_config … n` line", `keep` means "leave it and say why
in a spec comment".

Three rows below — `CONFIG_WQ_WATCHDOG`, `CONFIG_FUNCTION_ERROR_INJECTION`, and
`CONFIG_VALIDATE_FS_PARSER` — did not come from the name-regex oracle above; they
came from reading upstream Kconfig files directly for debug/test-adjacent
declarations, per the method note. They are what brings the closed set in the Scale
table from 7 to 10.

### behavior-risk

| Symbol | base | xr12 | rocky | Verdict | Why |
| --- | --- | --- | --- | --- | --- |
| `CONFIG_XFS_DEBUG` (`base.config:10218`) | y | **n** | n | already done (#92) | The 2026-08-22 incident. Upstream `fs/xfs/Kconfig`: "the resulting code will be HUGE and SLOW". Already overridden in `%prep`; keep it in the new gate as regression insurance. |
| `CONFIG_XFS_ASSERT_FATAL` (`:10220`) | y | **absent** | absent | already done (#92) | `depends on XFS_FS && XFS_DEBUG`, so it *vanishes* rather than going `n` once `XFS_DEBUG` is off. Upstream: "Say Y here to cause DEBUG mode ASSERT failures to result in fatal errors that BUG() the kernel by default." |
| `CONFIG_KUNIT_FAULT_TEST` (`:11521`) | y | y | n | **disable** | Upstream: "Enables fault handling tests for the KUnit framework. These tests may trigger a kernel `BUG()`, and the associated stack trace, **even when they pass**." Upstream default is `!PANIC_ON_OOPS`; `base.config:11302` has `CONFIG_PANIC_ON_OOPS=y`, so `=y` here is an **explicit deviation from the upstream default**, not an inherited one. With `PANIC_ON_OOPS=y` and `PANIC_TIMEOUT=0`, that `BUG()` is a hang-forever panic on an etcd voter. Reachable only by loading `kunit-test` (`KUNIT_TEST=m`). |
| `CONFIG_KUNIT_DEFAULT_ENABLED` (`:11525`) | y | y | n | **disable** | Sets the default of `kunit.enable`. 90 `*KUNIT*` symbols are built `=m` in this config, against 60 in Rocky stock. With this `y`, any one of those modules that gets loaded runs its suites. Rocky explicitly ships `n` — the opt-in posture. |
| `CONFIG_KUNIT_AUTORUN_ENABLED` (`:11526`) | y | absent in 6.12 | — | **disable** | Same family: default of `kunit.autorun`, "tests will not run after initialization unless `kunit.autorun=1`". Upstream default `y`. Redundant once `DEFAULT_ENABLED=n`, but disabling both is the belt-and-braces posture and costs nothing. Rocky's `-` here is a 6.12-vs-6.19 artifact, not a Rocky ruling. |

### perf-cost

| Symbol | base | xr12 | rocky | Verdict | Why |
| --- | --- | --- | --- | --- | --- |
| `CONFIG_DEBUG_PREEMPT` (`:11332`) | y | y | **n** | **disable** | The heaviest live finding. Upstream `lib/Kconfig.debug:1349`: "the kernel will use a debug variant of the commonly used `smp_processor_id()` … will detect preemption count underflows. **This option has potential to introduce high runtime overhead, depending on workload as it triggers debugging routines for each `this_cpu` operation. It should only be used for debugging purposes.**" Fleet-wide, every CPU, every `this_cpu` op. Rocky ships an explicit `n`. |
| `CONFIG_XFS_ONLINE_SCRUB_STATS` (`:10216`) | y | y | **n** | disable (weak) | Upstream default is `y`; Rocky explicitly declines it. Cost is confined to `xfs_scrub` invocations — "may slow down scrub slightly due to the use of high precision timers and the need to merge per-invocation information into the filesystem counters." **Say this plainly: it is a match-stock tidy-up, not an incident-class flag.** No steady-state cost. |
| `CONFIG_WQ_WATCHDOG` (`:11320`) | y | y | **n** | **disable** | Found via the Kconfig-file oracle, not the name regex (see method note) — a second perf-cost/log finding beside `DEBUG_PREEMPT`. Upstream `lib/Kconfig.debug:1289`, `depends on DEBUG_KERNEL`: "Say Y here to enable stall detection on workqueues. If a worker pool doesn't make forward progress on a pending work item for over a given amount of time, 30s by default, a warning message is printed along with dump of workqueue state." **Live-confirmed active, not theoretical:** honey reports `/sys/module/workqueue/parameters/watchdog_thresh = 30`. Rocky explicitly declines it. |

### harmless — enabled here, `n` or absent in Rocky, and it does not matter

| Symbol | base | xr12 | rocky | Verdict | Why |
| --- | --- | --- | --- | --- | --- |
| `CONFIG_AFS_DEBUG_CURSOR` (`:10501`) | y | y | n | disable (free) | Log-only: "cause the contents of a server cursor to be dumped to the dmesg log if the server rotation algorithm fails to successfully contact a server." `AFS_FS=m`; there is no AFS in the fleet. Upstream says "If unsure, say N." Cheap to match stock. |
| `CONFIG_FUNCTION_ERROR_INJECTION` (`:11532`) | y | y | **n** | keep (or disable, free) | Found via the Kconfig-file oracle, not the name regex. Upstream `lib/Kconfig.debug:2022`, `depends on HAVE_FUNCTION_ERROR_INJECTION && KPROBES`: "Add fault injections into various functions that are annotated with `ALLOW_ERROR_INJECTION()` in the kernel. BPF may also modify the return value of these functions." It reads like it belongs to the `FAULT_INJECTION` family the heavy-machinery list already clears, but it is a distinct sibling symbol that Rocky actually declines and that is `=y` in the shipped kernel — by this sheet's own standard it belongs in the ledger. Mitigating: both of its triggers are off in `base.config` — `CONFIG_FAULT_INJECTION=n` (no `FAIL_FUNCTION`) and `CONFIG_BPF_KPROBE_OVERRIDE=n` (no `bpf_override_return`) — so the annotations are compiled in but unreachable. Free to disable to match Rocky; equally defensible to keep and say why, same as the driver rows below. |
| `CONFIG_VALIDATE_FS_PARSER` (`:10190`) | y | y | **n** | disable (free) | Found via the Kconfig-file oracle, not the name regex. Upstream `fs/Kconfig:12`: "Enable this to perform validation of the parameter description for a filesystem when it is registered." A one-time, boot-path sanity check on each filesystem's own static parameter table — it catches bugs in a filesystem's parameter declarations, not anything a workload can trigger, and upstream describes no runtime cost. Rocky ships it off. Costs nothing to match stock. |
| `CONFIG_TEST_LIST_SORT` | m | m | n | keep | A test module. Inert unless someone `modprobe`s it. |
| `CONFIG_SCSI_MVSAS_DEBUG` | y | y | — | **keep** | Upstream `default y`, log-only: "prints some messages to the console." Rocky's `-` is **not** a policy choice — Rocky sets the parent `CONFIG_SCSI_MVSAS=n`, so the sub-option never appears. |
| `CONFIG_AIC94XX_DEBUG` | y | y | — | **keep** | Same shape: `default y`, log-only, parent `CONFIG_SCSI_AIC94XX=n` in Rocky. |
| `CONFIG_AIC7XXX_DEBUG_ENABLE`, `CONFIG_AIC79XX_DEBUG_ENABLE` | y | y | — | **keep** | Same shape; parents `SCSI_AIC7XXX`/`SCSI_AIC79XX` are `n` in Rocky. |
| `CONFIG_MLX4_DEBUG` | y | y | — | **keep** | Upstream `default y`: "causes debugging code to be compiled into the `mlx4_core` driver. The output can be turned on via the `debug_level` module parameter" — off at runtime by default. Immediate parent is `CONFIG_MLX4_CORE` (`depends on MLX4_CORE`), not `MLX4_EN`. `MLX4_CORE` has no prompt of its own — it is only ever turned on via `select MLX4_CORE` from `MLX4_EN` — and is absent from Rocky's config because `MLX4_EN=n` there, so nothing ever selects it. |
| `CONFIG_INFINIBAND_MTHCA_DEBUG` | y | y | — | **keep** | Same shape; parent `INFINIBAND_MTHCA=n` in Rocky. |

None of that hardware (Marvell 88SE64XX/94XX SAS, Adaptec `aic7xxx`/`aic79xx`/`aic94xx`
SAS, Mellanox mlx4 / MTHCA InfiniBand) exists on `honey`, `bumble`, or `sting`. All six
modules are `=m` and never loaded. Touching them buys nothing and risks nothing; the
honest verdict is `keep`.

### harmless — matches Rocky stock, therefore not a finding at all

72 debug-class symbols are `=y` in **both** `base.config` and Rocky stock. Named
explicitly because the first-pass brief flagged several of them:

`DM_DEBUG`, `NFS_DEBUG`, `SUNRPC_DEBUG`, `CIFS_DEBUG`, `AFS_DEBUG`,
`INFINIBAND_IPOIB_DEBUG`, `PAGE_POISONING`, `PAGE_OWNER`, `DEBUG_SHIRQ`, `DEBUG_LIST`,
`DEBUG_WX`, `DEBUG_MISC`, `DEBUG_FS`, `DEBUG_FS_ALLOW_ALL`, `SLUB_DEBUG`, `SCHEDSTATS`,
`SCHED_INFO`, `SCHED_STACK_END_CHECK`, `BUG_ON_DATA_CORRUPTION`,
`DEBUG_SECTION_MISMATCH`, `DEBUG_KERNEL`, `DEBUG_BUGVERBOSE`, `DYNAMIC_DEBUG`,
`PROFILING`, `STACKTRACE`, `ATOMIC64_SELFTEST`, `X86_DECODER_SELFTEST`, `KGDB_TESTS`,
`UAPI_HEADER_TEST`, `TEST_KSTRTOX`, `PM_DEBUG`, `PM_SLEEP_DEBUG`, `LD_ORPHAN_WARN`,
plus the `ARCH_HAS_*` / `HAVE_*` capability flags, which are compiler/arch facts and
not policy at all.

`CONFIG_RCU_TORTURE_TEST` and `CONFIG_TORTURE_TEST` are `=m` in all three configs —
modules only, harmless unless loaded. Listed so the ledger is complete.

The escalated variants of the log-only family are already off everywhere:
`CIFS_DEBUG2`, `CIFS_DEBUG_DUMP_KEYS`, `INFINIBAND_IPOIB_DEBUG_DATA`,
`DM_DEBUG_BLOCK_MANAGER_LOCKING`, `DM_KUNIT_TEST`.

> **Correction to the first-pass brief:** `CONFIG_DM_DEBUG` is `=y` in Rocky stock too.
> It is log-only ("Enable this for messages that may help debug device-mapper
> problems"), and the expensive device-mapper debug options are `n` in all three
> configs. It was not a contributor to the 2026-08-22 shutdown and it is not a finding.

## Findings the first pass did not have

These came out of the three-way diff and belong in W1's ledger even though none is a
debug flag to disable.

1. **`CONFIG_DEBUG_INFO_COMPRESSED_ZSTD` — the spec's own dead override.**
   `kernel-xr.spec` enables `CONFIG_DEBUG_INFO_COMPRESSED_ZSTD` and disables
   `CONFIG_DEBUG_INFO_COMPRESSED_NONE`. The symbol **does not exist in any of the three
   configs** — the build toolchain has no zstd debug-info support, so `olddefconfig`
   drops it and `COMPRESSED_NONE` stays `y`. The shipped `xr12` kernel, built
   2026-08-24, has `CONFIG_DEBUG_INFO_COMPRESSED_NONE=y`. No `check_config` line guards
   it. The override has been in the spec since the 2026-03-18 initial import: **five
   months of a silently-lost override.** This is the strongest live evidence for W1's
   thesis — *an override without a matching assertion is not a gate.* It also bears on
   the W4 / `TIN-4067` module-size lane.

2. **`CONFIG_GCC_PLUGINS` silently vanishes in the real build.** `base.config:1017` has
   `CONFIG_GCC_PLUGINS=y`, but the symbol is **absent** from the shipped `xr12` config,
   together with its dependents `RANDSTRUCT_FULL`, `RANDSTRUCT_PERFORMANCE`,
   `KSTACK_ERASE`, and `GCC_PLUGIN_LATENT_ENTROPY`. The XR build toolchain lacks the
   GCC plugin headers. **Tempered:** all four of those dependents —
   `RANDSTRUCT_FULL`, `RANDSTRUCT_PERFORMANCE`, `KSTACK_ERASE`, and
   `GCC_PLUGIN_LATENT_ENTROPY` — were already `n` in `base.config` before the build
   ever touched them, so no hardening was actually lost when they vanished. The finding is
   narrower than "a hardening capability the config claims is not in the kernel" —
   it is that the config asserts a toolchain feature (`GCC_PLUGINS=y`) the build
   doesn't have, and nothing asserts the mismatch. The config-vs-kernel truth gap is
   the finding, not a lost control.

3. **`CONFIG_KFENCE` — XR is weaker than stock.** `base.config:11293` has
   `# CONFIG_KFENCE is not set`; Rocky stock ships `CONFIG_KFENCE=y` with
   `KFENCE_SAMPLE_INTERVAL=100` and `KFENCE_NUM_OBJECTS=255`. KFENCE is a low-overhead
   *production* memory-safety detector, which is why RHEL enables it. This is an
   inverse finding — a hardening regression against stock, not a debug-flag hazard. It
   needs an operator ruling, **not** a sweep, and should not be flipped inside W1.

## The `base.config` → shipped-kernel delta

Only **28 symbols** differ between `base.config` and honey's shipped `xr12` config. The
~50 `scripts/config` calls in `%prep` collapse to exactly this, which independently
confirms the first-pass claim:

- DWARF5 swap (`DEBUG_INFO_DWARF5` off→on, `DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT` on→off)
- `DELL_RBU`, the `LEDS_LP55xx` family, `ITCO_WDT`, `FW_LOADER_USER_HELPER` off
- `LOCALVERSION` set to `-12.xr.el10`
- `m`→`y` on `OVERLAY_FS`, `UIO`, `UIO_PCI_GENERIC`
- the #92 XFS trio (`XFS_DEBUG` → `n`, `XFS_ASSERT_FATAL` / `XFS_DEBUG_EXPENSIVE` gone,
  `XFS_WARN` appearing as `n`)
- toolchain-version strings (`CC_VERSION_TEXT`, `PAHOLE_VERSION`) and the toolchain
  casualties from finding 2 above

Everything else in `base.config` — including `HZ_1000`, `CPU_ISOLATION`, `NO_HZ_FULL`,
`RCU_NOCB_CPU`, `HWLAT_TRACER`, `DRM_AMD_DC_DSC`, `DEBUG_INFO_BTF` — already had the
value the spec asks for. Those overrides are no-ops that happen to be true.

`base.config` vs Rocky 6.12 stock differs in 3,778 symbols (corrected from an earlier
3,768 after fixing the parser's lowercase-name blind spot — see the Scale section).
That number is a 6.19-vs-6.12 version gap, not a policy gap, and must not be quoted
as one.

## Verification: the three #92 defense layers still hold at `xr/main` head

Checked at `e31b29f` on 2026-08-27.

| Layer | Location | Status |
| --- | --- | --- |
| 1 — post-scrape override | `xr/specs/kernel-xr.spec:217-219` (`scripts/config --disable` on `XFS_DEBUG`, `XFS_DEBUG_EXPENSIVE`, `XFS_ASSERT_FATAL`, after `cp %{SOURCE1} .config` at `:153`) | present |
| 2 — post-`olddefconfig` re-apply | `xr/specs/kernel-xr.spec:285-287`, followed by a second `make olddefconfig` at `:290` | present |
| 3 — hard `check_config … n` | `xr/specs/kernel-xr.spec:330-332`, with the absent-tolerance rationale documented at `:326-329`; build aborts via the `fail` flag at `:339-344` | present |

The `check_config` helper (`:295-317`) has an `n` branch that accepts `is not set`, `=n`, **and**
`MISSING` — so a symbol that vanishes along with its parent passes rather than tripping
a false failure. That is what makes the `XFS_ASSERT_FATAL` assertion correct.

**Independent live proof, not just a code read:** honey's shipped
`/boot/config-6.19.5-12.xr.el10` (built 2026-08-24, the day after #92 merged) carries
`# CONFIG_XFS_DEBUG is not set`, and `CONFIG_XFS_ASSERT_FATAL` is absent from the file.
On honey today, `/sys/fs/xfs/debug` does not exist — the live oracle the spec comment
names. All three layers hold, and the fix is in the running kernel on the voter that
took the incident.

## Design note W1 must resolve before writing the gate

`check-security-config.sh` is wired into `flake.nix` `checks` at `:108-114` and runs
against **`xr/config/base.config`** (`flake.nix:112`). A `check-production-config.sh`
copied "exactly like security-config" and asserting `CONFIG_XFS_DEBUG n` would be
**red on its first run**, because `base.config:10218` still says `=y` *by design* — #92
fixed the flag in `%prep`, not in the scraped config.

There are only two coherent resolutions, and W1's brief names neither:

- **(a)** the new check asserts against the post-`%prep`, post-`olddefconfig` `.config`
  inside the build, and the PR-time `flake` check asserts only the symbols that must be
  right *in `base.config` itself* (the sanitizer/lockdep regression-insurance family,
  which is genuinely `n` there today); or
- **(b)** `base.config` is finally corrected for the disable-verdict symbols, the
  `%prep` overrides become belt-and-braces, and the PR-time check can assert the full
  list against `base.config` directly.

(b) is the honest end state and it is cheap, but it partly overlaps the
`merge_config.sh` regeneration that is deferred behind the W2 base decision
(`TIN-4065`). Pick one deliberately; do not let a copied `flake.nix` stanza pick for
you.

Two mechanical constraints for whichever path is chosen:

- Use `expect_disabled_or_absent` (already defined at
  `xr/scripts/check-security-config.sh:76-89`), **not** `expect_value … n`, for every
  disabled symbol — not only the vanish-prone ones. A `.config` never writes
  `CONFIG_X=n`; a disabled symbol is always the comment line
  `# CONFIG_X is not set`. That means `expect_value KEY n` produces a false failure
  against *every* disabled symbol, demonstrated directly against honey's
  correctly-built `xr12` config: `FAIL: CONFIG_XFS_DEBUG expected n, got # CONFIG_XFS_DEBUG
  is not set`. It is doubly wrong for symbols that can also vanish along with their
  parent — `XFS_ASSERT_FATAL`, `XFS_DEBUG_EXPENSIVE`, `KUNIT_FAULT_TEST` (depends on
  `KUNIT_TEST`), `KUNIT_AUTORUN_ENABLED` (absent before 6.19) — but the underlying
  mechanical constraint is broader than that subset: it applies to every disabled
  symbol in the file.
- `check-security-config.sh` has **zero** debug-flag coverage today — `grep -E
  'DEBUG|KUNIT|XFS'` over it returns nothing. The new script is a genuine sibling with
  a disjoint key list, not an extension.

## Deferred, deliberately

- Regenerating `base.config` from a declared Rocky-stock parent plus an `xr.fragment`
  via `merge_config.sh`. Right end state; deferred behind the W2 base decision
  (`TIN-4065`) because regenerating against a base the fleet is about to leave is
  wasted work.
- The module-size problem (`%global debug_package %{nil}` at `kernel-xr.spec:14`
  disabling `__debug_install_post`, so `find-debuginfo` never runs). W4 / `TIN-4067`.
- Enabling `CONFIG_KFENCE` to match stock. Needs an operator ruling.
- `CONFIG_XFS_WARN`. #92 ruled it off deliberately; not reopened here.
- `CONFIG_HZ`, `NO_HZ_FULL`, `CPU_ISOLATION`, `RCU_NOCB_CPU` — deliberate XR choices,
  and all enabled in stock RHEL 10 anyway. Out of scope.
