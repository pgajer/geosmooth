#!/usr/bin/env Rscript
# =============================================================================
# freeze_dgp_registry.R -- freeze the canonical DGP-library registry
#
# Contract: LPS Tiers 1-4, Amendment 1. Produces the FROZEN registry with one
# row per canonical dataset (dataset.id, G-tag, parameters, n, p, d, seed, sigma,
# SHA-256 of the materialized object) plus a provenance manifest, reusing the
# Tier-0 evidence-bundle discipline (git head, tree-clean state, R/BLAS/digest
# ids, sessionInfo, generating command, source + CSV checksums).
#
# Each row's SHA-256 is `dgp.content.sha256()` over the canonical content payload
# (U, X, truth, y, region + scalar ids); an auditor recomputes it by calling the
# same exported helper on the regenerated object, so the registry is verifiable
# without trusting this script's console output.
#
# Usage:  Rscript scripts/freeze_dgp_registry.R
# Output: inst/dgp_registry/{dgp_registry.csv, dgp_registry_manifest.md,
#                            sessionInfo.txt}
# =============================================================================

# Build from the exact working-tree source under audit (not a possibly-stale
# installed package). The generators are pure R; no compiled backend is needed.
source("R/dgp_library.R")
stopifnot(requireNamespace("digest", quietly = TRUE))

# --- provenance captured BEFORE writing any output (source-tree state) --------
git <- function(...) tryCatch(system2("git", c(...), stdout = TRUE, stderr = TRUE),
                              error = function(e) NA_character_)
git.head   <- git("rev-parse", "HEAD")
git.branch <- git("rev-parse", "--abbrev-ref", "HEAD")
git.status <- git("status", "--porcelain")
tree.clean <- length(git.status) == 0L ||
  all(!nzchar(git.status)) || identical(git.status, character(0))
stamp <- format(as.POSIXct(Sys.time(), tz = "UTC"), "%Y-%m-%dT%H:%M:%SZ")

