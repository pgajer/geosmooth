# DGP-library response re-audit

Date: 2026-06-12  
Auditor: Codex, independent re-audit pass  
Worktree: `/Users/pgajer/current_projects/geosmooth-dgp`  
Branch: `codex/geosmooth-dgp-library`  
Re-audited SHA: `9a62f72c06b58f33345874a8cbdba4733fea4c2a`  
Original audited SHA: `c0e0d17f42d763ec69a412c8f05ec73551abf37d`

## Verdict

**Accept the DGP-library response.** The two blocking findings from
`audits/dgp_library_audit_2026-06-11.md` are resolved:

1. **G6 clip-active fidelity:** fixed and mutation-qualified. Removing the
   clipping line now makes the committed test suite red.
2. **Frozen registry replay:** fixed and mutation-qualified. Corrupting a
   committed registry row now makes the committed test suite red.

Updated DGP-library status: **G1, G2, G3a, G3b, G3c, G3d, G4, G5, G6, and G7
are accepted** for their audited plan-defined uses. G6-consuming E2.x work is
no longer blocked by the prior clip-vacuity finding.

## Scope Checked

The response is test-only relative to `c0e0d17`:

- `git diff --exit-code c0e0d17 -- R/dgp_library.R inst/dgp_registry`:
  empty.
- Changed files since `c0e0d17`: `tests/testthat/test-dgp-library.R` and
  `audits/dgp_library_audit_response_2026-06-11.md`.

Thus the prior audit's accepted generator/registry facts remain applicable.

## Baseline Runs

Started from a clean worktree at `9a62f72c06b58f33345874a8cbdba4733fea4c2a`.

Baseline command, source mode:

```sh
Rscript -e 'source("R/dgp_library.R"); library(testthat); test_dir("tests/testthat", filter="dgp")'
```

Result: `268` passing expectations, `0` failures, `0` errors, `0` warnings,
`0` skips.

Package-load mode:

```sh
Rscript -e 'pkgload::load_all("."); library(testthat); as.data.frame(test_file("tests/testthat/test-dgp-library.R", reporter="silent"))'
```

Result: all `268` expectations passed; the registry replay test did not skip.

## Mutation Results

| Finding | Mutation | Expected result | Observed result |
|---|---|---|---|
| G6 clip-active fidelity | Replaced `p <- pmin(clip[2], pmax(clip[1], stats::plogis(alpha + eta)))` with `p <- stats::plogis(alpha + eta)` in `R/dgp_library.R` | New G6 clip-fidelity test turns red | **Red:** `failed=6`, all in `G6 clipping is active under a strong log-odds (clip-fidelity GATE)`. |
| Registry replay | Changed committed registry row `G3a-R2-lin-noiseless` params from `R=2` to `R=3`, leaving recorded SHA unchanged | New registry replay test turns red | **Red:** `failed=1`, in `every frozen registry row reproduces its recorded SHA-256`. |

Both mutations were restored with `git checkout -- ...`; the source-mode DGP
suite reran green afterward.

## Reproduced Numbers

I independently checked the repaired G6 clip-active case:

- `dgp.g6(n=600, prevalence=0.5, eta.fn=function(x) 6*sin(pi*x[,1]), seed=1)`
  returned `truth` range `[0.050000, 0.950000]`, with both exact lower and
  upper clip boundaries present.
- The same call with `clip=c(0.1,0.9)` returned range
  `[0.100000, 0.900000]`, again with both exact boundaries present.

I also rechecked representative registry rows:

- Registry rows: `24`
- G-tags covered: `G1,G2,G3a,G3b,G3c,G3d,G4,G5,G6,G7`
- `G3a-R2-lin-noiseless`: recomputed SHA matches
  `6664004a06816ffc476f2f030e8e1415e2772f5608b80cf403fd5fc3afd26cf1`.
- `G6-prev050-n400`: recomputed SHA matches
  `3956d3736671aae8fc880cea267703d5c8559ae7628a3c5078912b8416a25f07`.

## Handoff / Response Honesty

The response accurately describes the fixes:

- It does not claim generator or registry changes.
- It acknowledges the original G6 handoff omission about clip inactivity.
- It correctly states that the added registry replay test resolves the prior
  committed-test coverage gap.
- It does not claim that implementer self-checks are auditor acceptance
  evidence; the re-audit mutation runs above supply that evidence.

## Residual Notes

This re-audit did not reopen all previously accepted tags. Since generator
source and registry artifacts are unchanged from `c0e0d17`, the prior audit's
mutation-qualified acceptances for G1, G2, G3a, G3b, G3c, G3d, G4, G5, and G7
still stand.

Final source status after mutation restores was clean before adding this
untracked report.
