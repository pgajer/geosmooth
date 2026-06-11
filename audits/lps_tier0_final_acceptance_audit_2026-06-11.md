# LPS Tier-0 Final Acceptance Audit

Date: 2026-06-11
Auditor: Codex

Subject:

- `/Users/pgajer/current_projects/geosmooth/phase_handoffs/lps_tier0_final_acceptance_implementer_handoff_2026-06-11.md`

## Verdict

Tier-0 final acceptance is approved for the implemented gate set E0.1-E0.8, under the scope defined by the final-acceptance work order.

The final full bundle at commit `b86b796aeefa10204dc4a3b1e2e34c8b62dad837` is clean, source-bound, full-mode, green, and covers all required Tier-0 gate labels. The second native token is covered by the work-order-approved probe-only parity addendum on the same git head. Independent mutation/falsification checks were run by the auditor in a temporary worktree for representative correctness gates, and the earlier pre-fix full E0.6 failure artifact confirms that the final E0.6 support-schedule correction is not vacuous.

## Evidence Reviewed

Final handoff:

- `/Users/pgajer/current_projects/geosmooth/phase_handoffs/lps_tier0_final_acceptance_implementer_handoff_2026-06-11.md`

Binding contract/work order:

- `/Users/pgajer/current_projects/geosmooth/audit_contracts/lps_tier0/lps_tier0_execution_artifact_contract_2026-06-10.md`
- `/Users/pgajer/current_projects/geosmooth/audit_contracts/lps_tier0/lps_tier0_final_acceptance_work_order_2026-06-11.md`

Execution artifacts:

- `/Users/pgajer/current_projects/geosmooth/audit_artifacts/tier0_20260611T040812Z_cpp`
- `/Users/pgajer/current_projects/geosmooth/audit_artifacts/tier0_20260611T051534Z_cpp.local.pca`
- `/Users/pgajer/current_projects/geosmooth/audit_artifacts/tier0_20260611T025625Z_cpp` (pre-fix failed E0.6 artifact)

## Bundle Checks

### Full gate bundle, `cpp`

Artifact:

```text
audit_artifacts/tier0_20260611T040812Z_cpp
```

Manifest facts:

```text
mode: full
git_head: b86b796aeefa10204dc4a3b1e2e34c8b62dad837
tree_clean: true
native_backend_token: cpp
testthat_rc: 0
testthat_summary: tests=16 failed=0 error=0 warning=0 skipped=1
gate_contexts: E0.1;E0.2;E0.3a;E0.4;E0.5;E0.6;E0.7;E0.8
probe_rc: 0
```

The one skipped row is the sanctioned E0.3a deferral:

```text
E0.3a response-removal LOO shortcut matches the code path, or defers
```

The bundle's tracked files are exactly `R/lps.R` plus the three Tier-0 test files, and `git_status.txt` is empty. Recomputed source checksums from `b86b796aeefa10204dc4a3b1e2e34c8b62dad837` match the bundle's `source_checksums.txt`.

Backend parity:

```text
cpp, ok, 2.22044604925031e-16
```

Headroom/probe summary:

```text
E0.1 n=64 all_pass=TRUE max_err=3.331e-15 min_headroom=3002399.8x
E0.2 pass=TRUE id_res=4.441e-16 df_res=0.000e+00
determinism=0.000e+00
parity=ok
```

### Probe-only addendum, `cpp.local.pca`

Artifact:

```text
audit_artifacts/tier0_20260611T051534Z_cpp.local.pca
```

Manifest facts:

```text
mode: probe
git_head: b86b796aeefa10204dc4a3b1e2e34c8b62dad837
tree_clean: true
native_backend_token: cpp.local.pca
probe_rc: 0
```

Backend parity:

```text
cpp.local.pca, ok, 0
```

The final-acceptance work order explicitly allowed this second token to be probe-only because the Tier-0 testthat battery is backend-token-independent and uses `backend="R"` internally. I accept the probe-only addendum as sufficient for the second token under that work order.

## Full-Mode Accuracy Gates

E0.5 full-mode extraction reported:

```text
slope=-0.301974 se=0.005392 ci_hi=-0.291406
```

This clears the frozen `ci_hi < -0.1` criterion.

E0.6 full-mode output reported six binary-family/prevalence combinations. Every reported slope confidence upper bound is below `-0.1`; the held-out Bernoulli calibration check is included in the green full bundle. The E0.6 binomial path has nonzero fallback/NA diagnostics, but the maxima remain below the frozen finite-row criterion and are recorded rather than hidden.

## Independent Mutation/Falsification

I created a temporary detached worktree at `b86b796aeefa10204dc4a3b1e2e34c8b62dad837`, ran targeted baseline snippets, then applied reversible one-line mutations. The live working tree was not modified.

Observed results:

| Gate | Auditor mutation | Result |
|---|---|---|
| E0.1 | Made the under-specified-polynomial negative-control threshold impossible (`expect_gt(err, 1e3)`) | Red: 1 failure |
| E0.2 | Added `1e-4` to the extracted smoother matrix columns | Red: 14 failures across ambient/local-PCA linearity checks |
| E0.4 | Compared degree-0 boundary error against degree-0 instead of degree-1 | Red: 2 failures |
| E0.5 | Added a fixed positive bias to fitted values in the Truth-RMSE rate calculation | Red: 1 failure |
| E0.7 | Removed the held-out response perturbation, breaking the positive control | Red: 1 failure |
| E0.8 | Reversed the deterministic-tie assertion to require repeats to differ | Red: 1 failure |

E0.6 non-vacuity is additionally supported by the clean pre-fix full artifact:

```text
audit_artifacts/tier0_20260611T025625Z_cpp
mode: full
git_head: 8a0964364a4cfa2afb6186d35453d5371fb914e3
tree_clean: true
testthat_summary: tests=16 failed=2 error=0 warning=0 skipped=1
```

That failure was in E0.6 before the final support-schedule correction. The final corrected commit then passes the same full-mode E0.6 gate.

E0.3a remains a sanctioned deferral because `fit.lps` exposes no independent per-point GCV/LOO residual path. This is not mutation-qualified, but the contract already treats this row as a sanctioned skip folded into E0.2 rather than as an active correctness gate.

## Nonblocking Notes

The current working tree has unrelated untracked files, but the acceptance artifacts are bound to clean committed git heads. Do not use the current dirty working tree as acceptance evidence.

The frozen experimental spec source is currently visible as an untracked `project_briefs/lps_experimental_plan_2026-06-09.tex` in the local tree. That does not affect this artifact-bound Tier-0 verdict, but future tiers should keep binding specs tracked if they are used as audit authority.

## Conclusion

The final full bundle, second-token parity addendum, full-mode E0.5/E0.6 results, and independent falsification checks are sufficient to mark LPS Tier-0 final-accepted for the implemented E0.1-E0.8 gate set.
