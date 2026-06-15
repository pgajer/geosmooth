# K12 Audit Response Re-Audit: LPS Backend Policy and Auto-Dimension Contract

Audited: 2026-06-05 00:18:00 EDT

## Verdict

Partially accepted.  The two K12-specific blockers from the prior audit are
resolved:

1. `local.pca.real.data.contract` now excludes
   `local.chart.method = "second.order.svd"`.
2. The accidental LPS native diagnostic `.Rd` files are no longer generated,
   and the K12 `NAMESPACE` change for `lps.backend.diagnostics` is clean.

However, the audit response is not ready to accept as a package handoff because
it substantially expanded scope beyond K12.  It moves the gflow parity tests out
of the ordinary suite, removes `gflow` from `Suggests`, changes graph-geodesic
bridging to `dgraphs`, adds a new harmonic smoother native backend, and
introduces a new generated internal Rcpp man page.  Those changes may be the
right direction, but they need their own handoff/audit contract rather than
being bundled into the K12 response.

## Findings

### P1: Response hides parity skips from `make test` without adding an explicit migration-test target

The ordinary `make test` target runs only `tests/testthat`
(`/Users/pgajer/current_projects/geosmooth/Makefile:25`).  The response moves
the GE3/GE4 gflow parity tests from `tests/testthat` into
`tests/migration`, so the ordinary suite now reports zero skips.  Running the
migration suite directly still yields the same nine gflow-reference skips:

```text
[ FAIL 0 | WARN 0 | SKIP 9 | PASS 13 ]
```

This is not a K12 backend-policy blocker, but it is a package-audit blocker for
the response as submitted.  The response should either:

- add an explicit Makefile target such as `make test-migration` and document
  that parity tests are opt-in migration checks; or
- leave the parity tests in the ordinary suite until a separate migration-test
  policy is approved.

Otherwise, "ordinary suite has zero skips" is achieved by moving parity coverage
out of the checked path, not by resolving the parity preconditions.

### P1: Response includes broad non-K12 graph and harmonic backend changes

The response modifies code well beyond K12 diagnostics:

- `DESCRIPTION` removes `gflow` from `Suggests`.
- `R/split_bridge_helpers.R` replaces gflow bridge helpers with package-local
  graph payload validation and `dgraphs::shortest.path`.
- `R/malps.R`, `R/lpl_tf.R`, and `R/ssrhe_hessian_energy.R` documentation now
  describe `dgraphs` ownership.
- `R/harmonic_smoother.R` switches from a `gflow` native symbol call to a new
  package-local `rcpp_harmonic_smoother`.
- `src/harmonic_smoothing_native.cpp` adds a substantial topology-tracking
  backend implementation.
- graph-trend-filtering and graph-boundary tests are rewritten around the new
  package/dgraphs boundary.

These changes may be necessary for the broader geosmooth split, and the tests I
ran did pass.  But they are not just an audit response to the K12 LPS backend
policy.  They should be split into a separate graph-boundary/native-harmonic
handoff with parity expectations, especially because `AGENTS.md` says not to
silently change smoother semantics during migration.

### P2: Generated internal native documentation drift persists for a new wrapper

The previous audit flagged accidental generated `.Rd` files for internal LPS
native diagnostic wrappers.  Those two files are gone after `make document`.
But the response introduces another internal Rcpp wrapper,
`rcpp_harmonic_smoother()`, and `make document` generates:

```text
man/rcpp_harmonic_smoother.Rd
```

The page says it is an internal C++ backend for `harmonic.smoother()`.  If this
is intended as an internal native wrapper like the LPS diagnostic wrappers, mark
it `@noRd`; if it is intentionally documented, list it in the handoff and
explain why this internal wrapper should have an Rd page.

## Resolved K12 Items

- The contract predicate now requires ordinary PCA charting:
  `local.chart.method.effective == "pca"` in addition to local-PCA,
  `chart.dim = "auto"`, support metric `both`, and selection metric `operator`.
- The GE7 regression test now verifies that `local.chart.method =
  "second.order.svd"` has `chart.dim.auto = TRUE` but
  `local.pca.real.data.contract = FALSE`.
- Direct audit probe confirmed:

```text
local.chart.method.effective = second.order.svd
chart.dim.auto = TRUE
local.pca.real.data.contract = FALSE
```

- The earlier accidental generated files
  `man/rcpp_kernel_local_polynomial_cv_local_pca_profile.Rd` and
  `man/rcpp_kernel_local_polynomial_neighbor_probe.Rd` no longer appear after
  `make document`.

## Verification

Passed:

```sh
make document
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-ge7-lps-api.R", reporter = "summary")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-graph-trend-filtering.R", reporter = "summary")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_dir("tests/testthat")'
Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_dir("tests/migration")'
R CMD build .
R CMD check geosmooth_0.0.0.9000.tar.gz --as-cran --no-examples --no-tests --no-manual
git diff --check
```

Results:

- Focused GE7 test: passed.
- Focused graph-trend-filtering test: passed.
- Ordinary `tests/testthat`: `0` failures, `0` warnings, `0` skips, `916`
  passes.
- Migration tests: `0` failures, `0` warnings, `9` skips, `13` passes.
- `R CMD check --no-tests`: completed with `1 WARNING`, `1 NOTE`.
  The warning is the existing development/non-mainstream dependency warning;
  the note is the existing non-standard top-level `scripts` directory.

## Recommendation

Accept the narrow K12 LPS diagnostic fix after adding/confirming the generated
files intended for K12.  Do not accept the full response bundle as a single K12
handoff yet.  Split the graph-boundary, `dgraphs`, migration-test-policy, and
native harmonic smoother changes into a separate handoff with its own parity and
API contract, and either add a `test-migration` target or explicitly document
that migration parity is no longer part of ordinary package QA.
