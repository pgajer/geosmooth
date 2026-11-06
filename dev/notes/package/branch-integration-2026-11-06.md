# Branch integration, 6 November 2026

The branch audit compared all local branches and fetched `origin` branches
with `main`. Git ancestry was supplemented by source comparisons for older
branches whose fixes had been integrated under different commits.

## Integrated work

- `codex/logistic-trend-filtering` (`2f87abf`): fast-forwarded `main` to include
  the permutation assessment, numerical solver fixes, shape summaries,
  optional permutation tests, regression tests and documentation.
- `codex/exp039-tuning-resolution-20260917` (`6f17e3b`): integrated explicit
  conductance inputs, verified complete spectra, observed-response heat
  smoothing, and opt-in numerical cross-checks. This branch contains
  `codex/exp039-heat-observed-20260917`,
  `codex/exp039-verified-heat-20260917`, and
  `codex/exp039-final-gcv-20260917`.

The final independent numerical review of `6f17e3b` accepted the bounded
implementation and closed both score-calculation and tuning-resolution
findings. Integration preserves the refusal to tune structurally flat paths
or unresolved competing minima. Numerical resolution bands are operational
cross-checks, not confidence intervals or certified error enclosures.

The graph branch's only Git conflict was in `NEWS.md`; both sets of entries
were retained. The function guide, API signature appendix and article
navigation were updated for the integrated interface. The reviewed graph
solver implementation and numerical tests were preserved unchanged. The
fit help text was clarified to distinguish the zero-time identity diagnostic
from a valid GCV candidate.

## Branches requiring no further merge

`codex/neighbor-probability`, `codex/geosmooth-cran-artifact-cleanup`, and the
other branches with no commits outside `main` already have their work included.

Two local branches retain unmatched commit identities but no missing
functional changes:

- `codex/geosmooth-lps-contract-wip-20260611`: its smoke-contract wording is
  already present. Its old contract/script paths have been superseded by the
  current `dev/methods/lps/` layout.
- `codex/geosmooth-tier0-bucket2-isolated`: its reference values and helper
  code are already present. Differences are whitespace, relocated script
  references and generation metadata; the recorded reference source hash
  and numerical values agree.

No branches were deleted and no other worktree was modified.

## Separate PS-LPS experiment

The LPS solver and Tier-0 test changes in `88c1523` on
`codex/geosmooth-ge9-docs-examples` were already integrated in `e77fec2`.
Their source/test contents agree at those commits. The remaining commits
change PS-LPS defaults from monomial design and a single ridge multiplier
to an orthogonal polynomial design and guarded adaptive ridge, add a
degree-1 screening fallback, and add experiment/report scripts. They have
seven merge-conflict files against current `main`, including both solver
files and correctness tests. These are distinct model-policy changes,
not missing documentation alone.

The user chose to leave these PS-LPS experiments for a separate review.
The branch is retained without merging its experimental defaults or scripts.

## Integration validation

The first `make check` completed with one error: an older density-normalization
test requested `fit.metric.graph.lowpass(eta.grid = 0)`. Exact zero has undefined
GCV under the integrated selection contract. The density test now evaluates
that prescribed endpoint with `metric.graph.lowpass.basis()` and
`apply.metric.graph.lowpass.path()`, then checks the same raw and normalized
mass values. It also requires the identity diagnostic. All 30 assertions in
that density test file pass against the installed merged implementation.
No solver changes were needed. The failed check and its source tarball were
retained separately from the corrected rerun.

The corrected `make check` finished with **Status: OK: zero errors, zero
warnings and zero notes**. The package regression suite passed 14,435
assertions, with one expected skip because its source-tree runner is excluded
from the package tarball. As defined in `tests/testthat.R`, ten expensive
scientific-validation contexts are separate from package checks; they were
not rerun for this integration. Historical cohort validation was not repeated.

Examples, rebuilt vignettes, and PDF and HTML manuals passed. Source and
installed documentation audits resolved all 69 exports and 101 S3 methods;
the observed-data heat vignette is installed and indexed. All 281 selected
source, test and documentation files matched the final checked source tarball.
The check used one numerical thread and optimized C++ (`-O2 -g0`).

Local logs, both source tarballs, the branch inventory and source hashes are
retained in
`/Users/pgajer/.codex/private/geosmooth/branch-integration-20261106/`.
The failed first run is under `initial-check/`; `full-check-final.log` records
the corrected result.
