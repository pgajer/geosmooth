# DGP-library independent audit

Date: 2026-06-11
Auditor: Codex, independent audit pass
Worktree: `/Users/pgajer/current_projects/geosmooth-dgp`
Branch: `codex/geosmooth-dgp-library`
Audited SHA: `c0e0d17f42d763ec69a412c8f05ec73551abf37d`

## Verdict

This is an Amendment 1 infrastructure audit, not an estimator gate audit.

Accepted tags: **G1, G2, G3a, G3b, G3c, G3d, G4, G5, G7**. Their generators
match the frozen plan definitions I checked, emit the standard dataset object,
are deterministic for fixed seeds, have frozen registry rows where applicable,
and their fidelity tests turned red under property-breaking mutations.

Rejected pending required fix: **G6**. The current G6 generator output is
inside `[0.05, 0.95]` and the registry rows reproduce, but the required clip
mutation `p <- plogis(alpha + eta)` stayed green. Under the assignment rule, a
fidelity test that stays green under the property mutation does not verify that
property. G6 must add a clip-active test case, for example using a stronger
`eta.fn` or a boundary prevalence such that unclipped probabilities escape the
band, before it can unblock E2.x work.

Registry status: the current frozen registry is reproducible for all 24 rows,
including G6. However, the committed `tests/testthat/test-dgp-library.R` does
not itself check the registry CSV rows. I independently caught a corrupted
registry parameter using a `/tmp` copy and recommend adding that reproduction
check to the committed fidelity tests.

## Per-Tag Disposition

| Tag | Verdict | Basis | Downstream status |
|---|---|---|---|
| G1 | accept | Exact D=2 degree-2 polynomial, noiseless default, mutation red. | Releases G1-consuming checks/studies. |
| G2 | accept | Orthonormal random frame, `X = U Q^T`, isometry, intrinsic polynomial, mutation red. | Releases intrinsic flat-subspace uses. |
| G3a | accept | `X3 = (u1^2+u2^2)/(2R)`, apex curvature `1/R`, registry SHA reproduced, mutation red. | Releases E1.9c, E3.1, E3.2, E4.1 Part B uses of G3a. |
| G3b | accept | Sphere-cap identity and recorded curvature `1/R^2`, mutation red. | Releases G3b use in E3.1. |
| G3c | accept | Helix `X(t)=(cos t,sin t,c t)`, mutation red. | Releases G3c reference use. |
| G3d | accept | Standard torus patch on sub-rectangle, registry SHA reproduced, mutation red. | Releases E1.9c and E3.1 uses of G3d. |
| G4 | accept | 1-D thickened segment A, 2-D `z=0` patch B, region labels/dims, mutation red. | Releases E1.11 boundary/dimension-stabilizer DGP use. |
| G5 | accept | Clustered repeated-measures model and exact requested ICC, mutation red. | Releases E1.10b grouped-CV DGP use. |
| G6 | reject pending test fix | Current output is in-band, but removing the clip caused zero test failures. | Blocks E2.x DGP-consuming work until clip-active fidelity test is added and passes mutation. |
| G7 | accept | Simplex rows sum to 1 after documented structural zeros, mutation red. | Releases G7 compositional/structural-zero DGP use. |

## Baseline Execution

Started from a clean worktree:

- `pwd`: `/Users/pgajer/current_projects/geosmooth-dgp`
- `git rev-parse HEAD`: `c0e0d17f42d763ec69a412c8f05ec73551abf37d`
- `git status --short`: empty

Baseline command requested by the assignment:

```sh
Rscript -e 'source("R/dgp_library.R"); library(testthat); test_dir("tests/testthat", filter="dgp")'
```

Result: `236` passing expectations, `0` failures, `0` warnings, `0` skips.

Source and registry checksums:

- `R/dgp_library.R`: `2cff1220e5910b9f337264c8f01dca6f8f50bf691fc662ba31df9c0b4034156b`
- `inst/dgp_registry/dgp_registry.csv`: `da8ffa5226fcd5c9a7fffc4b52a1c1a6cac5d5058735f01037b27697e17236eb`

Registry manifest provenance records freeze at git head
`10e6bafe35d418c238691e66c331fa79606acd94` on a clean tree, with R 4.5.2,
Accelerate BLAS, LAPACK 3.12.1, and digest 0.6.39. The audited head
`c0e0d17` adds the registry and handoff on top of that generator-source commit.

