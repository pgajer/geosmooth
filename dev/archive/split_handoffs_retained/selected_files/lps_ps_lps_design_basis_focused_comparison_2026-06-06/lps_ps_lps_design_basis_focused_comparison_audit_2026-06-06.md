# LPS / PS-LPS Design-Basis Focused Comparison Audit

Auditor: Codex
Date: 2026-06-06 22:38:53 EDT

## Verdict

Pass for the intended focused backend smoke/audit exercise. I found no blocker
in the `orthogonal.polynomial.drop` numerical contract, the PS-LPS frame
transformation path, or the report's stated interpretation.

This is not yet enough evidence to promote `orthogonal.polynomial.drop` to a
general experiment-facing default. It is enough evidence to keep it as an
explicit candidate backend and to include it prominently in the next P7X-style
comparison.

## Scope Reviewed

- Handoff:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_design_basis_focused_comparison_2026-06-06/lps_ps_lps_design_basis_focused_comparison_auditor_handoff_2026-06-06.md`
- Script:
  `/Users/pgajer/current_projects/geosmooth/scripts/lps_ps_lps_design_basis_focused_comparison.R`
- HTML report:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_design_basis_focused_comparison_2026-06-06/lps_ps_lps_design_basis_focused_comparison.html`
- Summary/failure tables:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_design_basis_focused_comparison_2026-06-06/tables/lps_ps_lps_design_basis_summary.csv`
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_design_basis_focused_comparison_2026-06-06/tables/lps_ps_lps_design_basis_failures.csv`
- Relevant implementation paths:
  `/Users/pgajer/current_projects/geosmooth/R/lps.R`
  `/Users/pgajer/current_projects/geosmooth/R/ps_lps.R`
- Focused tests:
  `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R`
  `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ps-lps.R`

## Audit Answers

### 1. Orthogonal zero-ridge prediction-space preservation

Accepted.

The implementation builds the orthogonal basis from the weighted support design
using the SVD of `design * sqrt(weights)`, keeps singular directions above
`max(singular_value) * design.drop.tol`, and applies the same right-side
transform to `prediction.rows`. With ridge multiplier zero, this is a
coordinate change for the retained weighted-design column space, not a separate
model class.

The test suite also checks that LPS with `orthogonal.polynomial.drop`,
zero ridge, and no effective rank loss agrees with the monomial-span LPS
fit/CV values to numerical tolerance. That test passed in this audit run.

### 2. PS-LPS transformed frame designs

Accepted.

In `.ps.lps.prepare.frames`, each chart-local raw design and its anchor
prediction row are passed together through
`.klp.orthogonal.polynomial.transform()` when
`design.basis = "orthogonal.polynomial.drop"`. The resulting `design` and
`anchor.design` are stored in the frame, and the frame is marked with
`solver.design.basis = "orthogonal.polynomial.transformed"`.

Synchronization assembly then uses `fi$design[sr$row.i, ]` and
`fj$design[sr$row.j, ]` from those already-transformed frame designs, so the
sync rows are assembled in the same coefficient coordinates used by the local
data rows. The existing PS-LPS tests cover both transformed-frame creation and
zero-sync agreement with LPS under the orthogonal basis; they passed.

### 3. Ridge interpretation

Accepted.

The HTML report states the key distinction correctly: after orthogonalization,
the ridge penalty is applied to orthogonalized coefficient coordinates and is
not algebraically identical to ridge on raw monomial coefficients. I did not
find language in the script/report that blurs this distinction.

### 4. Honest numerical failure handling

Accepted, with one legacy caveat that is not triggered by this focused
guarded comparison.

The intended guarded behavior is present: failures become nonfinite/unstable
states, not silent weighted-mean rescues. The PS-LPS independent-solve path
only uses a weighted-mean fallback for the explicit legacy unguarded monomial
case: `design.basis = "monomial"`, single zero ridge, and infinite condition
cap. The focused comparison's monomial variant uses a tiny ridge, and the
guarded/drop variants use explicit condition handling, so this legacy fallback
is not the mechanism behind the reported successful rows.

