# =============================================================================
# E1.10 STUDIES -- nested CV optimism (a) and grouped CV under cluster
# dependence (b).  Contract sB/E1.10 (STUDY typing per sA1); plan sE1.10.
#
# PREDECLARED DECISION RULES (frozen before any acceptance run; post-hoc
# changes invalidate the study):
#
#   Study (a), generator dgp.g3a: n_train = 800, n_test = 4000, R = 40,
#   sigma = 0.10 (predeclared by the implementer; the spec pins G3a but not
#   sigma for E1.10).  Routine grids (below).  Statistic per replicate:
#   rel_x = |rmse_x - rmse_test| / rmse_test for x in {selected-min, nested},
#   where rmse_test is the fresh-sample error of the deployed full-train
#   selected-min fit, and optimism_delta = nested_rmse - selectedmin_score.
#   VERDICT (a): mean(rel_nested) < 0.10  AND  mean(optimism_delta) >= 0.
#   Supplementary (reported, not gated): one-sided Wilcoxon signed-rank
#   p-value for optimism_delta > 0; mean(rel_selectedmin).
#
#   Study (b), generator dgp.g5: K = 40 clusters, m = 20,
#   rho in {0.3, 0.6}, R = 40; fresh-cluster test set K_test = 100, m = 20
#   (cluster ids disjoint from training by construction).  Arms share the
#   realized training data; they differ ONLY in fold construction (the axis
#   under study, sec:paired): random = seeded random outer 5-fold + seeded
#   randomized round-robin inner folds; cluster = grouped outer 5-fold
#   (lps.grouped.foldid) + grouped inner folds.  PRIMARY statistic per arm:
#   the NESTED estimate under that arm's folding (spec memo s4; selection
#   optimism cancels between arms), rel_arm = |nested_arm - rmse_test_arm| /
#   rmse_test_arm with rmse_test_arm the fresh-cluster error of that arm's
#   deployed full-train selected-min fit; gap = rel_random - rel_cluster.
#   VERDICT (b), evaluated at rho = 0.6 only: mean(gap) > 0.10 AND
#   mean(rel_cluster) < 0.10.  rho = 0.3 is reported, not gated.
#   Supplementary: selected-min variant of both arms; realized ICC
#   (one-way ANOVA method-of-moments on y - truth).
#
#   Monte-Carlo error: thresholds/margins are 0.10; with R = 40 the SE of
#   each gated mean must satisfy SE < 0.10/3 = 0.033, i.e. across-replicate
#   sd < 0.21 -- plausible for relative errors of this size; the realized
#   sd and SE of every gated mean are written into the verdict row, and a
#   verdict with SE >= 0.033 is recorded as INCONCLUSIVE, never as pass.
#
# ROUTINE GRIDS (selection is the object of study; fit.lps public defaults,
# pinned explicitly): support {10,15,20}, degree 0:2, kernels
# {gaussian, tricube}, bandwidth.multiplier 1, design orthogonal.polynomial.
# drop, ridge {0,1e-10,1e-8}, ridge.condition.max 1e12, unstable.action na,
# backend R, outer 5-fold / inner 5-fold.
#
# MODES
#   --mode=smoke       (default) tiny INLINE fixtures, R = 2: exercises the
#                      full pipeline end-to-end.  The fixtures are NOT plan
#                      DGPs and smoke output is NEVER acceptance evidence.
#   --mode=acceptance  consumes the audited registry generators dgp.g3a /
#                      dgp.g5 ONLY; refuses to run unless both resolve in
#                      the geosmooth namespace AND LPS_E110_ACCEPT=1 is set
#                      (the orchestrator's confirmation that the DGP audit
#                      is clear).  No G3a/G5 logic is hand-rolled here.
#
# Usage:
#   Rscript validation/e1_10_nested_grouped_cv.R [--mode=smoke|acceptance]
#           [--out=<dir>]
# =============================================================================

suppressMessages(pkgload::load_all(".", quiet = TRUE))

