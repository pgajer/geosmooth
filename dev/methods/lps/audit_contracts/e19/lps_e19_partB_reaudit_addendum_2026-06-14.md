# E1.10 Part B re-audit — addendum (the bundle is now valid; proceed to the mutation phase)

Addendum to your standing assignment `project_briefs/lps_e19_partB_auditor_assignment_2026-06-14.md`
(role, run-in-place rules, mutation-table mechanics, and deliverable shape are there and apply
unchanged). This addendum points you at the re-run bundle, records what changed since that assignment was
written, and adds two emphases. The implementer handoff is
`dev/methods/lps/handoffs/phase/e1_10_partB_implementer_handoff_2026-06-14.md`.

## What changed: the prerequisite is now met

The prior audit (`audits/e1_10_partB_audit_2026-06-14.md`) rejected on an **incomplete, uncommitted
bundle** and stopped before the mutation phase. That is resolved. Certify this bundle:

| ref | SHA | what it is |
|---|---|---|
| audited tip | `ce4d558` | the source the prior audit hashed |
| audit verdict banked | `79b94bf` | "Add E1.10 Part B audit verdict (reject — incomplete bundle)" |
| **acceptance bundle** | `de0f861` | "Add E1.10 Part B acceptance bundle (complete, both studies, committed)" |

`de0f861` builds on the audited `ce4d558`; current `main` (t2) is **not** merged in (reconciliation is a
later step — do not pull it). The acceptance evidence is the **committed, tracked**
`reports/e1_10_acceptance/` (both studies' cases+verdicts, `MANIFEST.txt`, `run_metadata`, `sessionInfo`,
`source_checksums`, `realized_rho_per_replicate.csv`).

## Verify the re-run is source-clean (the daemonization fix is operational only)

The prior incompleteness was a killed background job; the implementer fixed it by daemonizing the ~33-min
run (`scripts/ci/_e110_daemon_launch.py`, double-fork/`setsid`). Confirm this changed **only how the run
is launched, not what it computes**:

- The four audited source files are **unchanged** `ce4d558..de0f861` (`git diff` is empty on `R/lps.R`,
  `R/lps_cv_utils.R`, `validation/e1_10_nested_grouped_cv.R`, `tests/testthat/test-lps-nested-grouped-cv.R`),
  and they still hash-match the prior audit's recorded values. Confirm both.
- Confirm the launch wrapper runs the study **verbatim** with the ratified parameters and
  `LPS_E110_ACCEPT=1` (no parameter substitution). The decisive check is your own: a fresh
  `Rscript validation/e1_10_nested_grouped_cv.R --mode=acceptance` with `LPS_E110_ACCEPT=1` should
  **reproduce the recorded numbers from the seeds** (Study (a) seed0 61000, Study (b) seed0 62000).
  Reproduce at least one cell of each study.

If the source is clean and the numbers reproduce, proceed to the full mutation table from the standing
assignment (leakage, cluster-integrity, the [P1] SE-guard → INCONCLUSIVE, [P3] fractional folds → error)
— it was blocked last time and is the central deliverable now.

## Emphasis 1 — Study (a): the PASS is near-vacuous, so the mutation must carry the weight

Study (a) PASSes the written rule (mean rel.nested 0.032, optimism-delta ≥ 0, both SE guards met), but the
optimism contrast is **near-degenerate**: only **1 of 40** `optimism.delta` values is nonzero and the
one-sided Wilcoxon p = 0.5. On `dgp.g3a`, nested and selected-min pick the same configuration in 39/40
replicates, so there is essentially no optimism to correct and the "nested ≥ selected-min" pass is almost
content-free. The study's teeth are therefore **entirely in the leakage mutation** — so it must be shown
non-vacuous:

- Run the leakage mutation (leak the held-out outer fold into inner selection) and check the effect in
  **`rel.nested`**, not `optimism.delta`: with the leak, nested CV stops correcting optimism, so
  `rel.nested` should **drop toward / below the test error** (the leak makes the in-sample estimate look
  better than honest). `optimism.delta` is ≈ 0 on this DGP and will not move informatively.
- If the leakage mutation is **also** vacuous here (the DGP is too stable for leaking to bite), that is a
  **study-design escalation** to record for the orchestrator: Study (a) then needs a config with genuine
  selection instability (smaller n / noisier / coarser grid where inner and outer selection diverge),
  not a green rubber-stamp.

## Emphasis 2 — Study (b): confirm the ρ=0.6 FAIL is genuine and correctly implemented; do NOT re-judge the bound

Study (b) returns **ρ=0.6 FAIL** (ρ=0.3 reported-only). This is the first negative STUDY verdict in the
program, which is healthy — but confirm it is a *real, correctly-implemented* result, not an artifact or a
bug:

- **Reproduce** the two gated quantities at ρ=0.6: the random-vs-cluster gap (**0.344**, ≫ 0.10, first
  clause met) and the cluster-fold relative error (**0.161**, > 0.10, second clause failed). Confirm both
  **SE guards pass** (se.gap 0.027, se.rel.cluster 0.021 < 0.0333) ⇒ it is a genuine **FAIL, not
  INCONCLUSIVE**.
- **Check the safeguards** (so the FAIL is not a folding defect): random arm splits clusters in 40/40
  reps, cluster arm whole in 40/40, train/test clusters disjoint (`train_`/`test_` prefixes), identical
  truth + noise law across arms, 0 missing predictions.
- **Sanity-check the mechanism** the handoff claims: cluster-fold *over*estimates fresh-cluster error
  (mean cluster − test ≈ +0.026), consistent with **K-fold train-size pessimism** (5-fold at K=40 trains
  each fold on 32/40 clusters; at ICC ≈ 0.59 the effective-data reduction biases the estimate upward) —
  a property of "K-fold trains on less data," orthogonal to cluster-vs-random folding. Confirm the
  numbers are consistent with this reading rather than a mis-built cluster fold.
- **Do not pre-judge or re-spec the decision rule.** Audit the FAIL **under the currently ratified rule**
  ("cluster-fold within 0.10 of truth"). Whether that second clause is the right target at K=40/5-fold is
  an **orchestrator** question handled *after* your verdict (a planned relative-criterion + leave-one-
  cluster-out re-spec, "Study b′"); your job is to certify the result as-run, not to move the goalpost.
- Note for your reading: the per-replicate `gap.primary` sign-flips a few times (min −0.064) because the
  per-rep statistic is an absolute-value ratio; the **gated quantity is the mean gap** (strongly
  positive), as specified — gate on the mean.

## Minor

The gate-battery bundle (`dev/methods/lps/audit_artifacts/e1_10_20260614T152852Z/`) is gitignored per the established
Part-A / E1.9 convention (in-worktree, reviewed in place); the committed `reports/e1_10_acceptance/` is the
acceptance evidence. If you want the gate-battery bundle tracked as well, request a force-add.

## Deliver

Your verdict per the standing Deliverable shape, with: the certified SHA (`de0f861`), the source-clean
confirmation, your reproduced numbers (one cell each from Study (a) and Study (b)), the full mutation
table now executed (incl. the **rel.nested** leakage non-vacuity for Study (a)), and an explicit line that
the Study (b) ρ=0.6 **FAIL is genuine and correctly implemented** (or, if not, what is wrong). Leave it
untracked for the orchestrator.

When this clears, E1.10 is content-complete; the ρ=0.6 FAIL travels as a **recorded finding** (§A1 — a
STUDY verdict is recorded, not a CI failure) for the orchestrator's Study b′ re-spec, and e19 proceeds to
its reconciliation merge against the already-merged t2.
