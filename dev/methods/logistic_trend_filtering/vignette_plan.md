# Logistic trend-filtering vignette

Authorized November 5, 2026: implement the proposed synthetic/Pima vignette.
AGP within-CST applications remain separate; no AGP outcomes are analyzed.

Use two predeclared probability signals: linear log odds and a localized bump
with a broad trough. For each use 600 independent training observations and
2,000 independent test observations, fixed seeds, five outcome-stratified
training folds, and the same observations/folds for all methods. Compare a
constant, linear and quadratic logistic regression, a natural-spline logistic
regression with df selected from 3, 5 and 7, and order-2 logistic trend filtering.
Use lambda = c(Inf, 10^seq(0,-4,by=-0.5)), chosen by minimum training CV log loss.
Report held-out log loss/Brier score and synthetic probability RMSE. Fixed
examples teach the workflow; they do not constitute a repeated-simulation
method ranking.

Use MASS::Pima.tr (200 women) for all real-data training/tuning, then the
published MASS::Pima.te (332 women) for assessment. Main nonlinear predictor:
glucose. Add a separate predeclared age/BMI-adjusted comparison. Test outcomes
do not select penalties, transformations, spline df or covariates. Show
calibration diagnostics, predictor support and counts outside training range.
MASS provides the data; no private files, downloads or new binary data assets
are needed. Plotting bins are descriptive, not model preprocessing.

Add an exact-tie/trial-weight equivalence illustration at a fixed lambda and
explicitly show convergence/failure/boundary diagnostics. No confidence bands
that ignore smoothing selection. No new statistical guarantees for logistic
trend filtering are asserted.

Competing AGP/neighbor numerical work was present. The user authorized one
thread and up to 1 GiB for this vignette. Use an optimized installed local
backend whose logistic R/C++ sources match current sources, or a sequential
current-source installation. Record source hashes, package/session information,
all selected parameters, scores and failed candidates in private build evidence.
Preserve the existing untracked banded_backend_report.html from another chat.

Completion: standalone installed-package Rmd, article/navigation integration,
execution without hidden inputs, rendered HTML and figures inspected, dependency
and vignette checks appropriate to a documentation change. Status: complete.

## Results and validation

The fixed local-changes example selected lambda 0.003162278 and six adaptive
knots. Probability RMSE on 2,000 independent test observations was 0.0457,
compared with 0.1868 for linear logistic regression and 0.0808 for the selected
natural spline. The linear-logit example selected the quadratic limit and
closely matched linear logistic regression. These are two illustrations, not
evidence of an average ranking across simulation replicates.

On the 332 Pima test observations, glucose-only trend filtering had log loss
0.4967 versus 0.4938 for linear logistic regression. The selected trend filter
had zero adaptive knots and matched the quadratic model. The age/BMI-adjusted
comparison likewise selected zero adaptive knots. The vignette states these
results without claiming that the flexible method improved prediction.

All four selected trend filters passed convergence checks. Binary and
trial-weighted grouped fits agreed within 1e-7 in predicted probability.
A deliberately iteration-limited fit failed and default prediction returned NA.
All ten trend-filtering candidates were eligible in each comparison.

Final execution used one thread, 1.74 seconds elapsed and 220,037,120 bytes
maximum resident memory (about 210 MiB), below the approved 1 GiB allocation.
This is a build observation, not a solver benchmark. The optimized installed
logistic R/C++ sources were verified by hashes against current package sources.
No native code was changed. All six figures were visually inspected; HTML
internal links, image descriptions and diagnostic notation were checked.
Independent checks recomputed Pima test log loss/Brier scores, confirmed MASS
data identity, training-only reference model sizes and stored spline knots,
checked failure gating, and parsed the tangled R source. API guide coverage
passed (68/68 exports); git diff --check passed. Full package checks were
subsequently requested and completed as recorded below.

Reproduction: render vignettes/logistic-trend-filtering.Rmd using
rmarkdown::render() with the current geosmooth installation, MASS, splines,
knitr and rmarkdown available. No download or private input is needed.
Run Rscript scripts/audit_api_guide.R --check for API guide coverage.
Private audit evidence (render script/log, session information, saved analysis
objects, independent verification script, score CSVs and source hashes) is at
/Users/pgajer/.codex/private/geosmooth/logistic-vignette-20261105/;
the final standalone HTML is in render-final/. Earlier render attempts remain
there for provenance. The vignette is linked in pkgdown Guides and the function
guide, and splines is declared in Suggests. AGP within-CST work remains separate.

## Full package QA and publication

The user subsequently requested full checks, repairs, commit and push. Checked
an isolated snapshot of geosmooth at 5bafb83 plus this task's changes, using
the Makefile's complete `make check` target: documentation regeneration,
source build, and `R CMD check --as-cran` including examples, package tests,
vignette rebuilding and PDF/HTML manuals. Compilation used -O2 -g0, one make
job and one numerical thread. No native source was changed.

The first build failed because the default dgraphs installation lacked the
header required by the newly committed neighbor estimator. Reused the local
dgraphs 0.3.0.9000 installation from tmp/neighbor-validation/library in a private
check library; its linf_simplex_distance.hpp matches the current sibling source.
No global package installation was replaced. The first complete check then
found missing help examples, an unqualified setNames call and six links to
unpublished website reference pages. Preserved the failed-check evidence.

Repairs: add runnable examples for five masked graph-field functions and four
logistic trend-filtering methods; regenerate their Rd files; qualify
stats::setNames; remove six broken hyperlinks while retaining the function
names; extend the installed-documentation audit to this vignette; regenerate
the API appendix's source locations. These repairs do not change the models.

Final full check: **Status: OK**, zero errors, warnings or notes. Package tests:
13,782 passing expectations, zero failures/warnings, one intentional skip for
the source-tree runner excluded from the tarball. Examples, all vignette
rebuilds, and PDF/HTML manuals passed. Installed help resolves for all 68
exports and 100 S3 methods; three audited guides and their labeled figures
are available offline. The source documentation audit, including negative
fixtures, and git diff --check passed after regeneration.

Full check evidence:
/Users/pgajer/.codex/private/geosmooth/vignette-full-check-20261105/.
The successful log is full-check-final.log; the checked installation and
00check.log are under source/geosmooth.Rcheck/. Initial build and failed check
logs remain alongside it. Commands used the private Makevars and R_LIBS
library in that evidence directory with OMP_NUM_THREADS, OMP_THREAD_LIMIT,
OPENBLAS_NUM_THREADS, MKL_NUM_THREADS and VECLIB_MAXIMUM_THREADS all set to 1.
Additional checks: Rscript scripts/check_installed_docs.R CHECKED_LIBRARY;
make update-api; Rscript scripts/test_documentation_checks.R.
