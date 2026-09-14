# Making the geosmooth API easier to navigate

Reviewed against the working source of geosmooth 0.1.0 on 14 September 2026.
This records the original review of the 93-export API. The subsequent user-approved
implementation retired the 25 dgraphs re-exports and unified quadratic Hessian
fitting, then consolidated refits and smoother-matrix extraction as S3 generics,
bringing the API to 60 exports. See [NEWS](../../../NEWS.md) for the
implemented migration and the current signature appendix. Proposals 1, 2, 3,
and 5 below are implemented; the others remain proposals. Counts and source
line references in the original analysis describe the pre-consolidation snapshot. The companion
[function guide](../../../vignettes/function-guide.Rmd) describes the API
that users can call today.

## Implemented consolidation: validation

The 25 dependency re-exports and two separate quadratic selection exports are
retired. The unified fitter preserves fixed-call argument positions and the
existing CV/GCV classes and diagnostics. Its selection controls and migration
mapping are documented in [NEWS](../../../NEWS.md) and the fitter's help.

`make test-ssrhe` passed 287 assertions, including an independent reconstruction
of held-out CV scores from fixed-operator linear solves. Seven comparisons
against the pre-change source agreed on fitted values, classes, penalties, and
selection diagnostics: fixed vector fits, weighted matrix fits, missing-label
CV, exact GCV, seeded Hutchinson GCV, and adaptive support searches under CV
and GCV. Measured runtimes were excluded from equality comparisons.

The full `make check` passed installation, loading, documentation consistency,
examples, vignettes, manuals, and 10,905 test assertions. One source-only runner
test was skipped in the tarball and passed separately from the source tree.
The sole CRAN incoming warning is the unchanged version 0.1.0 already existing
on CRAN; a submission requires a version increment. No submission was made.

Validation used dgraphs 0.2.1.9000 built from the sibling source into an isolated
temporary R library and selected through `R_LIBS`. This resolves the older
default-library dependency mismatch for the checks without replacing the
user's installed packages. That check package had exactly 66 exports,
and the guide checker verified one catalog row for each of them. Historical
review and validation details below describe the earlier documentation pass.

## Shared refit and smoother-matrix generics: validation

The subsequent consolidation replaces six refit exports with `refit(object,
y, ...)` and two smoother-matrix exports with `smoother.matrix(object, ...)`.
There are now 60 explicit exports and 44 registered S3 methods, including the
eight class methods and two defaults that explain unsupported inputs. Former
help aliases remain available; method-specific controls, response shapes,
selection behavior, and returned classes are preserved. Metric graph low-pass
and quadratic Hessian refit summaries still cannot themselves be refitted.

Sixteen comparisons with the installed package from before this change agreed
at tolerance 1e-12 after excluding calls and measured runtimes. They covered
all six refit families, stored-response reuse, weighted and robust MALPS,
fixed and per-column GCV graph refits, matrix responses, quadratic CV/GCV
subclass dispatch, fixed and CV Hessian L1 refits, and LPS/MALPS smoother
matrices (including a frozen-weight robust matrix). The new regression file
passed 58 assertions covering dispatch, independent numerical identities,
reuse, and invalid arguments. The first test run exposed two mistakes in the
new tests (an unsupported reference-fitter argument and an ambiguous partial
argument name); correcting those tests required no numerical implementation
changes.

The full `R_LIBS=/tmp/geosmooth-api-consolidation/library make check` completed:
10,963 assertions passed, with no test failures or test warnings. The single
source-only runner test skipped in the tarball passed separately in the source
tree, as did the exported-function/S3-method example-coverage test. S3
registration, code/documentation consistency, examples, vignettes, and both
manual checks passed. The sole CRAN warning remains the unchanged version
0.1.0 already existing on CRAN. No submission was made.

The installed namespace has exactly 60 exports: both generics are present,
all eight former entry points are absent, and all eight former help aliases
resolve. The vignette index lists both HTML documents. The refreshed guide's
catalog covers all 60 exports once, and its HTML internal anchors resolve.
The final documentation regeneration was warning-free and reproduced the
checked NAMESPACE and Rd files exactly. Validation used the same isolated
dgraphs library as the earlier consolidation.

