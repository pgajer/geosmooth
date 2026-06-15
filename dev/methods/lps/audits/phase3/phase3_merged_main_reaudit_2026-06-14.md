# Phase 3 merged-main re-audit, Pass 1 post-t2

Date: 2026-06-14
Auditor: Codex
Audited commit: `678565c214bfdc8f56b346b51ab8c01783e20aa7`
Materialized worktree: `/tmp/gm-phase3`
Scope: t2-into-main merge only. E1.9/E1.10/e19 reconciliation is out of scope
until Phase 3 Pass 2.

## Verdict

ACCEPT MERGE, with GE7 test-maintenance follow-ups.

The merged t2 behavior is preserved on `678565c`: the required full-size gate
battery passes, and each t2 gate reddens under its targeted mutation. The four
reported failures in `tests/testthat/test-ge7-lps-api.R` are real failures of
that old test file, but the assignment premise that they are post-t2 behavior
changes is false: the same four assertions fail with the same values at
`b86b796` and `41dc962`. They are pre-existing stale GE7 expectations, not a
t2-into-main regression.

No package source edits remain. The throwaway worktrees were clean after all
mutation restores.

## Certified Tree And Environment

- Certified SHA: `678565c214bfdc8f56b346b51ab8c01783e20aa7`.
- Initial `git status --short` in `/tmp/gm-phase3`: empty.
- Final `git status --short` in `/tmp/gm-phase3` before removal: empty.
- `R/lps.R` merged diff reviewed: `41dc962..678565c` changes
  `R/lps.R` by `+301/-37`.
- t2 commits touching `R/lps.R` in the merge:
  `75c1788` E2.14, `5065a18` E2.12, `550d7e8` E2.12 backend fix,
  `b79d041` E2.13, `fe57126` E2.15.
- R: 4.5.2 on macOS Tahoe 26.3.1.
- BLAS: `/System/Library/Frameworks/Accelerate.framework/Versions/A/Frameworks/vecLib.framework/Versions/A/libBLAS.dylib`.

Audited source checksums:

| file | sha256 |
|---|---|
| `R/lps.R` | `bd34722dcc5239ae54e237be9b4415dcfd42f82e55ec7da127c8580e2b6913fb` |
| `tests/testthat/test-lps-tier0-correctness-extended.R` | `6d361fb3d494ace72d8f635788319f31a414bbe13e3038c459ca8fe09f28c7bf` |
| `tests/testthat/test-lps-binary-metric-consistency.R` | `db3d5b77a7ee423aa370b8c83881c44b84f401320b2a0ee04deaab71c1bc42a7` |
| `tests/testthat/test-lps-binary-separation.R` | `15781b28a55a50ea265d08f9b7d468bd7e343662f40fc6c343088bd39433417c` |
| `tests/testthat/test-lps-binomial-na-consistency.R` | `193110f61ccc2b24d30ab1b8d97ffef0d9221477878b0fe9763114d6b93f1905` |
| `tests/testthat/test-lps-ridge-alignment.R` | `83d3188f1a730e86cdc3bc5bcf8ecd30b6193d53707c34eb55f885b937ae521d` |
| `tests/testthat/test-dgp-library.R` | `b7b7505e5d676531905480fa6e3afbd6d9aa1a1a7da29f47c2264d200e5a08de` |
| `tests/testthat/test-ge7-lps-api.R` | `775edc78c40bf087782c7c6a8a92cceea2db29af2bc32168e0e2f74653719287` |

## Battery Result

Command, run at `678565c` with `LPS_TIER0_FULL=1`:

```sh
Rscript -e 'pkgload::load_all(".", quiet=TRUE); library(testthat);
  for (f in c("test-lps-binary-metric-consistency",
              "test-lps-binary-separation",
              "test-lps-binomial-na-consistency",
              "test-lps-ridge-alignment",
              "test-lps-tier0-correctness",
              "test-lps-tier0-correctness-extended",
              "test-dgp-library"))
    test_file(file.path("tests/testthat", paste0(f, ".R")),
              reporter="summary")'
```

