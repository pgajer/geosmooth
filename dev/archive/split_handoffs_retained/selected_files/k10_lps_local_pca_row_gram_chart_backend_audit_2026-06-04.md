# K10 Audit: Row-Gram Local-PCA Chart Backend

Generated: 2026-06-04

## Scope

Audited `/Users/pgajer/current_projects/geosmooth/split_handoffs/k10_lps_local_pca_row_gram_chart_backend_handoff_2026-06-04.md`, the K10 script `/Users/pgajer/current_projects/geosmooth/scripts/k10_lps_local_pca_row_gram_chart_backend.R`, the shared native chart implementation in `/Users/pgajer/current_projects/geosmooth/src/local_pca_charts.cpp`, and the generated K10 CSV artifacts under `/Users/pgajer/current_projects/geosmooth/split_handoffs/k10_lps_local_pca_row_gram_chart_backend_2026-06-04/`.

## Decision

Accepted for the explicit opt-in native local-PCA path.

K10 correctly targets the shared local-PCA chart primitive and preserves the current routing contract: `backend = "cpp.local.pca"` remains explicit opt-in, while `backend = "auto"` still resolves local-PCA LPS to the R path.

Do not promote `cpp.local.pca` into `backend = "auto"` yet. Proceed to K11-style focused preflight/panel validation before any default-backend change.

## Findings

### P2: The pre/post K9 speedup CSV lacks an in-repo generator

The K10 handoff reports median high-dimensional/16S speedups from:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/k10_lps_local_pca_row_gram_chart_backend_2026-06-04/k10_pre_post_k9_profile_comparison.csv`

Those numbers are internally consistent and support the performance interpretation, but the K10 script only reads this CSV if it already exists; it does not regenerate it. I found no separate script or command in the repo that recreates the pre/post comparison from raw K9 outputs.

This is not a blocker for accepting the code change, because the implementation and parity checks pass. It is an auditability gap for the speedup claim. Before treating the K10 speedup table as a durable generated artifact, add either:

- a small script that rebuilds `k10_pre_post_k9_profile_comparison.csv` from named pre/post K9 profile artifacts; or
- a provenance note explaining exactly which pre-K10 and post-K10 profile files were compared and how the CSV was assembled.

### P3: Native install passes but still emits compiler warnings/notes

`R CMD INSTALL --preclean` passed, but the native compilation emitted Rcpp header-order notes and Eigen template `-Wmaybe-uninitialized` warnings involving chart-related code paths. These did not surface as R test warnings and are not a K10 functional blocker.

If this package is being prepared for stricter release or CRAN-style scrutiny, these compiler warnings should be reviewed or suppressed/addressed separately.

## Confirmed Behavior

- The row-Gram path is used only when the local support has fewer rows than ambient columns.
- The implementation recovers right singular vectors from `centered^T u / s`.
- The implementation falls back to Jacobi SVD when the row-Gram solve fails or when the selected singular subspace is too close to numerical rank deficiency.
- Independent chart checks matched R `svd()` singular values and projectors for:
  - unweighted `k < p`;
  - weighted `k < p`;
  - `k >= p` Jacobi fallback path;
  - mean centering;
  - `eigen.cumulative` dimension selection;
  - a near-rank-deficient support.
- LPS backend routing remains unchanged: local-PCA `backend = "auto"` uses `"R"`, while explicit `backend = "cpp.local.pca"` uses the native path.

## Artifact Checks

The refreshed K10 wrapper benchmark reports:

- maximum singular-value discrepancy: `4.263256e-14`;
- maximum projector discrepancy: `5.266620e-15`.

The pre/post profile comparison CSV reports:

- median chart-build speedup on high-dimensional/16S rows: `3.99457`;
- median native CV speedup on high-dimensional/16S rows: `2.80643`.

These values match the handoff after rerunning the K10 script.

## Verification

Commands run from `/Users/pgajer/current_projects/geosmooth`:

- `Rscript scripts/k10_lps_local_pca_row_gram_chart_backend.R`
- Independent R chart-subspace checks against `svd()` for weighted/unweighted and `k < p`/`k >= p` cases.
- Backend contract check confirming local-PCA `backend = "auto"` remains `"R"` and explicit `backend = "cpp.local.pca"` remains native.
- `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R", reporter="summary")'`
- `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge1-r-smoothers.R", reporter="summary")'`
- `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet=TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge4-ssrhe-hessian-energy.R", reporter="summary")'`
- `R CMD INSTALL --preclean /Users/pgajer/current_projects/geosmooth`
- `make test`
- `git diff --check`

Results:

- K10 script rerun: passed and regenerated the benchmark/handoff.
- Independent chart checks: passed.
- Backend contract check: passed.
- Focused GE7 LPS API tests: passed.
- Focused GE1 smoother tests: passed.
- Focused GE4 SSRHE Hessian energy tests: passed.
- `R CMD INSTALL --preclean`: passed, with compiler notes/warnings described above.
- `make test`: passed with `883` passes, `9` existing gflow-parity skips, `0` failures, and `0` R warnings.
- `git diff --check`: passed.

## Recommendation

Proceed to K11 focused high-dimensional and 16S-style backend preflight/panel validation. Add provenance or a generator for `k10_pre_post_k9_profile_comparison.csv` before using the K10 speedup table as a durable benchmark artifact.
