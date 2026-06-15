# LPS Local-Auto Chart Dimension: Non-Manifold Dataset Specifications

This document specifies candidate datasets for comparing
`fit.lps(..., coordinate.method = "local.pca", chart.dim = "auto")` against
`chart.dim = "local.auto"` on geometries where a single global local-PCA chart
dimension may be inappropriate.

The primary scientific question is not only whether `local.auto` improves Truth
RMSE.  It is also whether the estimated local chart dimension behaves
sensibly over a non-homogeneous state space: lower on curve-like, edge-like, or
cluster-like regions, and higher on surface-like or bulk regions.

## Common Experiment Contract

For every dataset below, save:

- `dataset.id`
- `geometry.family`
- `n`
- ambient dimension `p`
- observed coordinate matrix `X`
- optional latent coordinates `Z`, if synthetic
- region labels, when known
- true function values `f`
- noisy response `y = f + epsilon`
- noise standard deviation `sigma`
- fold IDs
- selected LPS candidates for both chart rules
- fitted values for both chart rules
- CV RMSE, observed RMSE, and Truth RMSE
- resolved global chart dimension for `chart.dim = "auto"`
- per-anchor chart dimensions for `chart.dim = "local.auto"`
- per-region summaries of local dimensions and errors

Use the same folds, support grid, degree grid, and kernel grid for both chart
rules.  The comparison is paired by dataset and response draw.

Recommended initial tuning grid:

```r
support.grid <- 15:35
degree.grid <- 2
kernel.grid <- c("gaussian", "tricube")
coordinate.method <- "local.pca"
local.chart.method <- "pca"
backend <- "R"
auto.chart.support.metric <- "both"
auto.chart.selection.metric <- "operator"
```

Use quadratic local polynomial fits in this comparison.  Fixing
`degree.grid <- 2` keeps the experiment focused on the chart-dimension rule
rather than mixing chart-dimension effects with degree selection effects.

For larger VALENCIA-derived datasets, use a smaller preflight grid first:

```r
support.grid <- c(15, 20, 25, 30, 35)
degree.grid <- 2
kernel.grid <- c("gaussian", "tricube")
```

## Truth Functions

Each geometry should use at least two smooth truth functions:

1. **Smooth mixture of Gaussians on the observed geometry**

   Choose centers from well-separated observed points.  Define

   \[
     f(x_i) =
     \sum_{\ell=1}^L a_\ell
     \exp\left\{
       -\frac{d(x_i,c_\ell)^2}{2s_\ell^2}
     \right\},
   \]

   where `d` is Euclidean distance for synthetic coordinate datasets and graph
   geodesic distance for graph-defined VALENCIA-derived datasets.

2. **Smooth ridge or broad-gradient function**

   For synthetic datasets with latent coordinates, use a broad function such as

   \[
     f(z) = \sin(2\pi z_1) + 0.5 z_2
   \]

   when latent coordinates are available.  For VALENCIA-derived data, use a
   broad geodesic Gaussian or a smooth gradient from one graph region to
   another.

Avoid spike-like or discontinuous truth functions in the main comparison.  The
goal is to test chart-dimension behavior, not edge recovery.

Use noise levels:

```r
sigma.grid <- c(0.05, 0.10, 0.20)
```

For an initial smoke run, use `sigma = 0.10` and one response draw per geometry.

## Real-Geometry Compositional Datasets

### LA-D1-RAW: VALENCIA Depth-1 dCST Four-Component State Space

Source:

- VALENCIA 13k relative abundance matrix.
- Depth-1 merged dCST phylotype groups with minimum CST size 50.
- Expected coarse components: `Li`, `Lc`, `Gv`, `Bv`, subject to actual asset
  names.

Construction:

1. Extract the four depth-1 dCST component abundances.
2. Keep rows with positive total abundance across these components.
3. L1-normalize each row so row sums are 1.
4. Stratified sample by dCST label.

Dataset sizes:

```r
n.grid <- c(250, 500, 1000)
```

Primary run:

```r
n <- 500
```

Labels:

- dominant depth-1 component
- original CST/dCST label, if available

Expected dimension behavior:

- Interior-like mixed samples may have effective dimension up to 3.
- Boundary-heavy samples should often have lower local dimension.
- `local.auto` should reveal dimension variation across compositional faces.

### LA-D1-HC: Depth-1 Hypercube/Homogeneous Embeddings

For each reference component \(r \in \{Li,Lc,Gv,Bv\}\), compute the extended
homogeneous/hypercube embedding from `linf`.

