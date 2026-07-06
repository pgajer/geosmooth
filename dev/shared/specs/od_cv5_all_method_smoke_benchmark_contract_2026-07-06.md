# OD-CV5 All-Method Smoke Benchmark Contract

Source: `/Users/pgajer/current_projects/geosmooth/dev/shared/specs/od_cv5_all_method_smoke_benchmark_contract_2026-07-06.md`

## Purpose

OD-CV5 closes the first occupation-density visit-CV implementation cycle by
running a small fixed-fixture smoke benchmark across every method that currently
supports

```r
fit.subject.od(..., od.cv = "visit")
```

The purpose is interface and telemetry validation.  OD-CV5 is not a replicated
performance benchmark and should not be used to decide which occupation-density
method is scientifically best.

The shared score is the held-out visit negative log occupation mass:

\[
  \mathrm{VisitCV}(\theta)
  =
  -\frac{1}{n_s}
  \sum_{r=1}^{n_s}
  \log\left\{
    \max\left(\widehat\rho^{(-F(r))}_{\theta}(x_r),
              \epsilon\right)
  \right\}.
\]

Here \(x_r\) is the state visited by the subject at visit \(r\), \(F(r)\) is its
visit fold, \(\widehat\rho^{(-F(r))}_{\theta}\) is the density fit after
removing that fold, and \(\epsilon=\texttt{visit.cv.epsilon}\).

## Included Methods

The OD-CV5 smoke benchmark includes the current OD visit-CV method surface:

- `graph_random_walk`;
- `chart_kernel`;
- `local_likelihood_density`;
- `local_likelihood_bernoulli`;
- `lps_count`;
- `lps_logistic_binary`;
- `ps_lps_count`.

The benchmark deliberately excludes `empirical`, because there is no tuning
parameter to select under the current OD-CV contract.

## Fixture

The benchmark uses one deterministic curved path fixture:

- \(n=28\) support points;
- observed support \(X_i=(t_i,t_i^2)\), where \(t_i\) is evenly spaced on
  \([-1,1]\);
- a fixed path graph with repeating edge lengths;
- twelve subject visits with repeated states;
- four preassigned visit folds.

This fixture is large enough to exercise graph, chart, LPS, PS-LPS, and local
likelihood paths, but intentionally small enough to remain a smoke benchmark.

## Output Contract

The benchmark is run by:

```sh
Rscript scripts/run_od_cv5_all_method_smoke.R
```

By default it writes:

```text
dev/shared/experiments/od_cv5_all_method_smoke_2026-07-06/
```

with these artifacts:

```text
od_cv5_all_method_smoke_report.html
tables/od_cv5_method_summary.csv
tables/od_cv5_candidate_table.csv
```

The method summary table must include at least:

```text
method
label
status
elapsed.sec
n.candidates
n.failed.candidates
selected.candidate.id
visit.cv.neg.log.rho
visit.cv.mean.heldout.rho
mass
max.rho
n.local.maxima
selected.summary
error.message
```

The candidate table records all method-level candidate telemetry returned by
`fit.subject.od(..., od.cv = "visit")`, with a `method` and `label` column added
for cross-method inspection.

## Report Contract

The HTML report must:

1. state that OD-CV5 is a contract smoke benchmark, not a performance claim;
2. define the held-out visit score;
3. report fit-status accounting across all included methods;
4. show a selected-score figure with a numbered caption;
5. include a compact selected-candidate table;
6. link the full summary and candidate CSV artifacts;
7. record the build timestamp and git commit used to generate the artifacts.

## Validation Contract

The script must be runnable to an arbitrary output directory with:

```sh
Rscript scripts/run_od_cv5_all_method_smoke.R --out-dir=<path>
```

The validation test belongs in the opt-in validation lane rather than the
default package smoke lane, because it intentionally runs all OD visit-CV
methods.

## Remaining Scope

OD-CV5 does not test graph-construction selection, real subject trajectories,
replicate uncertainty, or external microbiome data.  Those belong to later
scientific validation phases.

OD-CV5 does not include `metric_graph_lowpass` as a first-class OD method.
Metric graph low-pass can be normalized into a density, but it still lacks a
package-facing `fit.subject.od(method = "metric_graph_lowpass")` branch and
OD-level candidate contract.
