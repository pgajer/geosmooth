# DGP-library audit — implementer response

Date: 2026-06-11
Responder: implementer (Amendment 1 DGP library)
Audit responded to: `audits/dgp_library_audit_2026-06-11.md`
Audited SHA: `c0e0d17`  Branch/worktree: `codex/geosmooth-dgp-library`
Response SHA: this commit (test-only change on top of `c0e0d17`).

This response maps each audit finding to a fix. It does not revise, downgrade,
or pressure the auditor's verdict; the verdict and any mutation-qualification
remain the auditor's. The verdict on G6 (and the re-confirmation that the fix
is non-vacuous) is the auditor's to issue on re-audit.

## Scope of this change

Both fixes are **test-only**. The G6 generator and all other generators in
`R/dgp_library.R` are **byte-unchanged** from the audited commit `c0e0d17`
(`git diff c0e0d17 -- R/dgp_library.R` is empty), and
`inst/dgp_registry/` is unchanged (no re-freeze; the recorded source/registry
SHA-256s and the manifest still hold). Consequently the audit's nine accepted
tags (G1, G2, G3a, G3b, G3c, G3d, G4, G5, G7) and the reproduced registry rows
are unaffected by this change. The only modified file is
`tests/testthat/test-dgp-library.R`.

## Finding-by-finding

### Required fix 1 — G6 clip-active fidelity case (blocking) → FIXED

Audit: the G6 clip mutation `p <- plogis(alpha + eta)` stayed green because the
default `eta.fn = 1.5*sin(pi*x1)` never produces unclipped probabilities outside
`[0.05, 0.95]`, so the existing G6 case is clip-vacuous.

Fix: added `test_that("G6 clipping is active under a strong log-odds
(clip-fidelity GATE)", …)` in `tests/testthat/test-dgp-library.R`. It calls
`dgp.g6()` with `eta.fn = function(x) 6*sin(pi*x[,1])`, whose unclipped
probabilities span ≈ `[0.004, 0.998]` (escaping both band edges), and asserts:

- `all(truth ∈ [0.05, 0.95])` — false once the clip is removed (probs escape);
- `any(truth == 0.95)` and `any(truth == 0.05)` — exact boundary values are
  present only when the clip actually binds (absent without the clip);
- the same with a custom `clip = c(0.1, 0.9)`, so the band is read from the
  `clip` argument rather than hard-coded.

Non-vacuity self-check (to confirm the added test discriminates — not offered as
acceptance evidence; the auditor runs mutation-qualification):

```sh
# apply the auditor's mutation, then run the suite
#   p <- pmin(clip[2], pmax(clip[1], stats::plogis(alpha + eta)))  ->  p <- stats::plogis(alpha + eta)
Rscript -e 'source("R/dgp_library.R"); library(testthat);
  as.data.frame(test_file("tests/testthat/test-dgp-library.R", reporter="silent"))'
```

Observed under the mutation: `failed=6`, all in
`"G6 clipping is active under a strong log-odds (clip-fidelity GATE)"`, and no
other test affected. The source was restored with
`git checkout -- R/dgp_library.R` (no diff vs `c0e0d17`).

### Required fix 2 — committed registry-replay test (blocking) → FIXED

Audit: the registry is reproducible, but `test-dgp-library.R` does not itself
replay the registry CSV rows; the corrupted-row defect was caught only with a
`/tmp` checker.

Fix: added `test_that("every frozen registry row reproduces its recorded
SHA-256", …)`. It locates the frozen CSV across run modes (dev tree via
`testthat::test_path("..","..","inst","dgp_registry","dgp_registry.csv")` first,
then an installed package via `system.file("dgp_registry", …, package =
"geosmooth")`), parses each `params` row back into a generator argument list
with the correct integer/character/numeric typing, re-materializes via
`dgp.materialize()`, recomputes `dgp.content.sha256()`, and asserts equality to
the recorded `sha256` for every row. It `skip`s only if `digest` is absent or no
registry is found in the run mode.

Non-vacuity self-check:

```sh
# corrupt one committed row (R=2 -> R=3 for G3a-R2-lin-noiseless), run, restore
Rscript -e 'source("R/dgp_library.R"); library(testthat);
  as.data.frame(test_file("tests/testthat/test-dgp-library.R", reporter="silent"))'
git checkout -- inst/dgp_registry/dgp_registry.csv
```

Observed under the corruption: `failed=1`, in
`"every frozen registry row reproduces its recorded SHA-256"`, no other test
affected. The CSV was restored (no diff vs `c0e0d17`).

### Nonblocking — handoff did not disclose G6 clip-inactivity → acknowledged

Audit (Handoff Honesty): the handoff reported G6 clipping/prevalence tests
passing (true for the unmutated implementation) but did not disclose that the
clip test was inactive under the default profile.

Acknowledged as accurate. The original handoff's limitations section discussed
the G6 offset semantics (α solved on the unclipped mean) but did not flag that
the committed clip assertion was clip-vacuous; it should have. The added
clip-fidelity GATE now exercises active clipping, closing the gap. For the
record, the G6 *output* was never in question — the auditor confirmed it returns
in-band probabilities; the defect was test coverage, now fixed.

## Verification

Full suite, both run modes (restored tree):

```sh
# package level (compiled backend)
Rscript -e 'pkgload::load_all("."); library(testthat);
  as.data.frame(test_file("tests/testthat/test-dgp-library.R", reporter="silent"))'
# auditor baseline (source + test_dir, the assignment command)
Rscript -e 'source("R/dgp_library.R"); library(testthat);
  as.data.frame(test_dir("tests/testthat", filter="dgp", reporter="silent"))'
```

Both report: `expectations=268 failed=0 errors=0 skipped=0 warnings=0`
(up from 236: +6 clip-fidelity, +26 registry-replay). The registry-replay test
resolves the CSV in both run modes (it does not skip).

Unchanged-artifact checks:

```sh
git diff c0e0d17 -- R/dgp_library.R inst/dgp_registry   # empty
```

## What this does and does not claim

- It does **not** claim G6 is accepted or mutation-qualified; that is the
  auditor's call on re-audit. The self-checks above only confirm the two added
  tests are non-vacuous.
- The accepted tags and reproduced registry rows from the audit remain valid
  because no generator or registry artifact changed.
