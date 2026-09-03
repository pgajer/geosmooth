---
title: "Regression and signal estimation on graphs: an R software review"
subtitle: "Positioning geosmooth for an R Journal software paper"
lang: en
bibliography: references.bib
link-citations: true
---

## 1. Main findings

**geosmooth can be described as implementing established graph-signal filtering
and geometric regression methods alongside experimental extensions. It should
not be described, without qualification, as implementing the methods of both
Shuman et al. and Belkin et al.** The first is a survey containing a spectral
filter that can be matched to geosmooth; the second proposes particular
kernel-based algorithms that were not identified in geosmooth's exported API.
The more direct methodological references for its established regression
implementations are Wang et al. for graph trend filtering and Kim, Steinke,
and Hein for Hessian-energy regression [@shuman2013Graphs;
@belkin2006Manifold; @wang2016GraphTF; @kim2009Hessian; @geosmoothSource].

This review covers **ten neighboring R packages**, selected for direct method
overlap or a potentially confusing use of the term graph regression. Six are
currently listed on CRAN; three are archived there, and one has a removed
Bioconductor release with a separately available maintainer repository. The
package profiles below document these distinctions. The review is a targeted
documentation and source assessment, not an exhaustive systematic review,
installation test, performance benchmark, or proof that any method lacks an R
implementation.

The practical conclusion is that **the software gap cannot be the absence of
regression on graphs in R**. The paper should establish what geosmooth adds
through its particular local-coordinate models, constructed operators,
diagnostics, and combined workflows. Signal denoising, Laplacian smoothing,
graph total variation, and graph-based semi-supervised classification already
have relevant R implementations.

## 2. What counts as regression on a graph?

The central setting is a graph $G=(V,E)$ whose vertices represent observations
or locations, with an outcome attached to some or all vertices. Four tasks
must be distinguished:

- **Denoising:** estimate a signal from noisy measurements available at all
  vertices. There need not be a missing-response interface.
- **Reconstruction on a fixed graph:** estimate values at vertices with no
  observed response, using the graph and the remaining responses. This is a
  transductive task: the target vertices are part of the fitted geometry.
- **Inductive prediction:** predict at new observations or locations not
  included during fitting. A model needs an explicit extension rule.
- **Classification or probability estimation:** predicting a class label, a
  decision score, and a calibrated probability are different outputs. A
  least-squares classifier is not automatically a continuous-response
  regression interface, and a classifier's score need not estimate prevalence.

Another distinction concerns **what the graph connects**. A graph on predictor
variables regularizes regression coefficients; it is not ordinarily a graph
on sampled observations. Metric graphs add a further distinction: their edges
are continuous intervals with lengths, so predictions can occur along edges,
not just at vertices. These differences determine which comparisons are fair.

The profiles identify functions, graph inputs, statistical outputs, prediction
scope, tuning, availability, and relevance. “Not established” means the
inspected interface did not establish a capability; it is not a package-wide
claim of absence.

## 3. Which published methods can be attributed to geosmooth?

### Spectral graph filtering: a direct match with a qualification

Shuman et al., Section III-A and Example 2, describe spectral filtering and
Tikhonov graph denoising. For a symmetric positive-semidefinite graph Laplacian
$L=U\Lambda U^\top$, the latter has the form

$$
\widehat f=U\operatorname{diag}\!\left\{
\frac{1}{1+\eta\lambda_j}\right\}U^\top y,
\qquad \eta>0,
$$

where $y$ is the fully observed signal and $\lambda_j$ are the eigenvalues of
$L$ [@shuman2013Graphs].

`fit.metric.graph.lowpass(filter.type = "tikhonov")` uses precisely this
spectral multiplier. Its heat filter instead uses $\exp(-\eta\lambda_j)$.
The exact Tikhonov match requires the same Laplacian, smoothing parameter,
and a complete eigenbasis; a truncated basis gives a restricted spectral
approximation. Graph construction and length-to-conductance conversion are
also part of the specification. The fitter selects among candidate parameters
by generalized cross-validation. It rejects `NA`, `NaN`, and infinite
responses: **this interface is not a missing-measurement reconstructor**
[@geosmoothSource].

### Graph trend filtering: established operator family, explicit solver credit

Wang et al., Section 2.2, define least squares with an absolute graph-difference
penalty and recursive operators beginning with the incidence matrix, the
Laplacian, and their product. geosmooth's recursive family implements orders
0, 1, and 2; the unit-weight setting matches these unweighted operator
definitions. Its weighted conventions must be specified separately. Fitting
uses `genlasso`, so the contribution is not an independently developed
generalized-lasso solver [@wang2016GraphTF; @geosmoothSource].

### Hessian-energy regression: reconstruction is supported here

