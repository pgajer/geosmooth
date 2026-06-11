#!/usr/bin/env Rscript
# =============================================================================
# Tier-2 binary-path realized-quantities probe (E2.14; E2.12 sections appended
# as those gates land)
#
# The committed E2.14 tests assert pass/fail properties of the local logistic
# solver under (near-/exact) separation. This probe records the REALIZED
# quantities behind those assertions -- the full deviance trajectories,
# halving counts, statuses, fallback telemetry, and determinism -- without
# editing the committed tests. It reuses the committed fixture constructors
# by sourcing the test file with `test_that` shadowed to a no-op, so the
# probed inputs are exactly the gated inputs.
#
# Usage: Rscript scripts/ci/tier2_binary_probe.R <OUT_DIR>
# =============================================================================
args <- commandArgs(trailingOnly = TRUE)
OUT  <- if (length(args) >= 1L) args[[1L]] else "."
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

suppressMessages(pkgload::load_all(".", quiet = TRUE))

# Reuse committed fixture helpers without executing any test_that() body:
test_that <- function(...) invisible(NULL)          # shadow
suppressWarnings(source("tests/testthat/test-lps-binary-separation.R",
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

# ---- Summary -----------------------------------------------------------------
near <- e214.summary[e214.summary$arm == "near.separable", ]
exact <- e214.summary[e214.summary$arm == "exactly.separable", ]
ok <- isTRUE(near$converged) &&
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

cat(sprintf(
    paste0("E2.14 near: status=%s halvings=%d max.inc=%.3e pred=%.6f | ",
           "exact: status=%s max.inc=%.3e | fallback mean=%.6f na=%s | ",
           "determinism=%.3e | probe_ok=%s\n"),
    near$status, near$step.halvings, near$max.deviance.increase,
    near$prediction, exact$status, exact$max.deviance.increase,
    fallback["mean", "fitted"], fallback["na", "fitted.is.na"],
    det.max, ok))

quit(status = if (ok) 0L else 1L)
