# Re-audit: LPS Tier-0 Bucket-2 Remediation Audit Response

Date: 2026-06-10
Auditor: Codex
Subject: `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_tier0_bucket2_remediation_audit_response_2026-06-10.md`

## Verdict

Source-level remediation for the Bucket-2 smoke gate is accepted, but final Tier-0 acceptance remains blocked by provenance and release-gate issues.

The corrected E0.1 support policy, CI backend matrix, checksum regeneration, and E0.3a skip guard are present and pass focused verification. Clean-tree smoke artifacts now exist for both native backend tokens and are substantially stronger evidence than the audit response's dirty-tree artifacts.

Final acceptance should not be given yet because the clean artifacts are tied to a broad unrelated commit, the frozen contract/audit-response files live under an ignored `split_handoffs/` path and are not tracked, and the full Tier-0 plus mutation/falsification gates are still not complete.

## Evidence Reviewed

- Response:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_tier0_bucket2_remediation_audit_response_2026-06-10.md`
- Frozen contract working-tree copy:
  `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md`
- Tier-0 source/tests/workflow/harness:
  - `/Users/pgajer/current_projects/geosmooth/R/lps.R`
  - `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-lps-tier0-correctness.R`
  - `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-lps-tier0-correctness-extended.R`
  - `/Users/pgajer/current_projects/geosmooth/tests/testthat/test-lps-degenerate.R`
  - `/Users/pgajer/current_projects/geosmooth/scripts/ci/run_tier0_execution_artifact.sh`
  - `/Users/pgajer/current_projects/geosmooth/scripts/ci/tier0_headroom_probe.R`
  - `/Users/pgajer/current_projects/geosmooth/.github/workflows/tier0-gate.yml`
- Clean smoke artifacts:
  - `/Users/pgajer/current_projects/geosmooth/audit_artifacts/tier0_20260610T235428Z`
  - `/Users/pgajer/current_projects/geosmooth/audit_artifacts/tier0_20260610T235429Z`

## Passed Checks

1. E0.1 no longer uses the too-small `n=8` evidence case.

   The main E0.1 tests now use `n <- 200L` for both ambient and intrinsic basis-exactness cases.

2. E0.1 support policy is now documented and implemented consistently.

   The tests use:

   ```r
   support.size <- min(n - 1L, max(15L, 3L * n.cols))
   ```

   The contract now documents the same policy. This differs from the original bare `3 * c_p` language, but the floor is now explicit and paired with rank checks, so this is acceptable for the smoke gate.

3. Direct E0.1/E0.2 verification passes.

   I reran the focused Tier-0 correctness test file through `testthat::test_file()`. The relevant checks passed with no failures, errors, warnings, or skips:

   - E0.1 ambient: 256 expectations
   - E0.1 intrinsic: 384 expectations
   - E0.1 negative control: 2 expectations
   - E0.2 ambient: 13 expectations
   - E0.2 local PCA: 7 expectations

4. The GitHub Actions Tier-0 workflow now matrices both backend tokens.

   `.github/workflows/tier0-gate.yml` contains a backend matrix over:

   - `cpp`
   - `cpp.local.pca`

   The workflow YAML parses successfully.

5. The CI artifact now recomputes source checksums.

   The workflow invokes the Tier-0 artifact script for each backend rather than relying on checked-in checksum artifacts. The clean artifacts' `source_checksums.txt` match the current tracked contents of `R/lps.R` and the three Tier-0 test files.

6. The E0.3a skip guard is tighter.

   The workflow checks the testthat CSV for an actual skipped row whose test label matches `E0.3a`. This is materially better than a loose text grep.

7. Clean-tree smoke artifacts exist and pass for both backends.

   The response emphasizes dirty-tree artifacts, but stronger clean-tree artifacts are present:

   - `tier0_20260610T235428Z`: `native_backend_token: cpp`
   - `tier0_20260610T235429Z`: `native_backend_token: cpp.local.pca`

   Both have:

   - `tree_clean: true`
   - `testthat_rc: 0`
   - `tests=16 failed=0 error=0 warning=0 skipped=1`
   - gate contexts: `E0.1;E0.2;E0.3a;E0.4;E0.5;E0.6;E0.7;E0.8`
   - `probe_rc: 0`
   - headroom probe summary:
     `E0.1 n=64 all_pass=TRUE max_err=3.331e-15 min_headroom=3002399.8x | E0.2 pass=TRUE id_res=4.441e-16 df_res=0.000e+00 | determinism=0.000e+00 | parity=ok`

## Remaining Blockers

1. The clean artifacts are attached to a broad unrelated commit, not an isolated Tier-0 remediation commit.

   The clean artifacts record:

   ```text
   git_head: 75c35014c474cd264a229545e648c970a8745a8c
   ```

   That commit is `Add binary GM FF experiment assets and project briefs` and includes many unrelated binary/project-brief/experiment files outside Tier-0. Earlier Tier-0 guidance required isolation of Tier-0 files plus the accepted `R/lps.R` diff on a clean branch. This is not yet satisfied.

2. The frozen contract and response are ignored and not tracked.

   `git ls-files --error-unmatch` reports the following as untracked:

   - `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_tier0_execution_artifact_contract_2026-06-10.md`
   - `/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_tier0_bucket2_remediation_audit_response_2026-06-10.md`

   `git check-ignore -v` shows they are ignored by:

   ```text
   .gitignore:7:split_handoffs/
   ```

   This is a provenance problem because the contract says the contract version is this file's commit. At present, the contract version is not actually commit-bound.

3. Full Tier-0 execution remains incomplete.

   The available clean artifacts are smoke artifacts. The response correctly does not claim full `LPS_TIER0_FULL=1` completion. Final Tier-0 acceptance still requires full E0.5/E0.6 execution under the frozen contract.

4. Mutation/falsification evidence remains incomplete.

   The response correctly does not claim mutation completion. Final Tier-0 acceptance still requires the mutation/falsification checks specified by the frozen gate.

5. Whole-commit whitespace hygiene is not clean.

   `git diff --check HEAD~1..HEAD` reports whitespace errors in unrelated `project_briefs/` files. This does not invalidate the Tier-0 source-level fixes, but it reinforces that the current commit is not a clean isolated Tier-0 acceptance candidate.

## Required Next Steps

1. Rebase or rebuild the Tier-0 remediation onto an isolated clean branch/commit containing only the approved Tier-0 files and the accepted `R/lps.R` diff.

2. Track the frozen contract in git, either by force-adding the `split_handoffs/` contract file or moving it to a non-ignored audit/contract path. The contract must be commit-bound before final acceptance.

3. Generate clean-tree artifacts from the isolated commit for both backend tokens.

4. Run and archive the full Tier-0 gate with `LPS_TIER0_FULL=1` for both backend tokens.

5. Complete the mutation/falsification stage and include its artifacts in the final audit bundle.

## Conclusion

The implementer resolved the specific Bucket-2 smoke-gate defects that were previously blocking the remediation response. The remaining issues are not about the E0.1/E0.2 source behavior; they are release-gate and provenance issues. Treat this as accepted for Bucket-2 smoke remediation, but not as final Tier-0 acceptance.
