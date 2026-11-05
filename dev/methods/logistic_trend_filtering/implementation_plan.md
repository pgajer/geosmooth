# Order-2 logistic trend filtering implementation and validation

Authorized 2026-11-05: an R API with a C++ backend, convergence diagnostics,
and validation against the frozen custom logistic fits and corrected glmgen,
including five weak-penalty discrepancies. No new clinical analyses.

## Scope and objective

Implement summed weighted Bernoulli negative log likelihood plus lambda times
the L1 norm of third divided differences on normalized predictor locations.
Optional nuisance covariates, offsets, and explicitly selected nuisance/centered
curve ridge penalties. Exact ties share a curve but retain observation-level
covariates. Default ridge is zero. Training transformations are reused for
prediction. Constant boundary extrapolation is explicit.

The native solver will use a profiled logarithmic barrier for the L1 epigraph
with damped Newton steps. Check stationarity, dual feasibility, complementarity,
finite arithmetic and iteration limits independently of objective progress.
Use a scaled falling-factorial basis to preserve the quadratic null space.
This initial backend uses dense matrices with an explicit workspace guard;
large-data sparse/banded solvers are outside the initial implementation.

## Resources and evidence

No competing numerical jobs observed at setup. Each validation uses one
numerical thread, aggregate memory ceiling 55 GiB. Final package QA/vignette
rebuilding and independent validation may overlap, with at most two total
compute threads; no other numerical workloads were observed before overlap.
Compile optimized once per native revision and
load local dependencies from source. No timing comparisons are planned.

Frozen reference root:
/Users/pgajer/current_projects/vaginal_microbiome/projects/anatomy_of_vaginal_microbiome/results/immune_trendfilter_comparison_2026-11-01-v1

Use the 30 original observation files and seven original penalties (1 through
0.001) unchanged. Compare the common unadjusted, unstabilized objective.
Preserve original and stricter glmgen runs separately. Common numerical
agreement gate: absolute summed-objective difference / n <= 1e-5 and maximum
training probability difference <= 0.001. Failure remains a failure; do not
change datasets, penalties, or ridge to obtain agreement. Inspect the native
KKT diagnostics on all fits and directly compare native vs both references.
Additional synthetic tests cover binomial weights, ties, nuisance covariates,
offsets, polynomial null space, separation, and explicit nonconvergence.
Keep clinical inputs and fitted values outside versioned package sources.

## Completion

Generate Rcpp and roxygen outputs; run focused tests and package checks. Save
validation script, source/input hashes, session information, comparison tables,
all failures and a reader-facing account of the five previously unresolved
cases. Do not claim the original minimax theorem applies to stabilized logistic
models. Current status: implementation complete. The verified optimized installation
passed 48 focused assertions, 210/210 frozen unadjusted comparisons, and 30/30
saved adjusted full-fit comparisons. All five corrected-glmgen discrepancies
remain reproducible while the native fits agree with the custom reference.
See README.md for the exact agreement gates, diagnostic limits, package-check
results and preserved evidence. The user subsequently authorized committing and pushing all geosmooth changes.
