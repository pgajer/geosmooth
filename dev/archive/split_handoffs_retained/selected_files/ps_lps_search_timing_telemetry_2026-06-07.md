# PS-LPS Search Timing Telemetry

Date: 2026-06-07

## Purpose

This handoff records the first PS-LPS monomial backend/search profiling pass
after adding local-candidate timing telemetry.  The goal was to identify whether
PS-LPS runtime is dominated by final sparse solves, system assembly/cache
construction, lambda-search policy, or broad support-grid handling.

## Assets

- Profile HTML:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_monomial_backend_profile_2026-06-07/ps_lps_monomial_backend_search_profile.html`
- Summary table:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_monomial_backend_profile_2026-06-07/tables/ps_lps_monomial_profile_summary.csv`
- Per-candidate timing tables:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_monomial_backend_profile_2026-06-07/tables/*_local_candidate_timing.csv`
- Rprof tables:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_monomial_backend_profile_2026-06-07/tables/*_Rprof_by_total.csv`

## Code Changes

`fit.ps.lps()` now records single-candidate timing in `ps.lps.timing`, including:

- frame preparation;
- synchronization-row preparation;
- system-cache construction;
- fold component-cache construction;
- full component-cache construction;
- lambda-search elapsed time;
- final solve elapsed time;
- evaluated and unique lambda counts;
- boundary-expansion count.

When a support/kernel/degree grid is supplied, the multi-candidate wrapper now
propagates timing into `local.candidate.table`, including:

- `local.candidate.elapsed.sec`;
- `lambda.search.elapsed.sec`;
- `frame.prep.elapsed.sec`;
- `system.cache.elapsed.sec`;
- `fold.component.cache.elapsed.sec`;
- `final.solve.elapsed.sec`;
- `unique.lambda.count`;
- `boundary.expansion.count`.

No fitting decisions were changed by this telemetry patch.

## Profiled Tasks

Three completed P7X monomial PS-LPS tasks were rerun:

1. `LA-D1-HC-Li-N500`, `chart.dim = "auto"`;
2. `SYN-PARA-LINE-N500`, `chart.dim = "auto"`;
3. `SYN-SIMPLEX-FACES-N600`, `chart.dim = "auto"`.

The third task was selected as a harder, but still tractable, slow-path task. It
previously took roughly 221 seconds in the broad P7X run.

## Findings

The final selected full-data solve is not the runtime bottleneck.  In the
harder simplex-faces task, final solve phases were on the order of milliseconds
to hundredths of a second, while the full task took about 117 seconds.

The dominant cost is broad local-candidate evaluation combined with lambda
search:

- all 21 support candidates were evaluated;
- each support candidate evaluated 8 lambda values;
- the local-candidate loop accounted for essentially all elapsed time;
- lambda search accounted for about 81 seconds of the 117-second simplex task.

Per-candidate timing was fairly uniform in the simplex task: each support
candidate took about 5.1--6.2 seconds, with about 4.0--4.7 seconds in lambda
search.  This suggests the main short-term speed lever is not optimizing one
pathological support size, but reducing the number of support candidates and/or
lambda evaluations per candidate.

Rprof agrees with this interpretation.  The slow task spent most time under:

- `.ps.lps.search.lambda.sync()`;
- `.ps.lps.solve.component.cached()`;
- `.ps.lps.solve.normal.cached()`;
- Matrix sparse arithmetic and Cholesky-related calls.

## Recommendation

The next implementation step should be a screened PS-LPS support-search policy
for routine experiments:

1. run a cheap LPS screening pass over the full support grid;
2. keep the LPS-selected support, a small neighborhood of nearby supports, and
   a small number of guard supports;
3. run PS-LPS guarded lambda search only on that reduced candidate set;
4. compare screened PS-LPS against full-grid PS-LPS on existing P7X surfaces
   where full-grid results already exist.

This targets the observed bottleneck directly.  It is more likely to pay off
than optimizing the final selected sparse solve, because the latter is already a
small part of elapsed time in the profiled tasks.

## Screened Policy Implementation Result

The routine policy has been implemented as:

```r
local.candidate.search = "screened"
local.candidate.search.control = list(
    top.n = 8L,
    max.candidates = 12L,
    neighbor.radius = 1L,
    guard.support.quantiles = c(0, 0.5, 1)
)
```

Exact full-grid PS-LPS remains available through
`local.candidate.search = "full"`.

P7X-style task manifests now record the support-search policy explicitly with:

- `local_candidate_search`;
- `local_candidate_search_control`.

The same three profile tasks were rerun under the screened default:

- `LA-D1-HC-Li-N500`: 21 planned local candidates, 4 evaluated, about 7.0 s.
- `SYN-PARA-LINE-N500`: 21 planned local candidates, 11 evaluated, about 22.0 s.
- `SYN-SIMPLEX-FACES-N600`: 21 planned local candidates, 4 evaluated, about
  23.2 s.

For comparison, the full-grid profile of `SYN-SIMPLEX-FACES-N600` took about
116.8 s and evaluated all 21 candidates.  The screened policy therefore gives a
rough five-fold speedup on this harder profiled case while preserving a fully
auditable candidate table: every support candidate is still listed as either
`evaluated` or `screened_out`, with screening reason and local timing columns.

The screened simplex-faces selected CV RMSE was `0.102266`, close to the
full-grid selected CV RMSE `0.101979` from the prior full-grid profile.  This is
not yet a full accuracy audit, but it is a strong enough engineering signal to
use screened PS-LPS as the routine prospective-run policy and reserve
full-grid PS-LPS for retrospective reference checks.
