# =============================================================================
# E4.1 — Pointwise confidence-band coverage harness (Tier 4, Part B)
#
# GATE (contract §E / E4.1): interior average coverage in [0.93, 0.97] with
# known sigma; in [0.92, 0.98] with the plug-in sigma.hat.
# STUDY: boundary and high-curvature coverage, reported STRATIFIED (interior /
# boundary-within-h-of-edge / top-curvature-decile) and never averaged into
# the interior headline; undercoverage magnitude reported.
#
# ACCEPTANCE GATING: the acceptance run uses Amendment 1's frozen, audited
# G3a generator (sigma = 0.1 known, n = 1200, R = 500) — pass it as `dgp.fn`
# with `dgp.source = "amendment1-g3a"`. The inline paraboloid below is SMOKE
# WIRING ONLY (`dgp.source = "inline-smoke"`); a verdict row carrying an
# inline-smoke source is never acceptance evidence.
#
# UNPINNED KNOBS (e4_1_spec_questions_implementer_2026-06-11.md §4): the spec
# fixes singleton grids, chart.dim = 2, degree 1, n, sigma, R — but not the
# support size K, the kernel, or G3a's curvature radius. They are parameters
# here, recorded in every artifact; the orchestrator pins them for acceptance.
#
# POWER CALCULATION (spec §sec:tol, Monte-Carlo convention): per-point
# coverage across R independent replicates is Bernoulli-mean distributed with
# MC-SE = sqrt(p (1-p) / R) ~= sqrt(0.95 * 0.05 / R):
#   R = 500 (full)  -> MC-SE ~= 0.0097, about half the 0.02 distance from the
#                      nominal 0.95 to the gate bounds [0.93, 0.97];
#   R = 100 (smoke) -> MC-SE ~= 0.022 (wiring shakeout only, no verdict force).
# The interior-average statistic additionally averages over (positively
# correlated) eval points; its replicate-level MC-SE is estimated empirically
# as sd over replicates of the interior coverage fraction divided by sqrt(R),
# and is reported in the verdict row alongside the conservative per-point
# value.
#
# FAST PATH (spec-questions §5): S depends only on (X, configuration), and the
# geometry is FIXED across replicates (conditional-on-design coverage, the
# spec's "empirical coverage of f(x_i) across replicates"). The harness
# therefore extracts S once via lps.smoother.matrix() and computes each
# replicate's fit as yhat_r = S %*% y_r — the E0.2-pinned linear-smoother
# identity. Drift guard: at replicate 1, every `drift.check.every`-th
# replicate, and the last replicate, the full fit.lps() + lps.pointwise.band()
# pipeline is run and asserted to agree with the S-path to `drift.tol`
# (max-abs); any violation aborts the study. `fit.every.replicate = TRUE`
# disables the shortcut entirely.
#
# RNG (spec §sec:rng): the design uses `geometry.seed` (one draw, recorded);
# replicate r uses seed `base.seed + r` immediately before its noise draw.
# Every artifact records sessionInfo, package version + git head, BLAS id,
# the full fit.lps argument list, and all seeds.
#
# Usage:
#   Rscript validation/e4_1_coverage_study.R [key=value ...]    # from repo root
#   keys: n, R.replicates, sigma, support.size, kernel, curvature.radius,
#         base.seed, geometry.seed, level, drift.check.every, out.dir,
#         fit.every.replicate
# =============================================================================

suppressMessages(pkgload::load_all(".", quiet = TRUE))

