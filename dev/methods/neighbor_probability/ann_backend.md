# Euclidean ANN backend and bounded AGP timing

The three neighbor probability estimators share an exact ANN backend and an
optional approximate search. This change accelerates coordinate neighbor
retrieval while preserving the existing probability formulas. It does not
establish predictive value for any AGP outcome.

## Interface and distance definition

Use `search = "ann", eps = 0` for exact Euclidean search, or `eps > 0` for
approximate Euclidean search. `search = "brute"` retains the exhaustive reference.
The default `search = "auto"` selects exact ANN for Euclidean coordinates and
brute force for Chebyshev or precomputed distances. Explicit ANN requests for
those other inputs fail. Positive epsilon without Euclidean ANN also fails.

Sum or maximum normalization transforms the coordinates; it does not change
what `metric = "euclidean"` means. In particular, max-normalized Euclidean
search uses ambient chords through the cube. It is not an intrinsic surface
geodesic and is not Chebyshev distance.

## Retrieval, participants and ties

A tree contains answering training records only, ordered by the frozen ID
priority so approximate results are reproducible under row permutation.
Candidate counts expand geometrically until they support the largest requested
size. Query participants are excluded, and each remaining participant contributes
its closest answering visit. Exact search completes the necessary boundary with
an exact radius search when the retrieved prefix lacks a strictly more distant
record. Distances are recomputed with the reference arithmetic before ranking.
The existing ID rule resolves exact ties. The radius guard also covers the
1e-12 diagnostic near-tie window and floating-point rounding in tree pruning.

Approximate search can omit eligible participants. For every participant it does
retrieve, it checks all answering visits and retains the true nearest visit
before examining its label. It then uses the same three probability formulas.
The ANN distance tolerance does not bound probability error or the case stopping
rank, especially after exclusions and duplicate-visit removal. Approximate
boundary diagnostics count retrieved participants only; `boundary.complete`
is false. Total available people and cases remain exact, including discordant
repeated visits. Exhausting the candidate population recovers brute force.

Trees are reused across queries and requested sizes in a prediction call, and
across participants sharing a CV split. CV keeps a tree for each split/repeat;
its extra memory therefore scales with the summed training-matrix sizes.
Trees are not serialized in fitted objects and are rebuilt for a subsequent
prediction call. ANN has shared native search state, so this implementation
remains single-threaded; concurrent native ANN calls are not supported.

## Validation and timing scope

`make test-neighbors` compiles optimized native source and runs 1,476 passing
expectations with zero failures or warnings. This includes the original sPTB
Python fixtures and 529 added ANN checks. Exact paths agree with brute force
for all three estimators, grouped repeated CV scores and selected sizes, ties,
missing labels, large excluded groups, discordant visits, unsupported sizes,
row permutations, sparse 340-feature profiles and coordinate scales from
1e-100 to 1e100. Fits also survive serialization. Approximate tests cover
reproducibility, participant handling, valid probabilities and exact recovery
when the search exhausts training records. These checks do not certify an
approximate probability-error bound.

The authorized AGP pilot uses 128 frozen queries from distinct participants
against 24,411 identified reference records (21,323 people); the ten records
without participant linkage are excluded. Query selection is outcome-blind,
using the first record per participant in a frozen salted SHA-256 order.
All three estimators evaluate k = 3:20 on seasonal allergies and IBD, with sum
and maximum normalization, brute force, exact ANN and eps = 0.1/0.5. Each cell
is timed three times in randomized backend order. Prediction times include
tree construction; normalization and ID hashing are measured separately.
No full-cohort predictions, tuning or AGP model comparison is authorized here.

The run uses one compute thread, within the previously agreed four-thread and
10 GiB ceilings. Two one-thread AGP geometry workers and a separate vignette
build were active at admission. Native compilation occurs once before timing,
using `pkgbuild::compile_dll(debug = FALSE)`; the local dgraphs dependency is
loaded without recompilation. The private run manifest records source hashes,
input hashes, query IDs, session details and the resource allocation. Individual
labels and predictions remain outside Git.

Reproduction uses `scripts/prepare_neighbor_agp_timing.py` followed by
`scripts/benchmark_neighbor_agp_ann.R`. Both require explicit data/output paths;
they are not invoked by package tests. Each run requires a new output directory.

## Measured pilot results (November 5, 2026)

All 27,648 probabilities from exact ANN matched brute force exactly (12
method/outcome/normalization cells, each with 128 queries and 18 sizes).
Three repeated evaluations also reproduced every backend's predictions.
The table gives median prediction seconds over three runs, including tree
construction, for the complete 128-by-18 probability path. Fit preparation
(normalization, validation and ID hashing) took 0.170–0.346 seconds separately.

