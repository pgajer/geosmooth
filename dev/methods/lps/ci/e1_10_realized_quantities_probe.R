#!/usr/bin/env Rscript
# =============================================================================
# E1.10 realized-quantities probe (nested + grouped CV, Part A)
#
# Records the realized quantities behind the Part A GATEs -- leakage
# invariance residuals, grouped-fold balance, paired-telemetry identity --
# plus the provenance and verdict rows of the committed Part B SMOKE outputs
# (smoke is pipeline evidence only, never acceptance evidence).  Sources the
# committed GATE fixtures so no logic is re-implemented here.
#
# Usage: Rscript dev/methods/lps/ci/e1_10_realized_quantities_probe.R <OUT_DIR>
# =============================================================================
args <- commandArgs(trailingOnly = TRUE)
OUT <- if (length(args) >= 1L) args[[1L]] else "."
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

suppressMessages(pkgload::load_all(".", quiet = TRUE))

# Reuse committed fixtures without executing any test_that() body.
test_that <- function(...) invisible(NULL)
suppressWarnings(source("tests/testthat/test-lps-nested-grouped-cv.R",
                        local = TRUE))

# ---- Leakage invariance: realized per-fold deltas ----------------------------
fx <- e110.fixture()
base <- lps.nested.cv(X = fx$X, y = fx$y, outer.foldid = fx$outer.foldid,
                      fit.args = e110.fit.args(), inner.folds = 3L)
leak.rows <- lapply(seq_along(sort(unique(fx$outer.foldid))), function(pos) {
    label <- sort(unique(fx$outer.foldid))[[pos]]
    test.idx <- which(fx$outer.foldid == label)
    y.shift <- fx$y
    y.shift[test.idx] <- y.shift[test.idx] + 7
    shifted <- lps.nested.cv(X = fx$X, y = y.shift,
                             outer.foldid = fx$outer.foldid,
                             fit.args = e110.fit.args(), inner.folds = 3L)
    data.frame(
        gate = "E1.10A1", fold = label,
        max_abs_inner_cv_delta = max(abs(
            shifted$inner.cv.table[[pos]]$cv.rmse.observed -
                base$inner.cv.table[[pos]]$cv.rmse.observed
        )),
        selection_identical = identical(
            shifted$folds[pos, c("selected.support.size", "selected.degree",
                                 "selected.kernel",
                                 "selected.bandwidth.multiplier")],
            base$folds[pos, c("selected.support.size", "selected.degree",
                              "selected.kernel",
                              "selected.bandwidth.multiplier")]
        ),
        max_abs_prediction_delta = max(abs(
            shifted$predictions[test.idx] - base$predictions[test.idx]
        )),
        stringsAsFactors = FALSE
    )
})
leak <- do.call(rbind, leak.rows)
write.csv(leak, file.path(OUT, "e110_leakage_invariance.csv"),
          row.names = FALSE)

# ---- Grouped folds: realized balance ------------------------------------------
cfx <- e110.cluster.fixture()
grouped <- lps.grouped.foldid(cfx$cluster.id, v = 4L)
lco <- lps.grouped.foldid(cfx$cluster.id, v = length(cfx$sizes))
balance <- data.frame(
    gate = "E1.10A2",
    n = length(cfx$cluster.id),
    n_clusters = length(cfx$sizes),
    v = 4L,
    fold_sizes = paste(as.integer(table(grouped)), collapse = ";"),
    max_fold_size = max(table(grouped)),
    min_fold_size = min(table(grouped)),
    whole_cluster = all(vapply(split(grouped, cfx$cluster.id),
                               function(f) length(unique(f)) == 1L,
                               logical(1L))),
    deterministic = identical(grouped,
                              lps.grouped.foldid(cfx$cluster.id, v = 4L)),
    lco_folds = length(unique(lco)),
    stringsAsFactors = FALSE
)
write.csv(balance, file.path(OUT, "e110_grouped_balance.csv"),
          row.names = FALSE)

# ---- Paired telemetry ----------------------------------------------------------
paired <- data.frame(
    gate = "E1.10A3",
    selected_min_foldid_identical =
        identical(base$selected.min$foldid, base$outer.foldid),
    fit_foldid_identical =
        identical(base$selected.min$fit$foldid, base$outer.foldid),
    inner_foldid_roundtrip = all(vapply(
        seq_along(base$inner.foldid),
        function(pos) identical(base$inner.foldid.used[[pos]],
                                base$inner.foldid[[pos]]),
        logical(1L)
    )),
    stringsAsFactors = FALSE
)
write.csv(paired, file.path(OUT, "e110_paired_telemetry.csv"),
          row.names = FALSE)

