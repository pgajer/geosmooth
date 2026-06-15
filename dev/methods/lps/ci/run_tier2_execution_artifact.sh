#!/usr/bin/env bash
# =============================================================================
# Tier-2 execution-artifact harness (binary path & numerical hygiene)
#
# Reuses the Tier-0 execution-artifact pattern
# (dev/methods/lps/ci/run_tier0_execution_artifact.sh; contract
# dev/methods/lps/audit_contracts/tier0/lps_tier0_execution_artifact_contract_2026-06-10.md):
# produces a self-contained, tamper-evident bundle that lets an INDEPENDENT
# auditor verify the Tier-2 gates -- and that the Tier-0 battery still passes
# after the Tier-2 source changes -- against a CLEAN, COMMITTED tree.
#
# Usage:   bash dev/methods/lps/ci/run_tier2_execution_artifact.sh [REPO_ROOT]
# Env:     EXECUTOR  free-text executor id recorded in the manifest
#
# Exit status is ALWAYS 0 when a bundle was written (a failing battery must
# still produce its artifact). Gate acceptance is decided by the auditor, not
# by this script's exit code.
# =============================================================================
set -uo pipefail

REPO="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -d "$REPO" ] || { echo "ERR: repo root not found: '$REPO'" >&2; exit 2; }
cd "$REPO" || exit 2

# The Tier-0 battery is rerun in full: Tier-2 changes touch the shared LPS
# source, so the bundle must evidence that the accepted Tier-0 gates are
# unaffected. Tier-2 gate files are appended as the gates land.
TEST_FILES=(
  "tests/testthat/test-lps-tier0-correctness.R"           # E0.1, E0.2
  "tests/testthat/test-lps-tier0-correctness-extended.R"  # E0.3a, E0.4, E0.5, E0.6, E0.7
  "tests/testthat/test-lps-degenerate.R"                  # E0.8
  "tests/testthat/test-lps-binary-separation.R"           # E2.14
  "tests/testthat/test-lps-binary-metric-consistency.R"   # E2.12
  "tests/testthat/test-lps-ridge-alignment.R"             # E2.13
  "tests/testthat/test-lps-binomial-na-consistency.R"     # E2.15
)
SRC_FILE="R/lps.R"
PROBE="dev/methods/lps/ci/tier2_binary_probe.R"
STUDY="dev/methods/lps/ci/e2_12_crossclip_stability_study.R"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="dev/methods/lps/audit_artifacts/tier2_${STAMP}"
mkdir -p "$OUT"

