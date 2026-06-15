# Phase 2b reconciliation implementer handoff — the one R/lps.R merge

Date: 2026-06-14
Author: implementer agent (e19)
Work order: `project_briefs/lps_e19_reconciliation_workorder_2026-06-14.md` (Phase 2b)
Refs: integration plan §2b; Phase-3 Pass-1 audit `audits/phase3_merged_main_reaudit_2026-06-14.md`
Branch/worktree: `codex/geosmooth-e1-9-bandwidth-multiplier` / `geosmooth-e19`

## Certified result (for the Pass-2 auditor)

- **Resolved `main` tip SHA: `fee9485`** (fast-forwarded local-only; **not pushed**).
  `main` was at `ffa840a` (an ancestor of `fee9485`), so this is a true fast-forward.
- Merge commit: `4d458c5` (`Merge branch 'main' into codex/geosmooth-e1-9-bandwidth-multiplier`).
- GE7 fix commit: `fee9485`.
- The branch tip carries this handoff + reconciliation evidence ahead of `main`;
  `main` itself is `fee9485` (the integrated code + GE7 fixes), the state to certify.

## Step 0 — clean tree

Banked the b' audit verdict (`658ee79`, accepts the b' bundle as a valid STUDY
artifact — INCONCLUSIVE primary / FAIL LOCO recorded). The Part B + b' acceptance
bundles (`de0f861`, `92707c0`) were already committed. `git status --short` was
empty before `git merge main`.

## Step 1–2 — the union (additive; every new arg defaults bit-for-bit)

`git merge main` conflicted in `R/lps.R` (6 hunks across 3 conceptual regions) and
`NAMESPACE` (export union). Everything else is disjoint and auto-merged: e19's
kernel-weight/bandwidth body + `lps_cv_utils.R`; t2's IRLS/binary/selection body;
t4's `lps.pointwise.band`/`lps.smoother.matrix`.

**Region 1 — `fit.lps` signature (and its roxygen).** Unioned the three new
arguments at their bit-for-bit defaults:
`bandwidth.multiplier.grid = 1` (e19), `keep.cv.predictions = FALSE` (t2),
`ridge.shrinkage.target = c("zero", "local.mean")` (t2). The conflicting
`outcome.family` roxygen took main's updated E2.12 text (e19 had only the stale
text); the `bandwidth.multiplier.grid` `@param` was inserted before the two t2
`@param`s.

**Region 2 — per-argument cleaning / validation.** Order-independent union;
all auto-merged or carried verbatim: e19's
`.klp.clean.bandwidth.multiplier.grid()` call (`R/lps.R:248`) and its
`bandwidth.multiplier.grid` argument to `.klp.resolve.backend()` (`:260`);
t2's `keep.cv.predictions <- isTRUE(...)` and
`ridge.shrinkage.target <- match.arg(...)`.

**Region 3 — CV candidate-grid construction.** t2 added **no** grid axis (its
"clip" is the bernoulli Brier / log-loss selection *metric*, and
`ridge.shrinkage.target` is a scalar arg — neither is an `expand.grid`
dimension), so the merged `cand` is exactly e19's
`support × degree × kernel × bandwidth.multiplier` (`R/lps.R:299`). At the default
`bandwidth.multiplier.grid = 1` this is the **same 18-candidate set** as both
parents — no double-counting, no dropped candidates. The cv-table call threads
`ridge.shrinkage.target` (the bandwidth axis flows through the `cand` column).

Internal signatures `.klp.cv.table` and `.klp.predict.local.polynomial` carry
both `bandwidth.multiplier` (e19) and `ridge.shrinkage.target` (t2); the two
call sites (final fit, `predict.lps`) pass both. `NAMESPACE` unions all four LPS
exports and is roxygen-canonical (`roxygenise()` produced no change).

## Bit-for-bit confirmation (cross-parent verification)

Beyond the pinned GATEs, I ran a fixed config battery against the merged tip and
both parents in throwaway worktrees, comparing a sha256 digest of
`(fitted.values, cv.table$cv.rmse.observed)`:

| Config | Merged | e19 `bc733df` | main `ffa840a` |
|---|---|---|---|
| gaussian default | `4f4ea2…` | `4f4ea2…` | `4f4ea2…` |
| bandwidth grid {0.5,1,2} (n=54) | `b2602f…` | `b2602f…` | arg absent |
| bernoulli default | `92c6c3…` | `92c6c3…` | `92c6c3…` |
| binomial default | `5b4e7c…` | `c541ab…` | `5b4e7c…` |
| ridge `local.mean` (gaussian) | `4f4ea2…` | arg absent | `4f4ea2…` |

The merged output equals e19 on the e19-only axis (bandwidth) and equals main on
the t2-only axes (bernoulli/binomial/ridge). The binomial row is decisive:
merged == main, **≠ e19**, so the merge carries t2's E2.12/E2.15 binomial
behavior and did not retain e19's pre-t2 path. The gaussian default is identical
across all three. (`ridge local.mean` equals the gaussian default here because
the well-conditioned design selects `rho = 0`, where E2.13 says the two targets
coincide; the E2.13 GATE exercises the active-ridge difference and passes.)

