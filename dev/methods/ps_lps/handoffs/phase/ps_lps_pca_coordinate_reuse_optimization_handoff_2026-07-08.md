# PS-LPS PCA-Coordinate Reuse Optimization Handoff

Status: ready for independent audit
Role: implementer
Repository: `/Users/pgajer/current_projects/geosmooth`
Branch/worktree: `main`
Base commit: `63cf3fc Preserve PS-LPS runtime speedup handoff`
Final commit: `7454453 Reuse PS-LPS local PCA supports across chart dims`
Final git status at handoff creation: clean before this handoff file was added

## Goal

The implementation goal was to reduce repeated local-PCA coordinate work in
PS-LPS OD visit-CV runs when the candidate grid contains multiple explicit
numeric chart dimensions for the same support size and kernel.

Before this change, each PS-LPS candidate could rebuild local PCA supports at
its own requested `chart.dim`. The implemented reuse path computes local PCA
coordinates once at the maximum numeric chart dimension for each
`support.size` and `kernel` pair, then slices the precomputed coordinate matrix
for smaller numeric chart dimensions.

This optimization is limited to explicit scalar numeric chart-dimension grids,
for example `chart.dim.grid = c(1, 2, 4)`. The `auto` and `local.auto` chart
dimension policies were intentionally left on their prior path.

## Work Completed

The PS-LPS geometry cache now accepts optional precomputed local PCA supports.
When supplied, the frame-preparation code uses the cached support indices,
distances, kernel weights, and coordinate matrices, and slices the coordinate
matrix to the requested anchor-specific dimension.

The OD visit-CV candidate loop now builds a reuse plan for `ps_lps_count`
candidates. For numeric chart dimensions only, it groups candidates by
`support.size` and `kernel`, computes the maximum requested chart dimension for
each group, caches one native `rcpp_ps_lps_local_pca_supports()` result per
group, and passes that shared support object into the PS-LPS geometry cache.

The implementation preserves fallback behavior: if the reuse plan is empty, the
candidate is not scalar numeric, the requested support/kernel combination is not
eligible, or the shared support build fails, the existing direct geometry path
is used.

## Files Changed

- `/Users/pgajer/current_projects/geosmooth/R/ps_lps.R`
  - `.ps.lps.prepare.geometry.cache()` gained optional
    `local.pca.supports`.
  - `.ps.lps.prepare.frames()` gained optional `local.pca.supports` and slices
    cached coordinates to each requested chart dimension.
  - Primary implementation lines in the committed version:
    `/Users/pgajer/current_projects/geosmooth/R/ps_lps.R:1439` and
    `/Users/pgajer/current_projects/geosmooth/R/ps_lps.R:1479`.

- `/Users/pgajer/current_projects/geosmooth/R/state_density.R`
  - `.state.density.visit.cv.table()` now creates a PS-LPS numeric
    chart-dimension reuse plan and shared local-PCA-support cache.
  - Added helpers:
    `.state.density.ps.lps.chart.dim.reuse.plan()`,
    `.state.density.ps.lps.local.pca.supports.key()`, and
    `.state.density.ps.lps.shared.local.pca.supports()`.
  - Primary implementation lines in the committed version:
    `/Users/pgajer/current_projects/geosmooth/R/state_density.R:1013`,
    `/Users/pgajer/current_projects/geosmooth/R/state_density.R:2136`, and
    `/Users/pgajer/current_projects/geosmooth/R/state_density.R:2184`.

- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ps-lps.R`
  - Added equality regression coverage showing that max-dimension cached local
    PCA supports reproduce direct smaller-chart fits.
  - Test starts at
    `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ps-lps.R:683`.

- `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-state-density-odcv3-lps-outer-visit-cv.R`
  - Added OD visit-CV regression coverage showing that a `3`-dimension grid
    crossed with `2` support sizes invokes the native local-PCA support builder
    only once per support size in the constructed test.
  - Test starts at
    `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-state-density-odcv3-lps-outer-visit-cv.R:152`.

## Generated Artifacts

No generated report, benchmark bundle, package documentation, `man/` files, or
dashboard artifact was created for this implementation phase.

## Commands Run

All commands below were run from `/Users/pgajer/current_projects/geosmooth`
unless otherwise noted.

```sh
Rscript -e "parse('R/ps_lps.R'); parse('R/state_density.R'); cat('parsed ps_lps/state_density\n')"
```

```sh
Rscript -e "pkgload::load_all('.', quiet=TRUE); testthat::test_file('tests/testthat/test-ps-lps.R'); testthat::test_file('tests/testthat/test-state-density-odcv3-lps-outer-visit-cv.R')"
```

```sh
make test-ps-lps
```

```sh
make test-od
```

```sh
make test
```

```sh
git diff --check
```

```sh
git status --short
```

```sh
git add R/ps_lps.R R/state_density.R tests/testthat/test-ps-lps.R tests/testthat/test-state-density-odcv3-lps-outer-visit-cv.R
git commit -m "Reuse PS-LPS local PCA supports across chart dims"
git push
```

## Validation

Parsing of `R/ps_lps.R` and `R/state_density.R` completed successfully.

The focused PS-LPS and OD visit-CV test files passed after the trace-counter
test instrumentation was corrected. The initial failure was in the new test
counter, not in the package code path: the trace increment used a local
assignment that was not visible to the test assertion. The final test uses an
option-backed counter.

`make test-ps-lps` passed.

`make test-od` passed.

The full `make test` target passed with exit code `0`.

`git diff --check` passed before commit.

The committed OD regression test constructs `2` support sizes crossed with `3`
numeric chart dimensions, for `6` PS-LPS candidates. The observed number of
native local-PCA-support builds in that test is `2`, one per support size.

The committed PS-LPS equality regression test compares direct and reused
geometry caches for chart dimensions `1`, `2`, and `4`, and compares fitted
values for `lambda.sync = 0` and `lambda.sync = 0.1` with tolerance `1e-9`.

## Canonical And Generated File Notes

The canonical files for this phase are package source and test files. No
roxygen documentation, `NAMESPACE`, `man/`, generated HTML, or generated
dashboard files were modified.

## Source Modified After Validation

No package source or test files were modified after the final validation
commands listed above, other than staging, committing, and pushing the validated
diff.

This handoff file was written after the optimization commit.

## Limitations And Unverified Claims

No broad runtime benchmark was run after this optimization. The validation
establishes reduced native local-PCA-support call count for a constructed OD
visit-CV numeric chart-dimension grid and equality of fitted values for the
direct versus reused geometry paths in the targeted PS-LPS regression test. It
does not quantify wall-clock speedup on OD4-expanded, S3R, or other large
experiment manifests.

The reuse path is not used for `chart.dim = "auto"` or
`chart.dim = "local.auto"`. Those policies may still rebuild local PCA supports
through their existing chart-dimension-resolution paths.

The reuse plan groups only by `support.size` and `kernel`. The current
implementation assumes that for the eligible PS-LPS OD visit-CV path, these are
the relevant local-PCA-support inputs. Other candidate axes still affect design
matrix construction and fitting after the local support coordinates are
available.

The implementation accepts externally supplied `local.pca.supports` only through
private package helpers. There is no public API contract for users to pass
precomputed local PCA supports.

The added test counts calls to `rcpp_ps_lps_local_pca_supports()` by tracing the
R-visible native wrapper in the package namespace. It is a package-level
regression guard, not a profiler.

## Reusable Workflow Capture

Classification: no new reusable artifact created.

Rationale: the optimization is package-specific and already covered by focused
package tests. If more cache-sharing optimizations are added across LPS,
PS-LPS, chart-kernel, and local-likelihood methods, a shared cache-design note
may become useful.

## Next Actor

Ready for: independent audit under the worker-auditor workflow.

Requested decision: none from the implementer handoff. The auditor should use
the governing audit workflow and repository evidence to form any findings or
verdict independently.
