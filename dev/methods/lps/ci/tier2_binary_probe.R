#!/usr/bin/env Rscript
# =============================================================================
# Tier-2 binary-path realized-quantities probe (E2.14 + E2.12)
#
# The committed Tier-2 tests assert pass/fail properties; this probe records
# the REALIZED quantities behind those assertions without editing the
# committed tests: E2.14 deviance trajectories, halving counts, statuses,
# fallback telemetry, and determinism; E2.12 per-candidate raw vs deployed
# (clipped) selection scores, the ranking flip, selection-score/deployed-
# metric equality residuals, the clip pin, and the single-point dominance
# accounting. It reuses the committed fixture constructors by sourcing the
# test files with `test_that` shadowed to a no-op, so the probed inputs are
# exactly the gated inputs.
#
# Usage: Rscript dev/methods/lps/ci/tier2_binary_probe.R <OUT_DIR>
# =============================================================================
args <- commandArgs(trailingOnly = TRUE)
OUT  <- if (length(args) >= 1L) args[[1L]] else "."
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

suppressMessages(pkgload::load_all(".", quiet = TRUE))

# Reuse committed fixture helpers without executing any test_that() body:
test_that <- function(...) invisible(NULL)          # shadow
suppressWarnings(source("tests/testthat/test-lps-binary-separation.R",
                        local = TRUE))
suppressWarnings(source("tests/testthat/test-lps-binary-metric-consistency.R",
                        local = TRUE))

# ---- E2.14: solver behavior on both gated fixture arms -----------------------
arms <- list(
    near.separable    = e214.fixture(flip = TRUE),
    exactly.separable = e214.fixture(flip = FALSE)
)

trace.rows <- list()
summary.rows <- list()
args.lines <- character(0)
det.max <- 0
for (arm in names(arms)) {
    fx <- arms[[arm]]
    solved <- e214.solve(fx)
    solved.again <- e214.solve(fx)
    det.max <- max(det.max,
                   max(abs(solved$deviance.trace - solved.again$deviance.trace)),
                   if (!is.null(solved$coefficients)) {
                       max(abs(solved$coefficients - solved.again$coefficients))
                   } else 0)
    increases <- diff(solved$deviance.trace)
    trace.rows[[arm]] <- data.frame(
        arm = arm,
        iteration = seq_along(solved$deviance.trace) - 1L,
        deviance = solved$deviance.trace,
        stringsAsFactors = FALSE
    )
    summary.rows[[arm]] <- data.frame(
        arm = arm,
        status = solved$status,
        ok = isTRUE(solved$ok),
        converged = isTRUE(solved$converged),
        iterations = solved$iterations,
        step.halvings = solved$step.halvings,
        trace.length = length(solved$deviance.trace),
        max.deviance.increase = max(increases),
        n.increases.gt.slack = sum(increases > 1e-8),
        trace.all.finite = all(is.finite(solved$deviance.trace)),
        beta.all.finite = !is.null(solved$coefficients) &&
            all(is.finite(solved$coefficients)),
        prediction = if (!is.null(solved$prediction)) {
            solved$prediction[[1L]]
        } else NA_real_,
        prediction.in.open.unit = !is.null(solved$prediction) &&
            is.finite(solved$prediction[[1L]]) &&
            solved$prediction[[1L]] > 0 && solved$prediction[[1L]] < 1,
        stringsAsFactors = FALSE
    )
    args.lines <- c(args.lines, sprintf(
        paste0("arm=%s  .klp.solve.local.logistic(design=cbind(1, z), y, ",
               "weights, design.basis=\"orthogonal.polynomial.drop\", ",
               "design.drop.tol=1e-8, ridge.multiplier.grid=0, ",
               "ridge.condition.max=Inf, prediction.row=matrix(c(1,0),1)) ",
               "with z=[%s] y=[%s] weights=[%s]"),
        arm,
        paste(signif(fx$design[, 2L], 10), collapse = ", "),
        paste(fx$y, collapse = ", "),
        paste(signif(fx$weights, 10), collapse = ", ")
    ))
}
write.csv(do.call(rbind, trace.rows),
          file.path(OUT, "e2_14_deviance_traces.csv"), row.names = FALSE)