# --- SMOKE-ONLY inline paraboloid (G3a-shaped wiring stand-in) ---------------
# Latent u uniform on the unit disk (r = sqrt(U1), theta = 2 pi U2);
# X = (u1, u2, (u1^2 + u2^2) / (2 * curvature.radius));
# truth f_smooth(u) = sin(pi u1) * cos(pi u2).
# NOT the audited Amendment-1 G3a generator; never acceptance evidence.
e41.inline.smoke.dgp <- function(n, curvature.radius, seed) {
    set.seed(seed)
    r <- sqrt(stats::runif(n))
    theta <- 2 * pi * stats::runif(n)
    U <- cbind(r * cos(theta), r * sin(theta))
    X <- cbind(U[, 1L], U[, 2L],
               (U[, 1L]^2 + U[, 2L]^2) / (2 * curvature.radius))
    list(
        U = U,
        X = X,
        truth = sin(pi * U[, 1L]) * cos(pi * U[, 2L]),
        seed = seed,
        dgp.source = "inline-smoke"
    )
}

# Paraboloid principal curvatures at latent radius r (curvature knob R0):
# meridional (1/R0) / (1 + r^2/R0^2)^{3/2}, circumferential
# (1/R0) / (1 + r^2/R0^2)^{1/2}; the maximum is the circumferential one,
# monotone decreasing in r (apex kappa = 1/R0, the spec's knob definition).
e41.paraboloid.max.curvature <- function(r.latent, curvature.radius) {
    (1 / curvature.radius) / sqrt(1 + (r.latent / curvature.radius)^2)
}

e41.knn.bandwidth <- function(X, support.size) {
    n <- nrow(X)
    vapply(seq_len(n), function(i) {
        d <- sqrt(rowSums((X - matrix(X[i, ], n, ncol(X), byrow = TRUE))^2))
        sort(d, partial = support.size)[support.size]
    }, numeric(1L))
}