## Reproduced Numbers

I independently re-materialized all 24 rows in
`inst/dgp_registry/dgp_registry.csv` from their recorded `gtag` and `params`
fields and recomputed `dgp.content.sha256()`. Result:

- `registry_rows=24`
- `all_sha_match=TRUE`
- G-tags covered: `G1,G2,G3a,G3b,G3c,G3d,G4,G5,G6,G7`

For the required G3a independent check, I re-materialized
`G3a-R2-lin-noiseless` from the registry and recomputed the SHA:

- recorded SHA: `6664004a06816ffc476f2f030e8e1415e2772f5608b80cf403fd5fc3afd26cf1`
- recomputed SHA: `6664004a06816ffc476f2f030e8e1415e2772f5608b80cf403fd5fc3afd26cf1`
- match: `TRUE`

I also fit the exact quadratic height model and recomputed the apex curvature:

- `G3a-R2-apex-curvature=0.500000000000000`
- expected `1/R=0.500000000000000`

For determinism, I called `dgp.g6(n=120, prevalence=0.5, seed=77)` twice and
confirmed bitwise equality of `X`, `truth`, and `y`.

For the G6 clip weakness, I checked the unclipped default profile ranges:

- prevalence `0.3`: unclipped range `[0.0703, 0.6029]`
- prevalence `0.4`: unclipped range `[0.1159, 0.7248]`
- prevalence `0.5`: unclipped range `[0.1805, 0.8156]`
- prevalence `0.6`: unclipped range `[0.2700, 0.8814]`

These ranges explain why removing the clip is invisible to the current G6
fidelity test.

## Mutation Results

For source mutations, I edited `R/dgp_library.R`, ran the DGP fidelity tests
with `stop_on_failure=FALSE`, and restored with `git checkout -- R/dgp_library.R`
between mutations. Registry corruption was done only in `/tmp`.

| Mutation | Expected red check | Observed result |
|---|---|---|
| G1: change plan coefficient `b1` from `1.0` to `1.1` | G1 truth polynomial | Red: `failed=2`, covering G1 and G2 polynomial reuse. |
| G2: scale the orthonormal frame by `2` | G2 `Q^T Q=I` / isometry | Red: `failed=2` in the G2 frame/isometry test. |
| G3a: change coefficient `1/(2R)` to `1/R` | G3a height and apex curvature | Red: `failed=8` in the G3a height/curvature test. |
| G3b: change sphere-cap height from `R - sqrt(...)` to `R + sqrt(...)` | Sphere-cap identity | Red: `failed=1` in the G3b sphere-cap test. |
| G3c: change helix `x3` to `(c+0.1)t` | Helix pitch identity | Red: `failed=1` in the G3c helix test. |
| G3d: scale torus `x3` by `2` | Torus identity | Red: `failed=1` in the G3d torus test. |
| G4: move stratum B off the `z=0` plane | G4 stratum structure | Red: `failed=1` in the G4 structure test. |
| G5: use wrong tau formula `sqrt(rho*sigma^2)` | Exact ICC | Red: `failed=1` in the G5 ICC test. |
| G6: remove probability clipping | Clip to `[0.05,0.95]` | **Stayed green**: `failed=0`, `error=0`; mutated range for prevalence 0.4 was `[0.115933,0.724817]`. This is blocking for G6. |
| G7: skip renormalization after structural zeros | Simplex row sums | Red: `failed=2` in the G7 simplex test. |
| Determinism: remove the first seed reset in `dgp.g1` | Same seed bitwise-identical | Red: `failed=4` in the determinism test. |
| Registry: corrupt `G3a-R2-lin-noiseless` parameter `R=2` to `R=3` in `/tmp/dgp_registry_corrupt.csv` | Recorded SHA reproduces | Red in independent checker: `registry_corrupt_all_match=FALSE`, failed id `G3a-R2-lin-noiseless`. |

## Spec Fidelity

I found the accepted tags conformant to the frozen plan definitions:

- G1 uses iid `Unif([-1,1]^D)` and the exact D=2, p=2 polynomial.
- G2 uses iid latent `Unif([-1,1]^d)`, a recorded orthonormal frame, and
  `X = U Q^T`, which is the row-vector representation of plan `X_i = Q u_i`.