Kim, Steinke, and Hein construct local quadratic derivative estimates in PCA
coordinates and penalize their accumulated Hessian energy. Their final
criterion uses only labeled observations in its data-fit term
[@kim2009Hessian].

`fit.ssrhe.hessian.regression()` documents the corresponding second-order
construction and accepts missing responses through zero observation weights.
It solves a system of the form

$$
(W+\lambda_1 B+\lambda_2 B_S+\epsilon I)\widehat f=Wy,
$$

where $W$ contains observation weights, $B$ is the Hessian-energy matrix,
$B_S$ is an optional stabilizer, and $\epsilon$ is an optional ridge. Missing
entries of $y$ are replaced internally for this calculation and assigned zero
weight. With labeled indicators, no supplemental penalties, and the published
operator conventions, the paper's loss normalization is matched by setting
the package penalty multiplier to the number of labels times the paper's
multiplier. This supports a **semi-supervised geometric regression** claim,
not an arbitrary graph-only input claim: the operator still requires
coordinates. Numerical parity with the original software was not rerun for
this review [@geosmoothSource].

### Belkin-style manifold regularization: related framework, not verified implementation

Belkin et al. combine prediction loss, an ambient reproducing-kernel penalty,
and a data-graph penalty, producing Laplacian regularized least squares and
Laplacian SVM algorithms. Sharing a graph Laplacian is insufficient to establish
algorithmic equivalence [@belkin2006Manifold]. No corresponding exported
kernel LapRLS or Laplacian SVM fitter was identified in geosmooth. Use this
paper as related methodology, not as an attribution for a verified geosmooth
implementation [@geosmoothSource].

### Experimental and package-specific constructions

Keep path-divided-difference graph operators and the third-derivative
Hessian-family extension separate from their published baseline methods;
their documentation explicitly marks them experimental. Local polynomial
lifting, synchronization, and model averaging also require their own precise
definitions and provenance, rather than inheriting the identity or guarantees
of a neighboring method. This review does not establish their novelty.
The Bernoulli local-likelihood fitter currently uses coordinate supports;
regional harmonic smoothing is not an interchangeable arbitrary-label
propagation interface [@geosmoothSource].

**Suggested paper wording:**

> geosmooth provides implementations of established spectral graph filters,
> graph trend-filtering operators, and Hessian-energy regression, together
> with local polynomial methods and experimental geometric regularizers.
> These methods address signal estimation on graphs and sampled geometry,
> with input requirements and prediction capabilities documented separately
> for each method family.

## 4. Direct and closely related R implementations

### 4.1 gasper — spectral graph-signal denoising

- **Inspected version and status:** 1.1.6; listed on CRAN.
- **Methods and interface:** graph Fourier and spectral graph wavelet
  transforms, with `forward_sgwt()`, `inverse_sgwt()`, and SURE-based
  threshold selection through `SUREthresh()`. Inputs include vertex signals
  and a Laplacian eigensystem; graph-construction utilities are supplied.
- **Target and tuning:** denoising by thresholding graph-wavelet coefficients;
  SURE uses noise-level information and a threshold grid.
- **Limits:** inverse transformation reconstructs a signal from coefficients;
  this alone does not establish imputation of unobserved vertices. An
  inductive regression interface was not established by the inspected paths.
- **Relevance:** an essential graph-signal comparator, with a different
  estimator from geosmooth's low-pass shrinkage. Compare the estimators, not
  just whether both packages use an eigendecomposition [@gasperReview].

### 4.2 genlasso — arbitrary-graph fused lasso and supplied-operator fitting

- **Version and status:** 1.6.1; listed on CRAN.
- **Methods and interface:** `fusedlasso()` accepts an `igraph` graph or an
  incidence penalty matrix. `genlasso()` accepts a general penalty matrix;
  `trendfilter()` supplies univariate trend filtering, not automatically
  arbitrary-graph higher-order operators.
- **Target and tuning:** continuous-response penalized least squares;
  regularization paths, fitted values, and degrees of freedom are exposed.
- **Limits:** a user can formulate partially observed node estimation with a
  selection design, but rank-deficiency/ridge conventions matter. This is
  additional formulation work, not a universal missing-data interface.
- **Relevance:** both comparator and geosmooth dependency. Distinguish an
  operator constructor from the solver that accepts it; avoid counting the
  same backend as an independent computational innovation
  [@genlassoGraphReview; @genlassoDocs].

### 4.3 flsa — graph total-variation signal approximation

- **Version and status:** 1.5.5; listed on CRAN.
- **Methods and interface:** `flsa()` uses a `connListObj` to specify which
  coefficient differences are penalized. The documented connection list
  supports general adjacency, not only line or rectangular-grid defaults.
- **Target and tuning:** numeric signal approximation, separate magnitude
  and fusion penalties, and extraction from a computed solution path.
