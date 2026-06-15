#!/usr/bin/env bash
# =============================================================================
# E1.10 Study b' acceptance-bundle manifest builder
#
# Produces a self-contained, TRACKED bundle under dev/methods/lps/runs/e1_10_bprime/ binding
# the committed b' study outputs to the run: git head, tracked-source
# cleanliness, source checksums (with the frozen package source and the ratified
# Study-(b) script verified UNCHANGED against the Part-B audit record),
# sessionInfo, BLAS, the E1.9+E1.10 gate battery, generator seeds, realized rho
# per replicate, and the verdicts (core + arm C).
#
# Usage: bash dev/methods/lps/ci/e1_10_bprime_manifest.sh
# =============================================================================
set -uo pipefail
cd "$(git rev-parse --show-toplevel)" || exit 2

OUT="dev/methods/lps/runs/e1_10_bprime"
[ -f "$OUT/e1_10_bprime_run_metadata.txt" ] || {
  echo "ERR: $OUT/e1_10_bprime_run_metadata.txt absent — run the b' study first." >&2
  exit 2
}
SHA () { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$@"; else shasum -a 256 "$@"; fi; }

# Frozen files (must match the Part-B audit record) + the new b' script.
FROZEN=(R/lps.R R/lps_cv_utils.R dev/methods/lps/ci/e1_10_nested_grouped_cv.R \
        tests/testthat/test-lps-nested-grouped-cv.R)
BPRIME_SRC=(dev/methods/lps/ci/e1_10_grouped_loco_bprime.R)
OUT_FILES=(e1_10_bprime_core_cases.csv e1_10_bprime_core_verdict.csv \
           e1_10_bprime_armc_cases.csv e1_10_bprime_armc_summary.csv \
           e1_10_bprime_run_metadata.txt)

SHA "${FROZEN[@]}" "${BPRIME_SRC[@]}" > "$OUT/source_checksums.txt"
( cd "$OUT" && SHA "${OUT_FILES[@]}" >> source_checksums.txt )

Rscript -e 'writeLines(capture.output(sessionInfo()))' > "$OUT/sessionInfo.txt" 2>&1 || true

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

Rscript -e '
cc <- read.csv("dev/methods/lps/runs/e1_10_bprime/e1_10_bprime_core_cases.csv")
write.csv(cc[, c("rho.nominal","replicate","seed.base","realized.icc")],
          "dev/methods/lps/runs/e1_10_bprime/realized_rho_per_replicate.csv", row.names = FALSE)
' 2>&1 || true

{
  echo "=== E1.10 Study b' acceptance bundle manifest ==="
  echo "generated_local: $(date)"
  echo "git_head (certified source commit): $(git rev-parse HEAD)"
  echo
  echo "--- tracked-source status (must show no modified tracked files; only"
  echo "    untracked entry is this bundle being committed) ---"
  git status --porcelain
  echo "[end status]"
  echo
  echo "--- FROZEN-source verification vs Part-B audit (must be unchanged) ---"
  echo "expected:"
  echo "  588762790b651091717fedc5c424b6dd78ae348ac0bd70a5af1691c68c4ff2ee  R/lps.R"
  echo "  db1e6fdb3ab4befd25a126d4e9884dbd5c34ca9c3d1212eb6a3f4e35a1ee0a0a  R/lps_cv_utils.R"
  echo "  98c0a3f7ea764549097704d0ce4b273f1d35c4f1d34c0862b494cf51cdf1d1f3  dev/methods/lps/ci/e1_10_nested_grouped_cv.R"
  echo "  8bd66a2ff8cfb7f4f39b356127b3918bf41b7da9af648de8e9672599e573d9d2  tests/testthat/test-lps-nested-grouped-cv.R"
  echo "realized:"
  SHA "${FROZEN[@]}"
  echo
  echo "--- gate battery (regression) ---"
  cat "$OUT/gate_battery_summary.txt"
  echo
  echo "--- run metadata (seeds, fit args, BLAS) ---"
  cat "$OUT/e1_10_bprime_run_metadata.txt"
  echo
  echo "--- core verdict (primary relative + LOCO confirmatory) ---"
  cat "$OUT/e1_10_bprime_core_verdict.csv"
  echo
  echo "--- arm C summary (diagnostic K-sweep) ---"
  cat "$OUT/e1_10_bprime_armc_summary.csv"
  echo
  echo "--- realized rho per replicate: see realized_rho_per_replicate.csv ---"
} > "$OUT/MANIFEST.txt"

echo "[manifest] wrote $OUT/MANIFEST.txt and companions"