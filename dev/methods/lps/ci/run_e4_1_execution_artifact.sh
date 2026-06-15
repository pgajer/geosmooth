#!/usr/bin/env bash
# =============================================================================
# E4.1 execution-artifact harness (Tier 4 — pointwise variance & bands)
#
# Reuses the Tier-0 execution-artifact pattern: produces a self-contained,
# tamper-evident bundle that lets an INDEPENDENT auditor verify the E4.1
# Part A gate against a CLEAN, COMMITTED tree, without trusting the
# implementer's console output. The bundle additionally carries:
#   - the E4.1 headroom/determinism probe (realized margins vs the 1e-10
#     gate tolerance, analytic-vs-probe S agreement, bitwise determinism);
#   - a Part B coverage-harness SMOKE run (dgp.source = "inline-smoke") —
#     WIRING EVIDENCE ONLY, never acceptance evidence; the acceptance run is
#     gated on Amendment 1's audited G3a generator.
#
# Usage:   bash dev/methods/lps/ci/run_e4_1_execution_artifact.sh [REPO_ROOT]
# Env:     EXECUTOR        free-text executor id recorded in the manifest
#          E4_SMOKE        "1" (default) runs the Part B smoke leg; "0" skips
#          E4_SMOKE_N      smoke n (default 1200)
#          E4_SMOKE_R      smoke replicates (default 100)
#          E4_SMOKE_K      smoke support size (default 30)
#          E4_ACCEPT       "1" runs the Part B ACCEPTANCE leg (default "0"):
#                          dev/methods/lps/ci/e4_1_acceptance_run.R — the ratified
#                          pinned configuration (K=20, tricube, audited
#                          G3a-R1-smooth-s010-n1200, n=1200, R=500, known
#                          sigma=0.1), per the 2026-06-12 K ratification. The
#                          manifest then records K, kernel, design seed,
#                          realized interior mean/max bias-to-se, both
#                          interior coverages, and the boundary/top-curvature
#                          strata.
#          E4_ACCEPT_FIT_EVERY  "TRUE" forces full per-replicate fits in the
#                          acceptance leg (auditor's no-shortcut reproduction)
#
# Exit status is ALWAYS 0 when a bundle was written (a failing battery must
# still produce its artifact). Gate acceptance is decided by the auditor from
# the manifest, not by this script's exit code.
# =============================================================================
set -uo pipefail

REPO="${1:-$(git rev-parse --show-toplevel 2>/dev/null)}"
[ -d "$REPO" ] || { echo "ERR: repo root not found: '$REPO'" >&2; exit 2; }
cd "$REPO" || exit 2

TEST_FILES=(
  "tests/testthat/test-lps-tier4-uncertainty.R"   # E4.1 Part A unit GATE
)
SRC_FILES=(
  "R/lps.R"
  "R/lps_uncertainty.R"
  "dev/methods/lps/ci/e4_1_coverage_study.R"
  "dev/methods/lps/ci/e4_1_g3a_binding.R"
  "dev/methods/lps/ci/e4_1_k_calibration.R"
  "dev/methods/lps/ci/e4_1_acceptance_run.R"
  "dev/methods/lps/ci/e4_1_headroom_probe.R"
)
PROBE="dev/methods/lps/ci/e4_1_headroom_probe.R"
STUDY="dev/methods/lps/ci/e4_1_coverage_study.R"
ACCEPT_DRIVER="dev/methods/lps/ci/e4_1_acceptance_run.R"
E4_SMOKE="${E4_SMOKE:-1}"
E4_SMOKE_N="${E4_SMOKE_N:-1200}"
E4_SMOKE_R="${E4_SMOKE_R:-100}"
E4_SMOKE_K="${E4_SMOKE_K:-30}"
E4_ACCEPT="${E4_ACCEPT:-0}"
E4_ACCEPT_FIT_EVERY="${E4_ACCEPT_FIT_EVERY:-FALSE}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="dev/methods/lps/audit_artifacts/e4_1_${STAMP}"
mkdir -p "$OUT"

