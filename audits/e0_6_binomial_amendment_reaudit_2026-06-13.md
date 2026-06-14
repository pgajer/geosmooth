# E0.6 binomial amendment re-audit

Date: 2026-06-13
Auditor: Codex
Target handoff: `phase_handoffs/e0_6_binomial_amendment_handoff_2026-06-12.md`
Worktree: `/Users/pgajer/current_projects/geosmooth-t2`
Current HEAD: `6f1ad5a0b82a080ad9b8b2938358855dbe6d91f2`
Full-size evidence bundle: `audit_artifacts/tier2_20260612T233509Z/`
Bundle HEAD: `4367d10b3a738a870d0b0ef24b1470597efcc52c`

## Verdict

Accepted for the E0.6 binomial-arm amendment and Tier-0 re-acceptance
claim. The amendment is narrowly scoped to the E0.6 test harness: the
binomial arm now scores deployed `unstable.action = "mean"` predictions,
the bernoulli arm remains on `"na"`, and no production `R/lps.R` source was
changed by this amendment. The committed full-size bundle under
`LPS_TIER0_FULL=1` is internally consistent and green for E0.1--E0.8 plus
the Tier-2 gates.

No blocking findings.

## Evidence Reviewed

- `tests/testthat/test-lps-tier0-correctness-extended.R` lines 147--270:
  E0.6's binomial arm alone uses `unstable.action = "mean"`; the bernoulli
  arm stays on `"na"`. Existing thresholds are unchanged.
- `audit_contracts/lps_tiers1to4/e2_15_e06_interaction_raise_2026-06-12.md`:
  the stop-and-raise records the E2.15 interaction and the orchestrator's
  Option-1 resolution.
- `audit_artifacts/tier2_20260612T233509Z/`: committed full-size bundle at
  `4367d10`, with empty `git_status.txt` and `git_status_post_study.txt`.
- `testthat_stdout.txt` in the bundle prints the full-size E0.6 consistency
  rows. The binomial rows match the handoff table:
  prevalence 0.1 slope `-0.3181`, ci_hi `-0.2973`;
  prevalence 0.3 slope `-0.3175`, ci_hi `-0.2980`;
  prevalence 0.5 slope `-0.3269`, ci_hi `-0.3060`;
  all are comfortably below the frozen `ci_hi < -0.1` threshold.
- Bundle manifest reports `tests=29 failed=0 error=0 warning=0 skipped=1`,
  gate contexts `E0.1` through `E0.8` plus `E2.12`, `E2.12a`,
  `E2.12b`, `E2.13`, `E2.14`, `E2.15`, `probe_rc: 0`, `study_rc: 0`,
  and clean tree state before and after the study.
- The bundle checksum file verifies successfully for all files.

## Live Reproduction

I did not rerun the full 1.5--3 hour battery. Instead I ran targeted checks
against the current clean worktree:

1. Bundle checksum verification:
   `(cd audit_artifacts/tier2_20260612T233509Z && shasum -a 256 -c BUNDLE_CHECKSUMS.txt)`
   returned `OK` for every bundle file.
2. The reported n = 4000 calibration mirror reproduces exactly:
   - Bernoulli selected support 95, degree 0; 2000/2000 finite predictions;
     slope `0.80053888`, intercept `-0.078147854`.
   - Binomial selected support 95, degree 0; 2000/2000 finite predictions;
     slope `0.80053888`, intercept `-0.078147854`; fallback fraction 0.
   - Max absolute prediction difference between the bernoulli and binomial
     held-out predictions was `1.64e-15`, confirming the handoff's stated
     degree-0 identity rather than indicating a plumbing mix-up.
3. One documented pre-amendment stop-and-raise cell was reproduced:
   prevalence 0.3, n = 500, replicate 1. With `unstable.action = "na"`,
   binomial `fit.lps()` errors with no finite selection score. With
   `unstable.action = "mean"`, the fit succeeds, selects support 38,
   degree 0, produces all finite predictions, and records final fallback
   fraction `0.1`.

## Interpretation

The amendment fixes the specific E2.15/E0.6 inconsistency: the old E0.6
binomial protocol could score only the points a candidate happened to
predict, or fail entirely once E2.15 correctly made NA-heavy candidates
unselectable. The new E0.6 binomial protocol scores deployed fallback
predictions everywhere and records fallback fractions.

The full-size re-acceptance evidence supports the existing E0.6 thresholds.
The bernoulli calibration slope remains fragile: `0.8005` is only about
`5e-4` above the lower bound. That fragility is inherited from the accepted
bernoulli configuration, not introduced by this binomial amendment, but it
should stay visible before future numerical or BLAS-sensitive changes.

The binomial calibration analogue is correctly treated as reported-only:
E0.6 gates calibration on the bernoulli arm, and at n = 4000 both arms
select degree 0, so the binomial analogue is numerically identical to the
bernoulli value and is not independent calibration evidence for the
logistic path.

## Scope Limits

- I did not rerun the full-size `LPS_TIER0_FULL=1` bundle.
- I did not compare per-cell pre/post RMSE tables finer than the printed
  accepted-bundle summaries; the handoff accurately discloses that limitation.
- The audit does not add a new binomial calibration assertion. Whether E0.6
  should gain one remains a spec question.
- No package code was changed by this audit. The only durable output is this
  audit report.
