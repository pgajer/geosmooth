# Response to LPS Phase-0 Tier-0 and Binary 5-Rep Audit

This response addresses the audit in:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_phase0_audit_tier0_and_binary_5rep_2026-06-10.md`

## Summary

The binary GM/FF 5-repetition report has been revised to make fallback behavior explicit rather than treating the pooled Brier-vs-logistic comparison as a single homogeneous result.

The Tier-0 LPS correctness harness has also been strengthened as an execution artifact: it now records realized error/headroom, determinism, native-backend parity, and literal gate coverage labels. A small E0.1 negative control was added. The fresh local artifact is useful for review but is not a final gate artifact because the repository tree is intentionally dirty during this response.

## Binary GM/FF Report Revisions

Updated report:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_binary_gm_ff_telemetry_valid_5rep_20260609_001/reports/lps_binary_gm_ff_5rep_report.html`

New/updated report assets:

- `tables/binary_gm_ff_fallback_stratified_delta_summary.csv`
- `tables/binary_gm_ff_geometry_fallback_summary.csv`
- `reports/figures_lps_binary_gm_ff/figure_4_fallback_stratified_paired_delta.png`

Implemented changes:

- Added a fallback-stratified paired Truth-RMSE delta section.
- Grouped paired deltas by the logistic final-fit event-rate fallback fraction:
  - `0`
  - `(0, 0.05]`
  - `(0.05, 0.25]`
  - `>0.25`
- Reframed conclusions so the pooled result is not read as a pure Brier-vs-logistic comparison.
- Explicitly states that high fallback fractions mean the logistic-mode output is partly fallback-driven, not clean local logistic fitting alone.
- Kept observed log-loss labeled as full-data final-fit in-sample telemetry and did not add it as a performance plot.
- Preserved the selection-asymmetry caveat.

Fallback-stratified paired Truth-RMSE deltas:

| fallback stratum | pairs | median delta, logistic minus Brier | interpretation |
|---|---:|---:|---|
| `0` | 435 | `+0.0031317` | clean logistic fits mildly favor Brier |
| `(0, 0.05]` | 1174 | `+0.0105456` | low fallback still favors Brier |
| `(0.05, 0.25]` | 876 | `+0.0104128` | moderate fallback still favors Brier |
| `>0.25` | 395 | `-0.0177173` | heavy fallback reverses the sign and favors the logistic-mode output |

The revised interpretation is therefore: the pooled result mixes two regimes. In low- or zero-fallback settings, Brier is generally favored. In heavy-fallback settings, the logistic-mode output often wins, but this is not evidence that the local logistic solver itself is superior; it is evidence about the combined logistic/fallback procedure.

## Tier-0 Harness Revisions

Updated files:

- `tests/testthat/test-lps-tier0-correctness.R`
- `scripts/ci/run_tier0_execution_artifact.sh`
- `scripts/ci/tier0_headroom_probe.R`

Implemented changes:

- Added an E0.1 negative control: a degree-1 local model is intentionally asked to reproduce a degree-2 truth and is required not to pass exact reproduction.
- Fixed artifact CSV writing for list-valued `testthat` result columns.
- Fixed gate-context reporting so the manifest records `E0.1;E0.2` even when `testthat::test_file()` leaves the `context` column blank.
- Added a native backend parity probe using `LPS_NATIVE_BACKEND=cpp.local.pca`.
- The probe records realized reproduction error, tolerance headroom, E0.2 identity/df residuals, determinism, and native/R parity.

Fresh local artifact:

`/Users/pgajer/current_projects/geosmooth/audit_artifacts/tier0_20260610T184844Z`

Artifact manifest summary:

```text
tree_clean: false
native_backend_token: cpp.local.pca
testthat_rc: 0
testthat_summary: tests=5 failed=0 error=0 warning=0 skipped=0
gate_contexts: E0.1;E0.2
probe_rc: 0
probe_summary: E0.1 n=64 all_pass=TRUE max_err=2.220e-15 min_headroom=4503599.6x | E0.2 pass=TRUE id_res=4.441e-16 df_res=0.000e+00 | determinism=0.000e+00 | parity=ok
```

Key realized quantities:

| quantity | value |
|---|---:|
| E0.1 probed cases | 64 |
| E0.1 max realized error | `2.22044604925031e-15` |
| E0.1 minimum tolerance headroom | `4503599.6273705x` |
| E0.2 identity residual | `4.44089209850063e-16` |
| E0.2 df residual | `0` |
| determinism max difference | `0` |
| native/R parity max absolute difference | `0` |

The local artifact is deliberately not claimed as a final acceptance artifact because `tree_clean: false`. A final Tier-0 gate should be run from a clean, committed tree or by an independent executor/CI following:

`/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md`

## Remaining Open Items

The audit is correct that the current Tier-0 implementation covers only E0.1 and E0.2. It does not yet complete the full Tier-0 plan. The following remain open:

- E0.3 honest leave-one-out / training-removal behavior.
- E0.4 backend-equivalence expansion beyond the current focused parity probe.
- E0.5 grouped or nested CV behavior.
- E0.6 additional deterministic seed/run reproducibility if required outside the current fixed-configuration probe.
- E0.7/E0.8 remaining Tier-0 contract checks from the frozen plan.
- Independent clean-tree execution artifact.

Recommended next audit question:

Does the revised binary report now make the fallback-confounded interpretation unavoidable, and is the strengthened Tier-0 artifact harness acceptable as the execution vehicle once run from a clean committed tree by an independent executor?
