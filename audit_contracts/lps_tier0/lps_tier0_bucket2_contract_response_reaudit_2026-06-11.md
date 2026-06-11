# Re-audit: LPS Tier-0 Contract and Bucket-2 Response

Date: 2026-06-11
Auditor: Codex

Reviewed files:

- `/Users/pgajer/current_projects/geosmooth/audit_contracts/lps_tier0/lps_tier0_execution_artifact_contract_2026-06-10.md`
- `/Users/pgajer/current_projects/geosmooth/audit_contracts/lps_tier0/lps_tier0_bucket2_remediation_audit_response_2026-06-10.md`

## Verdict

Bucket-2 smoke remediation is accepted on source behavior and clean smoke evidence. Final Tier-0 acceptance is still not complete because the full `LPS_TIER0_FULL=1` artifact and mutation/falsification evidence remain outstanding.

The previous provenance blocker is mostly resolved: the contract and response now live under tracked `audit_contracts/lps_tier0/`, the current branch is clean, and clean-tree smoke artifacts exist for both backend tokens at the reviewed commit. Two documentation/automation issues were identified:

1. `.github/workflows/tier0-gate.yml` still watches the old ignored `split_handoffs/...contract...` path instead of the tracked `audit_contracts/...contract...` path.
2. The response file still describes the obsolete dirty-tree artifact state and old `split_handoffs` contract path, even though the current evidence is clean-tree and tracked.

Post-audit fix note: both issues were corrected after this re-audit. The workflow now watches the tracked `audit_contracts/...` contract path, the harness comment points to that path, and the response now records the clean smoke artifacts. The CI wording was also softened from "full Tier-0 contract" to "Tier-0 smoke artifact contract" to avoid implying that a default smoke CI run is the same as a heavier full-mode release gate.

## Findings

### P2 (fixed): Workflow path filter referenced the old contract location

File: `/Users/pgajer/current_projects/geosmooth/.github/workflows/tier0-gate.yml`

At the time of the re-audit, the workflow path filter included:

```text
split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md
```

but the tracked contract now lives at:

```text
audit_contracts/lps_tier0/lps_tier0_execution_artifact_contract_2026-06-10.md
```

This did not invalidate the current manually generated clean artifacts, but it meant future PRs that changed only the tracked contract might not trigger the Tier-0 workflow. This has been fixed: the workflow path filter and harness comment now point to the tracked `audit_contracts/lps_tier0/` contract.

### P2 (fixed): Audit response was stale relative to the current evidence

File: `/Users/pgajer/current_projects/geosmooth/audit_contracts/lps_tier0/lps_tier0_bucket2_remediation_audit_response_2026-06-10.md`

At the time of the re-audit, the response said the working tree remained dirty and that all local artifacts reported `tree_clean: false`; it also listed `split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md` as the changed contract file. That was no longer accurate and has been fixed.

Current evidence:

- Branch: `codex/geosmooth-tier0-bucket2-isolated`
- HEAD: `4d9285f488791dd4959103f41b028a78e00ab673`
- `git status --porcelain=v1`: empty
- Both reviewed files are tracked under `audit_contracts/lps_tier0/`
- Clean smoke artifacts:
  - `audit_artifacts/tier0_20260611T013246Z` for `cpp`
  - `audit_artifacts/tier0_20260611T013248Z` for `cpp.local.pca`

The response now records the clean-tree smoke artifacts as the current evidence and frames full-mode/mutation evidence as a broader Phase-0 release question.

### P3 (fixed): CI wording could be misread as full final acceptance

File: `/Users/pgajer/current_projects/geosmooth/.github/workflows/tier0-gate.yml`

At the time of the re-audit, the workflow step was named `Enforce full Tier-0 contract (section 4)` and printed `PASS: full Tier-0 contract satisfied`, but the default workflow did not set `LPS_TIER0_FULL=1`. The wording has been fixed to say `Tier-0 smoke artifact contract`, so the default CI run is not mislabeled as a heavier full-mode release run.

## Accepted Evidence

The tracked contract/response are no longer ignored:

- `audit_contracts/lps_tier0/lps_tier0_execution_artifact_contract_2026-06-10.md`
- `audit_contracts/lps_tier0/lps_tier0_bucket2_remediation_audit_response_2026-06-10.md`

The isolated branch history is now clean and scoped:

- `4eabfb8 Isolate LPS Tier-0 remediation`: Tier-0 source/tests/workflow/harness changes
- `4d9285f Track LPS Tier-0 audit contract`: tracked contract and response only

`git diff --check HEAD~1..HEAD` passed.

The workflow YAML parses successfully.

Focused E0.1/E0.2 rerun passed:

| Gate | Expectations | Failures | Warnings | Skips |
|---|---:|---:|---:|---:|
| E0.1 ambient polynomial reproduction | 256 | 0 | 0 | 0 |
| E0.1 intrinsic flat-subspace reproduction | 384 | 0 | 0 | 0 |
| E0.1 negative control | 2 | 0 | 0 | 0 |
| E0.2 ambient linear smoother | 13 | 0 | 0 | 0 |
| E0.2 local-PCA linear smoother | 7 | 0 | 0 | 0 |

Clean artifact `audit_artifacts/tier0_20260611T013246Z`:

- `git_head: 4d9285f488791dd4959103f41b028a78e00ab673`
- `tree_clean: true`
- `native_backend_token: cpp`
- `tests=16 failed=0 error=0 warning=0 skipped=1`
- gate coverage: `E0.1;E0.2;E0.3a;E0.4;E0.5;E0.6;E0.7;E0.8`
- `E0.1 n=64 all_pass=TRUE max_err=3.331e-15 min_headroom=3002399.8x`
- `E0.2 identity_residual=4.441e-16 df_residual=0`
- `determinism=0`
- backend parity: `ok`, max absolute difference `2.22044604925031e-16`

Clean artifact `audit_artifacts/tier0_20260611T013248Z`:

- `git_head: 4d9285f488791dd4959103f41b028a78e00ab673`
- `tree_clean: true`
- `native_backend_token: cpp.local.pca`
- `tests=16 failed=0 error=0 warning=0 skipped=1`
- gate coverage: `E0.1;E0.2;E0.3a;E0.4;E0.5;E0.6;E0.7;E0.8`
- `E0.1 n=64 all_pass=TRUE max_err=3.331e-15 min_headroom=3002399.8x`
- `E0.2 identity_residual=4.441e-16 df_residual=0`
- `determinism=0`
- backend parity: `ok`, max absolute difference `0`

For both clean artifacts, `git_status.txt` is empty, tracked files are exactly `R/lps.R` plus the three Tier-0 test files, and recomputed source/test checksums match `source_checksums.txt`. The single skipped row is the sanctioned E0.3a deferral.

## Remaining Final-Acceptance Gates

1. Run and archive at least one clean-tree `LPS_TIER0_FULL=1` artifact for both backend tokens or otherwise document the exact final full-run scope required by the contract owner.
2. Complete the mutation/falsification table from the independent audit brief.
3. Refresh the response trail so it points at `audit_contracts/lps_tier0/` and the current clean artifacts, not the older dirty smoke bundles.
4. Update the workflow path filter and CI wording so future contract changes and smoke-vs-full status are unambiguous.

## Conclusion

The substantive Bucket-2 source and smoke-artifact issues are resolved. The remaining work is release hygiene and final gate completion: path-filter correction, response-document refresh, full `LPS_TIER0_FULL=1` evidence, and mutation/falsification evidence.
