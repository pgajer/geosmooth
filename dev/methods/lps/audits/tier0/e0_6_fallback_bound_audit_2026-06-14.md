# E0.6 fallback-bound audit

Date: 2026-06-14
Auditor: Codex
Target handoff: `dev/methods/lps/handoffs/phase/e0_6_fallback_bound_handoff_2026-06-13.md`
Worktree: `/Users/pgajer/current_projects/geosmooth-t2`
Current HEAD: `794d12c47d5b315a11b01a8a80d084a7f01de070`

## Verdict

Accepted. The fallback-fraction bound directly addresses the combined re-audit
finding: an all-fallback binomial logistic path no longer passes E0.6. The
implementation is test-only, leaves production `R/lps.R` unchanged, keeps the
existing E0.6 consistency and calibration checks intact, and promotes the
already-printed binomial fallback telemetry into an enforceable gate.

No blocking findings.

## Evidence Reviewed

- `dev/methods/lps/handoffs/phase/e0_6_fallback_bound_handoff_2026-06-13.md`
- `tests/testthat/test-lps-tier0-correctness-extended.R`
- Smoke bundle `dev/methods/lps/audit_artifacts/tier2_20260613T235106Z/`
- Full-size bundle `dev/methods/lps/audit_artifacts/tier2_20260614T015321Z/`
- Commit history:
  - `83218b6`: only `tests/testthat/test-lps-tier0-correctness-extended.R`
    changed, adding the E0.6 binomial fallback bound.
  - `722628b`: tracked the two 2026-06-13 auditor notes verbatim.
  - `794d12c`: added the smoke and full-size execution evidence plus this
    handoff.

## Source Audit

The diff from `6f1ad5a` to `83218b6` changes only E0.6 inside
`tests/testthat/test-lps-tier0-correctness-extended.R`:

- It hoists the printed fallback statistic into `median.fallback`.
- It keeps the existing `expect_lt(ci.hi, -0.1)` consistency gate unchanged.
- It adds:

```r
if (identical(fam, "binomial")) {
    expect_lt(median.fallback, 0.3)
}
```

The guard is correctly binomial-only. Bernoulli has no logistic fallback path
in this test and therefore records `NA` fallback fractions.

## Bundle Checks

Both bundle manifests report clean execution at commit `83218b6`:

| bundle | size | tests | failures | skipped | tree clean | gate contexts |
|---|---|---:|---:|---:|---|---|
| `tier2_20260613T235106Z` | smoke | 29 | 0 | 1 | pre/post true | E0.1--E0.8, E2.12--E2.15 |
| `tier2_20260614T015321Z` | full-size | 29 | 0 | 1 | pre/post true | E0.1--E0.8, E2.12--E2.15 |

`shasum -a 256 -c BUNDLE_CHECKSUMS.txt` passed for both bundles.

Realized binomial fallback medians:

| size | prevalence | ci_hi | median_fallback | bound |
|---|---:|---:|---:|---:|
| smoke | 0.1 | -0.2400 | 0.0155 | < 0.3 |
| smoke | 0.3 | -0.2775 | 0.0000 | < 0.3 |
| smoke | 0.5 | -0.2148 | 0.0000 | < 0.3 |
| full | 0.1 | -0.2973 | 0.0020 | < 0.3 |
| full | 0.3 | -0.2980 | 0.0000 | < 0.3 |
| full | 0.5 | -0.3060 | 0.0000 | < 0.3 |

The slope/CI numbers reproduce the prior accepted E0.6 evidence to the printed
precision, consistent with this being an assertion-only change.

## Live Verification

Focused smoke command:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE);
  testthat::test_file("tests/testthat/test-lps-tier0-correctness-extended.R",
                      reporter="summary")'
```

Result: passed, with the sanctioned E0.3a skip. The printed binomial rows were
identical to the smoke bundle:

- prevalence 0.1: `ci_hi=-0.2400`, `median_fallback=0.0155`;
- prevalence 0.3: `ci_hi=-0.2775`, `median_fallback=0.0000`;
- prevalence 0.5: `ci_hi=-0.2148`, `median_fallback=0.0000`.

Negative control:

- I transiently inserted `return(fallback("forced_fallback"))` after the valid
  row check in `.klp.fit.logistic.prob.design()`.
- Rerunning the same focused E0.6 file produced exactly three failures at
  `tests/testthat/test-lps-tier0-correctness-extended.R:260`, one for each
  binomial prevalence:
  `Expected median.fallback < 0.3. Actual comparison: 1.00 >= 0.30`.
- `R/lps.R` was restored with `git checkout -- R/lps.R`; no mutation edits
  remain.

## Residual Risk

The `0.3` threshold is still a pragmatic guard rather than a mathematical
requirement from the frozen E0.6 spec. That is acceptable for this remediation:
it catches the specific all-fallback vacuity while leaving large slack above
the realized smoke and full-size values. If future legitimate numerical changes
raise fallback fractions materially, the threshold should be revisited with
documented evidence rather than silently relaxed.
