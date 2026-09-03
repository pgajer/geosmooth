---
title: "geosmooth: statement of the gap"
subtitle: "Bullet-point draft for an R Journal software paper"
lang: en
bibliography: references.bib
link-citations: true
---

## 1. Proposed central statement

- **The scientific motivation:** a data-derived graph can be more than a way
  to partition observations. It can supply neighborhoods for estimating how
  outcomes vary across the represented population: where a binary outcome is
  more frequent, how a continuous response changes, and where different
  response patterns vary together.
- **The motivating contrast:** a partition summarizes observations by group
  membership; a fitted response field describes variation within and between
  those groups without requiring a partition first. Neither target replaces
  the other. Use “coarse structural summary,” rather than “naive topological
  characterization,” for clustering: an algorithmic partition is not generally
  the connected-component decomposition or a topological invariant.
- **The software problem:** make this outcome-centered analysis practical in
  R, with neighborhood selection, local coordinates, fitting, and
  regularization explicit enough to inspect and compare.
- **The proposed contribution:** geosmooth brings local polynomial prediction,
  averaging of local models, and geometric regularization into one package,
  with explicit support and coordinate choices in the relevant method families
  and inspectable fitted objects and operators [@geosmoothSource].
- **The broader program:** extend a range of regression tools to data-derived
  graph neighborhoods, beginning with conditional means and probabilities and
  developing local association analyses from them. “The whole statistical
  regression apparatus” describes an ambition, not the present package scope.
- **The gap to substantiate:** the practical work needed to connect these
  components for a particular dataset, not the invention of regression on
  graphs. Graph-based regularization already supports regression and
  classification [@belkin2006Manifold]. Whether geosmooth reduces that work
  relative to existing alternatives remains a comparison question.
- **Candidate introduction wording:** “A graph constructed from observations
  can serve both as a summary of their relationships and as a domain for
  statistical estimation. Rather than requiring observations to be partitioned
  before outcomes are compared, graph-informed regression can describe how
  conditional means and outcome probabilities vary across the represented
  population. Motivated by this perspective, geosmooth provides local-model
  and geometric-regularization tools for nonparametric estimation.” This is
  motivation and scope, not a claim of priority or better prediction.

## 2. The intended user and analysis problem

- **User:** an applied researcher or statistical method developer working with
  numerical observations, an embedding, or a supplied weighted graph, who
  needs to estimate a response surface or smooth a signal at observed nodes.
- **What is being conditioned on:** let $Z$ denote the covariates or state
  used to define the analysis space. Vertices represent observations at
  $z_i$, and weighted edges encode a chosen notion of proximity. The graph
  supplies a finite representation of that geometry; conditioning on an
  arbitrary vertex identifier alone is not the scientific estimand. Specify
  whether the target is a population regression function or only values on a
  fixed observed graph.
- **Binary outcome:** for $D\in\{0,1\}$,
  $m_D(z)=\mathbb{E}[D\mid Z=z]=\Pr(D=1\mid Z=z)$.
  Thus conditional-mean estimation gives a local probability field. Calling
  that field population disease prevalence additionally requires a sampling
  design or adjustment that supports the population interpretation; a selected
  study sample need not do so.
- **Continuous outcome:** for an integrable response $Y$, the corresponding
  target is $m_Y(z)=\mathbb{E}[Y\mid Z=z]$. The conditional mean does not by
  itself describe conditional variance, tails, or uncertainty in its estimate.
- **Association between fitted fields:** study whether $m_A$ and $m_B$ rise
  and fall together across a specified neighborhood, or whether their local
  changes align. This answers the motivating question about association
  between the estimated response patterns. Define the neighborhood weights
  and the chosen measure; field co-variation and gradient alignment are not
  interchangeable quantities.
- **Residual association is a different target:** with finite second moments,
  $c_{AB}(z)=\operatorname{Cov}(A,B\mid Z=z)
  =\mathbb{E}[AB\mid Z=z]-m_A(z)m_B(z)$.
  This concerns deviations around the conditional means, not their co-variation
  across locations. For example, $A=f(Z)+\epsilon_A$ and
  $B=f(Z)+\epsilon_B$ have identical mean fields when both errors have
  conditional mean zero, yet have zero conditional covariance when the errors
  are conditionally independent. These are complementary analysis layers.
- **Keep the graph's role explicit:** a graph whose vertices are observations
  is not a variable-association network whose vertices are outcomes. An
  association analysis on the former might later produce the latter, but they
  encode different objects.
- **Neighborhood:** the observations allowed to inform a local fit. In the
  relevant geosmooth methods, the neighborhood may be selected through
  coordinate distances or shortest-path distances in a supplied graph.