SHA () { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

echo "[e4.1-artifact] repo=$REPO"
echo "[e4.1-artifact] out=$OUT"

# --- 1) Tree state: the gate REQUIRES a clean, committed tree -----------------
git rev-parse HEAD                              > "$OUT/git_head.txt"   2>/dev/null
git status --porcelain                          > "$OUT/git_status.txt" 2>/dev/null
git log -1 --format='%H%n%an <%ae>%n%aI%n%s'    > "$OUT/git_log1.txt"   2>/dev/null
CLEAN=true
[ -s "$OUT/git_status.txt" ] && CLEAN=false
if ! git ls-files --error-unmatch "${TEST_FILES[@]}" "${SRC_FILES[@]}" > "$OUT/tracked_files.txt" 2>&1; then
  CLEAN=false
fi

# --- 2) Bind the artifact to the exact reviewed source ------------------------
SHA "${SRC_FILES[@]}" "${TEST_FILES[@]}" > "$OUT/source_checksums.txt" 2>/dev/null

# --- 3) Environment capture ----------------------------------------------------
Rscript -e 'writeLines(capture.output(sessionInfo()))' > "$OUT/sessionInfo.txt" 2>&1 || true
Rscript -e 'cat("BLAS:", extSoftVersion()[["BLAS"]], "\nLAPACK_library:", La_library(), "\n")' \
        > "$OUT/blas.txt" 2>&1 || true

# --- 4) Authoritative pass/fail across the committed E4.1 battery ---------------
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
tests <- as.character(df$test)
labs <- unlist(regmatches(tests, gregexpr("E4[.][0-9]+[a-z]?", tests)))
gate.contexts <- sort(unique(labs))
if (!length(gate.contexts)) gate.contexts <- ""
writeLines(gate.contexts, "'"$OUT"'/gate_contexts.txt")
quit(status = if (nf == 0 && ne == 0) 0L else 1L)
' > "$OUT/testthat_stdout.txt" 2>&1
TESTTHAT_RC=$?

# --- 5) Headroom / determinism probe -------------------------------------------
Rscript "$PROBE" "$OUT" > "$OUT/probe_stdout.txt" 2>&1
PROBE_RC=$?

# --- 6) Part B coverage-harness smoke leg (wiring evidence ONLY) ----------------
if [ "$E4_SMOKE" = "1" ]; then
  Rscript "$STUDY" \
    n="$E4_SMOKE_N" R.replicates="$E4_SMOKE_R" support.size="$E4_SMOKE_K" \
    kernel=tricube sigma=0.1 out.dir="$OUT/smoke_study" \
    > "$OUT/smoke_stdout.txt" 2>&1
  SMOKE_RC=$?
else
  SMOKE_RC=0
  echo "E4_SMOKE=0: smoke leg skipped." > "$OUT/smoke_stdout.txt"
fi

# --- 6b) Part B ACCEPTANCE leg (ratified pinned configuration) ------------------
if [ "$E4_ACCEPT" = "1" ]; then
  Rscript "$ACCEPT_DRIVER" \
    out.dir="$OUT/acceptance_study" \
    fit.every.replicate="$E4_ACCEPT_FIT_EVERY" \
    > "$OUT/acceptance_stdout.txt" 2>&1
  ACCEPT_RC=$?
else
  ACCEPT_RC=0
  echo "E4_ACCEPT=0: acceptance leg not run." > "$OUT/acceptance_stdout.txt"
fi

# --- 7) Human/machine manifest ---------------------------------------------------
{
  echo "artifact_id: e4_1_${STAMP}"
  echo "generated_utc: ${STAMP}"
  if [ "$E4_ACCEPT" = "1" ]; then
    echo "gate: E4.1 (Part A unit GATE; Part B ACCEPTANCE leg at the ratified configuration)"
  else
    echo "gate: E4.1 (Part A unit GATE; Part B smoke leg, when run, is wiring evidence only)"
  fi
  echo "repo: ${REPO}"
  echo "git_head: $(cat "$OUT/git_head.txt" 2>/dev/null)"
  echo "tree_clean: ${CLEAN}"
  echo "testthat_rc: ${TESTTHAT_RC}"
  echo "testthat_summary: $(cat "$OUT/testthat_summary.txt" 2>/dev/null)"
  echo "gate_contexts: $(paste -sd';' "$OUT/gate_contexts.txt" 2>/dev/null)"
  echo "probe_rc: ${PROBE_RC}"
  echo "probe_summary: $(tail -n1 "$OUT/probe_stdout.txt" 2>/dev/null)"
  echo "smoke_enabled: ${E4_SMOKE}"
  echo "smoke_rc: ${SMOKE_RC}"
  echo "smoke_params: n=${E4_SMOKE_N} R=${E4_SMOKE_R} K=${E4_SMOKE_K} kernel=tricube sigma=0.1"
  echo "smoke_context: $(grep '^context:' "$OUT/smoke_study/e4_1_console_summary.txt" 2>/dev/null | head -n1)"
  echo "smoke_interior_known: $(grep 'known sigma' "$OUT/smoke_study/e4_1_console_summary.txt" 2>/dev/null)"
  echo "smoke_interior_plugin: $(grep 'plug-in sigma' "$OUT/smoke_study/e4_1_console_summary.txt" 2>/dev/null)"
  echo "accept_enabled: ${E4_ACCEPT}"
  echo "accept_rc: ${ACCEPT_RC}"
  if [ "$E4_ACCEPT" = "1" ]; then
    AS="$OUT/acceptance_study"
    echo "accept_config: K=20 kernel=tricube dgp=G3a-R1-smooth-s010-n1200 design_seed=1 n=1200 R=500 sigma=0.1 known (ratified 2026-06-12)"
    echo "accept_fit_every_replicate: ${E4_ACCEPT_FIT_EVERY}"
    echo "accept_context: $(grep '^context:' "$AS/e4_1_console_summary.txt" 2>/dev/null | head -n1)"
    echo "accept_dgp_source: $(grep '^dgp.source:' "$AS/e4_1_console_summary.txt" 2>/dev/null | head -n1)"
    echo "accept_interior_known: $(grep 'known sigma' "$AS/e4_1_console_summary.txt" 2>/dev/null)"
    echo "accept_interior_plugin: $(grep 'plug-in sigma' "$AS/e4_1_console_summary.txt" 2>/dev/null)"
    echo "accept_interior_bias_se: $(grep 'interior bias/se' "$AS/e4_1_console_summary.txt" 2>/dev/null)"
    echo "accept_stratified_csv_header: $(head -n1 "$AS/e4_1_stratified_summary.csv" 2>/dev/null)"
    echo "accept_stratum_interior: $(grep '\"interior\"' "$AS/e4_1_stratified_summary.csv" 2>/dev/null)"
    echo "accept_stratum_boundary: $(grep 'boundary.within.h' "$AS/e4_1_stratified_summary.csv" 2>/dev/null)"
    echo "accept_stratum_top_curvature: $(grep 'top.curvature.decile' "$AS/e4_1_stratified_summary.csv" 2>/dev/null)"
  fi
  echo "executor: ${EXECUTOR:-$(whoami 2>/dev/null)@$(hostname 2>/dev/null)}"
} > "$OUT/execution_manifest.txt"

# --- 8) Bundle checksums ----------------------------------------------------------
( cd "$OUT" && SHA $(find . -type f | sed 's|^\./||' | grep -v '^BUNDLE_CHECKSUMS.txt$' | sort) > BUNDLE_CHECKSUMS.txt 2>/dev/null ) || true

# --- 9) Preliminary readiness (the AUDITOR makes the final call) -------------------
echo "[e4.1-artifact] wrote bundle: $OUT"
$CLEAN || echo "[e4.1-artifact] WARNING: tree not clean/committed -> artifact INVALID for gate acceptance"
if [ "$TESTTHAT_RC" -eq 0 ] && [ "$PROBE_RC" -eq 0 ] && [ "$SMOKE_RC" -eq 0 ] && [ "$ACCEPT_RC" -eq 0 ] && $CLEAN; then
  echo "[e4.1-artifact] PRELIMINARY: green (auditor must still verify headroom, coverage, provenance)"
else
  echo "[e4.1-artifact] PRELIMINARY: NOT green"
fi
exit 0
