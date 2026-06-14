# =============================================================================
# E1.10 STUDY b' -- grouped CV folding-scheme correctness via a
# relative-improvement criterion, plus a leave-one-cluster-out (LOCO)
# confirmatory test of the train-size-bias explanation of the Study (b)
# rho=0.6 absolute FAIL.
#
# Origin: orchestrator adjudication + work order
#   project_briefs/lps_e1_10_bprime_adjudication_workorder_2026-06-14.md
# Additive and NON-BLOCKING: it does NOT alter the ratified Study (b)
# (validation/e1_10_nested_grouped_cv.R, which stays byte-frozen) and does NOT
# change package source. LOCO is the existing exported utility
# lps.grouped.foldid(cluster.id, v = n_clusters) fed to lps.nested.cv(); the
# relative criterion is a verdict computation. dgp.g5 is consumed from the
# audited registry (no hand-rolled generator).
#
# PREDECLARED DECISION RULES (frozen before any acceptance run; post-hoc
# changes invalidate the study). All gated means require their SE < 0.10/3,
# else INCONCLUSIVE.
#
#   Per replicate, per rho, three folding arms share the SAME realized train
#   and fresh-cluster test draw (arms differ ONLY in fold construction):
#     random   : random 5-fold outer + round-robin inner   (splits clusters)
#     groupedA : grouped 5-fold outer + grouped inner       (32/40 clusters/fold)
#     loco     : leave-one-cluster-out outer (v = K) + grouped inner
#                                                           (39/40 clusters/fold)
#   Primary statistic per arm = the NESTED estimate under that folding (as
#   ratified for Study (b)); rel.<arm> = |nested.<arm> - rmse.test.<arm>| /
#   rmse.test.<arm>, with rmse.test.<arm> the fresh-cluster error of that arm's
#   deployed full-train selected-min fit. gap = rel.random - rel.groupedA.
#
#   At rho = 0.6 (gated; rho = 0.3 reported-only):
#   * PRIMARY (relative-improvement, folding-scheme correctness):
#       mean(gap) > 0.10  AND  mean(rel.groupedA) <= (1 - f) * mean(rel.random),
#       with f = 0.50 (orchestrator-ratified; observed closure in Study (b)
#       was 0.68). SE guard on mean(gap) and mean(rel.groupedA). Expected PASS.
#       Reported: closure = 1 - mean(rel.groupedA)/mean(rel.random).
#   * CONFIRMATORY (LOCO absolute): mean(rel.loco) < 0.10, SE guard on
#       mean(rel.loco). Expected PASS; a FAIL here is an ESCALATION (the
#       absolute bound is unattainable even at minimal train-size reduction).
#
#   ARM C (diagnostic, NON-GATED): grouped 5-fold at K in {40, 80, 160},
#   m = 20, rho = 0.6, reduced replication R_C = 10 (a monotone-trend
#   diagnostic of train-size bias vs cluster count, reported with SE; not a
#   gated test, so reduced R is predeclared here, not chosen post-hoc).
#
#   Monte-Carlo error: gated thresholds/margins are 0.10; with R = 40 the SE
#   of each gated mean must be < 0.10/3 = 0.0333; a verdict with any gated-mean
#   SE >= 0.0333 is recorded INCONCLUSIVE.
#
#   ROUTINE GRIDS (identical to Study (b)): support {10,15,20}, degree 0:2,
#   kernels {gaussian,tricube}, design orthogonal.polynomial.drop,
#   ridge {0,1e-10,1e-8}, ridge.condition.max 1e12, unstable.action na,
#   backend R, inner folds 5. Seeds are FRESH (base 70000), distinct from
#   Study (a)/(b) seeds (61000/62000).
#
# MODES
#   --mode=smoke       (default) tiny INLINE fixtures (NOT plan DGPs), never
#                      acceptance evidence; exercises all arms + verdict logic.
#   --mode=acceptance  consumes registry dgp.g5 ONLY; refuses unless it resolves
#                      AND LPS_E110_ACCEPT=1.
#
# Usage:
#   Rscript validation/e1_10_grouped_loco_bprime.R [--mode=smoke|acceptance] [--out=DIR]
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
                                 "e1_10_bprime_smoke"
                             } else {
                                 "e1_10_bprime"
                             }))
dir.create(OUT, recursive = TRUE, showWarnings = FALSE)