## Main recommendation

Organize the documentation by task first. Then reduce the public API where
there is a clear ownership boundary or a shared operation. The best initial
changes are to retire the 25 transitional geometry/sampling re-exports and
unify the three quadratic Hessian fitters around their penalty-selection mode.
After a compatibility period, those two changes alone would reduce explicitly
exported names from **93 to 66**, without deleting any estimator.

Keep distinct estimators separate. In particular, local polynomial smoothing,
model averaging, prediction synchronization, local likelihood, and graph
regularization are not interchangeable choices behind one general `fit()`
function. Reducing the number of names is useful only if the resulting calls
remain easier to understand.

## What was reviewed

The review inventories every `export()` and `S3method()` entry in `NAMESPACE`,
parses function signatures in `R/`, and examines help, implementation, and
existing tests for the main consolidation candidates. Re-export ownership is
established by `importFrom(dgraphs, ...)` and
[the transition source](../../../R/synthetic_geometry_imports.R).
The [signature appendix](api-signatures.md) records exact local signatures,
argument counts, source locations, and the complete re-export list.

| Public surface | Count | What the count means |
|---|---:|---|
| Functions defined in geosmooth | 68 | Explicit exports of local implementations. |
| Functions re-exported from dgraphs | 25 | Existing implementations owned by the graph package. |
| Total explicit exports | 93 | Names users can access directly with `geosmooth::`. |
| Registered S3 methods | 34 | Methods selected by generics such as `predict`, `print`, `plot`, and `normalize.density`; counted separately. |

Argument counts include `...` as one formal argument, exclude arguments passed
through it, and do not measure statistical complexity. For example, the
two-argument generic `normalize.density(x, ...)` has richer method signatures.
This review does not measure external usage, compare predictive accuracy, or
establish that an export without many internal callers is unused by users.
No function should be deleted on that basis.

## What to learn from Hmisc

