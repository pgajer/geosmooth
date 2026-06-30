# Research lineage bridge

This directory records how package-facing `geosmooth` work relates to upstream
research repositories, especially:

- `~/current_projects/trend_filtering`: broad research sandbox for
  multidimensional trend filtering, local smoothing, SLPLiFT/LPL-TF/MALPS
  explorations, parameter-sweep studies, theory notes, and report bundles.
- `~/current_projects/geosmooth`: lean R package implementation home for the
  methods that survive enough exploration to become exported package features.

The intended boundary is simple:

- `trend_filtering` asks what might work, why it might work, and how it behaves
  in broad exploratory experiments.
- `geosmooth` answers what is implemented, tested, exported, and ready to use as
  a package method.

Lineage notes should be concise pointer documents. They may summarize why an
upstream asset matters and link to the canonical source, but they should not
copy bulky reports, run directories, RDS files, or generated experiment bundles
into `geosmooth`.

Method-specific provenance files live inside each method workspace, for example:

- `dev/methods/lps/provenance.md`
- `dev/methods/ps_lps/provenance.md`
- `dev/methods/lcov/provenance.md`