In-suite, the **E1.9b reference GATE** (pins e19's pre-change gaussian fits to
`1e-10`) and the **E2.12/E2.13/E2.14/E2.15 GATEs** both pass, independently
confirming each parent's behavior survives the union.

## Step 3 — GE7 test maintenance (folded in; commit `fee9485`)

The four `test-ge7-lps-api.R` failures are pre-existing stale tests (Pass-1
proved them identical at `b86b796`/`41dc962`/`678565c` — not a t2 regression).

- **Binomial NA-failure telemetry (3 assertions):** the former all-ones
  rank-deficient fixture now converges, so it no longer drives `na.failure`.
  Replaced it with the Pass-1 exact-separation fixture
  (`z <- c(seq(-0.20,-0.04,by=0.02), 6)`), which produces a genuine NA failure;
  `na.failure.count == 1`, `fallback.path.count == 1`, `event.rate.fallback == 0`.
- **Nearly-saturated WLS (line ~682):** orchestrator-ratified disposition. Kept
  `expect_false(.klp.local.design.is.safe(...))`; replaced the
  `weighted.mean` equality with the actual contract — a **finite** fitted
  intercept that is **not** the local weighted mean (robust finite + not-equal
  check, comment citing Pass-1). No `is.safe`→fallback production guard added.
- Out of scope (deferred to Phase-4, untouched): the E2.13 §A2 reference
  extension / `reports/e2_13_reference_fits.csv`.

## Step 4 — full suite green

`reports/phase2b_reconciliation/full_suite_summary.txt`:
`files=27 tests=262 failed=0 error=0 warning=66 skipped=1`.

- 0 failures, 0 errors. GE7 went 4→0.
- 1 skip: the sanctioned E0.3a deferral.
- The 66 warnings are **all** in `test-graph-trend-filtering.R` (per-file table in
  `reports/phase2b_reconciliation/full_suite_by_file.csv`) — pre-existing and
  unrelated to `R/lps.R`; their count has been 66 since base `b86b796` and is
  **unchanged by the merge** (no new warnings introduced). Coverage spans
  E1.9a/b, E1.10 (A1–A3), E2.12/13/14/15, Tier-0 (incl. amended E0.6 +
  fallback-bound), dgp, ge7-lps-api (now green), and the bandwidth/CV tests.

Evidence bundle (committed, tracked): `reports/phase2b_reconciliation/`
(`git_head.txt` = `fee9485`, `git_status.txt` empty, `source_checksums.txt`,
`sessionInfo.txt`, `blas.txt`, `full_suite_by_file.csv`,
`full_suite_summary.txt`). Environment: macOS arm64, R 4.5.2, Apple Accelerate
BLAS.

## Step 5 — fast-forward main (local; NOT pushed)

`git branch -f main codex/geosmooth-e1-9-bandwidth-multiplier` → `main = fee9485`.
**No `git push`** — the Phase-3 Pass-2 re-audit gates the push; the orchestrator
pushes after acceptance.

## Source / test declarations

- `R/lps.R`: merged (the authorized union; this is the one place two branches
  edit it). `NAMESPACE`: unioned, roxygen-canonical. `test-ge7-lps-api.R`:
  GE7 fixes. No other package source changed by me in this step.
- Tests run: ge7 file (24/24), full `testthat` suite (262, 0 failed),
  cross-parent digest battery. Mutations: **none run by me** — the Pass-2
  auditor owns them.

## Limitations and unverified claims

1. **`main` is fast-forwarded but not pushed**, by instruction; I did not verify
   any remote state. The certified tip is `fee9485`.
2. **Cross-parent digests are single-machine** (macOS arm64, R 4.5.2, Accelerate
   BLAS). The digest equalities are exact here; cross-platform reproduction was
   not attempted. The merge is a textual union with bit-for-bit defaults, so
   platform variation should not change the conclusion, but this is unverified.
3. **The 66 graph-trend-filtering warnings were not investigated** — they pre-date
   this work and are outside the LPS scope; I confirmed only that the merge adds
   none.
4. **"No double-counting" rests on the finding that t2 added no grid axis.** I
   verified main's `expand.grid` has no extra dimension and the merged default
   enumerates 18 candidates; if a later change adds a t2-side grid axis, the
   union logic would need revisiting.
5. **GE7 fix #2 asserts a negative contract** (the fit is *not* the weighted
   mean). It documents current long-standing behavior per the Pass-1 disposition;
   it is not a statement that this behavior is desirable. The deferred
   `is.safe`→fallback question is a separate orchestrator decision.
6. **`man/` was not committed** (gitignored, regenerated on build); only
   `NAMESPACE` is tracked and was verified canonical.
7. **No standalone mutation/falsification was run on the merged tree** — the
   union's correctness rests on the pinned GATEs + the cross-parent digests, and
   mutation qualification is the Pass-2 auditor's.
