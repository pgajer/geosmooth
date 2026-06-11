#!/usr/bin/env Rscript
# =============================================================================
# E1.9 realized-quantities probe (bandwidth multiplier gates)
#
# The committed GATEs only assert threshold inequalities (pass/fail). This
# probe records the REALIZED quantities and their headroom, the bit-identity
# of the default path against the pre-change pinned references, determinism,
# and the full provenance of every fit.lps argument list, WITHOUT editing the
# committed tests: it sources the exact committed fixture helpers.
#
# Usage: Rscript scripts/ci/e1_9_realized_quantities_probe.R <OUT_DIR>
# =============================================================================
args <- commandArgs(trailingOnly = TRUE)
OUT  <- if (length(args) >= 1L) args[[1L]] else "."
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("tests/testthat/helper-lps-e1-9.R")
source("tests/testthat/helper-lps-e1-9-reference.R")

# ---- E1.9a characterization: realized ESS/K and last-weight ratios ----------
distances <- e19.characterization.distances()
K <- length(distances)
kish.ess <- function(w) sum(w)^2 / sum(w^2)
char.rows <- lapply(
    c("gaussian", "tricube", "epanechnikov", "triangular"),
    function(kernel) {
        w <- .klp.kernel.weights(distances, kernel)
        ess.ratio <- kish.ess(w) / K
        last.ratio <- w[[K]] / max(w)
        ess.threshold <- switch(kernel,
                                gaussian = 0.9,
                                tricube = 0.85,
                                NA_real_)
        ess.direction <- switch(kernel,
                                gaussian = ">",
                                tricube = "<",
                                NA_character_)
        compact <- kernel %in% c("tricube", "epanechnikov", "triangular")
        ess.pass <- switch(kernel,
                           gaussian = ess.ratio > 0.9,
                           tricube = ess.ratio < 0.85,
                           NA)
        last.pass <- if (compact) last.ratio < 1e-6 else NA
        data.frame(
            gate = "E1.9a", kernel = kernel, K = K,
            ess_over_K = ess.ratio,
            ess_threshold = ess.threshold,
            ess_direction = ess.direction,
            ess_pass = ess.pass,
            last_weight_ratio = last.ratio,
            last_weight_threshold = if (compact) 1e-6 else NA_real_,
            last_weight_pass = last.pass,
            stringsAsFactors = FALSE)
    }
)
char <- do.call(rbind, char.rows)
write.csv(char, file.path(OUT, "e19_characterization.csv"),
          row.names = FALSE)

# ---- E1.9b exactness: realized residuals against the pinned references ------
tau.alg <- 1e-10
fitters <- list(A = e19.fit.A, B = e19.fit.B, C = e19.fit.C)
exact.rows <- lapply(names(fitters), function(name) {
    fit <- fitters[[name]]()
    fit.b1 <- fitters[[name]](bandwidth.multiplier.grid = 1)
    ref <- e19.reference[[name]]
    dfit <- max(abs(fit$fitted.values - ref$fitted.values))
    dcv <- max(abs(fit$cv.table$cv.rmse.observed - ref$cv.rmse.observed))
    data.frame(
        gate = "E1.9b", config = name,
        max_abs_dfitted = dfit,
        max_abs_dcv = dcv,
        tol = tau.alg,
        bit_identical_to_reference =
            identical(fit$fitted.values, ref$fitted.values) &&
            identical(fit$cv.table$cv.rmse.observed, ref$cv.rmse.observed),
        default_vs_explicit_b1_identical =
            identical(fit$fitted.values, fit.b1$fitted.values) &&
            identical(fit$cv.table, fit.b1$cv.table),
        selected_match =
            identical(as.integer(fit$selected$support.size[[1L]]),
                      ref$selected.support.size) &&
            identical(as.integer(fit$selected$degree[[1L]]),
                      ref$selected.degree) &&
            identical(as.character(fit$selected$kernel[[1L]]),
                      ref$selected.kernel),
        selected_bandwidth_multiplier =
            fit$selected$bandwidth.multiplier[[1L]],
        pass = (dfit < tau.alg) && (dcv < tau.alg),
        stringsAsFactors = FALSE)
})
exact <- do.call(rbind, exact.rows)
write.csv(exact, file.path(OUT, "e19_b1_exactness.csv"), row.names = FALSE)