# --- canonical dataset list: one row per frozen dataset -----------------------
# Each entry: id (stable), gtag, args (the exact generator call). Configs are
# tied to the studies waiting on the library (E1.9c, E3.1, E3.2, E4.1, E1.10,
# E1.11, E2.12) plus a reference instance for every G-tag. seed = 1 is the
# canonical replicate-0 reference; studies draw replicate r with seed = s0 + r.
canon <- list(
  # G1 ambient polynomial -----------------------------------------------------
  list(id = "G1-D2-n600",            gtag = "G1",
       args = list(n = 600L, D = 2L, sigma = 0, seed = 1L)),
  # G2 flat embedded ----------------------------------------------------------
  list(id = "G2-d2D3-n600",          gtag = "G2",
       args = list(n = 600L, d = 2L, D = 3L, sigma = 0, seed = 1L)),
  # G3a paraboloid -- E3.2 curvature sweep (noiseless, intrinsic-linear) -------
  list(id = "G3a-R1-lin-noiseless",  gtag = "G3a",
       args = list(n = 600L, R = 1, truth = "linear", sigma = 0, seed = 1L)),
  list(id = "G3a-R2-lin-noiseless",  gtag = "G3a",
       args = list(n = 600L, R = 2, truth = "linear", sigma = 0, seed = 1L)),
  list(id = "G3a-R4-lin-noiseless",  gtag = "G3a",
       args = list(n = 600L, R = 4, truth = "linear", sigma = 0, seed = 1L)),
  list(id = "G3a-R8-lin-noiseless",  gtag = "G3a",
       args = list(n = 600L, R = 8, truth = "linear", sigma = 0, seed = 1L)),
  # G3a -- E1.9c benefit STUDY (smooth truth, two noise levels) ---------------
  list(id = "G3a-R1-smooth-s003-n600", gtag = "G3a",
       args = list(n = 600L, R = 1, truth = "smooth", sigma = 0.03, seed = 1L)),
  list(id = "G3a-R1-smooth-s010-n600", gtag = "G3a",
       args = list(n = 600L, R = 1, truth = "smooth", sigma = 0.10, seed = 1L)),
  # G3a -- E3.1 (curvature-stratified, two sizes) -----------------------------
  list(id = "G3a-R1-smooth-s003-n1600", gtag = "G3a",
       args = list(n = 1600L, R = 1, truth = "smooth", sigma = 0.03, seed = 1L)),
  list(id = "G3a-R4-smooth-s001-n400",  gtag = "G3a",
       args = list(n = 400L, R = 4, truth = "smooth", sigma = 0.01, seed = 1L)),
  # G3a -- E4.1 coverage (known sigma) ----------------------------------------
  list(id = "G3a-R1-smooth-s010-n1200", gtag = "G3a",
       args = list(n = 1200L, R = 1, truth = "smooth", sigma = 0.10, seed = 1L)),
  # G3b sphere cap -- E3.1 -----------------------------------------------------
  list(id = "G3b-R2-smooth-s003-n600",  gtag = "G3b",
       args = list(n = 600L, R = 2, rho0 = 1, truth = "smooth", sigma = 0.03, seed = 1L)),
  list(id = "G3b-R2-smooth-s001-n1600", gtag = "G3b",
       args = list(n = 1600L, R = 2, rho0 = 1, truth = "smooth", sigma = 0.01, seed = 1L)),
  # G3c helix ------------------------------------------------------------------
  list(id = "G3c-c02-n600",          gtag = "G3c",
       args = list(n = 600L, c = 0.2, sigma = 0.1, seed = 1L)),
  # G3d torus -- E1.9c / E3.1 --------------------------------------------------
  list(id = "G3d-smooth-s003-n600",  gtag = "G3d",
       args = list(n = 600L, truth = "smooth", sigma = 0.03, seed = 1L)),
  list(id = "G3d-smooth-s010-n600",  gtag = "G3d",
       args = list(n = 600L, truth = "smooth", sigma = 0.10, seed = 1L)),
  list(id = "G3d-smooth-s003-n1600", gtag = "G3d",
       args = list(n = 1600L, truth = "smooth", sigma = 0.03, seed = 1L)),
  # G4 stratified -- E1.11 boundary --------------------------------------------
  list(id = "G4-n600",               gtag = "G4",
       args = list(n = 600L, fracA = 0.5, eta = 0.02, sigma = 0.1, seed = 1L)),
  list(id = "G4-n800",               gtag = "G4",
       args = list(n = 800L, fracA = 0.5, eta = 0.02, sigma = 0.1, seed = 1L)),
  # G5 clustered -- E1.10 grouped CV (two ICCs) --------------------------------
  list(id = "G5-K40-m20-rho03",      gtag = "G5",
       args = list(K = 40L, m = 20L, rho = 0.3, sigma = 0.1, seed = 1L)),
  list(id = "G5-K40-m20-rho06",      gtag = "G5",
       args = list(K = 40L, m = 20L, rho = 0.6, sigma = 0.1, seed = 1L)),
  # G6 binary -- E2.12 ---------------------------------------------------------
  list(id = "G6-prev050-n400",       gtag = "G6",
       args = list(n = 400L, prevalence = 0.5, seed = 1L)),
  list(id = "G6-prev030-n400",       gtag = "G6",
       args = list(n = 400L, prevalence = 0.3, seed = 1L)),
  # G7 compositional -----------------------------------------------------------
  list(id = "G7-D5-zf05-n600",       gtag = "G7",
       args = list(n = 600L, D = 5L, zero.fraction = 0.5, zero.parts = 5L,
                   sigma = 0.1, seed = 1L))
)

# --- materialize, checksum, collect rows -------------------------------------
arg.str <- function(a) {
  paste(vapply(names(a), function(k) {
    v <- a[[k]]
    paste0(k, "=", paste(format(v, trim = TRUE, scientific = FALSE),
                         collapse = ","))
  }, character(1)), collapse = "; ")
}

rows <- lapply(canon, function(row) {
  ds <- dgp.materialize(row$gtag, row$args)
  data.frame(
    dataset.id = row$id,
    gtag       = row$gtag,
    generator  = ds$provenance$generator,
    n          = ds$n,
    p          = ds$p,
    d          = ifelse(is.na(ds$d), "varies", as.character(ds$d)),
    seed       = ds$seed,
    sigma      = ifelse(is.na(ds$sigma), "NA", format(ds$sigma)),
    params     = arg.str(row$args),
    sha256     = dgp.content.sha256(ds),
    stringsAsFactors = FALSE)
})
registry <- do.call(rbind, rows)

