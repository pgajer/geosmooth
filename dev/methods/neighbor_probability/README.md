# Nearest-person binary probability estimators

Implemented on 2026-11-05. The public entry point is
[fit.neighbor.probability](../../../R/neighbor_probability.R); its three methods
are knn, case_raw and case_corrected. One
[C++ backend](../../../src/neighbor_probability.cpp) ranks records, retains one
answering visit per participant and evaluates every requested size. There is
no dense distance allocation for coordinate input and no internal parallelism.

Fixed-size fits store the training inputs. Prediction computes probabilities
and optionally the people/cases reached, radius and boundary-tie diagnostics.
predict(fit) excludes each training query's entire participant. Predictions at
new coordinates must supply query.group if the query belongs to a training
participant. Missing outcomes never count as controls. With repeated visits,
the closest answering visit is selected before its label is inspected. This
policy, and participant-balanced CV, extend the one-person-per-record study.
Insufficient reachable people or cases give NA without an implicit fallback.

Coordinate metrics are Euclidean and Chebyshev, with optional per-row sum or
maximum normalization. Precomputed dissimilarities permit externally prepared
geodesic/Fermat distances; the estimator does not construct or tune such paths.
Tuning supports explicit grouped fold vectors or repeated-fold matrices and
minimum-error, smoother one-SE and locality one-SE rules. Report tuning as
selection, not independent performance. Use grouped outer folds for assessment.

## Reference validation

The make test-neighbors target compiles optimized source once (debug = FALSE),
loads the local dgraphs source without rebuilding it, generates the two help
topics and registration, and runs the focused tests. It uses one compute thread.
The agreed ceiling for this task is four threads and 10 GiB aggregate.
No AGP fits or actual sPTB outcomes are used.

The [Python fixture generator](../../../scripts/neighbor_python_oracle.py)
parses the original study's compare.py with Python's AST and executes its
actual identity_order, distances, ordered_training, predictions, choose, tune
and diagnostics functions. It does not copy their formulas into a substitute
Python implementation and does not import the study driver.
The source SHA-256, extracted function names and NumPy version are embedded in
[the committed synthetic fixtures](../../../tests/testthat/fixtures/neighbor-python.json).

Regenerate the fixtures with:

    python3 scripts/neighbor_python_oracle.py \
      /Users/pgajer/current_projects/vaginal_microbiome/projects/anatomy_of_vaginal_microbiome/reports/enrollment_nearest_cases/compare.py \
      tests/testthat/fixtures/neighbor-python.json
    make test-neighbors
    Rscript scripts/audit_api_guide.R --check

Nine fixtures cross three synthetic profile configurations (ordinary,
duplicated and discrete/tie-heavy) with the three historical metrics. They
contain 18, 20 or 22 records, a held-out query block and two repetitions of
inner folds. Checks compare complete size paths for all three methods,
selected k, all inner Brier scores, case and neighbor counts, radii and tied
shells. Coordinate and precomputed-distance paths both match. Prediction
comparisons use tolerance 1e-15 and Brier comparisons 1e-14; selected sizes and
integer diagnostics agree exactly.

Additional tests enumerate every one of the 64 binary assignments on a
six-point example against independent rank arithmetic. Other tests cover
missing and one-class labels, insufficient cases, disconnected distances,
participant-held exclusion, discordant repeated visits, row permutation,
invalid inputs and all three selection rules. The current focused suite has
947 passing expectations, zero failures and zero warnings. This is correctness
evidence, not evidence of predictive value on microbiome outcomes.

A temporary installed-package check also passed the probability and
documentation tests, native symbol loading, and execution of both new help
examples. The feature commit includes the previously committed logistic
trend-filtering implementation as its parent; the new neighbor code does not
alter that estimator. The companion AGP documents count 17 estimators through
15 fitting entry points, since this interface represents three methods.

## QA limits

A separate run of the existing package-wide exported-example test fails for
five previously existing helpers whose Rd files lack examples:
fit.masked.graph.field, cv.masked.graph.field, compare.masked.graph.fields,
select.masked.graph.field, and support.masked.graph.field. The two new help
topics pass their focused documentation checks. The existing roxygen version
also rewrites the usage line of compare.synthetic.dataset.Rd when all docs
are regenerated; that unrelated generated drift is excluded from this change.

The full package test suite and CRAN submission checks are outside this
targeted feature validation. Reports must not describe this as a full-package
CRAN pass. Build logs and structured test summaries remain under
tmp/neighbor-validation, outside Git.