e214.summary <- do.call(rbind, summary.rows)
write.csv(e214.summary,
          file.path(OUT, "e2_14_solver_summary.csv"), row.names = FALSE)
writeLines(args.lines, file.path(OUT, "e2_14_solver_args.txt"))

# ---- E2.14: documented fallback + telemetry on the exact arm -----------------
fallback.rows <- list()
for (action in c("mean", "na")) {
    telemetry <- geosmooth:::.klp.logistic.telemetry.new("binomial")
    fx <- arms$exactly.separable
    fitted <- geosmooth:::.klp.fit.logistic.prob.design(
        design = fx$design,
        y = fx$y,
        weights = fx$weights,
        design.basis = "orthogonal.polynomial.drop",
        design.drop.tol = 1e-8,
        ridge.multiplier.grid = 0,
        ridge.condition.max = Inf,
        unstable.action = action,
        logistic.telemetry = telemetry
    )
    s <- geosmooth:::.klp.logistic.telemetry.summary(telemetry)
    fallback.rows[[action]] <- data.frame(
        unstable.action = action,
        fitted = fitted,
        fitted.is.na = is.na(fitted),
        attempted = s$attempted,
        converged = s$converged,
        fallback.path.count = s$fallback.path.count,
        event.rate.fallback.count = s$event.rate.fallback.count,
        na.failure.count = s$na.failure.count,
        weighted.event.rate = stats::weighted.mean(fx$y, fx$weights),
        stringsAsFactors = FALSE
    )
}
fallback <- do.call(rbind, fallback.rows)
write.csv(fallback, file.path(OUT, "e2_14_fallback_telemetry.csv"),
          row.names = FALSE)

# ---- E2.12(a): bernoulli selection vs deployed clipped metric ----------------
g.a <- e212.g6(seed = 2121L)
fit.a <- fit.lps(
    X = g.a$X, y = g.a$y, foldid = g.a$foldid,
    support.grid = c(8L, 60L), degree.grid = c(0L, 2L),
    kernel.grid = "gaussian", coordinate.method = "coordinates",
    backend = "R", design.basis = "orthogonal.polynomial.drop",
    ridge.multiplier.grid = 0, ridge.condition.max = Inf,
    unstable.action = "mean", outcome.family = "bernoulli",
    keep.cv.predictions = TRUE
)
ct.a <- fit.a$cv.table
pred.a <- fit.a$cv.predictions
deployed.a <- vapply(seq_len(ncol(pred.a)), function(j) {
    mean((g.a$y - pmin(1, pmax(0, pred.a[, j])))^2)
}, numeric(1L))
e212a <- data.frame(
    candidate = seq_len(nrow(ct.a)),
    support.size = ct.a$support.size,
    degree = ct.a$degree,
    kernel = ct.a$kernel,
    cv.rmse.observed = ct.a$cv.rmse.observed,
    raw.brier = ct.a$cv.rmse.observed^2,
    cv.brier.observed = ct.a$cv.brier.observed,
    deployed.clipped.brier = deployed.a,
    equality.residual = abs(ct.a$cv.brier.observed - deployed.a),
    selected = seq_len(nrow(ct.a)) == which(
        ct.a$support.size == fit.a$selected$support.size[[1L]] &
            ct.a$degree == fit.a$selected$degree[[1L]] &
            ct.a$kernel == fit.a$selected$kernel[[1L]]),
    stringsAsFactors = FALSE
)
write.csv(e212a, file.path(OUT, "e2_12a_selection_metric.csv"),
          row.names = FALSE)
