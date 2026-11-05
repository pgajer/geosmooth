# Structured logistic trend filtering: implementation and validation

Authorized 2026-11-05: add a sparse/banded C++ backend with the exact existing
objective and explicit convergence diagnostics; compare with the dense solver,
including the five frozen weak-penalty cases. Within-CST analyses with thousands
of observations are the main application. A single scalar predictor may also
have 24,000 observations; this is not multivariate graph smoothing.

## Solver design

Use an exact locally supported reparameterization of a working set of
falling-factorial knots. Form and solve the banded curve Hessian with a small
Schur complement for nuisance covariates/centering. Evaluate full-knot KKT
conditions through cumulative polynomial moments; add violating knots until the
same stationarity/complementarity gates pass. No knot thinning or approximate
rounding. Retain the dense solver as a reference and expose backend selection.
Prediction must also avoid a full observation-by-knot dense basis.

## Resources and scope

Two other AGP workers were active before numerical work. After consultation,
the user authorized up to three total compute threads and 6 GiB aggregate memory
for this task. Each numerical worker uses one thread. Compile optimized once
per native revision before workers start. Existing workers are not disturbed.

Compare all 210 frozen unadjusted fits, the five previously disputed cases and
saved adjusted full-data fits where practical. Same objective, original lambda
values and the existing probability/objective gates. Keep original results and
all failed numerical attempts. No new AGP clinical/outcome analyses are launched.

Synthetic scaling checks: 1,000, 4,000 and 24,000 distinct scalar locations,
fixed recorded seeds, binary responses from a smooth probability function,
identical fixed lambda settings, explicit time/RSS and solver diagnostics.
Success requires passing KKT conditions and the workspace guard within the
approved resources. Do not label an iteration-budget exhaustion a convergence
certificate. Source hashes and optimized build/session metadata accompany runs.

Current status: complete. The verified optimized installation passes all 210
frozen dense/banded comparisons, all 30 saved adjusted full-fit comparisons,
all 20 synthetic scaling fits, and 93 focused assertions. Final package QA has
zero errors/warnings and one documentation-URL NOTE. See banded_backend_report.md
for measurements, the five difficult cases, numerical development and limits.
The user subsequently authorized committing and pushing the implementation and
validation documentation. Unrelated committed neighbor-estimator changes were
preserved.

## Preserved numerical development

The initial structured implementation passed the frozen 210 unadjusted and 30
adjusted full-fit comparisons and the 1k/4k/24k smooth synthetic checks. An
additional 4,000-observation test with 100 exact predictor ties, observation-
level covariates/offsets and binary outcomes exposed iteration-limit stalls at
weak penalties. Those failures remain in the private `scaling-final` directory
(the name reflects the attempted run, not successful final acceptance).

A first admission-policy diagnostic (`stress-ties-v4`) admitted omitted knots
before oversolving a restricted subproblem, but one weak-penalty fit still
stalled. An independent dense reconstruction confirmed that the Newton step
was correct and its expected likelihood improvement was at rounding scale.
Compensated objective accumulation and a machine-precision line-search allowance
resolved the stall (`stress-ties-v5`). The same final global stationarity and
complementarity thresholds, likelihood, penalties, inputs and seeds were kept.
An independent full-basis gradient reconstruction is now a regression test.
All previous attempts, not only successful reruns, are retained in private
validation evidence. Debug direction arrays were removed from production
results; line-search step and directional derivative remain available.