- **Limits:** graph connection indices are zero-based. This interface is
  not a higher-order graph-polynomial constructor. A general missing-label
  or new-vertex prediction path was not established here.
- **Relevance:** a dedicated order-zero graph total-variation comparator.
  Disable the magnitude penalty when comparing pure fusion, and record
  algorithmic controls that can trade accuracy for speed [@flsaReview].

### 4.4 mgcv — graph-structured smooths inside regression models

- **Version and status:** 1.9-4; listed on CRAN as a recommended R package.
- **Methods and interface:** `s(node, bs = "mrf", xt = list(nb = ...))`
  accepts named neighborhoods; `xt$penalty` permits a supplied
  positive-semidefinite penalty. The default neighborhood penalty is a graph
  Laplacian. `gam()` integrates this smooth with other model terms and
  response families, including binomial models.
- **Target and tuning:** continuous or generalized responses,
  smoothing-parameter estimation, and model-based prediction.
- **Limits:** unobserved graph levels require explicit level/knots handling
  and basis-dimension constraints. The areal-data documentation does not
  require polygons when neighborhoods are supplied. Adapting it to one
  factor level per sampled vertex is a formulation to test, not a benchmark
  already performed.
- **Relevance:** a strong existing alternative for graph-informed conditional
  means and binary probabilities [@mgcvMrfReview; @mgcvGamDocs].

### 4.5 RSSL — explicit manifold-regularized classifiers

- **Version and status:** 0.9.8; listed on CRAN. Current source was inspected
  because some indexed help pages still show 0.9.7.
- **Methods and interface:** `LaplacianSVM()` and
  `LaplacianKernelLeastSquaresClassifier()` explicitly implement Belkin-style
  manifold regularization. They build a nearest-neighbor graph from labeled
  and unlabeled feature matrices. `GRFClassifier()` implements harmonic
  label propagation.
- **Target and tuning:** class prediction, with kernel, graph, and penalty
  controls. The kernel least-squares object also exposes decision values and
  prediction at new feature vectors.
- **Limits:** these are classifier interfaces, not documented general
  continuous-response regressors. Decision scores are not automatically
  calibrated prevalence estimates. `GRFClassifier()` is explicitly
  transductive; its targets must be included as unlabeled observations.
- **Relevance:** the most direct reviewed comparator for a future geosmooth
  classification claim, not evidence that geosmooth already implements the
  same algorithms [@rsslReview].

### 4.6 SSL — historical Laplacian learning implementations

- **Version and status:** 0.1; archived on CRAN on 2019-09-03 at the
  maintainer's request.
- **Methods and interface:** `sslLapRLS()` fits a kernel/Laplacian system
  using labeled and unlabeled features; `sslRegress()` contains graph-power
  regularization and interpolation paths.
- **Important output restriction:** both documented workflows take binary
  labels. Inspected code thresholds fitted scores to return $-1$ or $1$.
  The names do not establish a public continuous-regression interface.
- **Relevance:** historical coverage of graph learning in R, not a preferred
  current benchmark dependency. Any reuse would require installation,
  numerical-convention, and output-contract checks [@sslReview].

### 4.7 SSLR — an interface layer, not a separate Laplacian solver

- **Version and status:** 0.9.3.3; archived on CRAN on 2025-05-21 because it
  required the archived `conclust` package.
- **Verified paths:** `LaplacianSVMSSLR()` calls `RSSL::LaplacianSVM()`;
  `GRFClassifierSSLR()` calls `RSSL::GRFClassifier()`.
- **Scope:** the package's broader title includes regression and clustering,
  but these two inspected graph paths are classifiers and wrappers. They
  should not be counted as independent implementations of the same solver.
- **Relevance:** useful interface history; use RSSL directly for the
  corresponding core-method comparison [@sslrReview].

### 4.8 MetricGraph — probabilistic regression on metric networks

- **Version and status:** CRAN release 1.6.0. The inspected author vignette
  is from the development documentation, labeled 1.6.0.9000; these versions
  are not treated as identical tested installations.
- **Methods and interface:** `graph_lme()` fits models with covariates and
  graph-supported Gaussian random effects; `predict()` supplies kriging.
  The vignette covers Whittle–Matérn fields and also vertex-based
  graph-Laplacian models.
- **Domain and limits:** metric graphs allow locations along continuous
  edges. This differs from a point-cloud similarity graph, although the
  documented vertex models create additional overlap. New locations on a
  fixed metric network are not arbitrary new graph topologies.
- **Relevance:** include when discussing probabilistic graph regression and
  uncertainty. Benchmark only a matched domain/model, after confirming its
  availability in the pinned release [@metricGraphReview].

## 5. Related packages whose graphs play a different role

### 5.1 glmgraph — predictor-network regularization

- **Version and status:** 1.0.3; archived on CRAN on 2021-04-07 because
  check problems were not corrected in time.
