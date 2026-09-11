# Single-process package profiling

These tools measure the installed, internal `quadform_geodesics_solver` and a
separate instrumented copy of the same C++ sources. They do not alter the
package, its defaults, or the older experimental implementations.

Use an installed package built from the source being profiled. Set
`R_LIBS_USER` to that library and its dependencies. Rcpp, digest and jsonlite
are required by the measurement tools; Python is not used. Keep generated
sources, compiled copies, measurements and reports in a private output
directory outside the repository.

## Run

Create an empty output directory. In R, source `prepare.R` and call
`qgp.prepare(repo, file.path(output, "instrumented"))`. Then run these scripts
from this directory, in order:

```sh
Rscript --vanilla run.R "$REPO" "$OUTPUT"
Rscript --vanilla supplement.R micro "$OUTPUT"
Rscript --vanilla memory.R "$REPO" "$OUTPUT"
Rscript --vanilla analyze.R "$OUTPUT"
```

Set `OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`, and `MKL_NUM_THREADS=1` for
all commands. Do not run these measurements concurrently. `memory.R` uses
macOS `/usr/bin/time -l` and launches fresh R processes sequentially.

The main run covers 420 configurations: five surfaces, two refinement
methods, three neighborhood rules, four cache capacities and three seeds,
plus candidate-count, initial-path-size and optional-trace comparisons.
All searches complete eight rounds. Plateau stopping is disabled by setting
its threshold to nine rounds, and integration counts are unlimited. A
60-second safety allowance remains. Initial edges are approximately equal
in surface length; visits are randomized. This is a performance experiment,
not a new accuracy or random-sensitivity campaign.

## Measurement Checks

Ordinary installed-package timings include R invocation and returned result
construction, but not process startup, compilation, independent path checks,
or report writing. The main run rotates three timing modes across three
blocks: the R solver, the registered Rcpp entry with prepared options, and
the private copy with timers disabled. Each block batches short calls to
reduce clock-resolution effects. The main R invocation uses `do.call`;
the supplementary small-call experiment also measures an ordinary direct
R function call, separating that harness cost from the wrapper.

An independent R integral checks every final path. The private instrumented
copy must match the installed result exactly, except elapsed time. Separate
trace-enabled comparisons verify the full accepted-path history and visit
identifiers, without including those checks in ordinary timings.

Nested C++ timers report inclusive and exclusive time. Only exclusive times
may be added: they subtract time attributed to measured children. A fake
clock tests nesting, disabled timers and exception unwinding. More detailed
coordinate-key and interrupt-check timers run on six diagnostic cases only.
Both coarse and fine timers perturb execution; use ordinary timings for
end-to-end comparisons and interpret component shares as diagnostic estimates.
The core scope includes cache destruction, which the solver's returned
`elapsed_seconds` counter does not include.

Cache comparisons pair the same seed, surface, method, neighborhood and
round count. A calculation-count stopping rule would not hold refinement
work fixed when cache capacity changes. The comparison signature excludes
cache counters and the final numerical error estimate, which may tighten
when initialization integrals are reused. Any signature differences must be
investigated before calling the work equivalent.

`sources.csv` records source and installed-library hashes; the main run
checks that these files do not change during execution. The instrumentation
uses unique source anchors and a distinct C++ namespace to avoid accidentally
calling the production symbols. Source changes require a newly prepared
copy and a fresh output directory.

## Memory And Tracing

The memory checks measure the whole fresh R process, including its loaded
package, on the steep bowl with 64 initial edges and 128 candidates. They
compare both methods with caching off or at its default capacity, and with
tracing off or on. These are single-process observations, not a guarantee
about twelve-process memory use. Trace storage is bounded and in memory;
neither solver mode writes state files. Experiment output files are written
by these measurement scripts after the solver returns.
