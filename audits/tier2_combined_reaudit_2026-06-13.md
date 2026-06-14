# Tier-2 combined re-audit

Date: 2026-06-13
Auditor: Codex
Worktree: `/Users/pgajer/current_projects/geosmooth-t2`
Current HEAD: `6f1ad5a0b82a080ad9b8b2938358855dbe6d91f2`
Brief: `/Users/pgajer/current_projects/geosmooth/project_briefs/lps_t2_combined_reaudit_2026-06-12.md`

## Verdict

Accepted for delivered code correctness on E2.12, E2.13, E2.14, E2.15, and
the E0.6 binomial amendment as implemented. The focused gate run passes, the
committed full-size bundle is internally consistent, and targeted source
mutations redden the E2.12/E2.13/E2.14/E2.15 gates.

One E0.6 gate-hardening issue remains: if the binomial local logistic fitter
is transiently mutated to return the event-rate fallback for every local solve,
the E0.6 smoke test still passes all assertions. The printed fallback telemetry
does expose the collapse (`median_fallback=1.0000` for all binomial
prevalences), and the delivered full-size bundle does not show this pathology,
but E0.6 is not yet mutation-hardened against an all-fallback binomial path.

## Scope And Tree State

The brief said the tip should be `4367d10`, but the worktree is at `6f1ad5a`.
I treated this as acceptable for audit scope because `git diff --name-status
4367d10..HEAD` shows only the committed full-size evidence bundle
`audit_artifacts/tier2_20260612T233509Z/` and an update to
`phase_handoffs/e0_6_binomial_amendment_handoff_2026-06-12.md`; no package
source code changed after `4367d10`.

The local worktree was not literally empty: it contained one pre-existing
untracked audit report, `audits/e0_6_binomial_amendment_reaudit_2026-06-13.md`.
I left it untouched. After all transient mutations were restored, `git status
--short` again showed only that untracked audit report plus this new report.

## Evidence Reviewed

- Frozen plan/contract excerpts from the E19 branch for E0.6 and
  E2.12--E2.15.
- Orchestrator sign-offs:
  - `/Users/pgajer/current_projects/geosmooth/project_briefs/lps_g4_ridge_resolution_2026-06-12.md`
  - `/Users/pgajer/current_projects/geosmooth/project_briefs/lps_e2_15_binomial_na_consistency_amendment_2026-06-12.md`
  - `/Users/pgajer/current_projects/geosmooth/project_briefs/lps_e2_15_e06_adjudication_2026-06-12.md`
- Production source `R/lps.R`.
- Gate tests:
  - `tests/testthat/test-lps-tier0-correctness-extended.R`
  - `tests/testthat/test-lps-binary-metric-consistency.R`
  - `tests/testthat/test-lps-ridge-alignment.R`
  - `tests/testthat/test-lps-binary-separation.R`
  - `tests/testthat/test-lps-binomial-na-consistency.R`
- Full-size bundle `audit_artifacts/tier2_20260612T233509Z/`.

## Focused Reproduction

Focused command:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); library(testthat);
for (f in c("test-lps-tier0-correctness-extended.R",
            "test-lps-binary-metric-consistency.R",
            "test-lps-ridge-alignment.R",
            "test-lps-binary-separation.R",
            "test-lps-binomial-na-consistency.R"))
  test_file(file.path("tests/testthat", f))'