# ---- frozen parameters -------------------------------------------------------
SEED0 <- 70000L
CLOSURE.F <- 0.50
SE.MAX <- 0.10 / 3
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
    K.B <- 40L; M.B <- 20L; K.TEST.B <- 100L; RHO.B <- c(0.3, 0.6); R.B <- 40L
    ARMC.K <- c(40L, 80L, 160L); ARMC.R <- 10L; ARMC.RHO <- 0.6
} else {
    K.B <- 8L; M.B <- 6L; K.TEST.B <- 10L; RHO.B <- c(0.3, 0.6); R.B <- 2L
    ARMC.K <- c(8L, 12L); ARMC.R <- 2L; ARMC.RHO <- 0.6
}

# ---- generators --------------------------------------------------------------
# Registry adapter: the ONLY binding to the audited DGP library. Same field
# fallbacks as the ratified Study (b) script.
bprime.registry.g5 <- function() {
    ns <- asNamespace("geosmooth")
    g5 <- get0("dgp.g5", envir = ns)
    if (is.null(g5)) {
        stop("Registry generator dgp.g5 is not available in this geosmooth ",
             "build; acceptance mode requires the audited DGP library.",
             call. = FALSE)
    }
    field <- function(ds, candidates) {
        for (nm in candidates) if (!is.null(ds[[nm]])) return(ds[[nm]])
        stop("Registry dataset object lacks fields ",
             paste(candidates, collapse = "/"), ".", call. = FALSE)
    }
    list(
        source = "registry",
        g5 = function(K, m, rho, seed, cluster.prefix) {
            ds <- g5(K = K, m = m, rho = rho, seed = seed)
            cl <- field(ds, c("region", "cluster.id", "cluster",
                              "region.labels"))
            list(X = field(ds, "X"), y = field(ds, "y"),
                 truth = field(ds, "truth"),
                 cluster.id = paste0(cluster.prefix, as.character(cl)))
        }
    )
}

# SMOKE fixture (NOT a plan DGP); pipeline exercise only.
bprime.smoke.g5 <- function() {
    list(
        source = "inline-smoke-fixture (NOT plan DGP)",
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
        stop("Acceptance mode is gated: set LPS_E110_ACCEPT=1 only after the ",
             "orchestrator confirms the DGP-library audit accepted G5.",
             call. = FALSE)
    }
    GEN <- bprime.registry.g5()
} else {
    GEN <- bprime.smoke.g5()
}

