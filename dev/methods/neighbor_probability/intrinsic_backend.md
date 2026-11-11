# Streamed intrinsic surface probabilities

All three neighbor probability estimators now accept `metric = "linf.simplex"`.
They use dgraphs' exact Euclidean-length geodesic solver on the nonnegative
surface `max(x) = 1`, including paths through intermediate faces. This provides
the requested metric for max-normalized AGP profiles without a full distance
matrix. The bounded pilot evaluates implementation correctness and runtime;
it does not assess predictive performance or select k.

```r
fit <- fit.neighbor.probability(
    X, y, method = "case_raw", k = 10,
    id = sample_id, group = participant_id,
    metric = "linf.simplex", normalization = "max"
)
probability_path <- predict(
    fit, newdata = query_X, query.group = query_participant_id, k = 3:20
)
```

Use the same arguments with `method = "knn"` or `"case_corrected"`.
`normalization = "max"` accepts nonnegative counts or relative abundances with
positive row maxima. With `normalization = "none"`, training and query profiles
must already have maxima equal to one within `sqrt(.Machine$double.eps)`;
admitted rows are divided by their maxima. Negative or zero-mass rows and
sum normalization are rejected for intrinsic coordinate input.

`search = "auto"` resolves to `"brute"` because every eligible candidate is
evaluated. This name describes candidate enumeration, not ambient distance.
Diagnostics record `metric = "linf.simplex"` and `distance.backend = "dgraphs"`.
ANN and positive epsilon are rejected for this metric. Explicit
`metric = "euclidean", normalization = "max"` continues to mean ambient chords.

## Native implementation and memory

The C++ backend includes dgraphs' shared
`dgraphs/linf_simplex_distance.hpp` through `LinkingTo: dgraphs`; the solver is
not copied or reimplemented. The package already imports dgraphs. Local QA
installs the authoritative local dgraphs package into a private test library
when its header differs, checks header identity, and compiles geosmooth against
that header. `make test-neighbors` performs this setup without replacing the
user's global installed package.

Each prediction call prepares sparse training profiles once and evaluates one
query-to-training distance row at a time. It excludes unanswered records and
the query's entire participant, sorts by distance and the existing ID priority,
and retains the closest answering visit per training participant before looking
at its outcome. The same ordered row supports every requested k and all existing
boundary diagnostics. Insufficient people or cases remain NA.

Surface path search considers intermediate faces; neither a fixed sample graph
nor an endpoint-face shortcut is used. Distance and ranking workspace scales
linearly with training records; stored sparse profiles scale with the number
of positive coordinates. Per-pair work is quadratic in the union of positive
features in the worst case, with dgraphs' pruning and same-face shortcut.
The probability result itself has queries-by-requested-sizes storage.

Grouped CV reuses a sparse training cache per split and repeat. Native caches,
including ANN trees, are explicitly released on success or error from prediction
or tuning. Fit objects contain ordinary R data and remain serializable; a later
prediction call constructs a new cache. The implementation is single-threaded.

## Correctness checks

The focused suite has 1,971 passing expectations, including 495 intrinsic and
native-cache-lifetime checks. The new tests compare all three methods with
exhaustive matrices from the public `dgraphs::linf.simplex.distances()` API.
They cover one-dimensional through sparse 340-feature examples, intermediate
faces, same-face equality with Euclidean chords, duplicates and ties, missing
labels, discordant visits, participant exclusions, unsupported sizes, row
permutations, rescaling, grouped repeated CV scores and selected k, serialization,
and input/search restrictions. Native cache release is checked after normal
prediction, tuning and an error. Probability and integer comparisons are exact;
synthetic radius comparisons permit floating-point tolerance of 1e-14.

The original sPTB, ANN and documentation checks remain in the same suite. These
checks establish agreement with the declared metric and estimator arithmetic;
they do not establish biological predictive value or constitute full-package
CRAN validation.