- **Local coordinates:** the variables used to fit a polynomial inside a
  neighborhood. Centered observed coordinates and coordinates from local
  principal component analysis (PCA) are distinct choices; selecting graph
  neighbors does not itself turn observed coordinates into intrinsic ones.
- **Combination or regularization:** local predictions may be averaged, or
  local residuals and derivatives may define a penalty on fitted values.
  These operations answer related but non-identical estimation questions.
- **Motivating comparison:** on the same observations, determine whether
  changing support distance, local coordinates, or regularization changes
  accuracy, stability, and computational cost. No improvement is assumed.

## 3. Existing uses of data-derived graphs and neighboring R software

### Uses beyond clustering

- **Dimensionality reduction and representation:** graph spectra and diffusion
  provide ways to organize or embed observations; graph-signal methods also
  support filtering, denoising, and reconstruction of missing node values
  [@shuman2013Graphs]. These uses can concern geometry, signals on that
  geometry, or both.
- **Regression and semi-supervised classification:** manifold regularization
  combines a prediction loss with a data-graph penalty. It is direct prior
  work for the idea of estimating outcomes using sampled geometry
  [@belkin2006Manifold].
- **Trajectories and transitions:** single-cell analysis uses neighborhood
  graphs to study continuous transitions and branching relationships. PAGA
  connects a coarse grouping with trajectory structure rather than treating
  clustering and continuous variation as mutually exclusive [@wolf2019Paga].
- **Positioning:** these examples show that graph use is not limited to
  clustering. Treat a cluster-first workflow as the motivating setting, not
  as a quantified claim about the majority of all graph applications.

### Existing R capabilities

- `stats::loess()` fits local polynomial surfaces using distance-weighted
  neighborhoods. Local polynomial regression itself is therefore not the
  software gap [@loessDocs].
- `locfit` provides local regression and likelihood fitting, including density
  estimation, with a formula interface. Combining regression and density
  estimation in one package is not by itself a distinctive contribution
  [@locfitDocs].
- `mgcv::gam()` provides penalized regression-spline models, smoothing-parameter
  estimation, and smooth terms involving multiple covariates. Its documentation
  also describes sphere smooths and Gaussian Markov random fields. The paper
  must not characterize existing GAM software as only one-dimensional or as
  lacking all geometric or graph-related modeling facilities [@mgcvGamDocs].
- `genlasso` solves generalized-lasso problems for user-supplied penalty
  matrices and provides specialized trend-filtering and fused-lasso routines.
  The generic optimization problem is not new to geosmooth [@genlassoDocs].
- These examples establish overlap, not an exhaustive software review. The
  [targeted R graph-regression review](r_graph_regression_review.html) extends
  the comparison to graph-signal and semi-supervised implementations. A fuller
  method-by-method assessment remains necessary before making an absence or
  priority claim.

## 4. The narrower contribution supported by the current package

- **Separate support distance from local coordinates.** Model-averaged local
  polynomial smoothing (`fit.malps()`) and local polynomial lifting operators
  expose both support-metric and coordinate-method settings. This supports
  controlled comparisons of the two choices, although not every method
  accepts the same settings [@geosmoothSource].
- **Begin with conditional-mean and probability estimation.**
  `fit.local.likelihood(..., likelihood.family = "bernoulli")` implements
  local logistic fitting, but currently uses coordinate supports. This is not
  evidence that all graph-supported smoother families have a Bernoulli
  likelihood. Unconstrained least-squares smoothing of binary values can
  produce values outside $[0,1]$; a probability example must use a suitable
  estimator and check calibration. The exported API does not yet supply the
  complete local-association layer described above [@geosmoothSource].
- **Connect local models to explicit regularization operators.**
  `lpl.tf.operator()` constructs rows from self-excluded local prediction
  residuals. `slpl.tf.operator()` adds a component comparing local prediction
  maps over overlapping supports. The software contribution includes
  constructing, inspecting, and fitting with these objects; any claim that
  the estimators themselves are new requires a separate literature assessment.
- **Make numerical decisions inspectable.** Local polynomial lifting operators
  retain support information, row metadata, and diagnostics, and explicitly
  record dropped rank-deficient rows. These details can help users identify
  why a particular geometric construction is unsuitable for their data.
- **Provide an implementation of an established Hessian-energy approach.**
  The SSRHE operator exposes a local derivative operator, its quadratic energy
  matrix, and optional diagnostics. Its documentation identifies it as an
  implementation of prior methodology, not an invention of this package.
- **Use existing infrastructure explicitly.** Graph construction and
  shortest-path services belong to `dgraphs`; generalized-lasso fitting uses
  `genlasso` in relevant paths. The paper should credit those dependencies
  and identify geosmooth's contribution at their interface with local models.
