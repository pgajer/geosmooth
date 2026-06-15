# E4.1 Part B auditor report -- coverage acceptance at ratified K = 20

Date: 2026-06-12
Auditor: Codex
Target handoff: `phase_handoffs/e4_1_partB_implementer_handoff_2026-06-12.md`
Worktree audited: `/Users/pgajer/current_projects/geosmooth-t4`
Current HEAD: `d5b64b2b3561b2e9cf3483dfc42136c6c1c72da1`
Acceptance bundle HEAD: `0f2c086210b7a8ba5d1862b650e60f99ad233706`
Evidence bundle reviewed: `audit_artifacts/e4_1_20260612T195644Z/`

## Verdict

E4.1 Part B is accepted for the ratified conditional-on-design coverage
claim: at K = 20, `tricube`, audited G3a row
`G3a-R1-smooth-s010-n1200`, n = 1200, R = 500, and sigma = 0.1, the
interior-average known-sigma and plug-in coverage gates both pass.

This acceptance is for the frozen E4.1 average-interior coverage gate only.
It is not a per-point coverage guarantee, not a claim over redrawn G3a
geometries, and not a bias-corrected-band result.

## Findings

No blocking findings.

### [P3] Static manifest header still says the Part B smoke leg is wiring evidence only

File: `scripts/ci/run_e4_1_execution_artifact.sh` / generated
`audit_artifacts/e4_1_20260612T195644Z/execution_manifest.txt`.

The manifest's fixed `gate:` line still reads
`E4.1 (Part A unit GATE; Part B smoke leg is wiring evidence only)`, even
when `E4_ACCEPT=1` produced an acceptance leg. The explicit `accept_*` fields
are correct and unambiguous (`accept_enabled: 1`, `accept_context:
acceptance-candidate`, `accept_dgp_source: amendment1-g3a`, passing
coverage rows), so this is not a provenance blocker. Future harness output
should revise the static label to avoid confusing the acceptance bundle with
the earlier smoke-only Part B artifact.

## Evidence Checked

- The current HEAD differs from the acceptance bundle HEAD only by adding the
  Part B handoff. No package source, validation script, test, harness, or
  audit-contract file changed after the acceptance bundle commit.
- The acceptance driver pins the ratified configuration in code:
  `validation/e4_1_acceptance_run.R` sets n = 1200, R = 500, sigma = 0.1,
  support size K = 20, kernel `tricube`, curvature radius 1, geometry seed 1,
  drift guard every 25 replicates plus first and last, and the audited
  Amendment-1 G3a binding.
- The DGP binding independently re-materialized the frozen row from commit
  `58f5ab93b433b73d60c291fc6daebd53644054e8`, blob
  `030c1d00f43678eb519b62ab61ff8375cdb0dc14`, dataset
  `G3a-R1-smooth-s010-n1200`, SHA-256
  `b5a2e07699378e74eecbeeef5fb2b1108e3701a43601c4623babb81a9d204614`,
  `verified TRUE`.
- The machine-readable verdict rows report:
  known sigma coverage `0.941802752293578` in `[0.93, 0.97]`, verdict `pass`;
  plug-in sigma coverage `0.93531880733945` in `[0.92, 0.98]`, verdict
  `pass`; context `acceptance-candidate`; DGP source `amendment1-g3a`.
- The drift guard table has 21 rows and all fitted/band/df discrepancies are
  below `1e-10`; maximum observed guard discrepancy was `6.661e-16`.
- The focused E4.1 test file passed live after audit restoration:
  `test-lps-tier4-uncertainty.R` produced 53 passes, 0 failures, 0 warnings,
  0 skips.

## Mutation Qualification

I introduced one transient auditor mutation in
`validation/e4_1_coverage_study.R`: replaced

```r
row.norm <- sqrt(rowSums(S^2))
```

with

```r
row.norm <- rep(1, n)
```

Then I ran the pinned acceptance driver to `/tmp/e4_1_wrong_variance_mutation`.
The study turned red immediately:

```text
Error: drift guard failed at replicate 1: the S-path and the full
fit.lps/lps.pointwise.band pipeline disagree beyond 1e-10
(fitted 5.551115e-16, known band 0.1450476, plug-in band 0.1348593, df 0).
Study aborted.
```

The mutation was reverted, `git diff` for the mutated file was empty, and the
focused E4.1 tests were rerun green. This mutation confirms that the
acceptance harness does not quietly pass if the variance path used for bands
is corrupted; the drift guard catches the fault before a false verdict can be
reported.

Part A already mutation-qualified the production variance formula in
`R/lps_uncertainty.R`; this Part B mutation specifically qualifies the
acceptance-study fast path and drift guard at the ratified configuration.

## Numerical Interpretation

The accepted gate is the interior average. The stratified outputs correctly
show the limitations:

- Interior: known `0.9418`, plug-in `0.9353`, min per-point known coverage
  `0.842`, mean/max bias-to-se `0.216/0.913`.
- Boundary-within-h: known `0.9380`, plug-in `0.9312`, min per-point known
  coverage `0.828`, mean/max bias-to-se `0.248/1.007`.
- Top-curvature decile: known `0.9427`, plug-in `0.9366`, min per-point known
  coverage `0.858`.

These results support the frozen E4.1 interior-average claim, while also
showing why the handoff's deferral of per-point/bias-corrected coverage to a
future E4.2-style extension is scientifically important.

## Scope Limits

- I did not rerun the full R package test suite. The Part B handoff reports
  that `make test` remains red from pre-existing `test-ge7-lps-api.R`
  failures unrelated to E4.1, and no package source changed in Part B.
- I did not rerun the full R = 500 acceptance study from scratch without the
  fast path (`fit.every.replicate=TRUE`), because the ratified protocol uses
  21 drift guards and the accepted bundle already records them. The auditor
  mutation exercised the same drift guard and showed it fails hard under a
  corrupted variance path.
- No package code was changed by this audit. The only durable output is this
  audit report.
