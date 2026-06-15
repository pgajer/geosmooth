# Harlim Second-Order Local SVD H1 Audit

Date: 2026-06-04

Audited handoff:

- `/Users/pgajer/current_projects/geosmooth/split_handoffs/harlim_second_order_local_svd_handoff_2026-06-04.md`

Audited implementation files:

- `/Users/pgajer/current_projects/geosmooth/inst/include/geosmooth/local_second_order_svd_charts.h`
- `/Users/pgajer/current_projects/geosmooth/src/local_second_order_svd_charts.cpp`
- `/Users/pgajer/current_projects/geosmooth/src/local_second_order_svd_charts_rcpp.cpp`
- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-harlim-second-order-svd-chart.R`
- generated Rcpp/Rd registration files touched by `Rcpp::compileAttributes()` and roxygen

Verdict: accepted for H2/H3 chart-diagnostic smoke tests.

## Findings

No blocking correctness issues were found.

The H1 implementation matches the revised H0 contract closely:

- it introduces a separate experimental primitive rather than changing the existing plain local-PCA backend;
- the quadratic design uses square monomials first and doubled cross terms second;
- rank checks use the scale-relative cutoff specified in H0;
- fallback behavior distinguishes ordinary fixed-dimension plain-PCA fallback from structured failure when plain PCA is infeasible;
- diagnostics expose effective support, design rank/condition, first and second SVD ranks, fallback status, and primary failure reason;
- LPS, P7, and existing local-PCA call paths are not wired to the new primitive.

## Nonblocking Notes

The H1 tests are appropriate for the minimal prototype. For H2/H3, add broader diagnostics rather than more unit assertions inside H1:

- flat 2D planes, paraboloids, saddles, and high-dimensional embedded versions;
- symmetric and asymmetric supports;
- weighted supports with a few zero-weight rows;
- fallback-rate summaries as support size and curvature-design conditioning vary;
- runtime and tangent-projector error against ordinary local PCA.

One small implementation convention to keep visible: `curvature.condition.max = Inf` is currently accepted as an effective "no cap" setting. That is not a blocker, but H2/H3 reports should record the value used so ill-conditioned accepted fits cannot hide behind an implicit default.

## Additional Auditor Smoke Probes

In addition to the submitted unit test, I ran quick probes on:

- symmetric 2D paraboloid support;
- symmetric 2D saddle support;
- asymmetric random 2D paraboloid support.

The symmetric cases recovered the exact tangent plane. The asymmetric paraboloid case improved tangent-projector error relative to ordinary local PCA in the tested support.

These are not a substitute for H2/H3, but they are consistent with the H1 primitive behaving as intended.

## Validation

Commands run from `/Users/pgajer/current_projects/geosmooth`:

```sh
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-harlim-second-order-svd-chart.R")'
git diff --check
```

Results:

- targeted H1 test: 26 passed, 0 failures;
- `git diff --check`: clean.

I did not rerun full `make test` or `make check-fast` during this audit because the handoff already reports those package-level runs and the focused audit did not modify package source.

## Response to Harlim Agent

Accepted. Please proceed to H2/H3 chart-diagnostic smoke tests, not LPS integration yet.

Recommended H2/H3 scope:

1. Build a small deterministic chart-diagnostic script over flat, paraboloid, saddle, and high-dimensional embedded supports.
2. Compare plain local PCA and second-order local SVD using tangent-projector error, coordinate residual summaries, fallback status, design rank/condition, and runtime.
3. Include both centered symmetric supports and asymmetric/random supports, since symmetric supports can make curvature cancellation look easier than it is.
4. Record all numerical tolerances, support sizes, weights, center mode, and whether ordinary PCA fallback was used.
5. End with a recommendation on whether the primitive is ready for a narrow optional LPS/SLPLiFT chart-mode experiment.