# ---- Committed study outputs (smoke + acceptance): bind into the bundle --------
study.files <- c("e1_10_a_optimism_verdict.csv",
                 "e1_10_b_grouped_verdict.csv",
                 "e1_10_a_optimism_cases.csv",
                 "e1_10_b_grouped_cases.csv",
                 "e1_10_run_metadata.txt")
bind.study.dir <- function(dir) {
    present <- file.exists(file.path(dir, study.files))
    if (!all(present[1:2])) {
        return(list(summary = "verdict outputs missing", lines = c(
            paste0("dir: ", dir),
            paste0("files_present: ",
                   paste(study.files[present], collapse = ";")),
            "verdicts: verdict outputs missing"
        )))
    }
    va <- read.csv(file.path(dir, study.files[[1L]]))
    vb <- read.csv(file.path(dir, study.files[[2L]]))
    vb6 <- vb[vb$rho.nominal == 0.6, , drop = FALSE]
    summary <- sprintf(
        "a:%s b(rho=0.6):%s generator:%s acceptance_evidence:%s",
        va$verdict[[1L]],
        if (nrow(vb6)) vb6$verdict[[1L]] else "absent",
        va$generator[[1L]],
        all(c(va$acceptance.evidence, vb$acceptance.evidence))
    )
    list(summary = summary, lines = c(
        paste0("dir: ", dir),
        paste0("files_present: ",
               paste(study.files[present], collapse = ";")),
        paste0("verdicts: ", summary)
    ))
}
smoke.bind <- bind.study.dir("dev/methods/lps/runs/e1_10_smoke")
accept.bind <- bind.study.dir("dev/methods/lps/runs/e1_10_acceptance")
smoke.summary <- smoke.bind$summary
accept.summary <- accept.bind$summary
writeLines(c(
    "== smoke (pipeline evidence only; inline fixtures, NOT plan DGPs) ==",
    smoke.bind$lines,
    "",
    "== acceptance (registry dgp.g3a / dgp.g5; STUDY verdicts) ==",
    accept.bind$lines
), file.path(OUT, "e110_study_outputs_binding.txt"))

# ---- Provenance -----------------------------------------------------------------
writeLines(c(
    "== E1.10 probe provenance ==",
    "", "-- e110.fixture --", deparse(e110.fixture),
    "", "-- e110.fit.args --", deparse(e110.fit.args),
    "", "-- e110.cluster.fixture --", deparse(e110.cluster.fixture)
), file.path(OUT, "e110_provenance.txt"))

# ---- Summary --------------------------------------------------------------------
ok <- all(leak$max_abs_inner_cv_delta == 0) &&
    all(leak$selection_identical) &&
    all(leak$max_abs_prediction_delta == 0) &&
    isTRUE(balance$whole_cluster) && isTRUE(balance$deterministic) &&
    balance$lco_folds == balance$n_clusters &&
    all(unlist(paired[1, -1]))
summ <- data.frame(
    leakage_max_inner_cv_delta = max(leak$max_abs_inner_cv_delta),
    leakage_max_prediction_delta = max(leak$max_abs_prediction_delta),
    leakage_all_selection_identical = all(leak$selection_identical),
    grouped_whole_cluster = balance$whole_cluster,
    grouped_fold_sizes = balance$fold_sizes,
    paired_all_identical = all(unlist(paired[1, -1])),
    smoke_outputs = smoke.summary,
    acceptance_outputs = accept.summary,
    all_ok = ok,
    stringsAsFactors = FALSE
)
write.csv(summ, file.path(OUT, "e110_probe_summary.csv"), row.names = FALSE)
cat(sprintf(
    paste0("E1.10A1 max_inner_delta=%.3e max_pred_delta=%.3e sel_identical=%s | ",
           "E1.10A2 whole=%s sizes=%s | E1.10A3 paired=%s | smoke: %s | ",
           "acceptance: %s | all_ok=%s\n"),
    summ$leakage_max_inner_cv_delta, summ$leakage_max_prediction_delta,
    summ$leakage_all_selection_identical, summ$grouped_whole_cluster,
    summ$grouped_fold_sizes, summ$paired_all_identical,
    summ$smoke_outputs, summ$acceptance_outputs, ok))
quit(status = if (ok) 0L else 1L)
