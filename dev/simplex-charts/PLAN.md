# Local simplex charts: package integration

Integrate the October 27 research prototype into fit.local.likelihood as opt-in
Bernoulli charts; preserve legacy defaults. Use intrinsic distances for neighbor
selection and kernel weights, weighted PCA or training-only PLS1, weighted score
centering/scaling, ridge slopes and symmetric intercept pseudo-counts. Unsupported
unfoldings and failed optimizations retain diagnostics with explicit constant/NA
fallback. No density interpretation of an unfolded surface is introduced.

Validate analytical seam geometry, corners/ties, constant outcomes, CV exclusion,
legacy behavior and numerical parity with the Python prototype. Synthetic parity
fixtures must be small, deterministic and contain no cohort data. Compile local
native dependencies once optimized; no cohort outcome fits or timing claims.

Allocation: user authorized up to six single-threaded workers and 30 GiB in total
alongside the explorer asset rebuild. Use only the capacity required. Record QA
and remaining limits in RESULTS.md. Preserve existing simulation releases and
failed attempts; do not relabel previous Python simulations as R-package runs.
