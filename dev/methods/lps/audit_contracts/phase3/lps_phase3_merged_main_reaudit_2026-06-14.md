You are the independent auditor for the LPS Tiers 1–4 program in the `geosmooth` R package. Your
standing role, rules, deliverable shape, and do-not list are in
`/Users/pgajer/current_projects/geosmooth/project_briefs/lps_e19_auditor_prompt_2026-06-11.md`
(everything above its "FIRST ASSIGNMENT" heading) — read it first; it applies unchanged. The
integration plan that frames this pass is
`/Users/pgajer/current_projects/geosmooth/project_briefs/lps_integration_plan_2026-06-12.md` (§ Phase 3).

This is the **Phase 3 merged-`main` re-audit — Pass 1 (post-t2)**. The merged `fit.lps` is a new
artifact **no single audit saw**: t2's binary/ridge edits now live on `main`, reconciled against the
dgp + t4 merges. Pass 1 audits the **t2-into-main** merge. Pass 2 re-fires after e19's reconciliation
merge lands (bottom note). Out of scope here: e19's E1.9/E1.10 (not yet on `main`), the e19↔t2 signature
reconciliation, and re-litigating any already-accepted t2 gate in isolation — judge them **as merged**.

## Verified tree state (do not take on trust — re-confirm the SHAs)

| ref | SHA | what it is |
|---|---|---|
| base | `b86b796` | common fork point of all four worktrees |
| pre-t2 `main` | `41dc962` | base + **dgp** + **t4** (E4.1); `R/lps.R` still the base |
| **merged `main`** | `678565c` | `41dc962` + **t2** merge (`codex/geosmooth-t2-binary-hygiene`) |

The t2 merge brought E2.12 (`5065a18`/`550d7e8`), E2.14 step-halving (`75c1788`), E2.13 aligned ridge
(`b79d041`), E2.15 binomial NA-consistency (`fe57126`), the amended E0.6 (`5fb3a1c`), and the E0.6
fallback-bound (`83218b6`). `R/lps.R` changed **+301/−37** base→merged. The `main` branch is **not
checked out live** (the main repo HEAD sits on `codex/geosmooth-tier0-bucket2-isolated`).

## Why this fires now

A full-suite run on `678565c` is green on every audited gate **except 4 failing assertions in
`tests/testthat/test-ge7-lps-api.R`** (lines 322, 323, 325, 682). That test file is **byte-identical to
base** (`git diff b86b796 678565c -- tests/testthat/test-ge7-lps-api.R` is empty) — so these are **not**
random pre-existing failures and **not** edits by t2. They are t2's *accepted behavior changes* hitting
an *old, un-updated test*. Pass 1's headline job is to **triage those 4** and confirm the merge dropped
no t2 behavior. (The console wall of `edge.kk`/`layout.weighted` lines is `graph-trend-filtering`
deprecation noise — out of scope.)

## Materialize the merged tip and run in place

`main` isn't checked out anywhere, so you must materialize `678565c` — this is **not** an isolation
worktree, just the only way to reach the merged tip. A throwaway worktree is cleanest:

```sh
cd ~/current_projects/geosmooth
git worktree add /tmp/gm-phase3 678565c && cd /tmp/gm-phase3
git rev-parse HEAD            # MUST print 678565c… — RECORD it; this is the SHA you certify
git status --short            # MUST be empty
```

Mutate `R/lps.R` transiently and `git checkout -- R/lps.R` after each mutation; **never commit**; remove
the worktree when done (`cd ~/current_projects/geosmooth && git worktree remove /tmp/gm-phase3`).

## §1 — Battery green on the merged tip (the merge-acceptance baseline)

Run on `678565c` and confirm green (full-size where the gate has a full-size mode — set `LPS_TIER0_FULL=1`
for Tier-0):

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); library(testthat);
  for (f in c("test-lps-binary-metric-consistency","test-lps-binary-separation",
              "test-lps-binomial-na-consistency","test-lps-ridge-alignment",
              "test-lps-tier0-correctness","test-lps-tier0-correctness-extended",
              "test-dgp-library"))
    test_file(file.path("tests/testthat", paste0(f, ".R")), reporter="summary")'