There is also a direct test asserting that PS-LPS zero-sync local failures are
not weighted-mean rescues; it passed.

### 5. Sufficiency of the focused comparison

Sufficient as a smoke/audit exercise; insufficient for a default change.

The comparison is intentionally narrow: four deterministic subsamples,
`chart.dim = "auto"`, degree 2, tricube, and support grid `{15, 25}`. That is
appropriate for checking backend contracts and obvious failure modes, but it
does not cover enough local-dimension heterogeneity or support-size stress to
justify changing experiment-facing defaults.

Recommended next comparison:

- include `chart.dim = "local.auto"` as a first-class arm;
- expand support sizes beyond `{15, 25}`;
- include both deterministic first-batch fixtures and at least one larger
  P7X-style run;
- keep reporting candidate failure rates, selected-ridge metadata, and
  rank/drop summaries alongside Truth RMSE.

### 6. Meaning of the LPS `nonfinite_fit` rows

Likely strict guard / genuine local instability under the tested configuration,
not a candidate-selection/status-propagation bug.

The three nonfinite LPS rows were:

- `LA-D1-RAW-N500` / `LPS` / `weighted_qr_drop_tiny`
- `LA-D1-HC-Li-N500` / `LPS` / `monomial_tiny_ridge`
- `LA-D1-HC-Li-N500` / `LPS` / `weighted_qr_drop_tiny`

For all three rows, `finite.cv.candidates = 0` and
`total.cv.candidates = 2`. That means selection was not choosing a broken row
while finite alternatives existed; every candidate in that small grid was
unavailable/nonfinite under the backend and guard settings.

This should still be followed up, because one nonfinite row occurs even for
`monomial_tiny_ridge` on `LA-D1-HC-Li-N500`. But based on this table, the issue
is not an obvious selected-candidate propagation bug.

### 7. Overclaiming in the report

Accepted.

The report says this is a backend audit exercise and not a performance claim
about final defaults. It also states that successful behavior is not simply the
lowest Truth RMSE, but also explicit failure reporting, visible rank drops, and
recorded ridge choices. That framing is appropriate.

One minor future polish item: if this report is reused for a broader audience,
add one sentence immediately below "Best Row Per Dataset" saying that the
best-row table is descriptive for this small fixture set only and should not be
read as backend ranking evidence.

### 8. Opt-in versus preferred backend

Keep `orthogonal.polynomial.drop` opt-in for now, but use it as a preferred
candidate in the next P7X-style comparison.

The zero-ridge coordinate-change contract and PS-LPS transformed-frame contract
look sound. The run also shows that the orthogonal variants avoid the three
LPS nonfinite rows seen under monomial/weighted-QR variants. However, the run
is too small and too narrow to make this the broad default.

Recommended policy:

- keep the current default unchanged;
- include `orthogonal.polynomial.drop` in the next larger comparison as the
  main guarded design-basis candidate;
- defer default promotion until local-auto chart dimensions, larger support
  grids, and larger P7X-style datasets have been exercised.

## Verification Performed

- Parsed and summarized the result/failure CSVs.
- Inspected the LPS orthogonal transform and local WLS solve paths.
- Inspected PS-LPS frame preparation, sync row/cache assembly, and independent
  solve fallback behavior.
- Checked report prose for the performance-claim and ridge-coordinate caveats.
- Ran:
  `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet = TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ge7-lps-api.R")'`
  Result: 118 passed, 0 failed, 0 warnings, 0 skips.
- Ran:
  `Rscript -e 'pkgload::load_all("/Users/pgajer/current_projects/geosmooth", quiet = TRUE); testthat::test_file("/Users/pgajer/current_projects/geosmooth/tests/testthat/test-ps-lps.R")'`
  Result: 110 passed, 0 failed, 0 warnings, 0 skips.

## Required Follow-up

No blocker for accepting this focused comparison as a completed backend smoke
audit.

Before changing defaults, run the broader comparison described above. The
nonfinite LPS rows should also be retained as diagnostics in that follow-up
rather than hidden, because they are informative about backend/guard behavior.
