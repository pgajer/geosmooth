# LPS/PS-LPS Binary-Outcome Design Note

Date: 2026-06-07

## Purpose

This note records the first design decision point for binary-response versions of
local polynomial smoother (LPS) and prediction-synchronized LPS (PS-LPS).

For a binary response

\[
Y_i \in \{0,1\},
\]

the target conditional expectation is

\[
p(x) = \mathbb{E}(Y \mid X=x) = \Pr(Y=1\mid X=x).
\]

Thus a smoother for binary outcomes should be interpreted as estimating a
probability surface.  The design question is whether LPS/PS-LPS should continue
to use the current squared-error conditional-expectation machinery, or whether
they should introduce a Bernoulli/logistic local fitting objective.

## Existing Package Precedent

The current `geosmooth` LPS/PS-LPS/LPL-TF/S-LPL-TF implementations do not have a
dedicated binary-response mode.  They can accept numeric `0/1` responses, but
the fitting and tuning objectives remain squared-error style objectives.

Relevant binary-aware precedent exists mostly outside current LPS/PS-LPS:

- `malo::magelog()` and `malo::mabilog()` implement true local logistic smoothers
  for binary data.
- `gflow::ulogit()` and `gflow::eigen.ulogit()` implement logistic regression
  utilities for binary outcomes.
- `gflow::prepare.binary.cond.exp()` post-processes estimated conditional
  expectations for binary outcomes by clipping/winsorizing to `[0,1]`; this is
  not a different fitting objective.
- Some `malo` and old `gflow` helpers use binary-aware loss or clipping for
  intervals and fitted values, but this is not yet part of `fit.lps()` or
  `fit.ps.lps()`.

## Path 1: Minimal Brier-Risk Conditional-Expectation Mode

In the minimal path, binary responses are treated as numeric responses and the
model estimates \(p(x)\) by least squares.  For a fitted value \(\hat p_i\), the
natural binary prediction loss is the Brier loss

\[
L_{\rm Brier}(y_i,\hat p_i) = (y_i-\hat p_i)^2.
\]

The current LPS/PS-LPS squared-error machinery is already aligned with this loss
if \(y_i\in\{0,1\}\).  The main missing pieces are explicit probability handling
and diagnostics:

- expose `outcome.family = c("gaussian", "bernoulli")` or similar;
- for `bernoulli`, validate that observed responses are `0/1`;
- clip or warn on fitted values outside `[0,1]`;
- add binary-facing diagnostics such as Brier score and optional log loss;
- report the fraction of fitted probabilities below 0 or above 1 before clipping.

For LPS, local fits would remain weighted local polynomial least-squares fits.
For PS-LPS, the synchronized objective would remain a squared-error objective,
with the fitted synchronized chart predictions interpreted as probability
estimates.

### Advantages

- Minimal implementation risk.
- Uses the current fast LPS/PS-LPS machinery.
- Directly estimates the conditional expectation \(p(x)\).
- Brier risk is a proper scoring rule for binary probability prediction.
- Easy to compare with existing continuous-response experiments.

### Disadvantages

- Local polynomial least squares can produce fitted probabilities outside
  `[0,1]`.
- The model does not use the Bernoulli likelihood.
- Clipping is a post-processing step and can hide extrapolation or conditioning
  failures.
- For rare outcomes or near-separation regions, squared-error fitting may be
  statistically inefficient compared with logistic fitting.

## Path 2: Bernoulli/Logistic Local Fitting Mode

In the logistic path, each local chart estimates a local linear or polynomial
model for the log odds

\[
\eta(x) = \log\frac{p(x)}{1-p(x)}.
\]

The probability is then

\[
p(x) = \frac{1}{1+\exp\{-\eta(x)\}}.
\]

For a local chart centered at anchor \(i\), with local coordinates \(z_{ij}\),
the local model is

\[
\eta_{ij} = \theta_i^\top \phi_i(z_{ij}),
\]

where \(\phi_i(z)\) is the local polynomial feature vector.  The local weighted
Bernoulli negative log likelihood is

\[
\ell_i(\theta_i)
=
-\sum_{j\in N_i}
w_{ij}\left[
y_j \log p_{ij} + (1-y_j)\log(1-p_{ij})
\right],
\]

with

\[
p_{ij} =
\frac{1}{1+\exp\{-\theta_i^\top\phi_i(z_{ij})\}}.
\]

For LPS, each anchor would fit this local weighted logistic problem and predict
\(\hat p_i\) at the anchor.  For PS-LPS, the synchronization penalty could be
placed either on probabilities or on logits.  A probability-scale penalty might
look like

\[
\lambda_{\rm sync}
\sum_{(i,j)\in \mathcal O}
\omega_{ij}
\left(\hat p_i(x_j)-\hat p_j(x_j)\right)^2,
\]

where \(\mathcal O\) indexes overlap prediction constraints.  A logit-scale
version would replace \(\hat p\) by \(\hat\eta\).  The probability-scale version
is easier to interpret, while the logit-scale version may behave more naturally
near probability boundaries but can become numerically delicate when fitted
probabilities are close to 0 or 1.

### Advantages

- Uses the correct Bernoulli likelihood.
- Fitted probabilities are naturally constrained to `[0,1]`.
- Better statistical behavior is plausible for imbalanced binary outcomes.
- Builds directly on the existing `malo::magelog()` / `malo::mabilog()`
  precedent.

### Disadvantages

- More implementation complexity.
- Requires robust handling of local separation and small local sample sizes.
- Local degree-2 logistic fits may be unstable without ridge, Firth-type
  correction, or careful column dropping.
- PS-LPS synchronization becomes nonlinear if synchronization is imposed on
  probabilities.
- Runtime may increase substantially relative to least squares.

## Immediate Recommendation

The recommended sequence is:

1. Implement a minimal, explicit Bernoulli/Brier mode for LPS first.
2. Add diagnostics showing unclipped range, clipped range, Brier score, and log
   loss.
3. Validate it against ordinary numeric LPS on `0/1` outcomes to confirm that
   the un-clipped core fit is unchanged when using the minimal mode.
4. Only then design the logistic LPS mode, borrowing directly from
   `malo::magelog()` / `malo::mabilog()`.
5. Delay PS-LPS binary synchronization until the LPS binary target and local
   fitting semantics are frozen.

The minimal mode is not the final statistical model for binary outcomes, but it
is the safest first package-facing step because it makes the current behavior
explicit and auditable.  The logistic mode should be treated as the principled
second phase.

## Open Design Questions

- Should Bernoulli mode clip final predictions, warn, or both?
- Should CV optimize Brier score, log loss, or both?
- For PS-LPS, should synchronization happen on probability scale or logit scale?
- Should the first logistic implementation support only degree 1 before degree
  2 is allowed?
- What separation guard should be used: ridge, Firth-style correction, fallback
  to lower degree, or fallback to local weighted mean?
- Should binary PS-LPS require the same selected local chart dimensions and
  support policy as binary LPS for fair comparison?
