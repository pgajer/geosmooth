# E2.12 — cross-clip selection-stability STUDY (reported, NOT gated)
#
# Contract (S C / E2.12 sub-item (b)): "cross-clip selection stability over
# {1e-6, 1e-3} is a STUDY (reported, not gated: near-ties may legitimately
# reselect)." This script emits the machine-readable verdict row; a
# "not stable" outcome is recorded, never a CI failure.
#
# Predeclared decision rule (fixed before the numbers were read):
#   primary statistic = the argmin candidate of the observed CV log loss,
#   recomputed from the SAME out-of-fold CV predictions under probability
#   clips eps in {1e-15, 1e-6, 1e-3} (the clip enters only at scoring;
#   binomial CV predictions themselves do not depend on the scoring clip);
#   verdict "stable" iff argmin(eps = 1e-6) == argmin(eps = 1e-3);
#   the {1e-15 vs 1e-6} comparison and all per-candidate scores and margins
#   are reported alongside. No replication (the fixture is deterministic;
#   contract smoke/full: constructed G6 cases, n = 400).
#
# Fixture: the E2.12(b) motivating case -- G6 (eta = 6*tanh(15*x1), p
# clipped to [0.05, 0.95], n = 400, seed 7001) with observation 7's label
# deliberately flipped to 1 (the confident-wrong held-out point), binomial
# mode, candidates (support 60) x (degree 0, 1), gaussian kernel, explicit
# foldid -- identical to tests/testthat/test-lps-binary-metric-consistency.R.
#
# Run:    Rscript validation/e2_12_crossclip_stability_study.R
# Output: reports/e2_12_crossclip_scores.csv   (per candidate x clip)
#         reports/e2_12_crossclip_stability_verdict.csv (one row)

suppressMessages(pkgload::load_all(".", quiet = TRUE))

g6 <- function(n = 400L, seed, sharpness = 15, amplitude = 6) {
    set.seed(seed)
    X <- matrix(stats::runif(n * 2L, -1, 1), ncol = 2L)
    eta <- amplitude * tanh(sharpness * X[, 1L])
    p <- pmin(pmax(stats::plogis(eta), 0.05), 0.95)
    y <- stats::rbinom(n, 1L, p)
    list(X = X, p = p, y = y, foldid = rep(1:5, length.out = n))
}

g <- g6(seed = 7001L)
flip <- 7L
stopifnot(identical(g$y[[flip]], 0L), g$X[flip, 1L] < -0.5)
y <- g$y
y[[flip]] <- 1

fit <- fit.lps(
    X = g$X,
    y = y,
    foldid = g$foldid,
    support.grid = 60L,
    degree.grid = c(0L, 1L),
    kernel.grid = "gaussian",
    coordinate.method = "coordinates",
    backend = "R",
    design.basis = "orthogonal.polynomial.drop",
    ridge.multiplier.grid = 0,
    ridge.condition.max = Inf,
    unstable.action = "mean",
    outcome.family = "binomial",
    keep.cv.predictions = TRUE
)
pred <- fit$cv.predictions
ct <- fit$cv.table
stopifnot(all(is.finite(pred)))

logloss.at <- function(p, y, eps) {
    p <- pmin(1 - eps, pmax(eps, p))
    -mean(y * log(p) + (1 - y) * log1p(-p))
}
clips <- c(1e-15, 1e-6, 1e-3)
scores <- do.call(rbind, lapply(seq_len(nrow(ct)), function(j) {
    data.frame(
        candidate = j,
        support.size = ct$support.size[[j]],
        degree = ct$degree[[j]],
        kernel = ct$kernel[[j]],
        clip = clips,
        cv.logloss = vapply(clips, function(eps) logloss.at(pred[, j], y, eps),
                            numeric(1L)),
        stringsAsFactors = FALSE
    )
}))
dir.create("reports", showWarnings = FALSE)
utils::write.csv(scores, "reports/e2_12_crossclip_scores.csv",
                 row.names = FALSE)

argmin.at <- function(eps) {
    s <- vapply(seq_len(nrow(ct)),
                function(j) logloss.at(pred[, j], y, eps), numeric(1L))
    list(idx = which.min(s), margin = abs(diff(sort(s)))[[1L]])
}
a15 <- argmin.at(1e-15)
a06 <- argmin.at(1e-6)
a03 <- argmin.at(1e-3)
label <- function(a) sprintf("support=%d,degree=%d",
                             ct$support.size[[a$idx]], ct$degree[[a$idx]])
verdict <- data.frame(
    study = "e2_12_crossclip_stability",
    fixture = "G6 seed 7001, eta=6*tanh(15*x1), n=400, flip obs 7, binomial",
    n.candidates = nrow(ct),
    selected.eps.1e.15 = label(a15),
    selected.eps.1e.6 = label(a06),
    selected.eps.1e.3 = label(a03),
    margin.eps.1e.15 = a15$margin,
    margin.eps.1e.6 = a06$margin,
    margin.eps.1e.3 = a03$margin,
    stable.1e.6.vs.1e.3 = identical(a06$idx, a03$idx),
    stable.1e.15.vs.1e.6 = identical(a15$idx, a06$idx),
    verdict = if (identical(a06$idx, a03$idx)) "stable" else
        "not stable (near-tie reselected; recorded, not gated)",
    stringsAsFactors = FALSE
)
utils::write.csv(verdict, "reports/e2_12_crossclip_stability_verdict.csv",
                 row.names = FALSE)

cat(sprintf(
    paste0("E2.12 cross-clip STUDY: argmin@1e-15=%s argmin@1e-6=%s ",
           "argmin@1e-3=%s | margins %.6f / %.6f / %.6f | %s\n"),
    label(a15), label(a06), label(a03),
    a15$margin, a06$margin, a03$margin, verdict$verdict))
cat("wrote reports/e2_12_crossclip_scores.csv and reports/e2_12_crossclip_stability_verdict.csv\n")
