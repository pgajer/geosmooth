# PS-LPS C0/C1 System Cache Design

Date: 2026-06-05

This note defines the first cached-system contract for
prediction-synchronized local polynomial smoothing (PS-LPS).  The immediate
goal is not to change the statistical model.  The goal is to make repeated
solves over cross-validation folds and tuning parameters cheaper and more
auditable.

## Motivation

The S1 profile showed that after removing repeated R vector growth inside
`.ps.lps.solve()`, the remaining cost is split across:

- sparse triplet assembly;
- sparse matrix construction;
- \(A^\top A\) crossproducts;
- ridge-normal formation;
- sparse linear solves.

The current S1/S2 workload repeatedly solves systems with the same local chart
frames and the same synchronization overlap structure.  Across folds and tuning
values:

- data-row support patterns are determined by the same local frames;
- synchronization row patterns are fixed;
- \(\lambda_{\mathrm{sync}}\) rescales synchronization rows but does not change
  their support pattern;
- \(\lambda_{\mathrm{ridge}}\) changes only the diagonal ridge added after
  forming \(A^\top A\);
- fold weights remove or rescale data rows but do not change chart designs.

This makes PS-LPS a good candidate for a reusable system cache.

## C0 Contract

For fixed:

\[
  X,\quad y,\quad \texttt{support.size},\quad \texttt{kernel},\quad
  \texttt{degree},\quad \texttt{chart.dim.by.anchor},\quad
  \texttt{sync.neighbor.size},\quad \texttt{overlap.weight},
\]

the cache stores all static information needed to assemble and solve PS-LPS
systems for many values of:

\[
  \lambda_{\mathrm{sync}},\quad
  \lambda_{\mathrm{ridge}},\quad
  \texttt{response.weights}.
\]

The cache is intentionally not allowed to store truth values or cross-validation
outcomes.  It is a linear-system cache, not a model-selection cache.

## Cached Data Blocks

For each anchor \(i\), ordinary LPS already constructs a local frame:

\[
  N_i,\quad w_{ij},\quad \Phi_i,\quad \phi_i(x_i),
\]

where \(N_i\) is the support, \(w_{ij}\) are kernel weights, \(\Phi_i\) is the
local polynomial design on the support, and \(\phi_i(x_i)\) is the anchor row.

C1 caches, for each frame:

- support indices \(N_i\);
- kernel weights \(w_{ij}\);
- local design matrix \(\Phi_i\);
- coefficient-column offset;
- coefficient-column indices for this frame;
- design width \(q_i\).

The data-fit rows for a solve with response weights \(r_j\) are:

\[
  \sqrt{r_j w_{ij}}\ \phi_i(x_j)^\top \beta_i
  \approx
  \sqrt{r_j w_{ij}}\ y_j,
  \qquad j\in N_i.
\]

Rows with \(r_j=0\) are omitted in the current C1 implementation, matching the
existing fold-weighted behavior.

## Cached Synchronization Blocks

For each synchronized anchor pair \((i,\ell)\), and each overlap point
\[
  r\in O_{i\ell}=N_i\cap N_\ell,
\]
the synchronization row is:

\[
  \sqrt{\lambda_{\mathrm{sync}}\omega_{i\ell r}}\,
  \left\{
  \phi_i(x_r)^\top\beta_i-\phi_\ell(x_r)^\top\beta_\ell
  \right\}
  \approx 0.
\]

C1 caches the lambda-free row pieces:

- coefficient columns for the \(i\)-chart block;
- coefficient columns for the \(\ell\)-chart block;
- local design values \(\phi_i(x_r)\);
- local design values \(\phi_\ell(x_r)\);
- base row scale \(\sqrt{\omega_{i\ell r}}\).

At solve time, C1 multiplies these cached row pieces by
\(\sqrt{\lambda_{\mathrm{sync}}}\).

## C1 R Prototype

C1 adds private helpers:

- `.ps.lps.prepare.system.cache(frames, sync.rows)`;
- `.ps.lps.solve.cached(cache, y, response.weights, lambda.sync, lambda.ridge, coefficients.only = FALSE)`.

The prototype keeps the same numerical solve backend as `.ps.lps.solve()`:

1. assemble sparse triplets;
2. build a `Matrix::sparseMatrix`;
3. compute \(A^\top A\);
4. compute \(A^\top y\);
5. add the scale-relative ridge;
6. solve with `Matrix::solve`;
7. fall back to a small numerical ridge if needed.

The first C1 acceptance criterion is exact numerical equivalence, not speed:

\[
  \widehat f_{\mathrm{cached}}
  =
  \widehat f_{\mathrm{direct}}
\]

up to ordinary floating-point tolerance for representative full-data and
cross-validation-weighted solves.

## What C1 Does Not Yet Do

C1 does not yet:

- move assembly to C++;
- reuse symbolic factorization;
- reuse \(A^\top A\) components across \(\lambda_{\mathrm{sync}}\);
- reuse fold-independent synchronization crossproducts;
- change the public `fit.ps.lps()` code path.

Those are later C2/C3 topics.  C1 only freezes the cache API and verifies that
the cached solve can reproduce the existing direct solve.

## C2/C3 Direction

After C1 equivalence passes, C2 should decide whether to:

1. port sparse triplet assembly to C++ while keeping `Matrix` as the solve
   backend; or
2. first exploit cached crossproduct structure in R.

The S1 profile suggests that a full backend should eventually exploit
crossproduct and factorization reuse, not merely faster triplet filling.