Result: green for all requested files. The only skip was the sanctioned E0.3a
skip inside `test-lps-tier0-correctness-extended.R`.

Full-size E0.6 rows reproduced on the merged tip:

| family | prevalence | slope | ci_hi | max_na | median_fallback |
|---|---:|---:|---:|---:|---:|
| bernoulli | 0.1 | -0.3182 | -0.2963 | 0 | NA |
| bernoulli | 0.3 | -0.3219 | -0.3021 | 0 | NA |
| bernoulli | 0.5 | -0.3310 | -0.3088 | 0 | NA |
| binomial | 0.1 | -0.3181 | -0.2973 | 0 | 0.0020 |
| binomial | 0.3 | -0.3175 | -0.2980 | 0 | 0 |
| binomial | 0.5 | -0.3269 | -0.3060 | 0 | 0 |

## GE7 Triage

I ran `tests/testthat/test-ge7-lps-api.R` at `b86b796`, `41dc962`, and
`678565c`. All three commits fail the same four assertions with the same
values. Therefore these are not t2-introduced behavior changes.

| assertion | base/pre-t2 value | merged value | bound t2 commit | covering gate | classification | proposed fix |
|---|---|---|---|---|---|---|
| line 322, `is.na(failed)` for all-ones rank-deficient logistic design | `failed=0.534602`, not NA | same | none; behavior predates t2 | E2.14 covers actual NA fallback reachability on exact separation | STALE-TEST | Replace the all-ones fixture with the E2.14 exact-separation fixture when asserting `unstable.action="na"` fallback telemetry, or update this fixture to expect successful intercept convergence and add a separate exact-separation telemetry check. |
| line 323, `fallback.path.count == 1` | `0` | `0` | none | E2.14 exact-separation fallback telemetry | STALE-TEST | Same as line 322. |
| line 325, `na.failure.count == 1` | `0` | `0` | none | E2.14 exact-separation fallback telemetry | STALE-TEST | Same as line 322. |
| line 682, nearly saturated WLS returns weighted mean | `is.safe=FALSE`, fit `0.5124671`, weighted mean `0.4585523` | same | none; behavior predates t2 | no t2 gate covers GE7's unsafe-design expectation; E2.13 A2 pin does not cover unsafe/fallback inputs | STALE-TEST, with A2 coverage gap | Either update GE7 to the actual default behavior, or, if the intended contract is that `is.safe=FALSE` must force fallback, add a source guard and a new gate. Do not attribute this to t2. |

For lines 322/323/325, a replacement telemetry fixture can be lifted from
E2.14:

```r
z <- c(seq(-0.20, -0.04, by = 0.02), 6)
design <- cbind(1, z)
y <- as.numeric(z > 0)
weights <- geosmooth:::.klp.kernel.weights(abs(z), "gaussian")
telemetry <- geosmooth:::.klp.logistic.telemetry.new("binomial")
failed <- geosmooth:::.klp.fit.logistic.prob.design(
    design = design,
    y = y,
    weights = weights,
    design.basis = "orthogonal.polynomial.drop",
    design.drop.tol = 1e-8,
    ridge.multiplier.grid = 0,
    ridge.condition.max = Inf,
    unstable.action = "na",
    logistic.telemetry = telemetry
)
summary <- geosmooth:::.klp.logistic.telemetry.summary(telemetry)
expect_true(is.na(failed))
expect_equal(summary$fallback.path.count, 1L)
expect_equal(summary$event.rate.fallback.count, 0L)
expect_equal(summary$na.failure.count, 1L)
```

For line 682, the exact observed merged-tip numbers are:

```text
is_safe = FALSE
.klp.fit.intercept.design(...) = 0.5124671
weighted.mean(y, weights)     = 0.4585523
diff                          = 0.0539148
```