| Normalization | Outcome | Estimator | Brute (s) | Exact ANN (s) | eps 0.1 (s) | eps 0.5 (s) | Exact speedup |
|---|---|---|---:|---:|---:|---:|---:|
| Sum | Allergies | `knn` | 11.627 | 0.388 | 0.515 | 0.408 | 30.0x |
| Sum | Allergies | `case_raw` | 11.709 | 0.467 | 0.610 | 0.482 | 25.1x |
| Sum | Allergies | `case_corrected` | 11.448 | 0.543 | 0.805 | 0.528 | 21.1x |
| Sum | IBD | `knn` | 11.582 | 0.426 | 0.478 | 0.425 | 27.2x |
| Sum | IBD | `case_raw` | 11.645 | 4.948 | 6.583 | 5.768 | 2.4x |
| Sum | IBD | `case_corrected` | 11.394 | 4.768 | 6.180 | 5.459 | 2.4x |
| Max (ambient) | Allergies | `knn` | 11.584 | 0.992 | 1.045 | 0.879 | 11.7x |
| Max (ambient) | Allergies | `case_raw` | 11.540 | 1.040 | 1.116 | 0.974 | 11.1x |
| Max (ambient) | Allergies | `case_corrected` | 11.799 | 1.098 | 1.119 | 1.331 | 10.7x |
| Max (ambient) | IBD | `knn` | 11.467 | 0.884 | 0.923 | 0.828 | 13.0x |
| Max (ambient) | IBD | `case_raw` | 11.464 | 4.761 | 5.624 | 4.933 | 2.4x |
| Max (ambient) | IBD | `case_corrected` | 11.593 | 4.754 | 5.683 | 5.049 | 2.4x |

Exact speedups ranged from 2.35x to 30.0x in these ambient Euclidean tests.
The smaller gain for nearest-case IBD is consistent with needing to retrieve
more responding neighbors to reach the requested number of cases. This is a
runtime interpretation, not an assessment of prediction accuracy. Costs for
larger k grids, CV, state-specific references and intrinsic surface distances
were not measured.

At eps = 0.1, 0.622% of probabilities changed, with mean absolute difference
0.00002785 and maximum 0.05714 relative to exact search. At eps = 0.5, 11.806%
changed, with mean absolute difference 0.0006782 and maximum 0.16340. These
summaries pool equally sized grids across the 12 cells; correlated k values
are not independent observations. Approximation did not consistently improve
runtime. Use eps = 0 for the proposed Euclidean analysis.

The complete pilot, including preparation and validation assertions, took
712.07 seconds elapsed on the shared host. Maximum resident memory reported
by `/usr/bin/time -l` was 918,929,408 bytes (0.856 GiB); no swaps were reported.
The optimized C++ source fingerprint in the run manifest matches the feature
implementation. Timings are specific to this workload and concurrent host load.

The same 1,476 checks passed after integration with the banded logistic backend
and from the canonical source tree. A temporary installed-package check passed
exact/approximate predictions, serialization and both help examples. The API
guide audit passed. These are targeted feature checks, not a full package or
CRAN check.

Local evidence is retained in
[the run manifest](/Users/pgajer/current_projects/geosmooth-neighbor-estimators/tmp/neighbor-ann-agp-20261105/plan.json),
[raw timings](/Users/pgajer/current_projects/geosmooth-neighbor-estimators/tmp/neighbor-ann-agp-20261105/timings.tsv),
[error summaries](/Users/pgajer/current_projects/geosmooth-neighbor-estimators/tmp/neighbor-ann-agp-20261105/errors.tsv), and
[the resource log](/Users/pgajer/current_projects/geosmooth-neighbor-estimators/tmp/neighbor-ann-agp-20261105/run.log).
`scripts/summarize_neighbor_agp_ann.py OUTPUT` regenerates the aggregate table
without reading individual labels or predictions. Full AGP fits remain unrun.

## Max-normalized surface geometry: decision before AGP estimation

The user has requested intrinsic geometry for the max-normalized analysis.
The local dgraphs API `linf.simplex.distances()` implements shortest
Euclidean-length paths on the nonnegative surface `max(x) = 1`, permitting
intermediate faces. Its graph constructors `create.single.iknn.graph()` and
`create.iknn.graphs()` support `knn.metric = "linf.simplex", pca.dim = NULL`.
Their current native neighbor search evaluates every candidate using this
solver, with row-wise workspace. It is not ANN search.

A verified example is q = (1,0,0,0), A = (0,1,0,0), B = (1,1,1,1).
Ambient distances from q are sqrt(2) to A and sqrt(3) to B; surface distances
are 2 to A and sqrt(3) to B. Thus the nearest neighbor changes. Pure 1-CST
members sharing the same leading-taxon face have chord-equal surface distances;
merged 70%-1-CSTs can cross faces, so the equality cannot be assumed there.

For the next AGP analysis, use the dgraphs intrinsic surface metric as the
primary max-normalized metric, with ambient Euclidean results explicitly
identified if retained as a comparison. Keep the historical max-Chebyshev
geometry distinct. Existing map coordinates can display new probabilities but
do not redefine the metric used to estimate them.

At the time of this ANN pilot, the precomputed surface-distance interface
required a square training matrix. The subsequently implemented
[streamed intrinsic backend](intrinsic_backend.md) now uses dgraphs' exact
solver directly, retaining missing response handling, participant exclusions
and the frozen tie rule without an all-pairs matrix. A fixed kNN
graph can truncate before the kth eligible case and cannot silently replace
that adapter. Any later acceleration using Euclidean lower bounds must certify
that omitted candidates cannot change the intrinsic neighborhood. Positive ANN
epsilon is not a surface-geodesic approximation parameter.

The max-normalized rows in this pilot are ambient-Euclidean implementation
timings only. They do not predict runtime for the intrinsic surface solver.
