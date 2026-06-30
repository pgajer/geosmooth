# LPS Tier 0-4 Assets, Results, and Audit Closure Brief

Date: 2026-06-19

This brief pulls together the main assets generated during the LPS Tier 0-4 validation effort and records how that work answered the project-level audit in [LPS/PS-LPS JASA-style audit](../../../notes/cross_method/lps_ps_lps_jasa_style_audit_2026-06-09.md). The immediate implementation plan was [LPS Tiers 1-4 project brief](../specs/lps_tiers1to4_project_brief_2026-06-11.md), with the experimental details in [LPS experimental plan](../specs/lps_experimental_plan_2026-06-09.tex) and the multi-tier acceptance contract in [LPS Tiers 1-4 contract](../audit_contracts/tiers1to4/lps_tiers1to4_contract_2026-06-11.md).

The short version: the effort converted the broad audit into a much more disciplined LPS validation program. Tier 0 base correctness, Tier 1 bandwidth and CV machinery, Tier 2 binary/numerical hygiene, and Tier 4 fixed-configuration uncertainty were implemented and independently audited. The main unresolved LPS items are the local dimension/scale stabilization lane, the curvature-chart Tier 3 studies, and broader uncertainty beyond the narrow E4.1 fixed-configuration claim. PS-LPS audit issues remain outside this LPS Tier 0-4 closure and should stay in the PS-LPS program lane.

## What This Effort Was Responding To

The JASA-style audit identified several LPS-specific weaknesses:

- kernel bandwidth was confounded with neighborhood support size;
- selected CV error was selection-optimistic and random K-fold was inappropriate under clustered/dependent data;
- binary selection used inconsistent raw-vs-deployed probability scoring in some paths;
- log-loss clipping was too extreme for stable model comparison;
- local intrinsic dimension estimation was unstable on small neighborhoods;
- global `auto` dimension had transductive implications that needed to be made explicit or redesigned;
- ridge stabilization in orthogonal bases needed a clear penalty/target contract;
- the project lacked a stronger test suite for polynomial reproduction, smoother-matrix identity, grouped CV, binary clipping, logistic separation, curvature-chart behavior, and uncertainty.

The Tier 0-4 plan broke those issues into named gates and studies. Some were correctness gates, expected to pass or fail under targeted mutation. Others were scientific studies, where a negative or inconclusive result was still a valid outcome if it was honestly recorded.

## Status By Tier