args <- commandArgs(trailingOnly = TRUE)
flag <- function(name, default) {
    hit <- grep(paste0("^--", name, "="), args, value = TRUE)
    if (!length(hit)) return(default)
    sub(paste0("^--", name, "="), "", hit[[1L]])
}
MODE <- match.arg(flag("mode", "smoke"), c("smoke", "acceptance"))
OUT <- flag("out", file.path("reports",
                             if (identical(MODE, "smoke")) {
                                 "e1_10_smoke"
                             } else {
                                 "e1_10_acceptance"
                             }))
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- frozen study parameters -------------------------------------------------
SIGMA.A <- 0.10
SEED.A0 <- 61000L
SEED.B0 <- 62000L
ROUTINE.FIT.ARGS <- list(
    support.grid = c(10L, 15L, 20L),
    degree.grid = 0:2,
    kernel.grid = c("gaussian", "tricube"),
    backend = "R",
    design.basis = "orthogonal.polynomial.drop",
    ridge.multiplier.grid = c(0, 1e-10, 1e-8),
    ridge.condition.max = 1e12,
    unstable.action = "na"
)
if (identical(MODE, "acceptance")) {
    N.TRAIN.A <- 800L; N.TEST.A <- 4000L; R.A <- 40L
    K.B <- 40L; M.B <- 20L; K.TEST.B <- 100L; RHO.B <- c(0.3, 0.6); R.B <- 40L
} else {
    N.TRAIN.A <- 120L; N.TEST.A <- 400L; R.A <- 2L
    K.B <- 8L; M.B <- 6L; K.TEST.B <- 10L; RHO.B <- 0.6; R.B <- 2L
}
SE.MAX <- 0.10 / 3

# ---- generators ----------------------------------------------------------------
# Registry adapter: the ONLY place that binds the audited DGP library.  The
# argument names below are provisional until the audited registry is merged
# onto this branch; rebind them HERE if its signatures differ.  Field
# fallbacks cover the Amendment-1 "standard dataset object" naming.
e110.registry.generators <- function() {
    ns <- asNamespace("geosmooth")
    g3a <- get0("dgp.g3a", envir = ns)
    g5 <- get0("dgp.g5", envir = ns)
    if (is.null(g3a) || is.null(g5)) {
        stop("Registry generators dgp.g3a / dgp.g5 are not available in ",
             "this geosmooth build; acceptance mode requires the audited ",
             "DGP library (Amendment 1).", call. = FALSE)
    }
    field <- function(ds, candidates) {
        for (nm in candidates) if (!is.null(ds[[nm]])) return(ds[[nm]])
        stop("Registry dataset object lacks fields ",
             paste(candidates, collapse = "/"), ".", call. = FALSE)
    }
    list(
        source = "registry",
        g3a = function(n, seed) {
            ds <- g3a(n = n, sigma = SIGMA.A, seed = seed)
            list(X = field(ds, "X"), y = field(ds, "y"),
                 truth = field(ds, "truth"))
        },
        g5 = function(K, m, rho, seed, cluster.prefix) {
            ds <- g5(K = K, m = m, rho = rho, seed = seed)
            cl <- field(ds, c("cluster.id", "cluster", "region",
                              "region.labels"))
            list(X = field(ds, "X"), y = field(ds, "y"),
                 truth = field(ds, "truth"),
                 cluster.id = paste0(cluster.prefix, as.character(cl)))
        }
    )
}

# SMOKE FIXTURES -- pipeline exercise only.  Deliberately NOT the plan DGPs
# (no paraboloid embedding, own truth and parameters); never acceptance
# evidence.
e110.smoke.generators <- function() {
    list(
        source = "inline-smoke-fixture (NOT plan DGPs)",
        g3a = function(n, seed) {
            set.seed(seed)
            X <- matrix(stats::runif(n * 2L, -1, 1), ncol = 2L)
            truth <- 0.6 * sin(1.5 * pi * X[, 1L]) + 0.4 * X[, 2L]
            set.seed(seed + 1L)
            list(X = X, y = truth + 0.15 * stats::rnorm(n), truth = truth)
        },
        g5 = function(K, m, rho, seed, cluster.prefix) {
            sigma.eps <- 0.3
            tau2 <- rho * sigma.eps^2 / (1 - rho)
            set.seed(seed)
            centers <- matrix(stats::runif(K * 2L, -1, 1), ncol = 2L)
            cluster <- rep(seq_len(K), each = m)
            set.seed(seed + 1L)
            X <- centers[cluster, , drop = FALSE] +
                0.15 * matrix(stats::rnorm(K * m * 2L), ncol = 2L)
            truth <- sin(pi * X[, 1L]) + 0.5 * X[, 2L]
            set.seed(seed + 2L)
            b <- sqrt(tau2) * stats::rnorm(K)
            set.seed(seed + 3L)
            y <- truth + b[cluster] + sigma.eps * stats::rnorm(K * m)
            list(X = X, y = y, truth = truth,
                 cluster.id = paste0(cluster.prefix, cluster))
        }
    )
}