# ---- Determinism + multiplier liveness ---------------------------------------
b1.first <- e19.fit.B()$fitted.values
b1.second <- e19.fit.B()$fitted.values
det.max <- max(abs(b1.first - b1.second))
b2 <- e19.fit.B(bandwidth.multiplier.grid = 2)$fitted.values
b2.shift <- max(abs(b2 - e19.reference$B$fitted.values))

# ---- Provenance: full argument lists, seeds, reference header ----------------
prov <- c(
    "== E1.9 probe provenance ==",
    "",
    "Pinned-reference header (tests/testthat/helper-lps-e1-9-reference.R):",
    grep("^#", readLines("tests/testthat/helper-lps-e1-9-reference.R"),
         value = TRUE),
    "",
    "Characterization distance vector (sqrt(seq_len(20)/20)):",
    paste(sprintf("%.17g", distances), collapse = ", "),
    "",
    "Dataset seeds: ambient X 4101, ambient noise 4102, embedded U 4103,",
    "embedded frame 4104, embedded noise 4105 (set.seed immediately before",
    "each draw; see e19.pin.data.* below).",
    "",
    "Full fit.lps argument lists (committed fixture constructors):",
    "", "-- e19.pin.data.ambient --", deparse(e19.pin.data.ambient),
    "", "-- e19.pin.data.embedded --", deparse(e19.pin.data.embedded),
    "", "-- e19.fit.A --", deparse(e19.fit.A),
    "", "-- e19.fit.B --", deparse(e19.fit.B),
    "", "-- e19.fit.C --", deparse(e19.fit.C)
)
writeLines(prov, file.path(OUT, "e19_provenance.txt"))

# ---- Summary ------------------------------------------------------------------
summ <- data.frame(
    characterization_all_pass = all(c(char$ess_pass[!is.na(char$ess_pass)],
                                      char$last_weight_pass[
                                          !is.na(char$last_weight_pass)])),
    gaussian_ess_over_K = char$ess_over_K[char$kernel == "gaussian"],
    tricube_ess_over_K = char$ess_over_K[char$kernel == "tricube"],
    max_compact_last_weight_ratio =
        max(char$last_weight_ratio[!is.na(char$last_weight_pass)]),
    exactness_all_pass = all(exact$pass),
    exactness_max_abs_dfitted = max(exact$max_abs_dfitted),
    all_bit_identical = all(exact$bit_identical_to_reference),
    all_default_vs_b1_identical = all(exact$default_vs_explicit_b1_identical),
    determinism_max_diff = det.max,
    b2_shift_vs_b1 = b2.shift,
    multiplier_live = b2.shift > 1e-6,
    stringsAsFactors = FALSE)
write.csv(summ, file.path(OUT, "e19_probe_summary.csv"), row.names = FALSE)

cat(sprintf(
    paste0("E1.9a all_pass=%s gauss_ESS/K=%.4f tricube_ESS/K=%.4f ",
           "max_last_w=%.3e | E1.9b all_pass=%s max_dfit=%.3e ",
           "bit_identical=%s b1_identical=%s | determinism=%.3e | ",
           "b2_live=%s (shift=%.3e)\n"),
    summ$characterization_all_pass, summ$gaussian_ess_over_K,
    summ$tricube_ess_over_K, summ$max_compact_last_weight_ratio,
    summ$exactness_all_pass, summ$exactness_max_abs_dfitted,
    summ$all_bit_identical, summ$all_default_vs_b1_identical,
    summ$determinism_max_diff, summ$multiplier_live, summ$b2_shift_vs_b1))

ok <- summ$characterization_all_pass && summ$exactness_all_pass &&
    summ$all_default_vs_b1_identical && det.max == 0 && summ$multiplier_live
quit(status = if (ok) 0L else 1L)