If the four-component composition is

\[
  x = (x_1,x_2,x_3,x_4), \qquad \sum_j x_j = 1,
\]

then the reference-\(r\) embedding is

\[
  \phi_r(x) \in \mathbb R^3,
\]

with coordinates defined by the extended homogeneous-coordinate construction.
The implementation should use the exported `linf` function rather than
reimplementing the embedding.

Dataset IDs:

- `LA-D1-HC-Li`
- `LA-D1-HC-Lc`
- `LA-D1-HC-Gv`
- `LA-D1-HC-Bv`

Expected dimension behavior:

- Embeddings can unfold reference-relative compositional relationships.
- Local dimension may differ by reference component and by proximity to
  boundary strata.

### LA-D2-RAW: VALENCIA Depth-2 dCST State Space

Source:

- Depth-2 merged dCST assets.
- Use all depth-2 groups passing the minimum size threshold.

Construction:

1. Build the depth-2 relative abundance matrix.
2. Keep rows with positive total abundance.
3. L1-normalize rows.
4. Stratified sample by depth-2 dCST label.

Dataset sizes:

```r
n.grid <- c(250, 500, 1000)
```

Primary run:

```r
n <- 500
```

Expected dimension behavior:

- More components than depth-1, with more simplex faces.
- `local.auto` may be more useful than a single global dimension if different
  dCST regions occupy different faces or face intersections.

### LA-D2-HC: Selected Depth-2 Hypercube/Homogeneous Embeddings

Use a selected subset of depth-2 reference components rather than all possible
references.

Reference selection rule:

1. Include the largest depth-2 component by prevalence.
2. Include one component dominated by Lactobacillus-like states, if present.
3. Include one component dominated by diverse/anaerobic states, if present.
4. Include one component near a compositional boundary, if identifiable.

Initial target:

```r
n.references <- 4
```

Expected dimension behavior:

- Reference choice may change whether relationships look locally low-dimensional
  or more spread out.

### LA-D3-RAW: VALENCIA Depth-3 dCST State Space

Source:

- Depth-3 merged dCST assets.
- Use all depth-3 components passing the minimum size threshold.

Construction:

Same as `LA-D2-RAW`.

Primary run:

```r
n <- 500
```

Optional larger run:

```r
n <- 1000
```

Expected dimension behavior:

- Highest compositional complexity among the dCST-derived reduced datasets.
- More local dimension heterogeneity is expected.

### LA-D3-HC: Selected Depth-3 Hypercube/Homogeneous Embeddings

Use a selected subset of reference components:

```r
n.references <- 4
```

Selection rule:

- largest component
- one low-diversity component
- one high-diversity component
- one boundary/sparse component

### LA-13K-SUB: Stratified VALENCIA 13k Full Relative-Abundance State Space

Source:

- Full phylotype relative abundance matrix.
- Do not apply CLR.

Construction:

1. Use the phylotype relative abundance matrix directly.
2. Remove all-zero rows and all-zero columns in the selected sample.
3. L1-normalize rows if needed.
4. Stratified sample by VALENCIA CST or dCST label.

Dataset sizes:

```r
n.grid <- c(500, 1000)
```

Primary run:

```r
n <- 500
```

Expected dimension behavior:

- High ambient dimension with sparse, boundary-heavy compositional structure.
- This is the most realistic non-manifold test.
- `local.auto` should be evaluated carefully for stability and runtime.

## Synthetic Stratified and Singular Geometries

### SYN-PARA-LINE: Paraboloid Plus Intersecting Line

Ambient space:

\[
  \mathbb R^3.
\]

Surface component:

\[
  X_{\mathrm{surf}}(u,v) = (u,v,u^2+v^2),
  \qquad (u,v)\in[-1,1]^2.
\]

Line component:

\[
  X_{\mathrm{line}}(t) = (t,0,t^2),
  \qquad t\in[-1,1].
\]

The line lies on the paraboloid along the \(v=0\) curve.  To create a clearer
dimension-mixture stress test, also allow a transverse line variant:

\[
  X_{\mathrm{line}}^{\perp}(t) = (t,0,0.5t).
\]

Sampling:

```r
n.surface <- round(0.75 * n)
n.line <- n - n.surface
n <- 500
```

Labels:

- `surface`
- `line`
- `near_intersection`

Expected local dimensions:

- Away from the shared curve: surface region near 2.
- Along the isolated/transverse line: near 1.
- Near intersections: unstable or mixed dimension.

