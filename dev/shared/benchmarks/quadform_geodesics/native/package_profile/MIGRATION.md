# Historical profiler, not a current solver entry point

The production solver now lives in dgraphs. These older profiling scripts are
retained as historical development material, not as supported launchers for the
migrated package. Before the move, `prepare.R` already failed against the current
geosmooth source because its `Measure integrate(...)` instrumentation anchor no
longer existed. Changing only a package name would not repair that experiment.

Use the dgraphs solver tests and frozen-input comparison runner for current
verification. A new profiling study should instrument the current dgraphs source
in a separate private output directory and establish matching results before
reporting timings. Preserve old reports and their original source provenance.
