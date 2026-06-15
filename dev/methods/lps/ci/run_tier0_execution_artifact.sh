#!/usr/bin/env bash
# =============================================================================
# Tier-0 execution-artifact harness  (option-2 execution leg)
#
# Produces a self-contained, tamper-evident bundle that lets an INDEPENDENT
# auditor verify whether the LPS Tier-0 correctness battery passes against a
# CLEAN, COMMITTED tree -- without trusting the implementer's console output.
#
# Independence rule: run this by an executor (or CI) distinct from the
# implementer's interactive session. The auditor reviews the BUNDLE, never a
# bare "all dots passed" message. See:
#   dev/methods/lps/audit_contracts/tier0/lps_tier0_execution_artifact_contract_2026-06-10.md
#
# Usage:   bash dev/methods/lps/ci/run_tier0_execution_artifact.sh [REPO_ROOT]
# Env:     LPS_NATIVE_BACKEND  native backend token fit.lps accepts
#                              ("cpp" for ambient, "cpp.local.pca" for local-PCA)
#          MODE                "full" (default) runs the testthat battery plus
#                              probe; "probe" skips the backend-independent
#                              battery and runs only source/environment binding
#                              plus the per-token probe/parity addendum.
#          EXECUTOR            free-text executor id recorded in the manifest
#
# Exit status is ALWAYS 0 when a bundle was written (a failing battery must
# still produce its artifact). Gate acceptance is decided by the auditor / the
# CI "enforce" step from the manifest, not by this script's exit code.
# =============================================================================
set -uo pipefail

REPO="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -d "$REPO" ] || { echo "ERR: repo root not found: '$REPO'" >&2; exit 2; }
cd "$REPO" || exit 2

# The Tier-0 battery (all gate files run as one gate). Extend this list as gates
# are added; the manifest's gate_contexts is derived from the test names, so
# coverage is reported from what actually ran, not from this list.
TEST_FILES=(
  "tests/testthat/test-lps-tier0-correctness.R"           # E0.1, E0.2
  "tests/testthat/test-lps-tier0-correctness-extended.R"  # E0.3a, E0.4, E0.5, E0.6, E0.7
  "tests/testthat/test-lps-degenerate.R"                  # E0.8
)
SRC_FILE="R/lps.R"
PROBE="dev/methods/lps/ci/tier0_headroom_probe.R"
MODE="${MODE:-full}"
BACKEND_TOKEN="${LPS_NATIVE_BACKEND:-cpp}"
case "$MODE" in
  full|probe) ;;
  *) echo "ERR: MODE must be 'full' or 'probe', got '$MODE'" >&2; exit 2 ;;
esac
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="dev/methods/lps/audit_artifacts/tier0_${STAMP}_${BACKEND_TOKEN}"
mkdir -p "$OUT"

# portable sha256 (Linux: sha256sum, macOS: shasum -a 256)
SHA () { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

echo "[tier0-artifact] repo=$REPO"
echo "[tier0-artifact] out=$OUT"

# --- 1) Tree state: the gate REQUIRES a clean, committed tree -----------------
git rev-parse HEAD                              > "$OUT/git_head.txt"   2>/dev/null
git status --porcelain                          > "$OUT/git_status.txt" 2>/dev/null
git log -1 --format='%H%n%an <%ae>%n%aI%n%s'    > "$OUT/git_log1.txt"   2>/dev/null
CLEAN=true
[ -s "$OUT/git_status.txt" ] && CLEAN=false
# every gate file and the source MUST be tracked (untracked = not committed)
if ! git ls-files --error-unmatch "${TEST_FILES[@]}" "$SRC_FILE" > "$OUT/tracked_files.txt" 2>&1; then
  CLEAN=false
fi

# --- 2) Bind the artifact to the exact reviewed source ------------------------
SHA "$SRC_FILE" "${TEST_FILES[@]}" > "$OUT/source_checksums.txt" 2>/dev/null

# --- 3) Environment capture (reproducibility / determinism context) -----------
Rscript -e 'writeLines(capture.output(sessionInfo()))' > "$OUT/sessionInfo.txt" 2>&1 || true
Rscript -e 'cat("BLAS:", extSoftVersion()[["BLAS"]], "\nLAPACK_library:", La_library(), "\n")' \
        > "$OUT/blas.txt" 2>&1 || true

# --- 4) Authoritative pass/fail across the COMMITTED Tier-0 battery ------------
# Probe-only mode is used for the second native-backend token in full release
# evidence. The Tier-0 testthat battery uses backend="R" throughout and is
# therefore backend-token-independent; the probe is the only per-token output.
if [ "$MODE" = "full" ]; then
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
  # gate coverage: extract every E0.x label that appears in a test name, so the
  # manifest reports exactly which gates ran (context column is often blank).
  tests <- as.character(df$test)
  labs <- unlist(regmatches(tests, gregexpr("E0[.][0-9]+[a-z]?", tests)))
  gate.contexts <- sort(unique(labs))
  if (!length(gate.contexts)) gate.contexts <- ""
  writeLines(gate.contexts, "'"$OUT"'/gate_contexts.txt")
  quit(status = if (nf == 0 && ne == 0) 0L else 1L)
' > "$OUT/testthat_stdout.txt" 2>&1
  TESTTHAT_RC=$?
else
  TESTTHAT_RC=0
  {
    echo "MODE=probe: skipped backend-independent testthat battery."
    echo "The full battery must be supplied by a same-commit MODE=full bundle."
  } > "$OUT/testthat_stdout.txt"
  echo "tests=NA failed=NA error=NA warning=NA skipped=NA" \
    > "$OUT/testthat_summary.txt"
  : > "$OUT/gate_contexts.txt"
fi

# --- 5) Realized-error / determinism / backend-parity probe (E0.1/E0.2) -------
Rscript "$PROBE" "$OUT" > "$OUT/probe_stdout.txt" 2>&1
PROBE_RC=$?

# --- 6) Human/machine manifest ------------------------------------------------
{
  echo "artifact_id: tier0_${STAMP}"
  echo "generated_utc: ${STAMP}"
  echo "mode: ${MODE}"
  echo "repo: ${REPO}"
  echo "git_head: $(cat "$OUT/git_head.txt" 2>/dev/null)"
  echo "tree_clean: ${CLEAN}"
  echo "native_backend_token: ${BACKEND_TOKEN}"
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
echo "[tier0-artifact] wrote bundle: $OUT"
$CLEAN || echo "[tier0-artifact] WARNING: tree not clean/committed -> artifact INVALID for gate acceptance"
if [ "$TESTTHAT_RC" -eq 0 ] && [ "$PROBE_RC" -eq 0 ] && $CLEAN; then
  echo "[tier0-artifact] PRELIMINARY: green (auditor must still verify headroom, coverage, parity)"
else
  echo "[tier0-artifact] PRELIMINARY: NOT green"
fi
exit 0