### SYN-SADDLE-LINE: Saddle Plus Intersecting Line

Surface component:

\[
  X_{\mathrm{surf}}(u,v) = (u,v,u^2-v^2).
\]

Line components:

\[
  X_{\mathrm{line},1}(t) = (t,0,t^2),
  \qquad
  X_{\mathrm{line},2}(t) = (0,t,-t^2).
\]

Use one line in the first smoke run and both lines in a larger run.

Sampling:

```r
n <- 500
surface.fraction <- 0.75
```

Expected local dimensions:

- Surface: near 2.
- Line: near 1.
- Saddle crossing regions may show mixed local spectra.

### SYN-PARA-SADDLE-UNION: Union of Paraboloid and Saddle

Components:

\[
  X_1(u,v) = (u,v,u^2+v^2),
  \qquad
  X_2(u,v) = (u,v,u^2-v^2).
\]

Sampling:

```r
n <- 600
n.paraboloid <- n / 2
n.saddle <- n / 2
```

Optional separation:

To avoid exact overlap along multiple curves, embed in \(\mathbb R^4\):

\[
  X_1(u,v) = (u,v,u^2+v^2,0),
  \qquad
  X_2(u,v) = (u,v,u^2-v^2,\delta),
\]

with small \(\delta\), for example \(\delta=0.15\).

Expected local dimensions:

- Each component is locally 2D.
- Near intersections or close approaches, local neighborhoods may mix sheets.

### SYN-PLANE-CURVE: Plane Plus Curve

Ambient space:

\[
  \mathbb R^3.
\]

Plane:

\[
  X_{\mathrm{plane}}(u,v) = (u,v,0).
\]

Curve:

\[
  X_{\mathrm{curve}}(t) =
  \left(0.6\cos(2\pi t), 0.6\sin(2\pi t), t - 0.5\right).
\]

Sampling:

```r
n <- 500
plane.fraction <- 0.75
```

Expected local dimensions:

- Plane: near 2.
- Curve: near 1.
- Neighborhoods near curve-plane intersections may have mixed spectra.

### SYN-TWO-PLANES: Two Planes Intersecting Along a Line

Ambient space:

\[
  \mathbb R^3.
\]

Planes:

\[
  P_1 = \{(u,v,0): u,v\in[-1,1]\},
  \qquad
  P_2 = \{(u,0,w): u,w\in[-1,1]\}.
\]

They intersect along the \(x\)-axis.

Sampling:

```r
n <- 600
n.per.plane <- n / 2
```

Labels:

- `plane_1`
- `plane_2`
- `near_intersection`

Expected local dimensions:

- Away from the intersection: near 2.
- Near the intersection: local neighborhoods may look like a crossing of two
  2D sheets rather than a single smooth 2D chart.

### SYN-CONE: Cone or Double Cone

Single cone:

\[
  X(r,\theta) = (r\cos\theta,r\sin\theta,r),
  \qquad r\in[0,1].
\]

Double cone:

\[
  X(r,\theta,s) = (r\cos\theta,r\sin\theta,sr),
  \qquad s\in\{-1,1\}.
\]

Sampling:

```r
n <- 500
```

Use a distribution with extra points near the apex:

```r
r <- runif(n)^2
```

Expected local dimensions:

- Away from apex: near 2.
- Near apex: singular; dimension estimates may become unstable.

### SYN-DISK-CLUSTERS: Disk Plus Isolated Clusters

Ambient space:

\[
  \mathbb R^3.
\]

Disk:

\[
  X_{\mathrm{disk}}(r,\theta)=(r\cos\theta,r\sin\theta,0).
\]

Clusters:

\[
  X_{\mathrm{cluster},j} \sim N(\mu_j,\tau^2 I_3),
  \qquad \tau \ll 1.
\]

Sampling:

```r
n <- 500
disk.fraction <- 0.80
n.clusters <- 3
```

Expected local dimensions:

- Disk: near 2.
- Tight clusters: near 0 or 1 in practice, but chart dimension is bounded below
  by 1.

### SYN-Y-BRANCH: Noisy Y-Shaped Branching Graph

Ambient space:

\[
  \mathbb R^2 \quad \text{or} \quad \mathbb R^3.
\]

Three branches meet at the origin:

\[
  b_j(t)=t(\cos\theta_j,\sin\theta_j),
  \qquad t\in[0,1],
  \qquad
  \theta_j \in \{0,2\pi/3,4\pi/3\}.
\]