- The preceding implementation statements refer to the inspected source
  baseline [@geosmoothSource]. They do not establish that another package
  cannot provide an equivalent workflow.

## 5. Boundaries that keep the gap precise

- **New methods:** local lifting, synchronization, or model-averaging variants
  are candidates for methodological contributions. Do not label them novel
  until the mathematical definitions have been compared with prior work and
  the relevant method paper or preprint has been checked.
- **New implementations:** describe compiled code, diagnostics, and exposed
  operators as implementation contributions. A compiled implementation does
  not establish a speed advantage without an appropriate benchmark.
- **Integration:** test whether the package simplifies a meaningful combined
  analysis. A common package name does not imply one interchangeable API or
  identical statistical assumptions across all methods.
- **Prediction versus node-value estimation:** `predict.lpl_tf` currently
  returns training-point fitted values only. MALPS supports new-point
  prediction for coordinate supports, but not for graph-geodesic supports.
  Do not present all method families as unrestricted out-of-sample predictors
  [@geosmoothSource].
- **Scope:** lead the paper with regression. Include density estimation as a
  central contribution only if a complete example establishes why it belongs
  in the same argument. Local PCA should not be described as guaranteed
  recovery of intrinsic geometry, nor as removing dimensionality constraints.
- **Statistical interpretation:** the chosen graph is a modeling decision,
  not a guarantee that the response is smooth in its neighborhoods. State
  which variables built it. If an outcome or the variables whose association
  is being assessed also define the graph, explain the resulting conditioning
  and potential circularity; do not interpret the result as independent
  evidence of association. No causal interpretation follows from proximity
  or fitted-field co-variation alone.
- **Estimation versus inference:** fitted fields are not automatically
  confidence bands or calibrated hypothesis tests. Uncertainty accounting for
  tuning and estimated geometry, and tests for local associations, require
  their own methods and validation before being claimed as package facilities.
- **Performance:** make no current claim of universal superiority, scalability
  to arbitrary sample sizes, or reliable behavior on every geometric structure.

## 6. Evidence needed to turn the proposed gap into the paper's claim

- **Related-software comparison:** document supported inputs, neighborhood
  choices, coordinate models, penalties, tuning, prediction targets, diagnostics,
  and computational limits. Record package versions and source references.
  Distinguish a feature absent from documentation from one verified absent
  from the implementation.
- **A worked comparison of workflows:** solve one representative problem with
  geosmooth and an appropriate existing approach. Show the extra code or
  decisions needed by each; allow the result to favor the existing approach.
- **A motivating outcome analysis:** contrast a cluster-wise summary with a
  graph-informed conditional-mean field, including a continuous response and,
  where supported, a binary outcome. Show what within-group variation matters
  scientifically. Include a suitable existing graph-regression or graph-signal
  smoother; clustering alone is not a sufficient predictive comparator.
- **A geometric ablation:** vary the support distance and local coordinates
  separately, then examine the role of averaging or regularization. Use
  comparable tuning budgets and retain failures in the accounting.
- **Evaluation matched to the task:** for prediction at unseen observations,
  fit data-derived preprocessing and tuning within the training procedure. For
  a fixed observed graph with withheld responses, state explicitly which
  coordinates and graph structure are available to every method.
- **Numerical and runtime evidence:** use an optimized installed package,
  distinguish full fitting from cached refits, and report sample size,
  dimension, memory costs, and failure conditions. Existing development
  reports need a reproducibility review before supplying manuscript results.
- **A real analysis:** establish a scientific reason to consider geometry and
  show a complete, portable workflow with interpretable outputs.
- **Decision rule:** if the comparisons show little practical distinction,
  narrow the paper to the operator implementations or to the method family
  with a demonstrable contribution. Do not preserve a broad gap claim by
  weakening the comparators.

## 7. Evidence status and scope of this draft

- The four neighboring-R-software capability statements have been checked
  against their documentation. Three methodological sources establish relevant
  graph uses, without constituting an exhaustive review. The geosmooth
  implementation statements were checked against commit
  `9af73498f6e56c9ad9caf9d3b30b169d94eb8de2`.
- This is a user-facing manuscript outline. No benchmark or scientific
  experiment was run to produce it. Comparative novelty, superiority, and
  practical workflow savings are still unestablished.
- [Citation evidence](citation_verification.html) records the exact scope of
  each source. [Build instructions](README.md) explain how to render and check
  this document. Documentation citations are starting evidence for capability
  statements; the full article will also need verification of the specific
  geosmooth methodologies and a more targeted comparison of implementations.

## References
