#!/usr/bin/env bash
# =============================================================================
# E1.10 Part B acceptance-bundle manifest builder
#
# Produces a self-contained, TRACKED acceptance bundle under
# reports/e1_10_acceptance/ binding the committed study outputs to the run:
# git head, tracked-source cleanliness, source checksums (verified against the
# Part B audit's recorded hashes), sessionInfo, BLAS/LAPACK, generator seeds,
# realized rho per replicate, the study verdicts, and the E1.9+E1.10 gate
# battery summary. Unlike the audit_artifacts/ harness bundle (gitignored),
# this manifest is committed so the acceptance evidence is tracked.
#
# Usage: bash scripts/ci/e1_10_acceptance_manifest.sh
# =============================================================================
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

OUT="reports/e1_10_acceptance"
[ -f "$OUT/e1_10_run_metadata.txt" ] || {
  echo "ERR: $OUT/e1_10_run_metadata.txt absent — run the acceptance study first." >&2
  exit 2
}
SHA () { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

SRC_FILES=(R/lps.R R/lps_cv_utils.R validation/e1_10_nested_grouped_cv.R \
           tests/testthat/test-lps-nested-grouped-cv.R)
OUT_FILES=(e1_10_a_optimism_cases.csv e1_10_a_optimism_verdict.csv \
           e1_10_b_grouped_cases.csv e1_10_b_grouped_verdict.csv \
           e1_10_run_metadata.txt)

# Source + output checksums (the auditor recomputes these independently).
SHA "${SRC_FILES[@]}" > "$OUT/source_checksums.txt"
( cd "$OUT" && SHA "${OUT_FILES[@]}" >> source_checksums.txt )

# Environment.
Rscript -e 'writeLines(capture.output(sessionInfo()))' > "$OUT/sessionInfo.txt" 2>&1 || true

# E1.9 + E1.10 gate battery on the committed gate files (regression evidence).
Rscript -e '
suppressMessages(pkgload::load_all(".", quiet = TRUE))
files <- c("tests/testthat/test-lps-bandwidth-multiplier.R",
           "tests/testthat/test-lps-nested-grouped-cv.R")
df <- do.call(rbind, lapply(files, function(f) {
  as.data.frame(testthat::test_file(f, reporter = "silent"))
}))
cat(sprintf("E1.9+E1.10 gates: tests=%d failed=%d error=%d warning=%d skipped=%d\n",
            nrow(df), sum(df$failed), sum(df$error), sum(df$warning), sum(df$skipped)))
' > "$OUT/gate_battery_summary.txt" 2>&1

# Realized rho per replicate, extracted from the committed Study (b) cases.
Rscript -e '
b <- read.csv("reports/e1_10_acceptance/e1_10_b_grouped_cases.csv")
b <- b[, c("rho.nominal","replicate","seed.base","realized.icc")]
write.csv(b, "reports/e1_10_acceptance/realized_rho_per_replicate.csv",
          row.names = FALSE)
' 2>&1 || true

{
  echo "=== E1.10 Part B acceptance bundle manifest ==="
  echo "generated_local: $(date)"
  echo "git_head (certified source commit): $(git rev-parse HEAD)"
  echo
  echo "--- tracked-source status (must show no modified tracked files; the"
  echo "    only untracked entries are this bundle being committed) ---"
  git status --porcelain
  echo "[end status]"
  echo
  echo "--- source-hash verification against Part B audit (audits/e1_10_partB_audit_2026-06-14.md) ---"
  echo "expected (audit Bundle Validity):"
  echo "  588762790b651091717fedc5c424b6dd78ae348ac0bd70a5af1691c68c4ff2ee  R/lps.R"
  echo "  db1e6fdb3ab4befd25a126d4e9884dbd5c34ca9c3d1212eb6a3f4e35a1ee0a0a  R/lps_cv_utils.R"
  echo "  98c0a3f7ea764549097704d0ce4b273f1d35c4f1d34c0862b494cf51cdf1d1f3  validation/e1_10_nested_grouped_cv.R"
  echo "  8bd66a2ff8cfb7f4f39b356127b3918bf41b7da9af648de8e9672599e573d9d2  tests/testthat/test-lps-nested-grouped-cv.R"
  echo "realized:"
  SHA "${SRC_FILES[@]}"
  echo
  echo "--- gate battery ---"
  cat "$OUT/gate_battery_summary.txt"
  echo
  echo "--- run metadata (seeds, fit args, BLAS) ---"
  cat "$OUT/e1_10_run_metadata.txt"
  echo
  echo "--- Study (a) verdict ---"
  cat "$OUT/e1_10_a_optimism_verdict.csv"
  echo
  echo "--- Study (b) verdict ---"
  cat "$OUT/e1_10_b_grouped_verdict.csv"
  echo
  echo "--- realized rho per replicate: see realized_rho_per_replicate.csv"
  echo "    (rho.nominal, replicate, seed.base, realized.icc; 80 rows) ---"
} > "$OUT/MANIFEST.txt"

echo "[manifest] wrote $OUT/MANIFEST.txt and companions"
