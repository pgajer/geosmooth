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

The current probability interface can consume externally supplied surface
distances, but its precomputed training interface requires a square matrix.
Do not allocate a full AGP matrix. The next implementation step is a streamed
query-to-training distance adapter using dgraphs' exact solver, retaining missing
response handling, participant exclusions and the frozen tie rule. A fixed kNN
graph can truncate before the kth eligible case and cannot silently replace
that adapter. Any later acceleration using Euclidean lower bounds must certify
that omitted candidates cannot change the intrinsic neighborhood. Positive ANN
epsilon is not a surface-geodesic approximation parameter.

The max-normalized rows in this pilot are ambient-Euclidean implementation
timings only. They do not predict runtime for the intrinsic surface solver.