```

Result: all five focused files passed. E0.6 had one sanctioned skip for E0.3a
inside the extended file. The smoke E0.6 rows printed:

| family | prevalence | slope | ci_hi | max_na | median_fallback |
|---|---:|---:|---:|---:|---:|
| bernoulli | 0.1 | -0.3139 | -0.2383 | 0 | NA |
| bernoulli | 0.3 | -0.3491 | -0.2775 | 0 | NA |
| bernoulli | 0.5 | -0.3086 | -0.2227 | 0 | NA |
| binomial | 0.1 | -0.3139 | -0.2400 | 0 | 0.0155 |
| binomial | 0.3 | -0.3491 | -0.2775 | 0 | 0 |
| binomial | 0.5 | -0.2912 | -0.2148 | 0 | 0 |

## Reproduced Numbers

E2.12a, deployed clipped Bernoulli metric:

- Raw RMSE rule would select support 8, degree 0.
- Deployed clipped Brier rule selects support 60, degree 2.
- 263 out-of-fold raw predictions lie outside `[0, 1]`.
- Selected deployed-Brier recomputation difference: `0`.

E2.13, aligned ridge:

- Tiny-ridge max difference: `6.951233e-09` against threshold `1e-6`.
- At `rho = 1e2`, median `|f - ybar_w| / |f|`: `0.001764507`.
- Max ratio where `|ybar_w| > 0.2`: `0.01142179`.
- Mean `|f_big|`: `0.5006248`; mean `|ybar_w|`: `0.4996577`.
- Legacy zero-target mean `|z_big|`: `0.005970966`.
- Max `|f_big - z_big|`: `1.155161`.

E2.14, logistic separation:

- Near-separable support: status `ok`, iterations `9`, step halvings `1`,
  max deviance increase `1.776357e-15`, prediction `0.1246682`.
- Exact-separation support: status `not_converged`, iterations `50`,
  trace length `51`, max deviance increase `-1.579481e-10`; fitting-layer
  fallback is separately asserted by the test.

E2.15, binomial NA consistency:

- Candidate A, support 8: NA fraction `0.5583333`.
- Candidate B, support 110: NA fraction `0`.
- Old drop-NA log-loss scores: A `0.3015708`, B `0.6817591`; old rule would
  select A.
- New selection scores: A `Inf`, B `0.6817591`; selected support `110`.

E0.6 full-size bundle:

- Bundle `audit_artifacts/tier2_20260612T233509Z` records git head
  `4367d10b3a738a870d0b0ef24b1470597efcc52c`, clean tree before and after,
  `tests=29 failed=0 error=0 warning=0 skipped=1`, and gate contexts
  E0.1--E0.8 plus E2.12/E2.12a/E2.12b/E2.13/E2.14/E2.15.
- Full-size binomial E0.6 rows in `testthat_stdout.txt`:
  - prevalence 0.1: slope `-0.3181`, ci_hi `-0.2973`, max_na `0`,
    median_fallback `0.0020`;
  - prevalence 0.3: slope `-0.3175`, ci_hi `-0.2980`, max_na `0`,
    median_fallback `0`;
  - prevalence 0.5: slope `-0.3269`, ci_hi `-0.3060`, max_na `0`,
    median_fallback `0`.
- The prior E0.6 re-audit reproduced the full-size calibration mirror:
  Bernoulli selected support 95, degree 0, slope `0.80053888`, intercept
  `-0.078147854`; binomial analogue matched to `1.64e-15` because both arms
  selected degree 0. This confirms the handoff disclosure that binomial
  calibration is reported-only, not an independent gate.

## Mutation Table

| Area | Transient mutation | Targeted command | Result |
|---|---|---|---|
| E2.12 universal Bernoulli R backend | Changed the `backend="auto"` binary-family force-to-R branch to apply only to binomial. | `test-lps-binary-metric-consistency.R` | Red: Bernoulli auto path errored in the backend-policy test. |
| E2.13 aligned ridge | Set `aligned <- FALSE`, disabling the local-mean reparametrization. | `test-lps-ridge-alignment.R` | Red: 8 failures; large ridge shrank to zero instead of local weighted mean. |
| E2.14 step-halving | Set `max.step.halvings <- 0L`. | `test-lps-binary-separation.R` | Red: near-separable case failed with `step_halving_failed`. |
| E2.15 binomial NA consistency | Restored old `cv.logloss.observed <- .klp.logloss(...)` drop-NA selection rule. | `test-lps-binomial-na-consistency.R` | Red: 3 failures; NA-heavy support 8 was selected again. |
| E0.6 binomial logistic non-vacuity | Forced `.klp.fit.logistic.prob.design()` to return event-rate fallback for every local solve. | `test-lps-tier0-correctness-extended.R` | Still green; binomial rows showed `median_fallback=1.0000` for every prevalence. This is a gate-hardening finding. |

Each mutation was restored with `git checkout -- R/lps.R` before the next
mutation. No mutation edits remain.

## Separate Verdicts

E2.12: accepted. The source routes Bernoulli and binomial to the R CV path when
binary selection needs deployed per-point metrics; explicit C++ Bernoulli is
rejected; deployed clipped Brier and log-loss clip behavior are tested and
mutation-sensitive.

E2.13: accepted. The aligned `ridge.shrinkage.target="local.mean"` branch
shrinks toward the local weighted mean, the legacy default remains zero-target,
and the default path is protected by exact pre-change reference pins. The A2
ancestry check passed: `git merge-base --is-ancestor c796408 b79d041` returned
success.

E2.14: accepted. The step-halving logistic solver records a finite monotone
deviance trajectory, bounded fallback on exact separation, and no numerical
change on a benign zero-halving support. The named mutation reddens the gate.

E2.15: accepted. Binomial selection now applies Inf-on-any-non-finite semantics
to selection-facing log loss while leaving `.klp.logloss()` itself available
for observed-pair diagnostics. The old drop-NA selection mutation reddens the
gate on the intended fixture.

E0.6 amendment: accepted for the actual delivered amendment and full-size
evidence, with the gate-hardening caveat above. The implemented test harness
now scores deployed binomial fallback predictions and records fallback
fractions; full-size evidence has small or zero fallback fractions. However,
E0.6 should add an explicit fallback-fraction assertion or comparable
non-vacuity gate before relying on it as proof that the binomial logistic path,
rather than universal fallback, is being exercised.

## Recommended Follow-up

Add a bounded fallback-fraction assertion to E0.6 for the binomial arm. A
conservative form would assert that each prevalence has median or maximum
fallback fraction below a documented threshold under both smoke and full-size
settings, with the threshold chosen from current full-size evidence plus
reasonable numerical slack. This would turn the currently printed telemetry
into an enforceable non-vacuity gate.

