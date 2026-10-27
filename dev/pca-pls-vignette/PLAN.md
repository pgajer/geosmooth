# PCA versus PLS chart vignette

Create an executable package vignette using synthetic binary responses only.
Five predeclared scenarios: seam, high-variance signal, low-variance signal,
constant probability and nonlinear seam signal. Five independent repetitions
per scenario; seeds 271000 + 100 * scenario-index + repetition, indices 1:5.
Each dataset: 180 training, 60 tuning, 120 independent test observations.

Compare ambient PCA, unfolded PCA and unfolded PLS using the same intrinsic
support (60 training neighbors), Gaussian weights and ridge penalty 1. Show
fixed rank-one results and dimensions 1,2,3 selected by tuning Brier loss.
Include global and local smoothed-constant baselines. No feature standardization
before directions; standardized component scores as implemented by the package.
Known-probability MSE isolates estimation error; Brier loss evaluates binary
predictions. Report chart/solver fallbacks and every repetition, without
significance claims from five repeats. Never select seeds or variants using test
performance. Show first-repetition test plots and prespecified median-nuisance
slices, labelled as illustrations distinct from held-out performance.

Execution: user authorized up to six workers and 30 GiB alongside the HMP
chart-analysis and explorer build; the executable vignette uses one numerical
thread. Prior optimized native builds may be reused if unchanged.
No cohort outcomes. Sources remain in the package; HTML, PNGs, machine results
and logs go in ignored dev/html/pca-pls-vignette. Record package revisions and
runtime. Link the new vignette from the existing chart and function guides and
register it in pkgdown. Compile, validate data/figures and inspect rendered
layout before commit/push. Preserve failed attempts if any.