if (identical(MODE, "acceptance")) {
    if (!identical(Sys.getenv("LPS_E110_ACCEPT"), "1")) {
        stop("Acceptance mode is gated: set LPS_E110_ACCEPT=1 only after ",
             "the orchestrator confirms the DGP-library audit accepted ",
             "G3a and G5.", call. = FALSE)
    }
    GEN <- e110.registry.generators()
} else {
    GEN <- e110.smoke.generators()
}

# ---- shared helpers ------------------------------------------------------------
rmse <- function(pred, obs) {
    ok <- is.finite(pred) & is.finite(obs)
    if (!any(ok)) return(NA_real_)
    sqrt(mean((pred[ok] - obs[ok])^2))
}

# One-way ANOVA method-of-moments ICC of resid within clusters (unbalanced-
# safe); clipped to [0, 1].
e110.realized.icc <- function(resid, cluster) {
    cluster <- as.character(cluster)
    m.i <- table(cluster)
    k <- length(m.i)
    n <- length(resid)
    if (k < 2L || n <= k) return(NA_real_)
    means <- tapply(resid, cluster, mean)
    grand <- mean(resid)
    msb <- sum(m.i * (means - grand)^2) / (k - 1)
    msw <- sum((resid - means[cluster])^2) / (n - k)
    m0 <- (n - sum(m.i^2) / n) / (k - 1)
    icc <- (msb - msw) / (msb + (m0 - 1) * msw)
    max(0, min(1, icc))
}

mean.se <- function(x) stats::sd(x) / sqrt(length(x))

verdict.word <- function(pass, se.ok) {
    if (!se.ok) "INCONCLUSIVE" else if (pass) "PASS" else "FAIL"
}

# ---- Study (a): nested CV corrects selection optimism --------------------------
message(sprintf("[E1.10a] mode=%s generator=%s R=%d n_train=%d n_test=%d",
                MODE, GEN$source, R.A, N.TRAIN.A, N.TEST.A))
rows.a <- vector("list", R.A)
for (r in seq_len(R.A)) {
    train <- GEN$g3a(n = N.TRAIN.A, seed = SEED.A0 + r)
    test <- GEN$g3a(n = N.TEST.A, seed = SEED.A0 + 100000L + r)
    set.seed(SEED.A0 + 200000L + r)
    outer.foldid <- sample(rep_len(1:5, N.TRAIN.A))
    nested <- lps.nested.cv(
        X = train$X, y = train$y, outer.foldid = outer.foldid,
        fit.args = ROUTINE.FIT.ARGS, inner.folds = 5L,
        inner.shuffle.seed = SEED.A0 + 300000L + r
    )
    pred.test <- predict(nested$selected.min$fit, newdata = test$X)
    rmse.test <- rmse(pred.test, test$y)
    rows.a[[r]] <- data.frame(
        study = "E1.10a", replicate = r,
        seed.train = SEED.A0 + r, seed.test = SEED.A0 + 100000L + r,
        seed.outer = SEED.A0 + 200000L + r,
        seed.inner = SEED.A0 + 300000L + r,
        nested.rmse = nested$nested.rmse,
        selectedmin.score = nested$selected.min$cv.score,
        rmse.test = rmse.test,
        rel.nested = abs(nested$nested.rmse - rmse.test) / rmse.test,
        rel.selectedmin =
            abs(nested$selected.min$cv.score - rmse.test) / rmse.test,
        optimism.delta = nested$nested.rmse - nested$selected.min$cv.score,
        n.missing.predictions = nested$n.missing.predictions,
        stringsAsFactors = FALSE
    )
}
cases.a <- do.call(rbind, rows.a)
write.csv(cases.a, file.path(OUT, "e1_10_a_optimism_cases.csv"),
          row.names = FALSE)

se.rel.nested <- mean.se(cases.a$rel.nested)
se.delta <- mean.se(cases.a$optimism.delta)
se.ok.a <- is.finite(se.rel.nested) && se.rel.nested < SE.MAX
pass.a <- mean(cases.a$rel.nested) < 0.10 &&
    mean(cases.a$optimism.delta) >= 0
