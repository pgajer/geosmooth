# E0.6 fallback-fraction hardening — decision + work order

Date: 2026-06-13. Responds to the Tier-2 combined re-audit
(`geosmooth-t2/audits/tier2_combined_reaudit_2026-06-13.md`).

## Decision

- **Tier-2 gates E2.12, E2.13, E2.14, E2.15 — ACCEPTED.** Each reddens under its mutation, the §A2
  ancestry check passed, and the auditor reproduced the key numbers independently. t2's Tier-2 portion
  is cleared.
- **E0.6 amendment — accepted for the delivered code, but harden it before final acceptance.** The
  auditor's non-vacuity mutation (force the binomial logistic fitter to event-rate fallback on every
  local solve) left E0.6 **green** — the telemetry shows `median_fallback=1.0` but nothing asserts on
  it. Per our standard (a gate must redden under the mutation of the property it guards), E0.6 has a
  blind spot: it cannot tell a healthy logistic path from a fully-degenerate one. Close it now — the
  fix is tiny and we re-opened E0.6 precisely to get it right. (Merging t2 with a known-vacuous Tier-0
  gate would contradict the discipline the whole program rests on.)

## Work order — t2 implementer (test-only, continues the E0.6 amendment)

Add a bounded **fallback-fraction assertion** to E0.6's binomial arm — turning the already-printed
telemetry into an enforceable non-vacuity gate:

- Assert each prevalence's **median** fallback fraction (the robust choice) stays **below a documented
  threshold**, under both smoke and full-size.
- Choose the threshold from realized evidence + slack: realized median is ~`0.002` (full-size) /
  ~`0.0155` (smoke), with occasional hard cells around `0.1`. A median-fallback bound near **`0.3`**
  passes the real code comfortably while reddening the all-fallback pathology (median `1.0`). Finalize
  the number from the full-size distribution; document the threshold + rationale in the test header.
- No production `R/lps.R` change. Re-bundle (smoke + full-size green).

## Auditor re-check (targeted — not a full re-audit)

Re-run **only** the E0.6 non-vacuity mutation (force event-rate fallback on every local solve) and
confirm it now **reddens** E0.6 (median fallback `1.0` trips the new assertion). The rest of Tier-2 is
already mutation-qualified at this tip — no need to repeat it. Append the result to the combined
verdict.

## Scope note

This closes the **all-fallback** vacuity specifically. The fuller **independent logistic-path
calibration at degree ≥ 1** remains the deferred enhancement (the logistic path's calibration is still
reported-only, coinciding with bernoulli at degree 0) — not folded in here.

## Status

Tier-2 gates accepted. **t2 is fully done once the fallback-fraction assertion lands and the auditor's
one-mutation re-check passes** — then t2 → main (the `R/lps.R` reconciliation against e19).