- G3a uses disk sampling with radius `rho0=1` and height
  `(u1^2+u2^2)/(2R)`, yielding apex curvature `1/R`.
- G3b, G3c, and G3d satisfy their sphere-cap, helix, and torus identities.
- G4 implements the 1-D and 2-D strata with labels and dimension metadata.
- G5 implements the clustered repeated-measures response with requested ICC.
- G7 draws a Dirichlet composition, zeros a documented subset, and renormalizes.

The G6 implementation itself currently returns in-band probabilities and solves
the prevalence offset on the unclipped expit as documented. The problem is not
the current output; the problem is that the fidelity test does not exercise
active clipping, so a broken implementation without clipping passes.

## Bundle / Registry Validity

This assignment has no Tier-0-style `audit_artifacts/` execution bundle. The
committed evidence is the frozen registry directory:

- `inst/dgp_registry/dgp_registry.csv`
- `inst/dgp_registry/dgp_registry_manifest.md`
- `inst/dgp_registry/sessionInfo.txt`

I verified the source tree was clean before baseline execution, verified the
recorded source/registry checksums, and independently rematerialized all
registry rows. The registry is valid for the audited source, but the lack of a
committed test that replays every registry row is a coverage gap.

## Handoff Honesty

The implementer handoff is mostly factual and useful:

- It correctly reports that no estimator source such as `R/lps.R` was modified.
- It lists the exported generators and the registry artifacts.
- It admits mutation/falsification was not run by the implementer.
- It discloses that the registry is environment-relative because
  `digest` uses R serialization.
- It discloses that LA-* / VALENCIA-derived real-data assets are not
  regenerated here and that G7 is the plan's Dirichlet-with-zeros DGP.

The handoff says G6 clipping/prevalence tests passed, which is true for the
unmutated implementation, but it does not disclose the clip-inactivity issue:
with the tested default profile, removing clipping still passes.

## Required Fixes

1. Add a G6 clip-active fidelity case. The test must fail when the line
   `p <- pmin(clip[2], pmax(clip[1], plogis(alpha + eta)))` is replaced by
   `p <- plogis(alpha + eta)`. A simple approach is to call `dgp.g6()` with a
   stronger `eta.fn` whose unclipped probabilities escape `[0.05,0.95]`, then
   assert the returned `truth` is clipped and still within the declared band.

2. Add a committed registry replay test or script invocation to the fidelity
   suite. It should read `inst/dgp_registry/dgp_registry.csv`, parse each
   `params` row, materialize the dataset, recompute `dgp.content.sha256()`, and
   fail if any SHA differs. The current registry is valid, but this protection
   is not yet in `test-dgp-library.R`.

## Downstream Unblock Statement

Unblocked by this audit:

- G3a: E1.9c, E3.1, E3.2, and E4.1 Part B may consume the accepted G3a
  generator/registry rows.
- G3d: E1.9c and E3.1 may consume the accepted G3d generator/registry rows.
- G5: E1.10b may consume the accepted G5 generator/registry rows.
- G1, G2, G3b, G3c, G4, and G7 may be used by their corresponding
  plan-referenced studies/checks.

Still blocked:

- G6-consuming E2.x work remains blocked until the clip-active fidelity test
  is added and mutation-qualified.

## Commands Run

```sh
pwd
git rev-parse HEAD
git status --short
git show codex/geosmooth-e1-9-bandwidth-multiplier:project_briefs/lps_experimental_plan_2026-06-09.tex > /tmp/plan.tex
git show codex/geosmooth-e1-9-bandwidth-multiplier:project_briefs/lps_tiers1to4_contract_2026-06-11.md > /tmp/contract.md
Rscript -e 'source("R/dgp_library.R"); library(testthat); test_dir("tests/testthat", filter="dgp")'
Rscript -e 'source("R/dgp_library.R"); library(testthat); as.data.frame(test_dir("tests/testthat", filter="dgp", reporter="silent"))'
shasum -a 256 R/dgp_library.R inst/dgp_registry/dgp_registry.csv
```

Additional one-off R scripts were run to rematerialize registry rows, recompute
G3a curvature, test G6 determinism, inspect unclipped G6 ranges, and perform
the `/tmp` registry-corruption check.

Final source status after all restores: clean except for this untracked audit
report under `audits/`.
