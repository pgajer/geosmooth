# Document locations

Scientific sources and reports formerly stored under `manuscripts/r-journal/`
and selected `dev/notes/` and `dev/methods/` paths now live in the local sibling
workspace `../geosmooth_manuscripts/`. Its README links the R Journal drafts,
foundations tutorials, LPS reports, local-association design, occupation-density
comparison, and metric graph low-pass experiments.

Quadform-geodesic research belongs instead to
`../dgraphs_manuscripts/reports/quadform_geodesics/`. Broader exploratory
programs remain with `../trend_filtering/`.

These are local writing workspaces, not runtime dependencies. Public help,
vignettes, implementation, tests, fixtures, and binding package-test
specifications remain here. Package validation tooling remains here unless
it was solely the runner or renderer for a moved standalone study.

Agent-only reviews, handoffs, prompts, and execution records belong in private
project storage. New generated figures and reports belong with their source
study, normally under its `build/` directory. Do not recreate the removed
report bundles in the package or add links to private files as build inputs.
