# Quadratic-surface fixtures moved

The sealed v1 collection and its maintained validators are now in dgraphs at
`dev/shared/fixtures/quadform_geodesics/`. The duplicate collection was removed
only after byte equality was established. No inputs were regenerated or sealed
again during this migration.

The adaptive-refinement LaTeX, bibliography and `build_refinement.py` have also
moved out of the package. Their canonical home is the sibling manuscript
repository, `dgraphs_manuscripts/reports/quadform_geodesics/`. Derived documents
and figures belong in that workspace's `build/` directory. The local old build
paths are compatibility links to the unchanged historical assets; do not rebuild
here or introduce a second maintained copy of the manuscript.