Add small transverse Gaussian noise.

Sampling:

```r
n <- 450
n.per.branch <- 150
```

Expected local dimensions:

- Away from branch point: near 1.
- Near branch point: mixed directions; dimension may rise.

### SYN-SIMPLEX-FACES: Boundary-Heavy Simplex Faces

Ambient space:

\[
  \Delta^{p-1} \subset \mathbb R^p.
\]

Initial setting:

```r
p <- 5
n <- 600
```

Sampling:

- 20% from vertices or near-vertices
- 30% from edges
- 30% from 2D faces
- 20% from the simplex interior

All rows should sum to 1.

Expected local dimensions:

- Vertices: chart dimension lower bound 1.
- Edges: near 1.
- Faces: near 2.
- Interior: up to \(p-1\).

This is the synthetic analogue closest to sparse compositional microbiome data.

### SYN-RANK-BLOCKS: Region-Varying Effective Rank

Ambient space:

\[
  \mathbb R^{50}
  \quad \text{or} \quad
  \mathbb R^{100}.
\]

Construct three regions:

1. Rank-1 region:
   \[
     X = t v_1 + \eta.
   \]
2. Rank-2 region:
   \[
     X = u v_1 + v v_2 + \eta.
   \]
3. Rank-4 region:
   \[
     X = \sum_{j=1}^4 z_j v_j + \eta.
   \]

where \(v_j\) are orthonormal ambient directions and \(\eta\) is small ambient
noise.

Sampling:

```r
n <- 600
n.per.region <- 200
p <- 100
```

Expected local dimensions:

- Region 1: near 1.
- Region 2: near 2.
- Region 4: near 4, possibly capped by support size and polynomial degree.

## Frozen Recommended First Batch

The first batch is frozen as the initial comparison suite for
`chart.dim = "auto"` versus `chart.dim = "local.auto"`.  It is geometry-first:
each row below defines one geometry.  The first run should use one primary
smooth Gaussian-mixture truth function per geometry, `sigma = 0.10`, and one
fixed fold assignment.  Secondary truth functions and additional noise levels
should be added only after the first-batch dimension diagnostics have been
inspected.

Use these common fitting settings unless a later audited implementation note
overrides them:

```r
support.grid <- 15:35
degree.grid <- 2
kernel.grid <- c("gaussian", "tricube")
coordinate.method <- "local.pca"
local.chart.method <- "pca"
backend <- "R"
auto.chart.support.metric <- "both"
auto.chart.selection.metric <- "operator"
sigma <- 0.10
response.seed <- 1L
fold.seed <- 20260605L
```

For each frozen geometry, run exactly two LPS variants:

```r
chart.dim.rule <- c("auto", "local.auto")
```

Freeze artifacts were generated by
`scripts/freeze_lps_local_auto_nonmanifold_first_batch.R` and written to:

```text
split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/
```

The directory contains:

- `asset_manifest.csv` with one row per frozen asset and SHA-256 hashes;
- `source_manifest.csv` with source-path hashes for VALENCIA/linf inputs;
- `freeze_summary.md`;
- ignored `.rds` geometry/response assets under `assets/`.

The frozen first-batch registry is:

| Batch ID | Dataset ID | Source family | n | p / ambient rule | Frozen construction |
|---|---:|---|---:|---|---|
| `FB01` | `LA-D1-RAW-N500` | VALENCIA depth-1 dCST | 500 | 4 components | Depth-1 dCST component relative-abundance matrix, rows L1-normalized, stratified by depth-1 dCST label. |
| `FB02` | `LA-D1-HC-Li-N500` | VALENCIA depth-1 hypercube | 500 | 3 | Extended homogeneous/hypercube embedding with `Li` as reference. |
| `FB03` | `LA-D1-HC-Lc-N500` | VALENCIA depth-1 hypercube | 500 | 3 | Extended homogeneous/hypercube embedding with `Lc` as reference. |
| `FB04` | `LA-D1-HC-Gv-N500` | VALENCIA depth-1 hypercube | 500 | 3 | Extended homogeneous/hypercube embedding with `Gv` as reference. |
| `FB05` | `LA-D1-HC-Bv-N500` | VALENCIA depth-1 hypercube | 500 | 3 | Extended homogeneous/hypercube embedding with `Bv` as reference. |
| `FB06` | `LA-D2-RAW-N500` | VALENCIA depth-2 dCST | 500 | number of depth-2 components | Depth-2 dCST component relative-abundance matrix, rows L1-normalized, stratified by depth-2 dCST label. |
| `FB07` | `LA-D2-HC-TOP1-N500` | VALENCIA depth-2 hypercube | 500 | depth-2 components minus 1 | Extended homogeneous/hypercube embedding using the largest depth-2 component by prevalence as reference. |
| `FB08` | `LA-D3-RAW-N500` | VALENCIA depth-3 dCST | 500 | number of depth-3 components | Depth-3 dCST component relative-abundance matrix, rows L1-normalized, stratified by depth-3 dCST label. |
| `FB09` | `LA-13K-SUB-N500` | VALENCIA full phylotype matrix | 500 | selected nonzero phylotypes | Stratified sample from the phylotype relative-abundance matrix. Do not apply CLR. Remove all-zero columns after sampling and L1-normalize rows if needed. |
| `FB10` | `SYN-PARA-LINE-N500` | synthetic stratified surface/curve | 500 | 3 | 75% paraboloid surface plus 25% transverse line segment. |
| `FB11` | `SYN-SADDLE-LINE-N500` | synthetic stratified surface/curve | 500 | 3 | 75% saddle surface plus 25% one intersecting line segment. |
| `FB12` | `SYN-TWO-PLANES-N600` | synthetic singular sheet union | 600 | 3 | Two planes intersecting along a line, sampled 50/50 from each plane. |
| `FB13` | `SYN-SIMPLEX-FACES-N600` | synthetic compositional strata | 600 | 5 | Boundary-heavy 5-component simplex: vertices/near-vertices, edges, faces, and interior. |
| `FB14` | `SYN-RANK-BLOCKS-N600-P100` | synthetic high-dimensional rank strata | 600 | 100 | Three equal regions with effective ranks 1, 2, and 4 plus small ambient noise. |

The first batch deliberately includes:

- one raw low-dimensional dCST geometry;
- all four depth-1 reference-relative hypercube embeddings;
- one raw depth-2 and one raw depth-3 dCST geometry;
- one depth-2 hypercube embedding selected by a deterministic prevalence rule;
- one full high-dimensional VALENCIA phylotype subsample;
- five synthetic geometries with known local dimension structure.

This is the frozen first-pass suite.  The following examples are explicitly
deferred to a second batch unless the first batch reveals a need for them:

- all depth-2 hypercube references;
- all depth-3 hypercube references;
- `SYN-PARA-SADDLE-UNION`;
- `SYN-PLANE-CURVE`;
- `SYN-CONE`;
- `SYN-DISK-CLUSTERS`;
- `SYN-Y-BRANCH`;
- additional truth functions and noise levels.

## Main Figures for the Comparison Report

For each dataset:

1. Truth RMSE paired dot plot:
   - one point for `chart.dim = "auto"`
   - one point for `chart.dim = "local.auto"`
   - connected by dataset/response draw

2. Local dimension diagnostic plot:
   - x-axis: region label or low-dimensional embedding coordinate
   - y-axis: local chart dimension
   - color: geometry region or dominant dCST label

3. Per-region summary:
   - median local dimension
   - IQR local dimension
   - Truth RMSE by chart rule

4. If the dataset has known regions:
   - confusion-style summary comparing expected dimension class to estimated
     local dimension.

Across datasets:

1. Paired Truth-RMSE delta:

   \[
     \Delta =
     \mathrm{TruthRMSE}_{\mathrm{local.auto}}
     -
     \mathrm{TruthRMSE}_{\mathrm{auto}}.
   \]

   Negative values favor `local.auto`.

2. Bayesian paired mean/median delta analysis.

3. Runtime ratio:

   \[
     \frac{T_{\mathrm{local.auto}}}{T_{\mathrm{auto}}}.
   \]

4. Stability diagnostics:
   - dimension range
   - dimension IQR
   - fraction of anchors at support cap
   - fraction of anchors at dimension 1

## Acceptance Criteria

The experiment should not promote `local.auto` as a default unless all of the
following are true:

1. It improves or ties Truth RMSE on most non-manifold examples.
2. It does not substantially worsen performance on any major biologically
   relevant VALENCIA-derived dataset.
3. Its local dimension maps are interpretable on synthetic examples with known
   region dimensions.
4. Runtime is acceptable for the intended VALENCIA-scale workloads.

If `local.auto` improves interpretability but not RMSE, keep it as an
experimental diagnostic mode rather than a recommended fitting default.
