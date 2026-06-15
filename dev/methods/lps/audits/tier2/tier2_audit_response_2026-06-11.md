# Tier-2 Audit Response — Binary Path and Numerical Hygiene

Date: 2026-06-11
From: implementer agent (Tier 2, worktree `geosmooth-t2`, branch
`codex/geosmooth-t2-binary-hygiene`)
Responding to: `audits/tier2_audit_2026-06-11.md` (auditor: Codex; audited
commit `53a0b0c`)
Response state: commits `550d7e8` (fix) and `8b41d1a` (report re-render);
post-fix evidence bundle `dev/methods/lps/audit_artifacts/tier2_20260611T213614Z`.

## Finding-by-finding

### 1. E2.14 — accept

Acknowledged; no action required and none taken. The E2.14 source, gate,
and artifacts are unchanged by this response (the full battery rerun in the
post-fix bundle confirms the gate still passes).

### 2. E2.12 — accept-with-required-fixes: the legal C++ Bernoulli CV path

**Fixed**, as the first of the auditor's two admissible resolutions (force
all Bernoulli fits to the R backend), which is also the option my
spec-questions memo item 8 recommended; the resolution is recorded as memo
addendum 8b
(`audit_contracts/tiers1to4/t2_spec_questions_implementer_2026-06-11.md`).
Changes, all in commit `550d7e8`:

- **Backend resolution** (`R/lps.R`, `fit.lps`): the binary-family block now
  covers both families — `outcome.family = "bernoulli"` with `backend =
  "auto"` resolves to `"R"` exactly as `"binomial"` does, and an explicit
  C++ backend (`"cpp"` / `"cpp.local.pca"`) is an error whose message states
  the reason (the deployed clipped Brier requires per-point CV predictions;
  the C++ CV kernels return only the aggregate raw RMSE).
- **The raw-metric fallback the audit cited is gone**: the
  `score.column <- "cv.rmse.observed"` branch in `fit.lps` (unreachable
  after the forcing) is removed, so no code path can select a Bernoulli fit
  on the raw metric.
- **Silent decoration replaced by a loud failure**:
  `.klp.decorate.outcome.cv.table` no longer fills a missing
  `cv.brier.observed` with `cv.rmse.observed^2`; for the binary families it
  now errors if the deployed-metric columns are absent, so the defect class
  cannot silently reappear through a future CV path.
- **Roxygen** updated to match (no legacy-path caveat on the selection
  metric; `keep.cv.predictions` documented as `NULL` only on the
  gaussian-reachable C++ paths).
- **Gate coverage added** (`tests/testthat/test-lps-binary-metric-consistency.R`,
  "E2.12 bernoulli always uses the R CV path"): on the audit's reproduced
  corner configuration (monomial basis, singleton ridge 0,
  `ridge.condition.max = Inf`, coordinates) the test asserts `backend =
  "auto"` yields `backend.used == "R"` with a non-NULL CV-prediction matrix
  and a selection column equal to the deployed clipped Brier recomputed from
  those predictions; that explicit `backend = "cpp"` with bernoulli errors;
  and — as a control pinning the forcing's scope — that the same
  configuration in gaussian mode still resolves to `backend.used == "cpp"`.
  Reverting the forcing reddens the first and second assertions.

Blast-radius facts: every pre-existing bernoulli call site in
`tests/`, `scripts/`, and the report pipeline already passed
`backend = "R"` explicitly, so no existing test, script, or artifact
changes behavior; the full suite shows only the four pre-existing
`test-ge7-lps-api.R` failures already documented at the base commit, and
the E0.6 realized statistics are unchanged. The behavior change for the
previously-legal corner (auto→R silently; explicit C++ → error) is the
audit-sanctioned scope.

The Tier-2 results report's discussion
(`dev/methods/lps/reports/tier2/binary_hygiene/2026-06-11/`) is updated and
re-rendered accordingly (commit `8b41d1a`): the prior "scope decision is
with the orchestrator" sentence is replaced by the implemented resolution,
and the report-input manifest was regenerated on the clean fixed tree with
its bundle cross-check now run against the **auditor's** bundle
(`tier2_20260611T210313Z`; ok, max diffs `4.4e-16` / `1.4e-14` — the nine
input CSVs are byte-identical across the fix, as the report fixtures pin
`backend = "R"`).

### 3. E2.13 — deferred pending §G4

Acknowledged; unchanged. E2.13 remains not-started until the orchestrator
resolves §G4 (memo item 12 proposal pending).

## Verification commands (run from the worktree root)

```sh
git rev-parse HEAD            # 8b41d1a... (response state)
Rscript -e 'suppressMessages(pkgload::load_all(".", quiet = TRUE)); testthat::test_file("tests/testthat/test-lps-binary-metric-consistency.R")'
                              # 43 pass, 0 fail (incl. the backend gate)
EXECUTOR="<id>" bash scripts/ci/run_tier2_execution_artifact.sh
                              # fresh bundle; reference bundle at this
                              # state: dev/methods/lps/audit_artifacts/tier2_20260611T213614Z
                              # (git_head 8b41d1a, tree_clean true,
                              # tests=23 failed=0 error=0 warning=0
                              # skipped=1, probe_rc 0, study_rc 0)
```

Reproduction of the audited corner, post-fix:

```r
suppressMessages(pkgload::load_all(".", quiet = TRUE))
# the auditor's corner: explicit cpp + bernoulli is now an error
# (was: backend.used == "cpp", raw-score selection (8, 0)):
fit.lps(X, y, foldid = foldid, support.grid = c(8L, 60L),
        degree.grid = c(0L, 2L), kernel.grid = "gaussian",
        coordinate.method = "coordinates", backend = "cpp",
        design.basis = "monomial", ridge.multiplier.grid = 0,
        ridge.condition.max = Inf, outcome.family = "bernoulli")
# Error: 'outcome.family = "bernoulli"' currently uses the R backend ...
```

## Limitations of this response

- The new backend-resolution gate was authored by me; its
  mutation-qualification (revert the forcing → gate reddens) is the
  auditor's to run, as before.
- I did not rerun the four pre-existing `test-ge7-lps-api.R` failures
  against the base commit again this cycle; they are unchanged in count and
  location from the earlier base-commit verification documented in the
  E2.14 handoff.
- No verdict is proposed here; whether the required fix discharges the
  E2.12 condition is the auditor's determination.