a.raw.idx <- which.min(ct.a$cv.rmse.observed)
a.clip.idx <- which.min(ct.a$cv.brier.observed)
a.n.out <- sum(pred.a < 0 | pred.a > 1)
a.flip <- a.raw.idx != a.clip.idx
a.equal <- max(e212a$equality.residual) < 1e-12
a.selected.clip <- isTRUE(e212a$selected[[a.clip.idx]])
fit.a2 <- fit.lps(
    X = g.a$X, y = g.a$y, foldid = g.a$foldid,
    support.grid = c(8L, 60L), degree.grid = c(0L, 2L),
    kernel.grid = "gaussian", coordinate.method = "coordinates",
    backend = "R", design.basis = "orthogonal.polynomial.drop",
    ridge.multiplier.grid = 0, ridge.condition.max = Inf,
    unstable.action = "mean", outcome.family = "bernoulli",
    keep.cv.predictions = TRUE
)
a.det <- max(abs(fit.a$cv.predictions - fit.a2$cv.predictions))

# ---- E2.12(b): log-loss clip pin + single-point dominance --------------------
clip.pin <- identical(formals(geosmooth:::.klp.clip.probability)$eps, 1e-6)
g.b <- e212.g6(seed = 7001L)
flip <- 7L
y.b <- g.b$y
y.b[[flip]] <- 1
fit.b <- fit.lps(
    X = g.b$X, y = y.b, foldid = g.b$foldid,
    support.grid = 60L, degree.grid = c(0L, 1L),
    kernel.grid = "gaussian", coordinate.method = "coordinates",
    backend = "R", design.basis = "orthogonal.polynomial.drop",
    ridge.multiplier.grid = 0, ridge.condition.max = Inf,
    unstable.action = "mean", outcome.family = "binomial",
    keep.cv.predictions = TRUE
)
ct.b <- fit.b$cv.table
pred.b <- fit.b$cv.predictions
manual.logloss <- function(p, y, eps) {
    p <- pmin(1 - eps, pmax(eps, p))
    -mean(y * log(p) + (1 - y) * log1p(-p))
}
b.rows <- lapply(seq_len(nrow(ct.b)), function(j) {
    binders <- which((y.b == 1 & pred.b[, j] < 1e-6) |
                         (y.b == 0 & pred.b[, j] > 1 - 1e-6))
    swing.total <- manual.logloss(pred.b[, j], y.b, 1e-15) -
        manual.logloss(pred.b[, j], y.b, 1e-6)
    swing.point <- (-log(pmax(pred.b[flip, j], 1e-15)) +
                        log(pmax(pred.b[flip, j], 1e-6))) / length(y.b)
    contrib15 <- -(y.b * log(pmin(1 - 1e-15, pmax(1e-15, pred.b[, j]))) +
                       (1 - y.b) * log1p(-pmin(1 - 1e-15,
                                               pmax(1e-15, pred.b[, j]))))
    data.frame(
        candidate = j,
        support.size = ct.b$support.size[[j]],
        degree = ct.b$degree[[j]],
        logloss.1e.15 = manual.logloss(pred.b[, j], y.b, 1e-15),
        logloss.1e.6 = manual.logloss(pred.b[, j], y.b, 1e-6),
        logloss.1e.3 = manual.logloss(pred.b[, j], y.b, 1e-3),
        cv.logloss.observed = ct.b$cv.logloss.observed[[j]],
        equality.residual = abs(ct.b$cv.logloss.observed[[j]] -
                                    manual.logloss(pred.b[, j], y.b, 1e-6)),
        n.wrong.side.binders = length(binders),
        binder.is.flip = identical(binders, flip),
        flip.prediction = pred.b[flip, j],
        flip.share.of.crossclip.swing = swing.point / swing.total,
        flip.contrib.1e.15 = contrib15[[flip]],
        max.other.contrib.1e.15 = max(contrib15[-flip]),
        stringsAsFactors = FALSE
    )
})
e212b <- do.call(rbind, b.rows)
write.csv(e212b, file.path(OUT, "e2_12b_clip_dominance.csv"),
          row.names = FALSE)