# portable sha256 (Linux: sha256sum, macOS: shasum -a 256)
SHA () { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

echo "[tier2-artifact] repo=$REPO"
echo "[tier2-artifact] out=$OUT"

# --- 1) Tree state: the gate REQUIRES a clean, committed tree -----------------
git rev-parse HEAD                              > "$OUT/git_head.txt"   2>/dev/null
git status --porcelain                          > "$OUT/git_status.txt" 2>/dev/null
git log -1 --format='%H%n%an <%ae>%n%aI%n%s'    > "$OUT/git_log1.txt"   2>/dev/null
CLEAN=true
[ -s "$OUT/git_status.txt" ] && CLEAN=false
if ! git ls-files --error-unmatch "${TEST_FILES[@]}" "$SRC_FILE" "$PROBE" "$STUDY" > "$OUT/tracked_files.txt" 2>&1; then
  CLEAN=false
fi

# --- 2) Bind the artifact to the exact reviewed source ------------------------
SHA "$SRC_FILE" "$PROBE" "$STUDY" "${TEST_FILES[@]}" > "$OUT/source_checksums.txt" 2>/dev/null

# --- 3) Environment capture (reproducibility / determinism context) -----------
Rscript -e 'writeLines(capture.output(sessionInfo()))' > "$OUT/sessionInfo.txt" 2>&1 || true
Rscript -e 'cat("BLAS:", extSoftVersion()[["BLAS"]], "\nLAPACK_library:", La_library(), "\n")' \
        > "$OUT/blas.txt" 2>&1 || true

# --- 4) Authoritative pass/fail across the committed battery ------------------
R_FILES="c($(printf '"%s",' "${TEST_FILES[@]}" | sed 's/,$//'))"
Rscript -e '
suppressMessages(pkgload::load_all(".", quiet = TRUE))
files <- '"$R_FILES"'
flatten <- function(d) {
  for (nm in names(d)) {
    if (is.list(d[[nm]])) {
      d[[nm]] <- vapply(d[[nm]], function(x) {
        paste(capture.output(str(x, give.attr = FALSE)), collapse = " ")
      }, character(1L))
    }
  }
  d
}
collect <- function(f) {
  d <- as.data.frame(testthat::test_file(f, reporter = "silent"))
  d$source_file <- f
  flatten(d)
}
df <- do.call(rbind, lapply(files, collect))
write.csv(df, "'"$OUT"'/testthat_results.csv", row.names = FALSE)
nf <- sum(df$failed); ne <- sum(df$error); nw <- sum(df$warning); ns <- sum(df$skipped)
line <- sprintf("tests=%d failed=%d error=%d warning=%d skipped=%d", nrow(df), nf, ne, nw, ns)
writeLines(line, "'"$OUT"'/testthat_summary.txt")
cat(line, "\n")
# gate coverage across tiers: every E<k>.<j> label appearing in a test name.
tests <- as.character(df$test)
labs <- unlist(regmatches(tests, gregexpr("E[0-9][.][0-9]+[a-z]?", tests)))
gate.contexts <- sort(unique(labs))
if (!length(gate.contexts)) gate.contexts <- ""
writeLines(gate.contexts, "'"$OUT"'/gate_contexts.txt")
quit(status = if (nf == 0 && ne == 0) 0L else 1L)
' > "$OUT/testthat_stdout.txt" 2>&1
TESTTHAT_RC=$?

# --- 5) Tier-2 realized-quantities probe ---------------------------------------
Rscript "$PROBE" "$OUT" > "$OUT/probe_stdout.txt" 2>&1
PROBE_RC=$?

# --- 5b) E2.12 cross-clip STUDY (reported, not gated) --------------------------
# Regenerates the committed verdict/scores CSVs (deterministic) and copies
# them into the bundle; a "not stable" verdict is recorded, never a failure.
Rscript "$STUDY" > "$OUT/e2_12_study_stdout.txt" 2>&1
STUDY_RC=$?
cp dev/methods/lps/runs/tier2/e2_12_crossclip_stability_verdict.csv \
   dev/methods/lps/runs/tier2/e2_12_crossclip_scores.csv "$OUT/" 2>/dev/null || true
git status --porcelain > "$OUT/git_status_post_study.txt" 2>/dev/null

# --- 6) Human/machine manifest ------------------------------------------------
{
  echo "artifact_id: tier2_${STAMP}"
  echo "generated_utc: ${STAMP}"
  echo "repo: ${REPO}"
  echo "git_head: $(cat "$OUT/git_head.txt" 2>/dev/null)"
  echo "tree_clean: ${CLEAN}"
  echo "testthat_rc: ${TESTTHAT_RC}"
  echo "testthat_summary: $(cat "$OUT/testthat_summary.txt" 2>/dev/null)"
  echo "gate_contexts: $(paste -sd';' "$OUT/gate_contexts.txt" 2>/dev/null)"
  echo "probe_rc: ${PROBE_RC}"
  echo "probe_summary: $(tail -n1 "$OUT/probe_stdout.txt" 2>/dev/null)"
  echo "study_rc: ${STUDY_RC}"
  echo "study_summary: $(grep '^E2.12 cross-clip STUDY' "$OUT/e2_12_study_stdout.txt" 2>/dev/null | tail -n1)"
  echo "tree_clean_post_study: $([ -s "$OUT/git_status_post_study.txt" ] && echo false || echo true)"
  echo "executor: ${EXECUTOR:-$(whoami 2>/dev/null)@$(hostname 2>/dev/null)}"
} > "$OUT/execution_manifest.txt"

# --- 7) Bundle checksums (tamper-evidence over the whole bundle) --------------
( cd "$OUT" && SHA $(ls | grep -v '^BUNDLE_CHECKSUMS.txt$') > BUNDLE_CHECKSUMS.txt 2>/dev/null ) || true

# --- 8) Preliminary readiness (the AUDITOR makes the final call) --------------
echo "[tier2-artifact] wrote bundle: $OUT"
$CLEAN || echo "[tier2-artifact] WARNING: tree not clean/committed -> artifact INVALID for gate acceptance"
if [ "$TESTTHAT_RC" -eq 0 ] && [ "$PROBE_RC" -eq 0 ] && $CLEAN; then
  echo "[tier2-artifact] PRELIMINARY: green (auditor must still verify coverage and realized quantities)"
else
  echo "[tier2-artifact] PRELIMINARY: NOT green"
fi
exit 0