| Tier / gate | Main question | Status | Main evidence | Remaining caveat |
|---|---|---|---|---|
| Tier 0, E0.1-E0.8 | Does base LPS satisfy polynomial reproduction, linear-smoother identity, leakage, rate, binary probability recovery, and degeneracy smoke gates? | Accepted after remediation and final integration. | Historical rejection and remediation in ignored `split_handoffs`; full `cpp` artifact `audit_artifacts/tier0_20260611T040812Z_cpp`; Phase 3 pass-2 re-audit. | Tier 0 artifacts were produced before the `dev/` reorganization; not all early files are curated under `dev/`. |
| DGP library | Are frozen G1-G7 generators deterministic and faithful enough for downstream LPS gates? | Accepted. | [DGP re-audit](../audits/dgp/dgp_library_reaudit_2026-06-12.md). | This is enabling infrastructure, not itself an estimator result. |
| Tier 1, E1.9 | Does the bandwidth multiplier decouple kernel scale from support size without changing default behavior? | E1.9a/E1.9b accepted. | [E1.9 audit](../audits/e1_9/e1_9_audit_2026-06-11.md). | E1.9c benefit study over curved DGPs was deferred. |
| Tier 1, E1.10 | Can nested and grouped CV machinery avoid selection and dependence leakage? | Machinery accepted; studies recorded. | [E1.10 Part A audit](../audits/e1_10/e1_10_audit_2026-06-12.md), [Part B re-audit](../audits/e1_10/e1_10_partB_reaudit_2026-06-14.md), [b-prime audit](../audits/e1_10/e1_10_bprime_audit_2026-06-14.md), [closure note](lps_e1_10_grouped_cv_closure_2026-06-14.md). | Grouped CV removes random-fold optimism, but absolute fresh-cluster accuracy was variance-limited at 40 clusters; this is a recorded negative/inconclusive study result. |
| Tier 1, E1.11 | Can local dimension estimates be stabilized without smearing genuine dimension changes? | Not completed in Tier 1-4; moved into LDS/local dimension-and-scale planning. | [LPS LDS design plan](../specs/lps_lds_design_and_test_plan_2026-06-13.tex), [local dimension regularization implementation notes](../specs/lps_local_dimension_regularization_implementation_notes.tex). | Still needs implementation, audits, and performance studies. |
| Tier 2, E2.12 | Does binary selection score the deployed clipped probability metric? | Accepted after required fixes. | [Tier 2 audit](../audits/tier2/tier2_audit_2026-06-11.md), [combined re-audit](../audits/tier2/tier2_combined_reaudit_2026-06-13.md), [binary hygiene report](../reports/tier2/binary_hygiene/2026-06-11/lps_tier2_binary_hygiene_report_2026-06-11.html). | Cross-clip stability is a recorded diagnostic, not a correctness gate. |
| Tier 2, E2.13 | Is ridge stabilization aligned with the intended shrinkage target? | Accepted. | [Tier 2 combined re-audit](../audits/tier2/tier2_combined_reaudit_2026-06-13.md); Phase 3 integration audit. | Future default changes should keep the shrinkage target explicit. |
| Tier 2, E2.14 | Are local logistic fits robust under near/exact separation? | Accepted. | [Tier 2 audit](../audits/tier2/tier2_audit_2026-06-11.md), [combined re-audit](../audits/tier2/tier2_combined_reaudit_2026-06-13.md). | Covers the tested local logistic path and fixtures. |
| Tier 2, E2.15 / E0.6 amendment | Does binomial NA/fallback behavior avoid silent selection and all-fallback vacuity? | Accepted. | [E0.6 binomial amendment re-audit](../audits/tier2/e0_6_binomial_amendment_reaudit_2026-06-13.md), [E0.6 fallback-bound audit](../audits/tier0/e0_6_fallback_bound_audit_2026-06-14.md). | The fallback bound is pragmatic, not a theorem; revisit only with evidence. |
| Tier 3, E3.1/E3.2 | Do second-order/curvature charts improve high-curvature behavior and pass curvature-bias checks? | Specified and DGP-unblocked, but not completed as accepted Tier 3 evidence. | DGP audit released G3a/G3b/G3d for use; Tier 3 contract section remains the main spec. | Curvature-chart exploration was later put on hold because early evidence did not justify prioritizing it over more urgent LPS/PS-LPS work. |
| Tier 4, E4.1 Part A | Can the fixed-config smoother matrix produce correct pointwise variance, df, sigma estimate, and bands? | Accepted. | [E4.1 Part A audit](../audits/e4_1/e4_1_partA_audit_2026-06-11.md). | Only for a narrow fixed-config envelope, not arbitrary grids or auto chart modes. |
| Tier 4, E4.1 Part B | Does the fixed-config confidence band achieve the frozen interior-average coverage gate on audited G3a? | Accepted for the ratified conditional-on-design claim. | [E4.1 Part B audit](../audits/e4_1/e4_1_partB_audit_2026-06-12.md). | Not a per-point, bias-corrected, redrawn-geometry, or auto/local-auto uncertainty guarantee. |
| Phase 3 integration | Did merged main preserve Tier 0, Tier 1, Tier 2, and GE7 behavior? | Accepted. | [Phase 3 pass-1 re-audit](../audits/phase3/phase3_merged_main_reaudit_2026-06-14.md), [Phase 3 pass-2 re-audit](../audits/phase3/phase3_pass2_reaudit_2026-06-14.md). | Full suite had warnings attributed to pre-existing graph-trend-filtering paths; not LPS gate failures. |

## Audit Issues Addressed

### Bandwidth/support confounding

Addressed by E1.9. `bandwidth.multiplier.grid` was added so support size and kernel scale can vary separately. The default multiplier `1` was pinned to reproduce pre-change behavior exactly. The benefit study was intentionally deferred until audited DGPs were available.

Key assets:

- [E1.9 audit](../audits/e1_9/e1_9_audit_2026-06-11.md)
- [E1.9 implementer handoff](../handoffs/phase/e1_9_implementer_handoff_2026-06-11.md)
- [E1.9 audit contract](../audit_contracts/e19/lps_e19_auditor_prompt_2026-06-11.md)

### Selection optimism and grouped CV

Partly addressed by E1.10. The machinery for nested CV and grouped fold construction was accepted and mutation-qualified. The scientific study did not simply turn green: it showed that random K-fold is optimistic under cluster dependence, while grouped/LOCO CV is the right procedure but can still have high variance when the effective number of clusters is small.

Key assets:

- [E1.10 Part A audit](../audits/e1_10/e1_10_audit_2026-06-12.md)
- [E1.10 Part B re-audit](../audits/e1_10/e1_10_partB_reaudit_2026-06-14.md)
- [E1.10 b-prime audit](../audits/e1_10/e1_10_bprime_audit_2026-06-14.md)
- [E1.10 grouped-CV closure note](lps_e1_10_grouped_cv_closure_2026-06-14.md)
- [E1.10 acceptance run directory](../runs/e1_10_acceptance/MANIFEST.txt)
- [E1.10 b-prime run directory](../runs/e1_10_bprime/MANIFEST.txt)

### Binary scoring, clipping, and logistic separation

Addressed by Tier 2. Binary selection now uses deployed clipped probability-scale metrics where required; log-loss clipping is pinned to a finite value; local logistic fitting has step-halving and fallback telemetry under near/exact separation; binomial NA-heavy candidate behavior is no longer allowed to win by dropping bad predictions.