wilcox.p.a <- if (R.A >= 5L) {
    suppressWarnings(stats::wilcox.test(
        cases.a$optimism.delta, alternative = "greater"
    )$p.value)
} else {
    NA_real_
}
verdict.a <- data.frame(
    study = "E1.10a", mode = MODE, generator = GEN$source,
    R = R.A, n.train = N.TRAIN.A, n.test = N.TEST.A, sigma = SIGMA.A,
    mean.rel.nested = mean(cases.a$rel.nested),
    se.rel.nested = se.rel.nested,
    mean.rel.selectedmin = mean(cases.a$rel.selectedmin),
    mean.optimism.delta = mean(cases.a$optimism.delta),
    se.optimism.delta = se.delta,
    wilcoxon.p.greater = wilcox.p.a,
    rule = "mean(rel.nested)<0.10 & mean(optimism.delta)>=0; SE<0.0333",
    verdict = verdict.word(pass.a, se.ok.a),
    acceptance.evidence = identical(MODE, "acceptance"),
    stringsAsFactors = FALSE
)
write.csv(verdict.a, file.path(OUT, "e1_10_a_optimism_verdict.csv"),
          row.names = FALSE)
message(sprintf(
    "[E1.10a] verdict=%s mean.rel.nested=%.4f mean.rel.selmin=%.4f mean.delta=%.4f",
    verdict.a$verdict, verdict.a$mean.rel.nested,
    verdict.a$mean.rel.selectedmin, verdict.a$mean.optimism.delta))

# ---- Study (b): grouped CV under cluster dependence ----------------------------
message(sprintf("[E1.10b] mode=%s generator=%s R=%d K=%d m=%d K_test=%d",
                MODE, GEN$source, R.B, K.B, M.B, K.TEST.B))
rows.b <- list()
for (rho in RHO.B) {
    for (r in seq_len(R.B)) {
        seed.base <- SEED.B0 + round(1e6 * rho) + r
        train <- GEN$g5(K = K.B, m = M.B, rho = rho, seed = seed.base,
                        cluster.prefix = "train_")
        test <- GEN$g5(K = K.TEST.B, m = M.B, rho = rho,
                       seed = seed.base + 100000L,
                       cluster.prefix = "test_")
        stopifnot(!length(intersect(unique(train$cluster.id),
                                    unique(test$cluster.id))))
        n <- nrow(train$X)

        set.seed(seed.base + 200000L)
        outer.random <- sample(rep_len(1:5, n))
        arm.random <- lps.nested.cv(
            X = train$X, y = train$y, outer.foldid = outer.random,
            fit.args = ROUTINE.FIT.ARGS, inner.folds = 5L,
            cluster.id = train$cluster.id,
            inner.foldid.method = "round.robin",
            inner.shuffle.seed = seed.base + 300000L
        )
        outer.cluster <- lps.grouped.foldid(
            train$cluster.id, v = 5L,
            shuffle.seed = seed.base + 400000L
        )
        arm.cluster <- lps.nested.cv(
            X = train$X, y = train$y, outer.foldid = outer.cluster,
            fit.args = ROUTINE.FIT.ARGS, inner.folds = 5L,
            cluster.id = train$cluster.id,
            inner.foldid.method = "grouped",
            inner.shuffle.seed = seed.base + 500000L
        )
        arm.stats <- function(arm) {
            pred <- predict(arm$selected.min$fit, newdata = test$X)
            rt <- rmse(pred, test$y)
            list(
                nested = arm$nested.rmse,
                selmin = arm$selected.min$cv.score,
                rmse.test = rt,
                rel.nested = abs(arm$nested.rmse - rt) / rt,
                rel.selmin = abs(arm$selected.min$cv.score - rt) / rt
            )
        }
        s.r <- arm.stats(arm.random)
        s.c <- arm.stats(arm.cluster)
        rows.b[[length(rows.b) + 1L]] <- data.frame(
            study = "E1.10b", rho.nominal = rho, replicate = r,
            seed.base = seed.base,
            realized.icc = e110.realized.icc(train$y - train$truth,
                                             train$cluster.id),
            random.split.clusters = !isTRUE(arm.random$outer.cluster.whole),
            cluster.arm.whole = isTRUE(arm.cluster$outer.cluster.whole),
            nested.random = s.r$nested, nested.cluster = s.c$nested,
            selmin.random = s.r$selmin, selmin.cluster = s.c$selmin,
            rmse.test.random = s.r$rmse.test,
            rmse.test.cluster = s.c$rmse.test,
            rel.nested.random = s.r$rel.nested,
            rel.nested.cluster = s.c$rel.nested,
            rel.selmin.random = s.r$rel.selmin,
            rel.selmin.cluster = s.c$rel.selmin,
            gap.primary = s.r$rel.nested - s.c$rel.nested,
            gap.selmin = s.r$rel.selmin - s.c$rel.selmin,
            n.missing.random = arm.random$n.missing.predictions,
            n.missing.cluster = arm.cluster$n.missing.predictions,
            stringsAsFactors = FALSE
        )
    }
}
cases.b <- do.call(rbind, rows.b)
write.csv(cases.b, file.path(OUT, "e1_10_b_grouped_cases.csv"),
          row.names = FALSE)