## AGP pilot design and authorization

The reference contains 24,411 identified records from 21,323 people, with 340
frozen features. Ten of the original 24,421 records lack participant linkage and
are excluded. The pilot uses the first 64 distinct-person query representatives
from the earlier outcome-blind ANN pilot's salted sample-ID ordering. Training
retains multiple visits, using the declared closest-answering-visit rule.
No one-record-per-person analysis population is selected by this timing exercise.

For seasonal allergies and IBD, each method evaluates the complete k = 3:20
path on those 64 queries. There are three timed repeats in randomized cell
order. Times include sparse-cache construction, distances, ranking, probability
calculation and native-cache cleanup. Normalization, validation and ID hashing
are timed separately. No full AGP predictions, CV, k selection or CST fits run.

An independent reference uses the public dgraphs API to compute only a
64-by-reference distance matrix. A separate R implementation then excludes
participants, orders distances and frozen ID priorities, deduplicates visits,
and applies the three probability formulas. It calls none of geosmooth's native
ranking or prediction helpers. This oracle also checks available people/cases,
radii, stopping ranks and tied boundaries. The streaming backend does not use
the reference matrix.

The timing study used at most four compute threads and 10 GiB, with one thread
per numerical process. Two AGP geometry workers were active on the shared host.
Native code was compiled optimized before timing; workers did not compile. The run records source and input fingerprints, dgraphs'
header fingerprint, query identities, session information and resource usage.
Individual outcomes and predictions stay outside Git.

## Measured results (November 5, 2026)

All 6,912 probabilities matched the independent exhaustive reference exactly.
Neighbor counts, case counts, available people/cases, tied-boundary diagnostics
and radii also agreed exactly. All three timed repeats reproduced the same
predictions. Median seconds for 64 queries and the full k = 3:20 path were:

| Outcome | kNN (s) | Raw nearest-case (s) | Corrected nearest-case (s) |
|---|---:|---:|---:|
| Seasonal allergies | 3.651 | 3.639 | 3.639 |
| IBD | 3.574 | 3.585 | 3.574 |

These times include cache construction and immediate cleanup. Preparation
costs are recorded separately in the raw timing table. Similar times across
methods and outcomes reflect exhaustive candidate evaluation for the intrinsic
metric; reaching fewer cases does not reduce the distance work. The data contain
23,230 answering allergy records (9,193 positive) and 22,833 answering IBD
records (1,228 positive), before query-participant exclusion and visit selection.
These are record counts, not participant prevalence estimates.

The final validation-and-timing process took 101.40 seconds elapsed and peaked
at 1,429,520,384 resident bytes (1.331 GiB), including the independent reference
matrix and loaded packages. The shared host still had its two AGP geometry
workers. The benchmark measures this bounded workload; it does not establish
whole-cohort, CV or CST runtime. In particular, the previous ambient ANN pilot
used different query counts and a different metric and is not an intrinsic
speedup comparison.

The final 1,971 source checks and 495 intrinsic checks against a temporary
installed package passed, as did the executable help examples and API guide
audit. No full AGP predictions, tuning or state-specific fits were run.

The run manifest records source and input identities; raw timing tables and
reference comparisons support the aggregate results above. Reproduction
requires the original cohort inputs and the commands below.

## Reproduction and evidence

Run `make test-neighbors` from the package root. Set `NEIGHBOR_FORCE_BUILD=true`
for a full optimized rebuild; otherwise only changed native sources rebuild.
Then run the data extractor with explicit frozen-cohort, linkage, survey and
new output-directory arguments, followed by:

    Rscript scripts/benchmark_neighbor_agp_intrinsic.R FROZEN OUTPUT
    python3 scripts/summarize_neighbor_agp_intrinsic.py OUTPUT

The first pilot remains preserved separately. The final timing run includes the
explicit native-cache cleanup added after that pilot; its result agreement was
checked again. All original and failed development logs remain available.
