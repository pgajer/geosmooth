#!/usr/bin/env bash
# =============================================================================
# E1.9 execution-artifact harness (bandwidth multiplier gates)
#
# Reuses the Tier-0 execution-artifact pattern
# (scripts/ci/run_tier0_execution_artifact.sh): produces a self-contained,
# tamper-evident bundle that lets an INDEPENDENT auditor verify whether the
# E1.9 GATEs -- and the Tier-0 battery they must not regress -- pass against
# a CLEAN, COMMITTED tree, without trusting the implementer's console output.
#
# Usage:   bash scripts/ci/run_e1_9_execution_artifact.sh [REPO_ROOT]
# Env:     EXECUTOR  free-text executor id recorded in the manifest
#
# Exit status is ALWAYS 0 when a bundle was written (a failing battery must
# still produce its artifact). Gate acceptance is decided by the auditor from
# the manifest, not by this script's exit code.
# =============================================================================
set -uo pipefail

REPO="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -d "$REPO" ] || { echo "ERR: repo root not found: '$REPO'" >&2; exit 2; }
cd "$REPO" || exit 2

# The E1.9 gate file plus the full Tier-0 battery (regression evidence: the
# new default path must leave every Tier-0 gate green).
TEST_FILES=(
  "tests/testthat/test-lps-bandwidth-multiplier.R"        # E1.9a, E1.9b
  "tests/testthat/test-lps-tier0-correctness.R"           # E0.1, E0.2
  "tests/testthat/test-lps-tier0-correctness-extended.R"  # E0.3a, E0.4-E0.7
  "tests/testthat/test-lps-degenerate.R"                  # E0.8
)
HELPER_FILES=(
  "tests/testthat/helper-lps-e1-9.R"
  "tests/testthat/helper-lps-e1-9-reference.R"
)
SRC_FILE="R/lps.R"
PROBE="scripts/ci/e1_9_realized_quantities_probe.R"
PIN_SCRIPT="validation/e1_9_pin_reference_fits.R"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="audit_artifacts/e1_9_${STAMP}"
mkdir -p "$OUT"

# portable sha256 (Linux: sha256sum, macOS: shasum -a 256)
SHA () { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

echo "[e1.9-artifact] repo=$REPO"
echo "[e1.9-artifact] out=$OUT"

# --- 1) Tree state: the gate REQUIRES a clean, committed tree -----------------
git rev-parse HEAD                              > "$OUT/git_head.txt"   2>/dev/null
git status --porcelain                          > "$OUT/git_status.txt" 2>/dev/null
git log -1 --format='%H%n%an <%ae>%n%aI%n%s'    > "$OUT/git_log1.txt"   2>/dev/null
CLEAN=true
[ -s "$OUT/git_status.txt" ] && CLEAN=false
# every gate file, helper, probe, pin script, and the source MUST be tracked
if ! git ls-files --error-unmatch "${TEST_FILES[@]}" "${HELPER_FILES[@]}" \
     "$SRC_FILE" "$PROBE" "$PIN_SCRIPT" > "$OUT/tracked_files.txt" 2>&1; then
  CLEAN=false
fi

# --- 2) Bind the artifact to the exact reviewed source ------------------------
SHA "$SRC_FILE" "${TEST_FILES[@]}" "${HELPER_FILES[@]}" "$PROBE" "$PIN_SCRIPT" \
  > "$OUT/source_checksums.txt" 2>/dev/null

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
# gate coverage: every E<k>.<j> label appearing in a test name (E0.* and E1.*)
tests <- as.character(df$test)
labs <- unlist(regmatches(tests, gregexpr("E[0-9]+[.][0-9]+[a-z]?", tests)))
gate.contexts <- sort(unique(labs))
if (!length(gate.contexts)) gate.contexts <- ""
writeLines(gate.contexts, "'"$OUT"'/gate_contexts.txt")
quit(status = if (nf == 0 && ne == 0) 0L else 1L)
' > "$OUT/testthat_stdout.txt" 2>&1
TESTTHAT_RC=$?

# --- 5) Realized-quantities probe (E1.9a/E1.9b headroom + provenance) ---------
Rscript "$PROBE" "$OUT" > "$OUT/probe_stdout.txt" 2>&1
PROBE_RC=$?

# --- 6) Human/machine manifest ------------------------------------------------
{
  echo "artifact_id: e1_9_${STAMP}"
  echo "generated_utc: ${STAMP}"
  echo "repo: ${REPO}"
  echo "git_head: $(cat "$OUT/git_head.txt" 2>/dev/null)"
  echo "tree_clean: ${CLEAN}"
  echo "testthat_rc: ${TESTTHAT_RC}"
  echo "testthat_summary: $(cat "$OUT/testthat_summary.txt" 2>/dev/null)"
  echo "gate_contexts: $(paste -sd';' "$OUT/gate_contexts.txt" 2>/dev/null)"
  echo "probe_rc: ${PROBE_RC}"
  echo "probe_summary: $(tail -n1 "$OUT/probe_stdout.txt" 2>/dev/null)"
  echo "executor: ${EXECUTOR:-$(whoami 2>/dev/null)@$(hostname 2>/dev/null)}"
} > "$OUT/execution_manifest.txt"

# --- 7) Bundle checksums (tamper-evidence over the whole bundle) --------------
( cd "$OUT" && SHA $(ls | grep -v '^BUNDLE_CHECKSUMS.txt$') > BUNDLE_CHECKSUMS.txt 2>/dev/null ) || true

# --- 8) Preliminary readiness (the AUDITOR makes the final call) --------------
echo "[e1.9-artifact] wrote bundle: $OUT"
$CLEAN || echo "[e1.9-artifact] WARNING: tree not clean/committed -> artifact INVALID for gate acceptance"
if [ "$TESTTHAT_RC" -eq 0 ] && [ "$PROBE_RC" -eq 0 ] && $CLEAN; then
  echo "[e1.9-artifact] PRELIMINARY: green (auditor must still verify realized quantities, coverage)"
else
  echo "[e1.9-artifact] PRELIMINARY: NOT green"
fi
exit 0