- **Method:** `glmgraph(X, Y, L, ...)` combines a sparsity penalty with a
  Laplacian penalty in Gaussian or binomial regression. Its documented
  example constructs a graph on the columns of `X`.
- **Relevance:** demonstrates graph-constrained regression in R, but its
  ordinary use smooths predictor coefficients, not an outcome field over
  an observation graph. Do not treat it as a direct node-denoising comparator
  without an explicit reformulation [@glmgraphReview].

### 5.2 netReg — predictor- and response-network coefficient penalties

- **Version and status:** maintainer source reports 1.12.0. Bioconductor
  lists netReg among removed packages; the current-release package URL
  returned 404. The maintainer source remains accessible. Installation was
  not attempted.
- **Method:** `edgenet()` uses affinity matrices on predictors and/or response
  variables to regularize rows/columns of a regression coefficient matrix;
  the documented interface includes Gaussian and binomial families.
- **Relevance:** important terminology boundary. Neither affinity matrix
  connects the rows representing sampled observations. Multiple response
  variables do not make this an estimator of local association fields on
  an observation graph [@netregReview].

## 6. Consequences for the software paper

The following is a **comparison plan inferred from the inspected capabilities**,
not an empirical ranking:

1. **Fully observed continuous signals:** compare geosmooth's low-pass and
   local-model methods with a clearly specified Laplacian smoother, gasper
   denoising, and graph total variation through genlasso or flsa. Include
   mgcv where its model specification is appropriate.
2. **Partially observed continuous outcomes:** use a separate experiment with
   an explicit observation mask. Compare only methods with a verified masked
   loss or reconstruction path. Do not pass missing responses to the current
   geosmooth low-pass fitter or equate wavelet synthesis with imputation.
3. **Binary outcomes:** distinguish probability estimation from classification.
   Include a binomial graph smooth for probability questions; RSSL is relevant
   for class prediction. Use calibration and probability losses only for
   outputs that actually have a probability interpretation.
4. **Metric-network regression:** include MetricGraph only where the
   observation domain and latent-field assumptions make it a fair comparator.
5. **Operator contributions:** compare geosmooth's constructed penalties with
   established ones while controlling the solver. A shared `genlasso`
   backend can help isolate the effect of the operator itself.

Match the graph, edge-weight meaning, Laplacian normalization, observation
mask, and tuning information wherever feasible. If a method builds its own
graph, disclose the resulting difference. Separate fixed-graph transduction
from inductive prediction; allow all methods the same legitimate access to
unlabeled covariates. Report numerical failures and tuning cost rather than
only successful fits. Do not infer speed from implementation language.

**The promising contribution to substantiate:** making graph-informed local
polynomial estimation and several geometric penalties available as inspectable
R workflows, with explicit neighborhood/coordinate choices and diagnostics.
The present review establishes neighboring capabilities. It does not yet
establish that this combination is unique, easier to use, or more accurate.
That requires a version-pinned workflow comparison and a reproducible
scientific example.

## 7. Search scope, provenance, and verification

- **Evidence date:** 2026-09-02. Availability is an observation on that date,
  not a promise of future installation success.
- **Search:** targeted searches combining R/CRAN with graph signal processing,
  Laplacian regularization, graph fused lasso, semi-supervised learning, and
  graph regression; followed by official manuals, maintainer documentation,
  CRAN source mirrors, and the cited primary papers. Package references and
  wrappers were followed to identify shared implementations.
- **Selection:** eight direct or domain-adjacent packages and two
  predictor-network contrasts. General graph libraries, graph estimation,
  clustering-only software, neural-network frameworks, and non-R libraries
  were outside the main comparison. This is not a count of every eligible
  package in the ecosystem.
- **geosmooth baseline:** version 0.1.0, commit
  `9af73498f6e56c9ad9caf9d3b30b169d94eb8de2`. The inspected files include
  `R/metric_graph_lowpass.R`, `R/graph_trend_filtering.R`,
  `R/ssrhe_hessian_energy.R`, `R/harmonic_smoother.R`,
  `R/local_likelihood.R`, the local-model files, and `NAMESPACE`.
- **Checks performed:** primary-source reading, relevant public-interface and
  implementation inspection, current repository-status lookup, bibliography
  verification, and document rendering. **No packages were installed and no
  fitting experiments or runtime benchmarks were executed for this review.**
- **Evidence trail:** [citation verification](citation_verification.html)
  records the supporting passages, package versions, and limitations;
  [references.bib](references.bib) contains the cited metadata. Mutable
  documentation should be replaced or supplemented by archived source bundles
  when fixing the eventual paper's benchmark environment.
- **Rebuild:** from the repository root, run
  `make -C manuscripts/r-journal`. The HTML timestamp records document
  generation, not a fresh network search or rerun of software comparisons.

## References