Key assets:

- [Tier 2 audit](../audits/tier2/tier2_audit_2026-06-11.md)
- [Tier 2 combined re-audit](../audits/tier2/tier2_combined_reaudit_2026-06-13.md)
- [Tier 2 binary hygiene HTML report](../reports/tier2/binary_hygiene/2026-06-11/lps_tier2_binary_hygiene_report_2026-06-11.html)
- [Tier 2 full-size bundle, 20260614T015321Z](../runs/audit_artifacts/tier2_20260614T015321Z/execution_manifest.txt)

### Ridge penalty structure

Addressed by E2.13 and final Phase 3 integration. The aligned local-mean shrinkage target and legacy zero target are explicitly distinguished, and tests protect both the intended new behavior and the default compatibility path.

Key assets:

- [Tier 2 combined re-audit](../audits/tier2/tier2_combined_reaudit_2026-06-13.md)
- [Phase 3 pass-2 re-audit](../audits/phase3/phase3_pass2_reaudit_2026-06-14.md)

### Uncertainty quantification

Addressed narrowly by E4.1. The fixed-configuration smoother matrix, pointwise variance, degrees of freedom, plug-in sigma, and confidence-band construction are accepted. The coverage study on audited G3a passed the interior-average gate at the ratified configuration.

Key assets:

- [E4.1 Part A audit](../audits/e4_1/e4_1_partA_audit_2026-06-11.md)
- [E4.1 Part B audit](../audits/e4_1/e4_1_partB_audit_2026-06-12.md)
- [E4.1 Part B implementer handoff](../handoffs/phase/e4_1_partB_implementer_handoff_2026-06-12.md)

### Test-suite hardening and mutation qualification

Substantially addressed. The final integration audit records mutation checks for E1.9, E1.10, E2.12, E2.13, E2.14, E2.15, E0.6, and the GE7 cleanup. Tier 0 itself had an explicit rejection-remediation cycle, which is valuable because it prevented a weak green check from becoming accepted evidence.

Key assets:

- [Phase 3 pass-2 re-audit](../audits/phase3/phase3_pass2_reaudit_2026-06-14.md)
- Historical first rejection: `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_tier0_independent_execution_audit_2026-06-10.md`
- Historical bucket-2 re-audit: `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_tier0_bucket2_remediation_audit_response_reaudit_2026-06-10.md`

## Issues Still Requiring Follow-Up

### E1.9c bandwidth-benefit study

The correctness of the bandwidth multiplier and backward compatibility are accepted, but the promised benefit study over curved DGPs was deferred. If bandwidth multiplier is going to be promoted as scientifically useful rather than just available, this study still needs to run.

### E1.11 local dimension stabilization

The JASA audit's concern about unstable `auto` / `local.auto` dimension estimation remains the largest LPS-specific open modeling issue. It has not disappeared; it moved into the LDS/local dimension-and-scale program. The relevant current plans are:

- [LPS LDS design and test plan](../specs/lps_lds_design_and_test_plan_2026-06-13.tex)
- [Local dimension regularization implementation notes](../specs/lps_local_dimension_regularization_implementation_notes.tex)

### Global `auto` dimension and transductive interpretation

The audit concern that global `auto` dimension can use all `X` before CV is not fully closed by Tiers 0-4. Future reports should state the estimand and selection protocol explicitly: transductive fixed-design smoothing is different from fresh-sample generalization with fold-local dimension estimation.

### Tier 3 curvature-chart tests

The DGP library made G3a/G3b/G3d available, but the E3.1/E3.2 curvature-chart validation does not appear as an accepted Tier 3 evidence bundle. This should remain listed as deferred, not completed.

### Broader uncertainty beyond E4.1

E4.1 is accepted only for a fixed configuration and an interior-average coverage claim. Still open: uncertainty for auto/local-auto chart selection, non-singleton grids, adaptive support/dimension, boundary correction, bias-corrected bands, binary outcomes, and real-geometry settings.

### PS-LPS audit issues

The JASA-style audit also raised PS-LPS-specific issues, including degrees-of-freedom for synchronized fits, lambda-path behavior, sync graph tuning, endpoint characterization, and alternative penalties. Those were outside the LPS Tier 0-4 closure and should remain in the PS-LPS lane.

## Recommended Use Of This Brief

Use this document as the top-level index for the LPS Tier 0-4 validation history. For implementation claims, cite the specific audit file, not this summary. For scientific claims, preserve the distinction between accepted correctness gates and recorded studies with negative or inconclusive outcomes.

A good one-sentence status is:

> LPS base correctness, binary/numerical hygiene, bandwidth-multiplier plumbing, nested/grouped CV machinery, and fixed-config uncertainty were audited and integrated; local dimension/scale stabilization, Tier 3 curvature charts, and broader uncertainty remain follow-up work.