b.sel.idx <- which(
    ct.b$support.size == fit.b$selected$support.size[[1L]] &
        ct.b$degree == fit.b$selected$degree[[1L]] &
        ct.b$kernel == fit.b$selected$kernel[[1L]])
b.ok <- clip.pin &&
    all(e212b$n.wrong.side.binders == 1L) &&
    all(e212b$binder.is.flip) &&
    all(e212b$flip.share.of.crossclip.swing > 0.999) &&
    all(e212b$equality.residual < 1e-12) &&
    (e212b$flip.contrib.1e.15[[b.sel.idx]] /
         e212b$max.other.contrib.1e.15[[b.sel.idx]] > 5)

writeLines(c(
    sprintf(paste0("E2.12(a) fit.lps(X, y, foldid=rep(1:5,80), ",
                   "support.grid=c(8,60), degree.grid=c(0,2), ",
                   "kernel.grid=\"gaussian\", coordinate.method=",
                   "\"coordinates\", backend=\"R\", design.basis=",
                   "\"orthogonal.polynomial.drop\", ridge.multiplier.grid=0, ",
                   "ridge.condition.max=Inf, unstable.action=\"mean\", ",
                   "outcome.family=\"bernoulli\", keep.cv.predictions=TRUE); ",
                   "G6 seed=2121 eta=6*tanh(15*x1) n=400")),
    sprintf(paste0("E2.12(b) same but support.grid=60, degree.grid=c(0,1), ",
                   "outcome.family=\"binomial\"; G6 seed=7001, y[7] flipped ",
                   "0->1 (deliberate confident-wrong held-out point)"))
), file.path(OUT, "e2_12_fit_args.txt"))

# ---- Summary -----------------------------------------------------------------
near <- e214.summary[e214.summary$arm == "near.separable", ]
exact <- e214.summary[e214.summary$arm == "exactly.separable", ]
e214.ok <- isTRUE(near$converged) &&
    near$max.deviance.increase <= 1e-8 &&
    near$step.halvings >= 1L &&
    isTRUE(near$prediction.in.open.unit) &&
    isTRUE(near$beta.all.finite) &&
    identical(exact$status, "not_converged") &&
    exact$max.deviance.increase <= 1e-8 &&
    isTRUE(exact$trace.all.finite) &&
    !fallback["mean", "fitted.is.na"] &&
    fallback["mean", "event.rate.fallback.count"] == 1L &&
    fallback["na", "fitted.is.na"] &&
    fallback["na", "na.failure.count"] == 1L &&
    det.max == 0
e212.ok <- a.flip && a.equal && a.selected.clip && a.n.out > 0L &&
    a.det == 0 && b.ok
ok <- e214.ok && e212.ok

cat(sprintf(
    paste0("E2.14 near: status=%s halvings=%d max.inc=%.3e pred=%.6f | ",
           "exact: status=%s max.inc=%.3e | fallback mean=%.6f na=%s | ",
           "determinism=%.3e || E2.12a flip=%s raw.pick=(%d,%d) ",
           "clip.pick=(%d,%d) max.eq.res=%.1e n.out=%d det=%.1e | ",
           "E2.12b clip.pin=%s binders.unique=%s share>0.999=%s ",
           "contrib.ratio=%.2f || probe_ok=%s\n"),
    near$status, near$step.halvings, near$max.deviance.increase,
    near$prediction, exact$status, exact$max.deviance.increase,
    fallback["mean", "fitted"], fallback["na", "fitted.is.na"], det.max,
    a.flip, ct.a$support.size[[a.raw.idx]], ct.a$degree[[a.raw.idx]],
    ct.a$support.size[[a.clip.idx]], ct.a$degree[[a.clip.idx]],
    max(e212a$equality.residual), a.n.out, a.det,
    clip.pin, all(e212b$binder.is.flip),
    all(e212b$flip.share.of.crossclip.swing > 0.999),
    e212b$flip.contrib.1e.15[[b.sel.idx]] /
        e212b$max.other.contrib.1e.15[[b.sel.idx]],
    ok))

quit(status = if (ok) 0L else 1L)