run.e4.1.coverage.study <- function(
    n = 1200L,
    R.replicates = 100L,
    sigma = 0.1,
    support.size = 30L,
    kernel = "tricube",
    curvature.radius = 1,
    base.seed = 20260611L,
    geometry.seed = 20260611L,
    level = 0.95,
    drift.check.every = 25L,
    drift.tol = 1e-10,
    fit.every.replicate = FALSE,
    dgp.fn = NULL,
    dgp.source = NULL,
    out.dir = file.path("audit_artifacts", "e4_1_coverage_runs",
                        format(Sys.time(), "e4_1_coverage_%Y%m%dT%H%M%SZ",
                               tz = "UTC"))) {

    stamp.start <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    if (is.null(dgp.fn)) {
        dgp.fn <- e41.inline.smoke.dgp
        dgp.source <- "inline-smoke"
    } else if (is.null(dgp.source)) {
        stop("an external dgp.fn requires an explicit dgp.source label.",
             call. = FALSE)
    }

    ## ---- design (fixed across replicates) and truth -------------------------
    dgp <- dgp.fn(n = n, curvature.radius = curvature.radius,
                  seed = geometry.seed)
    X <- dgp$X
    U <- dgp$U
    truth <- dgp$truth
    stopifnot(nrow(X) == n, nrow(U) == n, length(truth) == n)

    ## ---- the pinned fixed configuration (full fit.lps argument list) --------
    fit.args <- list(
        foldid = rep(1:2, length.out = n),
        support.grid = as.integer(support.size),
        degree.grid = 1L,
        kernel.grid = kernel,
        coordinate.method = "local.pca",
        chart.dim = 2L,
        local.chart.method = "pca",
        backend = "R",
        design.basis = "orthogonal.polynomial.drop",
        ridge.multiplier.grid = 0,
        ridge.condition.max = Inf,
        unstable.action = "na"
    )
    full.fit <- function(y) do.call(fit.lps, c(list(X = X, y = y), fit.args))

    ## ---- extract S once (y-independent at the fixed configuration) ----------
    set.seed(base.seed + 1L)
    y.first <- truth + stats::rnorm(n, 0, sigma)
    fit.S <- full.fit(y.first)
    if (anyNA(fit.S$fitted.values)) {
        stop("the fixed configuration produced NA local fits on this design; ",
             "the coverage study requires complete fits.", call. = FALSE)
    }
    S <- lps.smoother.matrix(fit.S)
    df <- sum(diag(S))
    stopifnot(is.finite(df), df < n)
    row.norm <- sqrt(rowSums(S^2))
    z <- stats::qnorm(1 - (1 - level) / 2)
    se.known <- sigma * row.norm
    bias <- as.numeric(S %*% truth) - truth   # exact smoothing bias at f
    bias.se.ratio <- abs(bias) / se.known     # deterministic, per point

    ## ---- strata --------------------------------------------------------------
    r.latent <- sqrt(rowSums(U^2))
    h.point <- e41.knn.bandwidth(X, as.integer(support.size))
    boundary <- (1 - r.latent) < h.point
    boundary.global <- (1 - r.latent) < stats::median(h.point)
    kappa <- e41.paraboloid.max.curvature(r.latent, curvature.radius)
    top.curvature <- kappa >= stats::quantile(kappa, 0.9, type = 7)
    interior <- !boundary

    ## ---- replicate loop -------------------------------------------------------
    R <- as.integer(R.replicates)
    cover.known <- matrix(NA, n, R)
    cover.plugin <- matrix(NA, n, R)
    sigma.hat.r <- numeric(R)
    guard.at <- sort(unique(c(
        1L,
        seq.int(drift.check.every, R, by = drift.check.every),
        R
    )))
    if (fit.every.replicate) guard.at <- seq_len(R)
    guard.rows <- list()

    for (r in seq_len(R)) {
        set.seed(base.seed + r)
        y.r <- truth + stats::rnorm(n, 0, sigma)
        yhat.r <- as.numeric(S %*% y.r)
        rss.r <- sum((y.r - yhat.r)^2)
        sh.r <- sqrt(rss.r / (n - df))
        sigma.hat.r[[r]] <- sh.r

        lo.k <- yhat.r - z * se.known
        hi.k <- yhat.r + z * se.known
        cover.known[, r] <- truth >= lo.k & truth <= hi.k

        se.p <- sh.r * row.norm
        lo.p <- yhat.r - z * se.p
        hi.p <- yhat.r + z * se.p
        cover.plugin[, r] <- truth >= lo.p & truth <= hi.p

        if (r %in% guard.at) {
            fit.r <- full.fit(y.r)
            d.fit <- max(abs(fit.r$fitted.values.raw - yhat.r))
            band.k <- lps.pointwise.band(fit.r, sigma = sigma, level = level)
            band.p <- lps.pointwise.band(fit.r, level = level)
            d.known <- max(abs(band.k$lower - lo.k), abs(band.k$upper - hi.k),
                           abs(band.k$se - se.known))
            d.plugin <- max(abs(band.p$lower - lo.p), abs(band.p$upper - hi.p),
                            abs(band.p$sigma.hat - sh.r))
            d.df <- abs(band.p$df - df)
            guard.rows[[length(guard.rows) + 1L]] <- data.frame(
                replicate = r,
                max.abs.fitted.diff = d.fit,
                max.abs.known.band.diff = d.known,
                max.abs.plugin.band.diff = d.plugin,
                abs.df.diff = d.df
            )
            if (max(d.fit, d.known, d.plugin, d.df) > drift.tol) {
                stop("drift guard failed at replicate ", r, ": the S-path ",
                     "and the full fit.lps/lps.pointwise.band pipeline ",
                     "disagree beyond ", format(drift.tol), " (fitted ",
                     format(d.fit), ", known band ", format(d.known),
                     ", plug-in band ", format(d.plugin), ", df ",
                     format(d.df), "). Study aborted.", call. = FALSE)
            }
        }
    }
    guard.table <- do.call(rbind, guard.rows)

    ## ---- coverage summaries ----------------------------------------------------
    pp.known <- rowMeans(cover.known)
    pp.plugin <- rowMeans(cover.plugin)
    strata <- list(
        interior = interior,
        boundary.within.h = boundary,
        top.curvature.decile = top.curvature,
        all.points = rep(TRUE, n)
    )
    stratum.summary <- do.call(rbind, lapply(names(strata), function(nm) {
        idx <- strata[[nm]]
        data.frame(
            stratum = nm,
            n.points = sum(idx),
            coverage.known = mean(pp.known[idx]),
            coverage.plugin = mean(pp.plugin[idx]),
            undercoverage.known = level - mean(pp.known[idx]),
            undercoverage.plugin = level - mean(pp.plugin[idx]),
            min.point.coverage.known = min(pp.known[idx]),
            max.point.coverage.known = max(pp.known[idx]),
            mean.abs.bias = mean(abs(bias[idx])),
            mean.se.known = mean(se.known[idx]),
            mean.bias.se.ratio = mean(bias.se.ratio[idx]),
            max.bias.se.ratio = max(bias.se.ratio[idx])
        )
    }))

    interior.frac.known <- colMeans(cover.known[interior, , drop = FALSE])
    interior.frac.plugin <- colMeans(cover.plugin[interior, , drop = FALSE])
    interior.known <- mean(interior.frac.known)
    interior.plugin <- mean(interior.frac.plugin)
    mc.se.empirical.known <- stats::sd(interior.frac.known) / sqrt(R)
    mc.se.empirical.plugin <- stats::sd(interior.frac.plugin) / sqrt(R)
    mc.se.perpoint <- sqrt(0.95 * 0.05 / R)

    git.head <- tryCatch(
        system("git rev-parse HEAD", intern = TRUE)[[1L]],
        error = function(e) NA_character_
    )
    context <- if (identical(dgp.source, "amendment1-g3a")) {
        "acceptance-candidate"
    } else {
        "smoke-wiring (NOT acceptance evidence)"
    }
    verdict.rows <- data.frame(
        gate = "E4.1",
        sub.item = c("interior.coverage.known.sigma",
                     "interior.coverage.plugin.sigma"),
        type = c("GATE", "GATE"),
        statistic = "interior.average.coverage",
        value = c(interior.known, interior.plugin),
        lower.bound = c(0.93, 0.92),
        upper.bound = c(0.97, 0.98),
        verdict = c(
            if (interior.known >= 0.93 && interior.known <= 0.97) "pass"
            else "fail",
            if (interior.plugin >= 0.92 && interior.plugin <= 0.98) "pass"
            else "fail"
        ),
        context = context,
        dgp.source = dgp.source,
        mc.se.empirical = c(mc.se.empirical.known, mc.se.empirical.plugin),
        mc.se.perpoint.bernoulli = mc.se.perpoint,
        interior.mean.bias.se.ratio = mean(bias.se.ratio[interior]),
        interior.max.bias.se.ratio = max(bias.se.ratio[interior]),
        n = n,
        R.replicates = R,
        sigma = sigma,
        support.size = as.integer(support.size),
        kernel = kernel,
        curvature.radius = curvature.radius,
        chart.dim = 2L,
        degree = 1L,
        level = level,
        df.trace = df,
        n.interior = sum(interior),
        n.boundary = sum(boundary),
        n.top.curvature = sum(top.curvature),
        n.boundary.global.h = sum(boundary.global),
        base.seed = base.seed,
        geometry.seed = geometry.seed,
        git.head = git.head,
        generated.utc = stamp.start,
        stringsAsFactors = FALSE
    )

    ## ---- artifacts ---------------------------------------------------------------
    dir.create(out.dir, recursive = TRUE, showWarnings = FALSE)
    provenance <- list(
        session.info = capture.output(sessionInfo()),
        package.version = as.character(utils::packageVersion("geosmooth")),
        git.head = git.head,
        git.status.lines = tryCatch(
            length(system("git status --porcelain", intern = TRUE)),
            error = function(e) NA_integer_
        ),
        blas = tryCatch(extSoftVersion()[["BLAS"]], error = function(e) NA),
        lapack = tryCatch(La_library(), error = function(e) NA),
        working.directory = getwd(),
        fit.lps.arguments = fit.args,
        full.fit.replicates = guard.at,
        parameters = list(
            n = n, R.replicates = R, sigma = sigma,
            support.size = as.integer(support.size), kernel = kernel,
            curvature.radius = curvature.radius, base.seed = base.seed,
            geometry.seed = geometry.seed, level = level,
            drift.check.every = drift.check.every, drift.tol = drift.tol,
            fit.every.replicate = fit.every.replicate,
            dgp.source = dgp.source
        ),
        started.utc = stamp.start,
        finished.utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    )
    per.point <- data.frame(
        point = seq_len(n),
        r.latent = r.latent,
        h.point = h.point,
        kappa = kappa,
        interior = interior,
        boundary.within.h = boundary,
        boundary.global.h = boundary.global,
        top.curvature.decile = top.curvature,
        bias = bias,
        se.known = se.known,
        bias.se.ratio = bias.se.ratio,
        smoother.row.norm = row.norm,
        coverage.known = pp.known,
        coverage.plugin = pp.plugin
    )
    results <- list(
        provenance = provenance,
        verdict.rows = verdict.rows,
        stratum.summary = stratum.summary,
        per.point = per.point,
        sigma.hat.by.replicate = sigma.hat.r,
        interior.fraction.by.replicate.known = interior.frac.known,
        interior.fraction.by.replicate.plugin = interior.frac.plugin,
        drift.guard = guard.table,
        df = df
    )
    saveRDS(results, file.path(out.dir, "e4_1_coverage_results.rds"))
    utils::write.csv(verdict.rows,
                     file.path(out.dir, "e4_1_verdict_rows.csv"),
                     row.names = FALSE)
    utils::write.csv(stratum.summary,
                     file.path(out.dir, "e4_1_stratified_summary.csv"),
                     row.names = FALSE)
    utils::write.csv(per.point,
                     file.path(out.dir, "e4_1_per_point_coverage.csv"),
                     row.names = FALSE)
    utils::write.csv(guard.table,
                     file.path(out.dir, "e4_1_drift_guard.csv"),
                     row.names = FALSE)
    writeLines(c(
        paste0("context: ", context),
        paste0("dgp.source: ", dgp.source),
        sprintf("interior coverage (known sigma):   %.4f  [gate 0.93, 0.97] -> %s",
                interior.known, verdict.rows$verdict[[1L]]),
        sprintf("interior coverage (plug-in sigma): %.4f  [gate 0.92, 0.98] -> %s",
                interior.plugin, verdict.rows$verdict[[2L]]),
        sprintf("empirical MC-SE (known / plug-in): %.4f / %.4f",
                mc.se.empirical.known, mc.se.empirical.plugin),
        sprintf("interior bias/se: mean %.4f  max %.4f",
                mean(bias.se.ratio[interior]), max(bias.se.ratio[interior])),
        sprintf("df = tr S: %.3f   n: %d   R: %d", df, n, R),
        paste0("out.dir: ", out.dir)
    ), file.path(out.dir, "e4_1_console_summary.txt"))
    cat(readLines(file.path(out.dir, "e4_1_console_summary.txt")), sep = "\n")
    cat("stratified summary (never averaged into the interior headline):\n")
    print(stratum.summary, row.names = FALSE)
    invisible(results)
}

## ---- CLI ---------------------------------------------------------------------
if (sys.nframe() == 0L) {
    args <- commandArgs(trailingOnly = TRUE)
    overrides <- list()
    for (a in args) {
        kv <- strsplit(a, "=", fixed = TRUE)[[1L]]
        if (length(kv) != 2L) stop("arguments must be key=value, got: ", a)
        key <- kv[[1L]]
        val <- utils::type.convert(kv[[2L]], as.is = TRUE)
        overrides[[key]] <- val
    }
    do.call(run.e4.1.coverage.study, overrides)
}