# ---- helpers (self-contained; Study (b) script stays byte-frozen) ------------
rmse <- function(pred, obs) {
    ok <- is.finite(pred) & is.finite(obs)
    if (!any(ok)) return(NA_real_)
    sqrt(mean((pred[ok] - obs[ok])^2))
}
bprime.realized.icc <- function(resid, cluster) {
    cluster <- as.character(cluster)
    m.i <- table(cluster); k <- length(m.i); n <- length(resid)
    if (k < 2L || n <= k) return(NA_real_)
    means <- tapply(resid, cluster, mean); grand <- mean(resid)
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
# One folding arm: nested estimate + deployed fresh-cluster error + rel error.
arm.eval <- function(train, test, outer.foldid, inner.method, inner.seed) {
    fit <- lps.nested.cv(
        X = train$X, y = train$y, outer.foldid = outer.foldid,
        fit.args = ROUTINE.FIT.ARGS, inner.folds = 5L,
        cluster.id = train$cluster.id, inner.foldid.method = inner.method,
        inner.shuffle.seed = inner.seed
    )
    pred <- predict(fit$selected.min$fit, newdata = test$X)
    rt <- rmse(pred, test$y)
    list(nested = fit$nested.rmse, rmse.test = rt,
         rel = abs(fit$nested.rmse - rt) / rt,
         whole = isTRUE(fit$outer.cluster.whole),
         n.missing = fit$n.missing.predictions)
}

# ---- core arms: random / groupedA / loco ------------------------------------
message(sprintf("[E1.10b'] mode=%s generator=%s R=%d K=%d m=%d K_test=%d",
                MODE, GEN$source, R.B, K.B, M.B, K.TEST.B))
rows <- list()
for (rho in RHO.B) {
    for (r in seq_len(R.B)) {
        seed.base <- SEED0 + round(1e6 * rho) + r
        train <- GEN$g5(K = K.B, m = M.B, rho = rho, seed = seed.base,
                        cluster.prefix = "train_")
        test <- GEN$g5(K = K.TEST.B, m = M.B, rho = rho,
                       seed = seed.base + 100000L, cluster.prefix = "test_")
        stopifnot(!length(intersect(unique(train$cluster.id),
                                    unique(test$cluster.id))))

        set.seed(seed.base + 200000L)
        outer.random <- sample(rep_len(1:5, nrow(train$X)))
        a.random <- arm.eval(train, test, outer.random, "round.robin",
                             seed.base + 300000L)

        outer.groupedA <- lps.grouped.foldid(train$cluster.id, v = 5L,
                                             shuffle.seed = seed.base + 400000L)
        a.groupedA <- arm.eval(train, test, outer.groupedA, "grouped",
                              seed.base + 500000L)

        # LOCO: each cluster its own outer fold (deterministic), grouped inner.
        outer.loco <- lps.grouped.foldid(train$cluster.id, v = K.B)
        a.loco <- arm.eval(train, test, outer.loco, "grouped",
                          seed.base + 600000L)

        rows[[length(rows) + 1L]] <- data.frame(
            study = "E1.10b'", rho.nominal = rho, replicate = r,
            seed.base = seed.base,
            realized.icc = bprime.realized.icc(train$y - train$truth,
                                               train$cluster.id),
            rel.random = a.random$rel, rel.groupedA = a.groupedA$rel,
            rel.loco = a.loco$rel,
            gap.primary = a.random$rel - a.groupedA$rel,
            nested.random = a.random$nested, nested.groupedA = a.groupedA$nested,
            nested.loco = a.loco$nested,
            rmse.test.random = a.random$rmse.test,
            rmse.test.groupedA = a.groupedA$rmse.test,
            rmse.test.loco = a.loco$rmse.test,
            random.split = !a.random$whole, groupedA.whole = a.groupedA$whole,
            loco.whole = a.loco$whole,
            loco.outer.folds = length(unique(outer.loco)),
            n.missing.random = a.random$n.missing,
            n.missing.groupedA = a.groupedA$n.missing,
            n.missing.loco = a.loco$n.missing,
            stringsAsFactors = FALSE
        )
    }
}
cases <- do.call(rbind, rows)
write.csv(cases, file.path(OUT, "e1_10_bprime_core_cases.csv"),
          row.names = FALSE)

verdict.rows <- lapply(RHO.B, function(rho) {
    cc <- cases[cases$rho.nominal == rho, ]
    gated <- identical(rho, 0.6)
    m.gap <- mean(cc$gap.primary); se.gap <- mean.se(cc$gap.primary)
    m.gA <- mean(cc$rel.groupedA); se.gA <- mean.se(cc$rel.groupedA)
    m.rand <- mean(cc$rel.random)
    m.loco <- mean(cc$rel.loco); se.loco <- mean.se(cc$rel.loco)
    closure <- 1 - m.gA / m.rand
    primary.se.ok <- is.finite(se.gap) && se.gap < SE.MAX &&
        is.finite(se.gA) && se.gA < SE.MAX
    primary.pass <- m.gap > 0.10 && m.gA <= (1 - CLOSURE.F) * m.rand
    loco.se.ok <- is.finite(se.loco) && se.loco < SE.MAX
    loco.pass <- m.loco < 0.10
    data.frame(
        study = "E1.10b'", mode = MODE, generator = GEN$source,
        rho.nominal = rho, gated = gated, R = nrow(cc),
        K = K.B, m = M.B, K.test = K.TEST.B, closure.f = CLOSURE.F,
        mean.realized.icc = mean(cc$realized.icc),
        mean.rel.random = m.rand,
        mean.rel.groupedA = m.gA, se.rel.groupedA = se.gA,
        mean.rel.loco = m.loco, se.rel.loco = se.loco,
        mean.gap.primary = m.gap, se.gap.primary = se.gap,
        closure.fraction = closure,
        primary.verdict = if (gated) verdict.word(primary.pass, primary.se.ok)
                          else "REPORTED-ONLY",
        loco.confirmatory.verdict = if (gated) verdict.word(loco.pass, loco.se.ok)
                                   else "REPORTED-ONLY",
        all.groupedA.whole = all(cc$groupedA.whole),
        all.loco.whole = all(cc$loco.whole),
        all.random.split = all(cc$random.split),
        rule = paste0("primary: gap>0.10 & rel.groupedA<=(1-0.5)*rel.random; ",
                      "confirmatory: rel.loco<0.10; SE<0.0333 (rho=0.6 gated)"),
        acceptance.evidence = identical(MODE, "acceptance"),
        stringsAsFactors = FALSE
    )
})
verdict <- do.call(rbind, verdict.rows)
write.csv(verdict, file.path(OUT, "e1_10_bprime_core_verdict.csv"),
          row.names = FALSE)
for (i in seq_len(nrow(verdict))) {
    message(sprintf(
        paste0("[E1.10b'] rho=%.1f primary=%s loco=%s | gap=%.3f closure=%.2f ",
               "rel.random=%.3f rel.groupedA=%.3f rel.loco=%.3f icc=%.3f"),
        verdict$rho.nominal[[i]], verdict$primary.verdict[[i]],
        verdict$loco.confirmatory.verdict[[i]], verdict$mean.gap.primary[[i]],
        verdict$closure.fraction[[i]], verdict$mean.rel.random[[i]],
        verdict$mean.rel.groupedA[[i]], verdict$mean.rel.loco[[i]],
        verdict$mean.realized.icc[[i]]))
}

# ---- arm C: grouped 5-fold cluster-fold bias vs cluster count (diagnostic) ---
message(sprintf("[E1.10b' armC] grouped 5-fold at K in {%s}, rho=%.1f, R_C=%d",
                paste(ARMC.K, collapse = ","), ARMC.RHO, ARMC.R))
armc.rows <- list()
for (K in ARMC.K) {
    for (r in seq_len(ARMC.R)) {
        seed.base <- SEED0 + 800000L + K * 1000L + r
        train <- GEN$g5(K = K, m = M.B, rho = ARMC.RHO, seed = seed.base,
                        cluster.prefix = "train_")
        test <- GEN$g5(K = K.TEST.B, m = M.B, rho = ARMC.RHO,
                       seed = seed.base + 100000L, cluster.prefix = "test_")
        outer <- lps.grouped.foldid(train$cluster.id, v = 5L,
                                    shuffle.seed = seed.base + 400000L)
        a <- arm.eval(train, test, outer, "grouped", seed.base + 500000L)
        armc.rows[[length(armc.rows) + 1L]] <- data.frame(
            study = "E1.10b'-armC", K = K, m = M.B, rho.nominal = ARMC.RHO,
            replicate = r, seed.base = seed.base,
            train.clusters.per.fold = K - as.integer(round(K / 5)),
            realized.icc = bprime.realized.icc(train$y - train$truth,
                                               train$cluster.id),
            rel.cluster = a$rel, nested = a$nested, rmse.test = a$rmse.test,
            n.missing = a$n.missing,
            stringsAsFactors = FALSE
        )
    }
}
armc <- do.call(rbind, armc.rows)
write.csv(armc, file.path(OUT, "e1_10_bprime_armc_cases.csv"),
          row.names = FALSE)
armc.summary <- do.call(rbind, lapply(ARMC.K, function(K) {
    cc <- armc[armc$K == K, ]
    data.frame(study = "E1.10b'-armC", K = K, m = M.B, rho.nominal = ARMC.RHO,
               R_C = nrow(cc), mean.rel.cluster = mean(cc$rel.cluster),
               se.rel.cluster = mean.se(cc$rel.cluster),
               mean.realized.icc = mean(cc$realized.icc),
               note = "diagnostic, non-gated; expect rel.cluster decreasing in K",
               stringsAsFactors = FALSE)
}))
write.csv(armc.summary, file.path(OUT, "e1_10_bprime_armc_summary.csv"),
          row.names = FALSE)
for (i in seq_len(nrow(armc.summary))) {
    message(sprintf("[E1.10b' armC] K=%d rel.cluster=%.3f (se=%.3f) icc=%.3f",
                    armc.summary$K[[i]], armc.summary$mean.rel.cluster[[i]],
                    armc.summary$se.rel.cluster[[i]],
                    armc.summary$mean.realized.icc[[i]]))
}

# ---- run metadata ------------------------------------------------------------
meta <- c(
    paste0("study: E1.10b' (grouped CV relative-improvement + LOCO confirmatory)"),
    paste0("mode: ", MODE),
    paste0("generator_source: ", GEN$source),
    paste0("git_head: ",
           tryCatch(system("git rev-parse HEAD", intern = TRUE),
                    error = function(e) NA_character_)),
    paste0("generated_utc: ",
           format(Sys.time(), "%Y%m%dT%H%M%SZ", tz = "UTC")),
    paste0("r_version: ", R.version.string),
    paste0("blas: ", extSoftVersion()[["BLAS"]]),
    "fit_args:", deparse(ROUTINE.FIT.ARGS),
    sprintf("core: K=%d m=%d K_test=%d R=%d rho=%s seed0=%d closure_f=%.2f",
            K.B, M.B, K.TEST.B, R.B, paste(RHO.B, collapse = ","), SEED0,
            CLOSURE.F),
    sprintf("armC: K=%s m=%d rho=%.1f R_C=%d (diagnostic, non-gated)",
            paste(ARMC.K, collapse = ","), M.B, ARMC.RHO, ARMC.R)
)
writeLines(meta, file.path(OUT, "e1_10_bprime_run_metadata.txt"))
message("[E1.10b'] wrote ", OUT)