# --- write outputs ------------------------------------------------------------
out.dir <- file.path("inst", "dgp_registry")
dir.create(out.dir, recursive = TRUE, showWarnings = FALSE)
csv.path <- file.path(out.dir, "dgp_registry.csv")
utils::write.csv(registry, csv.path, row.names = FALSE)

si.path <- file.path(out.dir, "sessionInfo.txt")
writeLines(utils::capture.output(utils::sessionInfo()), si.path)

# file-level checksums (match `shasum -a 256`)
src.sha <- digest::digest(file = "R/dgp_library.R", algo = "sha256")
csv.sha <- digest::digest(file = csv.path,          algo = "sha256")
digest.ver <- as.character(utils::packageVersion("digest"))

manifest <- c(
  "# DGP-library frozen registry -- manifest",
  "",
  sprintf("Frozen: %s", stamp),
  sprintf("Contract: LPS Tiers 1-4, Amendment 1 (consolidate the DGP library)."),
  sprintf("Plan (DGP definitions matched): lps_experimental_plan_2026-06-09.tex (sec:dgp)."),
  "",
  "## Provenance (source-tree state at freeze time)",
  "",
  sprintf("- geosmooth git head: `%s`", paste(git.head, collapse = " ")),
  sprintf("- branch: `%s`", paste(git.branch, collapse = " ")),
  sprintf("- source tree clean at freeze: **%s**", tolower(as.character(tree.clean))),
  sprintf("- R: %s", R.version.string),
  sprintf("- platform: %s", R.version$platform),
  sprintf("- BLAS: %s", unname(extSoftVersion()["BLAS"])),
  sprintf("- LAPACK library: %s", La_library()),
  sprintf("- LAPACK version: %s", La_version()),
  sprintf("- digest: %s", digest.ver),
  sprintf("- generator source: `R/dgp_library.R`  sha256 `%s`", src.sha),
  sprintf("- registry CSV: `inst/dgp_registry/dgp_registry.csv`  sha256 `%s`", csv.sha),
  "",
  "## Registry",
  "",
  sprintf("- rows: %d", nrow(registry)),
  sprintf("- G-tags covered: %s",
          paste(sort(unique(registry$gtag)), collapse = ", ")),
  "",
  "## Checksum definition (so the auditor can recompute each row)",
  "",
  "Each row's `sha256` is `geosmooth::dgp.content.sha256(ds)` =",
  "`digest::digest(.dgp.content(ds), algo = \"sha256\", serialize = TRUE)`, where",
  "`.dgp.content(ds)` is the fixed-order list",
  "`(dataset.id, gtag, n, p, d, seed, sigma, U, X, truth, y, region)` of the",
  "materialized object -- environment-derived provenance (package version) is",
  "excluded, so the checksum depends only on the data. Reproduce a row with:",
  "",
  "```r",
  "library(geosmooth)",
  "ds <- dgp.materialize(<gtag>, <args from params column>)",
  "stopifnot(dgp.content.sha256(ds) == <sha256 from CSV>)",
  "```",
  "",
  "Determinism is environment-relative (spec sec:rng): same R/BLAS/digest as",
  "above -> bitwise-identical objects and checksums.",
  "",
  "## Generating command",
  "",
  "```sh",
  "Rscript scripts/freeze_dgp_registry.R",
  "```",
  "",
  "Full environment in `inst/dgp_registry/sessionInfo.txt`."
)
writeLines(manifest, file.path(out.dir, "dgp_registry_manifest.md"))

# --- console summary ----------------------------------------------------------
cat(sprintf("[freeze-dgp] wrote %d rows -> %s\n", nrow(registry), csv.path))
cat(sprintf("[freeze-dgp] G-tags: %s\n",
            paste(sort(unique(registry$gtag)), collapse = ", ")))
cat(sprintf("[freeze-dgp] source sha256: %s\n", src.sha))
cat(sprintf("[freeze-dgp] csv    sha256: %s\n", csv.sha))
cat(sprintf("[freeze-dgp] tree clean at freeze: %s  head: %s\n",
            tolower(as.character(tree.clean)), paste(git.head, collapse = " ")))