verdict.b.rows <- lapply(RHO.B, function(rho) {
    cc <- cases.b[cases.b$rho.nominal == rho, ]
    se.gap <- mean.se(cc$gap.primary)
    se.relc <- mean.se(cc$rel.nested.cluster)
    gated <- identical(rho, 0.6)
    se.ok <- is.finite(se.gap) && se.gap < SE.MAX &&
        is.finite(se.relc) && se.relc < SE.MAX
    pass <- mean(cc$gap.primary) > 0.10 &&
        mean(cc$rel.nested.cluster) < 0.10
    data.frame(
        study = "E1.10b", mode = MODE, generator = GEN$source,
        rho.nominal = rho, gated = gated,
        R = nrow(cc), K = K.B, m = M.B, K.test = K.TEST.B,
        mean.realized.icc = mean(cc$realized.icc),
        mean.gap.primary = mean(cc$gap.primary),
        se.gap.primary = se.gap,
        mean.rel.nested.random = mean(cc$rel.nested.random),
        mean.rel.nested.cluster = mean(cc$rel.nested.cluster),
        se.rel.nested.cluster = se.relc,
        mean.gap.selmin = mean(cc$gap.selmin),
        all.cluster.arm.whole = all(cc$cluster.arm.whole),
        rule = paste0("at rho=0.6: mean(gap.primary)>0.10 & ",
                      "mean(rel.nested.cluster)<0.10; SE<0.0333"),
        verdict = if (gated) verdict.word(pass, se.ok) else "REPORTED-ONLY",
        acceptance.evidence = identical(MODE, "acceptance"),
        stringsAsFactors = FALSE
    )
})
verdict.b <- do.call(rbind, verdict.b.rows)
write.csv(verdict.b, file.path(OUT, "e1_10_b_grouped_verdict.csv"),
          row.names = FALSE)
for (i in seq_len(nrow(verdict.b))) {
    message(sprintf(
        "[E1.10b] rho=%.1f verdict=%s gap=%.4f rel.cluster=%.4f realized.icc=%.3f",
        verdict.b$rho.nominal[[i]], verdict.b$verdict[[i]],
        verdict.b$mean.gap.primary[[i]],
        verdict.b$mean.rel.nested.cluster[[i]],
        verdict.b$mean.realized.icc[[i]]))
}

# ---- run metadata ---------------------------------------------------------------
meta <- c(
    paste0("mode: ", MODE),
    paste0("generator_source: ", GEN$source),
    paste0("git_head: ",
           tryCatch(system("git rev-parse HEAD", intern = TRUE),
                    error = function(e) NA_character_)),
    paste0("generated_utc: ",
           format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")),
    paste0("r_version: ", R.version.string),
    paste0("blas: ", extSoftVersion()[["BLAS"]]),
    "fit_args:",
    deparse(ROUTINE.FIT.ARGS),
    sprintf("study_a: n_train=%d n_test=%d R=%d sigma=%.2f seed0=%d",
            N.TRAIN.A, N.TEST.A, R.A, SIGMA.A, SEED.A0),
    sprintf("study_b: K=%d m=%d K_test=%d R=%d rho=%s seed0=%d",
            K.B, M.B, K.TEST.B, R.B, paste(RHO.B, collapse = ","), SEED.B0)
)
writeLines(meta, file.path(OUT, "e1_10_run_metadata.txt"))
message("[E1.10] wrote ", OUT)