The old GE7 assertion expects fallback merely because
`.klp.local.design.is.safe()` is false. Current production code does not use
that guard on the default orthogonal-polynomial ridge path; this was already
true before t2.

## A2 Pin Coverage Finding

`validation/e2_13_pin_reference_fits.R` generates 308 reference values plus a
header in `reports/e2_13_reference_fits.csv`. It uses one deterministic
G1-style, well-conditioned `n=150`, `D=2` fixture for Gaussian and Bernoulli
default `fit.lps()` runs:

- support grid `c(20L, 30L)`;
- degree grid `c(0L, 1L)`;
- kernel `gaussian`;
- coordinate method `coordinates`;
- backend `R`;
- default `design.basis="orthogonal.polynomial.drop"`;
- default ridge grid `c(0, 1e-10, 1e-8)`;
- default `ridge.condition.max=1e12`.

There is no ill-conditioned, unsafe-design, rank-deficient, or fallback input
in the reference generator. Therefore the E2.13 A2 bit-for-bit pin protects the
well-conditioned default fit path, but it does not certify GE7 line 682 or any
default fallback/unsafe-design behavior. If the program wants A2 to cover those
paths, extend the reference with at least:

1. the GE7 near-saturated unsafe WLS fixture;
2. a rank-deficient orthogonal-polynomial/drop fixture with a known fallback or
   solve outcome;
3. one logistic `unstable.action="na"` exact-separation telemetry fixture.

## Mutation Qualification

All mutations were applied transiently to `/tmp/gm-phase3/R/lps.R`, then
restored with `git checkout -- R/lps.R`. The worktree was clean after each
restore.

| target | mutation | gate run | result |
|---|---|---|---|
| E2.13 ridge alignment | Removed the `+ ybar.w` add-back from the aligned prediction branch. | `test-lps-ridge-alignment.R` | Red: 9 failures, including tiny-ridge invariance and large-ridge local-mean assertions. |
| E2.14 separation | Set `max.step.halvings <- 0L`. | `test-lps-binary-separation.R` | Red: near-separable support failed with `step_halving_failed`. |
| E2.12 deployed metric/backend | Changed the binary `backend="auto"` force-to-R branch to apply only to binomial. | `test-lps-binary-metric-consistency.R` | Red: Bernoulli auto backend-policy test errored. |
| E2.15 NA consistency | Restored old drop-NA `cv.logloss.observed <- .klp.logloss(...)`. | `test-lps-binomial-na-consistency.R` | Red: 3 failures; NA-heavy support 8 was selected again. |
| E0.6 fallback bound | Inserted `return(fallback("forced"))` in `.klp.fit.logistic.prob.design()`. | `test-lps-tier0-correctness-extended.R` smoke | Red: 3 failures at `median.fallback < 0.3`, one per binomial prevalence. |

## Spec Fidelity And Handoff Honesty

The merged t2 gates match the accepted Tier-2/fallback-bound contracts. The
fallback-bound mutation now fails as required.

The attached Phase 3 brief was materially wrong about GE7 provenance. It says
the four GE7 failures appear at post-t2 `678565c` relative to passing pre-t2
`41dc962`. In my runs, `b86b796`, `41dc962`, and `678565c` all fail the same
four assertions with the same observed values. The failures are still real
test-maintenance items, but they should not be used as evidence of a t2 merge
regression.

## Overall Decision

ACCEPT MERGE. Required follow-up is test maintenance, not t2 rollback:

1. update or replace the stale GE7 telemetry fixture so it exercises a reachable
   `na.failure` path post-merge;
2. adjudicate GE7 line 682's intended contract. If unsafe designs must always
   fall back, add a production guard and a real gate; otherwise update the GE7
   expectation to the current long-standing behavior;
3. extend the E2.13 A2 reference if the default fallback/unsafe path is meant to
   be included in the bit-for-bit compatibility claim.