Hmisc provides a named overview help topic with a function-and-purpose table.
That gives readers an entry point beyond individual help pages. It also uses
shared help topics: the summary-formula documentation groups the main
operation, its output methods, and related helpers. These are documentation
patterns we can adopt without merging implementations.
([Hmisc reference manual](https://cran.r-project.org/web/packages/Hmisc/refman/Hmisc.html),
[summary-formula source](https://github.com/harrelfe/Hmisc/blob/master/man/summary.formula.Rd))

The Hmisc website separately links usage examples, runnable source, related
material, and a tutorial devoted to its summary functions. The tutorial also
shows how newer calls replace particular older workflows. For geosmooth,
family tutorials and concrete old-to-new examples would make any later
deprecation much easier to follow.
([Hmisc website](https://hbiostat.org/r/hmisc/),
[summary-function tutorial](https://hbiostat.org/R/Hmisc/summaryFuns.pdf))

My recommendation is to add task categories to that overview pattern. Hmisc's
overview is largely an alphabetical function-purpose list; a workflow map for
geosmooth should distinguish fitting, refitting, operators, uncertainty, and
simulation. Hmisc is evidence that a large API can be navigable, not evidence
that all related functions should share one signature.

### Documentation structure

The new `function-guide` vignette supplies a starting-point table, examples,
prediction limits, and a complete catalog. The package help and README should
link directly to it. Users can navigate entirely within an installed package;
the guide does not depend on a website being deployed.

For a later documentation pass, group related help through roxygen `@family`,
`@seealso`, and selected shared `@rdname` topics. Keep separate argument
sections when signatures differ substantially. A future pkgdown reference
index should mirror the guide's categories; pkgdown configuration and hosting
are separate work, and no site is assumed to exist here.

The first page should feature the ordinary fitters. Put reusable operators,
low-level search helpers, experimental transport methods, and `dgraphs`
re-exports in their own sections. Mark experimental status where the current
help already does so; do not invent a maturity ranking from naming or file size.

## Removal and consolidation candidates

### 1. Retire the 25 transitional dgraphs re-exports

**Recommendation: strong, with a migration period.** The source explicitly
calls these migrated interfaces re-exports “during the transition.” They include
geometry constructors, nine sampling constructors, embedding and edge-length
helpers, and the two quadratic-geometry differential helpers. All 25 are listed
in the guide and signature appendix.

The replacement is direct and keeps signatures and implementation intact:

```r
# Current geosmooth spelling
geosmooth::synthetic.circle(radius = 2)

# Preferred ownership-explicit spelling, already available
dgraphs::synthetic.circle(radius = 2)
```

Keep `synthetic.spec()`, truth and response constructors, materialization,
registry access, and dataset validation in geosmooth. Those represent regression
experiments and response generation. `synthetic.sampling.stratified()` is a local
implementation and is not one of the 25 re-exports; evaluate its ownership
separately instead of removing it with a name-prefix rule.

First update package examples and vignettes to qualify migrated constructors,
and check downstream examples and dependent packages. Announce the mapping in
NEWS. Preserve re-exports during the announced compatibility period; later
remove their export tags while retaining any imports needed internally. A bare
re-export cannot itself issue a deprecation warning without adding a wrapper.
Do not promise runtime warnings unless that wrapper is actually implemented.

This is a namespace cleanup, not the elimination of synthetic-data capability
or removal of the `dgraphs` dependency. Evidence:
[re-export declarations](../../../R/synthetic_geometry_imports.R) and
[dependency declaration](../../../DESCRIPTION).

### 2. Unify fixed, CV, and GCV quadratic Hessian fits

**Recommendation: strong.** These three exports fit the same quadratic
Hessian-energy model:

- `fit.ssrhe.hessian.regression()` — supplied penalties, 29 arguments.
- `fit.ssrhe.hessian.regression.cv()` — label-fold selection, 36 arguments.
- `fit.ssrhe.hessian.regression.gcv()` — GCV selection, 35 arguments.

The fixed fitter shares 27 argument names with each selection wrapper. Its
two scalar penalties become grids in the selection functions; the remaining
differences mostly concern the selection procedure. The CV and GCV results
already inherit from the common `ssrhe.hessian.fit` class. This is a natural
selection option within one estimator.

A possible future call would retain the existing main function name:

```r
# Proposed, not currently available
fit.ssrhe.hessian.regression(
  X, y, k = 12, tangent.dim = 2,
  lambda.selection = "cv",
  lambda1.grid = c(0.01, 0.1, 1),
  cv.control = list(foldid = folds, loss = "mse", selection = "min")
)
```

Preserve the existing fixed call `lambda1 = ..., lambda2 = ...`. Require
selection to be explicit when grids are supplied; reject conflicting scalar
and grid inputs. Group shared neighborhood/numerical settings rather than
concatenating all three current signatures into a longer one.

CV and GCV must retain distinct validation rules. Label CV can tune with
missing labels and positive-weight observed subsets. GCV currently requires
one fully observed response and strictly positive weights. Its Hutchinson
trace option is randomized and needs its own seed/probe controls. Keep the
selected penalty, criterion, support candidates, and CV/GCV tables accessible
in results. Compatibility wrappers should preserve old class vectors and
fields until users have migrated.

Do **not** include `fit.ssrhe.hessian.l1.regression()` in this first merger.
Its absolute-value penalty uses a different optimizer, path behavior, and
solver controls; sharing an operator is not enough to justify sharing the
entire interface. Evidence:
[quadratic fitting and selection](../../../R/ssrhe_hessian_energy.R#L1086),
[CV signature](../../../R/ssrhe_hessian_energy.R#L1298),
[GCV signature](../../../R/ssrhe_hessian_energy.R#L1701), and
[absolute-value fitter](../../../R/ssrhe_hessian_energy.R#L2614).

### 3. Use a common refit generic, with class-specific methods

**Recommendation: worthwhile after specifying reuse behavior.** Six exports
perform the same broad operation on an existing fit: `refit.malps`,
`refit.lpl.tf`, `refit.slpl.tf`, `refit.metric.graph.lowpass`,
`refit.ssrhe.hessian.regression`, and `refit.ssrhe.hessian.l1.regression`.
Their common inputs are a fitted object and a replacement response.

```r
# Implemented after this review
refit(object, y, ...)
```

R's S3 dispatch can select the appropriate method without a giant shared
parameter list. Method help must expose its own arguments. Normalize the
common input names (`object`, `y`) while preserving method-specific penalties,
weights, and numerical controls. Check for generic-name conflicts with packages
users commonly attach before exporting the generic.

| Method family | Existing behavior that must survive dispatch |
|---|---|
| Model-averaged local regression | Holds supports and averaging weights fixed; may change case weights and recomputes response-dependent robust weights. |
| Lifting trend filters | Reuses operators and supplied/stored fixed penalties. |
| Graph low-pass | Accepts response matrices; can reselect smoothing separately per column with `per.column.gcv`. |
| Quadratic Hessian | Accepts new response vectors or matrices and new fixed penalties/weights. |
| Absolute-value Hessian | Supports one response vector and fixed or CV-selected penalties. |

Do not silently make every refit rerun CV. Nor should a new generic imply that
matrix responses or repeated refitting are supported uniformly. In particular,
the current quadratic Hessian refit returns a separate class and the existing
refit function accepts the base fit class; decide explicitly whether a refit
result can itself be refitted. Preserve old entry points during migration.
Six retired explicit names replaced by one generic eventually save five
exports; registered methods are not additional explicit exports.

Evidence: [MALPS](../../../R/malps.R#L585),
[LPL-TF](../../../R/lpl_tf.R#L578),
[synchronized LPL-TF](../../../R/slpl_tf.R#L487),
[low-pass](../../../R/metric_graph_lowpass.R#L1062), and
[Hessian refits](../../../R/ssrhe_hessian_energy.R#L1202).

### 4. Consider one harmonic smoother with optional tracking

**Recommendation: conditional; not a direct alias replacement.**
`perform.harmonic.smoothing()` has six arguments. `harmonic.smoother()` shares
all six with the same defaults and adds three recording/stability controls.
A single smoother with `track.topology` and `tracking.control` is natural in
principle and would eventually save one export.

However, inspection of the two native routines shows a behavioral discrepancy:
the basic routine enters its iteration loop only when both boundary and
interior are nonempty; the tracked routine can iterate on a boundary-free
region. The basic routine checks both update size and harmonic residual; the
tracked routine checks update size. Tracking records topology stability but
does not stop relaxation at the first stable topology.

A diagnostic using the current native source confirmed the boundary-free
difference. On a four-vertex unit-length path, with the region containing all
four vertices and a limit of two iterations, the results were:

| Values | Vertex 1 | Vertex 2 | Vertex 3 | Vertex 4 |
|---|---:|---:|---:|---:|
| Input | 0 | 2 | -1 | 1 |
| Basic routine | 0 | 2 | -1 | 1 |
| Tracked routine | -0.5 | 1.75 | -0.75 | 1.5 |

This tests behavior under the same inputs, not convergence quality or which
boundary-free policy is preferable. Neither the signature overlap nor a
shared mathematical description establishes numerical equivalence.

Unify the boundary contract and convergence definition first. Check whole-graph
regions, proper subregions, empty interiors, disconnected components, and
iteration limits. Decide and document whether a boundary-free request should
be unchanged, rejected, or treated as a different smoothing problem. A tracking
flag must not silently change the mathematical boundary-value problem. Old
wrappers may need to retain legacy behavior during migration.

There is also existing help drift: the basic routine's algorithm description
mentions degree-one vertices as boundary points, while the native boundary
test uses neighbors outside the region. The new navigation guide states the
implementation's rule; the original function help needs a dedicated correction.
Evidence: [R interfaces](../../../R/harmonic_smoother.R#L63) and
[native routines](../../../src/harmonic_smoothing_native.cpp#L175).

### 5. Consider a shared smoother-matrix generic

**Recommendation: useful, but preserve different validity domains.**
`lps.smoother.matrix(object, check.tol)` and
`malps.smoother.matrix(object, max.n, allow.robust, ...)` both return a linear
map from responses to fitted values. A proposed `smoother.matrix(object, ...)`
generic could replace two explicit exports with one, while keeping
method-specific controls.

LPS can return an evaluation-by-training matrix and currently enforces a
fixed Gaussian configuration, R backend, supported basis, and fixed chart
dimension. MALPS returns a dense training-by-training matrix conditional on
supports/weights, with a size guard and an optional robust fixed-weight
linearization. Do not erase these restrictions or describe the selected
pipeline itself as response-linear. Keep `lps.pointwise.band()` and
`bootstrap.malps()` separate: analytic pointwise uncertainty and a conditional
case-weight bootstrap are different procedures.

Evidence: [LPS validation and matrix extraction](../../../R/lps_uncertainty.R#L14)
and [MALPS matrix construction](../../../R/malps.R#L677).

### 6. Lifting and synchronized lifting: a later family-level decision

**Recommendation: plausible, lower priority.** The synchronized operator wraps
the ordinary lifting operator and adds overlap disagreement rows. The
constructors share 26 argument names; the ordinary constructor additionally
exposes `exclude.self`, whereas synchronization fixes it to `TRUE` and adds
two synchronization controls. The synchronized objective reduces to the
ordinary objective when its synchronization penalty is zero *and the same
residual operator is used*.

A future lifting-family API could expose `lambda` and `lambda.sync = 0`, with
optional synchronization at operator construction. Preserve ordinary
self-inclusion options, avoid constructing unused synchronization matrices,
and explicitly resolve the different current tuning defaults: ordinary LPL-TF
defaults to CV, synchronized LPL-TF to fixed penalties. Preserve operator
classes, fields, CV behavior, and prediction restrictions via adapters.

This is a stronger candidate than merging unrelated smoothers, but sharing a
documented family may deliver most of the benefit without an immediate code
merger. Treat it separately from the refit proposal when counting reductions,
because replacing synchronized refits in both plans would double-count savings.
Evidence: [synchronized construction](../../../R/slpl_tf.R#L25) and
[penalized solve](../../../R/slpl_tf.R#L899).

## Simplify existing signatures before adding dispatchers

### Remove ineffective choices

| Argument | Current implementation | Recommendation |
|---|---|---|
| `refit.malps(reuse.selection)` | Requires `TRUE`; `FALSE` errors. | Make fixed selection part of the documented operation; accept the old `TRUE` argument temporarily during deprecation. |
| `refit.malps(refit.local.coefficients)` | Also requires `TRUE`. | Remove the apparent choice using the same compatibility approach. |
| `refit.metric.graph.lowpass(n.cores)` | Validates a positive integer, but per-column GCV loops serially and reports one core used. | Deprecate the control until parallel execution is implemented; do not advertise it as a speed control. |
| Reserved `...` and singleton choices | Several lifting/prediction functions reject all supplied dots or support only one solver/type. | Omit these from introductory examples; do not invent additional choices. Preserve `...` where generic compatibility needs it. |

These are parameter reductions, not export reductions. Evidence:
[MALPS guards](../../../R/malps.R#L603),
[serial refit](../../../R/metric_graph_lowpass.R#L1090), and
[lifting prediction](../../../R/lpl_tf.R#L629).

### Put advanced controls into small, validated groups

The longest local signatures are the transported graph Hessian constructor
(52 arguments), absolute-value Hessian fitter (46), MALPS fitter (41),
prediction-synchronized fitter (37), and quadratic Hessian CV fitter (36).
This is a stronger usability concern than the number of short, descriptive
synthetic constructors.

| Family | Keep prominent | Candidate control groups |
|---|---|---|
| Local polynomial models | `X`, `y`, neighborhood/degree/kernel choices, coordinate method, chart dimension | CV; numerical stability; advanced chart selection. |
| MALPS and lifting operators | Data/graph, anchor choices, support type and scale, degree/kernel | Support search; local solver; model averaging or synchronization where applicable. |
| Hessian models | `X`, `y`, tangent dimension, neighborhood, penalty/selection | Neighborhood construction; CV/GCV; numerical solver. |
| Spectral graph smoothing | Graph inputs, filter type, smoothing grid, eigenpair count | Conductance conversion; eigensolver; guarded search. |
| Transported graph Hessian | Graph, transport rule/order, optional coordinates | Local embedding; direction matching; gradient estimation. |

For example, MALPS solver options could become
`solver.control = list(method = "qr", normal.equations.max.condition = 1e8)`.
Keep frequently changed scientific choices visible. Every control group needs
documented names/defaults, early validation, rejection of unknown fields, and
clear precedence when old and new arguments are both supplied. A single
untyped `control = list(...)` for the entire package would hide rather than
simplify the API. Plain validated lists avoid creating many new exported
control constructors solely to reduce other signatures.

The prediction-synchronized fitter exposes `ps.lps.geometry.cache` and
`ps.lps.local.pca.supports`. They belong in an advanced reuse interface with
validation of compatibility with `X` and geometry controls; their removal is
not justified solely by their implementation-oriented names.

### Align terms without conflating their meanings

Use `foldid`, `cv.folds`, `cv.seed`, and `cv.loss` consistently for row/label
CV; current graph/Hessian interfaces use `nfolds`, `fold.id`, or `loss` in
places. Align common refit arguments as `object` and `y`. Keep
`visit.foldid` distinct because it indexes visits rather than support rows.
Likewise, `selection.strategy` chooses which candidates to evaluate, whereas
`selection = "one.se"` chooses among evaluated candidates; these must not
become one ambiguous `selection` flag.

Do not standardize the *meaning* of `weight.list` by renaming alone. Lengths,
conductances, quadrature weights, response masses, and observation precision
weights are different quantities. Document these alongside signatures and
validate them at the correct boundary. The function guide now emphasizes the
length-versus-conductance distinction.

For functions exposing both a scalar setting and a candidate grid, specify
what wins and when tuning happens. Keep `fit.lps()`'s grid-oriented contract
unless a separate fixed-fit mode is deliberately designed; adding another
scalar/grid pair for every argument would increase ambiguity.

## Functions that should remain separate

| Functions or family | Reason |
|---|---|
| `fit.lps`, `fit.malps`, `fit.ps.lps` | Different local-fitting and aggregation/synchronization objectives; different prediction domains and response support. Shared local geometry code is an internal reuse opportunity. |
| `fit.chart.kernel`, `fit.lps` at degree zero | Related in restricted cases, but the chart-kernel denominator supports reference-measure quadrature weights. Prove equivalence and preserve normalization diagnostics before considering any substitution. |
| `fit.local.likelihood`, ordinary local regression | Exponential-tilt density and logistic likelihood objectives have different response constraints and failure policies. |
| `fit.density`, `fit.subject.od`, `normalize.density` | Respectively fit masses, adapt repeated visits with optional visit CV, and normalize an already fitted field. Their input and validation units differ. |
| Quadratic and absolute-value Hessian fits | Different penalty geometry and solver/path contracts. A common operator does not imply one simple fit signature. |
| Graph trend filters, lifting filters, and parallel-transport filters | Different operator construction, graph/coordinate requirements, and boundary policies. Keep shared optimization machinery internal. |
| `pttf.geometry`, `pttf.operator`, transport diagnostic constructor | Geometry, derivative operators, and direction-matching diagnostics are distinct reusable objects. The diagnostic constructor's 52 arguments are a reason to organize controls, not to merge it with another constructor. |
| Spectral operator, basis, path application, fitted model | Different stages useful for reuse and benchmarking; one compulsory fit call would discard those capabilities. |
| `materialize.synthetic`, `materialize.synthetic.instance` | User-controlled specification/seed versus a frozen identity with checksum guarantees. Do not hide that difference with string-or-object dispatch. |
| Synthetic truth and response constructors | Short signatures are already clear. Covariance matrices, scalar noise scales, outlier controls, and Bernoulli constraints do not belong in one large family-switch signature. |
| Uniform interval/box/rectangle sampling | Belong to dgraphs and encode draw ordering/algorithm identity; similar distributions do not guarantee frozen-seed equivalence. |
| Validation, comparison, checksum functions | Answer different reproducibility questions and return different information. Group their documentation. |

`get.region.boundary()`, `lps.backend.diagnostics()`,
`metric.graph.heat.eta.grid()`, `metric.graph.heat.extend.lower()`,
`pttf.operator.filter.rows()`, and `ssrhe.support.grid()` should initially stay
exported in an advanced section. The lower-heat-time helper is explicitly
designed for an external search controller; it is not obviously accidental
public surface. A later ownership/usage review could relocate the boundary
utility to dgraphs, but no existing replacement has been established here.

`malps.gcv()` is a diagnostic of an existing fit, even though `fit.malps()` can
already use GCV for support selection. Keep that distinction. Similarly, keep
the grouped-fold helper and nested-CV wrapper: preventing group leakage and
assessing the tuned procedure are useful user operations.

## Migration sequence and expected benefit

| Step | User-visible benefit | Eventual explicit exports |
|---|---|---:|
| Current API plus task guide | Users can find functions without learning every name. | 93 |
| Retire 25 dgraphs re-exports after migration | Clear package ownership. | 68 |
| Consolidate the three quadratic Hessian fitters | One estimator entry point with explicit tuning mode. | 66 |
| Replace six refit exports with one generic | One operation name, class-specific documented behavior. | 61 |
| Replace two smoother-matrix exports with one generic | One extraction operation, method-specific restrictions. | 60 |
| Consolidate harmonic interfaces after semantic alignment | Optional tracking on a defined smoothing operation. | 59 |

These are cumulative steady-state counts, assuming old exports are actually
retired and no unrelated exports are added. Adding generics while keeping all
compatibility functions may temporarily increase the export count. The later
lifting-family option is excluded from these totals. If re-exports are retained
for convenience, the quadratic merger alone takes the count from 93 to 91.

Implement the documentation and ineffective-argument cleanup first. Next
prototype quadratic Hessian selection and refit dispatch. Require equivalent
fitted values, selected penalties, weights, diagnostics, class compatibility,
and expected errors on representative existing tests before deprecating any
old call. Confirm matrix responses only where already supported, and test
missing-label CV separately from fully observed GCV. For stochastic tuning,
fix seeds and compare selection diagnostics as well as final predictions.

Keep a release-level mapping of old calls to new ones, with examples. Review
downstream use and announce the retirement release before removing exports.
No removal or numerical/API behavior change is part of this documentation pass.

## Validation of this documentation pass

The catalog checker verified all 93 exports appear exactly once and recorded
all 68 local signatures and 34 S3 registrations. Local Markdown link targets
were checked. The HTML vignette rendered with its regression and occupation
examples evaluated, and the regenerated package help passed `tools::checkRd`.

The initial `make document` attempt failed because the default installed
dgraphs was 0.2.0, below this checkout's requirement of 0.2.1.9000. Roxygen
generation succeeded after loading the sibling dgraphs source. That full
generation also reclassified `compare.synthetic.dataset` as an S3 method;
those unrelated NAMESPACE/help changes were restored, preserving the existing
93-export API. Only the intended package overview help change was retained.
Thus the retry does not establish that an unmodified `make document` works in
the current installed-library environment.

The source-loaded geosmooth session could render the guide examples, but could
not load the harmonic native symbol. The harmonic comparison above therefore
used `Rcpp::sourceCpp("src/harmonic_smoothing_native.cpp")` followed by
`source("R/harmonic_smoother.R")` in a fresh session. It tests the current source
implementation, not the installed package binary. A full package build,
installation, and CRAN-style check were not run for this documentation change.

To refresh the catalog and signature appendix from the package root:

```sh
Rscript scripts/audit_api_guide.R
```

To render the guide with compatible source namespaces already available:

```r
pkgload::load_all("../dgraphs", quiet = TRUE, compile = FALSE, export_all = FALSE)
pkgload::load_all(".", quiet = TRUE, compile = FALSE, export_all = FALSE)
dir.create("validation/api-guide", recursive = TRUE, showWarnings = FALSE)
rmarkdown::render(
  "vignettes/function-guide.Rmd",
  output_dir = normalizePath("validation/api-guide")
)
```

Using `compile = FALSE` assumes any native routines needed by the examples are
already available; it is not a replacement for building/installing the package
when checking native methods. The guide's examples ran in the source session
described above; native-method verification has the separate scope just stated.