```

These cover E2.12 / E2.14 / E2.15 / E2.13 / Tier-0 E0.1–E0.8 (incl. amended E0.6 + fallback-bound, in
`-extended`) / dgp-library. A green battery on `678565c` is the baseline that says the merge preserved
every audited behavior. (E1.9a/b + E1.10 gates are **not** on this tip — they arrive in Pass 2.)

## §2 — The `test-ge7-lps-api.R` triage (the core)

**Method.** Run `test-ge7-lps-api.R` at **`41dc962`** (pre-t2) and at **`678565c`** (post-t2); diff
per-assertion. For each of the 4, bind it to the t2 commit that changed the behavior and to the **gate
that now validates the new behavior**, then classify it as exactly one of:

- **STALE-TEST (benign)** — old assertion encodes pre-t2 behavior; an accepted gate validates the new
  behavior → propose the test edit (do not apply it; see §5).
- **REGRESSION** — t2 changed behavior that no gate covers and that is wrong → reject, route to the t2
  implementer.
- **UN-PINNED CHANGE** — change is on a path the §A2 bit-for-bit pin *claimed* covered but its reference
  set does not actually include → extend the reference (§3), then decide STALE vs REGRESSION on merits.

**2a. Lines 322 / 323 / 325 — binomial NA-failure telemetry.** Input is an **all-ones, rank-deficient**
`3×5` design with `unstable.action = "na"`. Pre-t2: `is.na(failed)` TRUE, `fallback.path.count == 1`,
`na.failure.count == 1`. Post-t2 (E2.14 step-halving `75c1788` + E2.15 `fe57126`): not-NA, both counts
`0` (line 324, `event.rate.fallback.count == 0`, still passes). Likely the new solver drops the dependent
columns and converges to the event-rate intercept rather than NA-failing. Decide: **(i)** is converging
on this degenerate-but-consistent design correct? **(ii)** more important — is the NA-failure telemetry
path **still reachable and still exercised somewhere** post-merge? E2.15's na-consistency contract needs
a test that actually drives `na.failure`; if this input no longer does, that coverage must move, not
vanish. Classify + propose the fix.

**2b. Line 682 — ill-conditioned WLS fallback (the one to actually investigate).** Near-saturated `35×k`
design (last column ≈ second-to-last + `1e-8` noise), **default** args. Pre-t2: the inner
`.klp.solve.local.wls` fails → `.klp.fit.intercept.design` returns `weighted.mean(y, weights)` ≈ **0.459**.
Post-t2 (E2.13 weighted-centering reparametrization, `b79d041` — the `ybar.w`/`xw.centered`/`yw.centered`
add-back): the solve **succeeds** → returns ≈ **0.512**. The guard `.klp.local.design.is.safe(...)` on
line ~681 **still returns FALSE** (it passes), so the design is *still classified unsafe* yet the fitter
now produces a "successful" reparametrized result. Two questions, both required:

  1. **§A2 coverage** — this is the **default** path (no `ridge.shrinkage.target` set ⇒ `"zero"`), which
     E2.13 §A2 pinned bit-for-bit. Did the pin's reference actually cover an ill-conditioned design? (See
     §3 — its commit says "default-configuration … fits," i.e. well-conditioned.) If not, the pin passing
     does **not** certify 682; treat as **UN-PINNED CHANGE**.
  2. **safe/unsafe contract** — should a design flagged `is.safe = FALSE` proceed to a reparametrized
     "successful" fit, or should `.klp.fit.intercept.design` honor the guard and fall back to the weighted
     mean (the conservative pre-t2 behavior)? Recommend: update the test to the new behavior, **or** treat
     the bypassed guard as a regression and gate the new solve on `is.safe`.

## §3 — §A2 pin coverage audit (generalize 2b)

Inspect the reference pin: `reports/e2_13_reference_fits.csv` (309 lines = 308 fits + header) and its
generator `validation/e2_13_pin_reference_fits.R`, pinned at `c796408` from a pre-E2.13 `R/lps.R`. Its
own commit message scopes it to **"default-configuration gaussian and bernoulli fits"** — i.e.
well-conditioned. Confirm by reading the generator whether **any** ill-conditioned / unsafe-design /
fallback input is represented. A reference that omits the fallback paths can be **bit-for-bit AND still
miss 682**. Report the coverage and the gap, and state whether the reference should be extended (and with
which inputs) before the §A2 bit-for-bit claim can be said to cover the default fallback path.

## §4 — Mutation qualification on merged `main` (no behavior silently dropped by the merge)

For each row: run the named gate clean (expect green), mutate `R/lps.R` in the worktree, re-run, confirm
the named reddening, then `git checkout -- R/lps.R`.

| Target | Mutation | Must happen |
|---|---|---|
| E2.13 ridge alignment | revert the weighted-centering add-back (drop the `+ ybar.w` / use raw `y`) | `test-lps-ridge-alignment.R` reddens |
| E2.14 separation | disable IRLS step-halving (force a single full step) | `test-lps-binary-separation.R` reddens |
| E2.12 metric | revert the deployed clipped selection metric (un-clip / wrong backend) | `test-lps-binary-metric-consistency.R` reddens |
| E2.15 NA-consistency | drop the binomial `na → mean` selection arm | `test-lps-binomial-na-consistency.R` reddens |
| E0.6 fallback-bound | force the logistic fitter to all-fallback (`return(fallback("forced"))`) | E0.6 in `test-lps-tier0-correctness-extended.R` reddens |

A surviving (green) gate under its mutation means the merge dropped that behavior — a blocking finding.

## §5 — Do-not / boundaries

Do **not** commit anything. Do **not** edit `tests/testthat/test-ge7-lps-api.R` in place — it is a
tracked test the orchestrator will adjudicate; **propose the exact diff** in your verdict instead. Do not
pull in e19 or touch the reconciliation. Restore `R/lps.R` after every mutation and remove the throwaway
worktree.

## Deliver

`audits/phase3_merged_main_reaudit_<your-run-date>.md`, per the standing Deliverable shape, containing:

1. the certified SHA (`678565c`) and clean-tree confirmation;
2. the §1 battery result (per-gate pass/fail, full-size where applicable);
3. the **ge7 triage table** — 4 rows, each with: assertion (line), pre-t2 value, post-t2 value, bound t2
   commit, covering gate, **classification** (STALE / REGRESSION / UN-PINNED), and proposed fix;
4. the §3 §A2-coverage finding (does the reference include ill-conditioned designs? extend?);
5. the §4 mutation table;
6. an overall verdict: **ACCEPT MERGE** (with test-maintenance follow-ups), **ACCEPT WITH REQUIRED FIX**
   (e.g. 682 ruled a regression / guard-bypass), or **REJECT**.

Leave it untracked for the orchestrator.

## After this accepts — Pass 2

Phase 3 **re-fires** once e19's reconciliation merge lands (integration plan §2b): that adds E1.9a/E1.9b +
E1.10 gates and the unioned `fit.lps` signature (`bandwidth.multiplier.grid` ∪ `ridge.shrinkage.target` +
the E2 args). Pass 2 = this same battery **plus** E1.9/E1.10 **plus** a signature-union check that every
argument still defaults bit-for-bit (§A2) and the CV grid spans both axes without double-counting.
