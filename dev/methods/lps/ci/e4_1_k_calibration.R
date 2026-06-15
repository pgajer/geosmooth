# =============================================================================
# E4.1 — support-size (K) calibration on the audited G3a (Part B, Item 4a)
#
# Orchestrator resolution 2026-06-12 (Item 4a): before the acceptance run,
# report the realized interior bias-to-se ratio as a function of K on the
# frozen, audit-accepted row G3a-R1-smooth-s010-n1200, and propose the largest
# K whose interior bias/se is small enough that bias cannot move coverage out
# of the gate band (target interior bias/se <~ 0.3). Kernel pinned: tricube.
# The proposed K is RATIFIED BY THE ORCHESTRATOR before the acceptance run;
# this script produces the table, not the decision.
#
# The calibration is DETERMINISTIC — no Monte Carlo:
#   bias_i = E[yhat_i] - f(x_i) = (S f)_i - f_i   (S is y-free at the fixed
#            configuration; the expectation is exact),
#   se_i   = sigma * ||S_i.||_2                   (known sigma = 0.1),
#   per-point expected coverage of the known-sigma z-band under exact bias:
#            Phi(z - r_i) - Phi(-z - r_i),  r_i = |bias_i| / se_i,
# so each K costs one S extraction and the table is exact under the model
# (gaussian noise, fixed design), with no replicate-count caveats.
#
# Strata per the ratified Item 4d: boundary iff (1 - ||u_i||) < h_i with h_i
# the realized per-point K-th-NN ambient distance (so the interior set depends
# on K, by definition); interior = complement; top-curvature decile reported
# as an overlay context column.
#
# Usage:  Rscript dev/methods/lps/ci/e4_1_k_calibration.R [key=value ...]
#         keys: K.grid (comma-separated), sigma, level, target.ratio, out.dir
# =============================================================================

suppressMessages(pkgload::load_all(".", quiet = TRUE))
source("dev/methods/lps/ci/e4_1_coverage_study.R")   # helpers; CLI is sys.nframe()-guarded
source("dev/methods/lps/ci/e4_1_g3a_binding.R")

run.e4.1.k.calibration <- function(
    K.grid = c(10L, 12L, 15L, 18L, 20L, 22L, 25L, 28L, 30L, 35L, 40L),
    sigma = 0.1,
    level = 0.95,
    target.ratio = 0.3,
    out.dir = file.path("dev", "methods", "lps", "audit_artifacts",
                        format(Sys.time(), "e4_1_k_calibration_%Y%m%dT%H%M%SZ",
                               tz = "UTC"))) {

    stamp.start <- format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    lib <- e41.load.audited.dgp.library()
    g3a <- e41.materialize.audited.g3a(lib)
    ds <- g3a$dataset
    X <- ds$X
    U <- ds$U
    truth <- ds$truth
    n <- ds$n
    z <- stats::qnorm(1 - (1 - level) / 2)
    r.latent <- sqrt(rowSums(U^2))
    kappa <- e41.paraboloid.max.curvature(r.latent, curvature.radius = 1)
    top.curv <- kappa >= stats::quantile(kappa, 0.9, type = 7)

    fit.args.template <- list(
        foldid = rep(1:2, length.out = n),
        degree.grid = 1L,
        kernel.grid = "tricube",
        coordinate.method = "local.pca",
        chart.dim = 2L,
        local.chart.method = "pca",
        backend = "R",
        design.basis = "orthogonal.polynomial.drop",
        ridge.multiplier.grid = 0,
        ridge.condition.max = Inf,
        unstable.action = "na"
    )

    rows <- list()
    for (K in as.integer(K.grid)) {
        fit <- do.call(fit.lps, c(list(X = X, y = ds$y,
                                       support.grid = K),
                                  fit.args.template))
        if (anyNA(fit$fitted.values)) {
            stop("K = ", K, " produced NA local fits on the audited design; ",
                 "calibration requires complete fits.", call. = FALSE)
        }
        S <- lps.smoother.matrix(fit)
        bias <- as.numeric(S %*% truth) - truth
        se <- sigma * sqrt(rowSums(S^2))
        ratio <- abs(bias) / se
        cov.exp <- stats::pnorm(z - ratio) - stats::pnorm(-z - ratio)
        h.point <- e41.knn.bandwidth(X, K)
        boundary <- (1 - r.latent) < h.point
        interior <- !boundary
        rows[[length(rows) + 1L]] <- data.frame(
            K = K,
            df.trace = sum(diag(S)),
            n.interior = sum(interior),
            n.boundary = sum(boundary),
            interior.max.ratio = max(ratio[interior]),
            interior.mean.ratio = mean(ratio[interior]),
            interior.q90.ratio =
                as.numeric(stats::quantile(ratio[interior], 0.9, type = 7)),
            interior.expected.coverage = mean(cov.exp[interior]),
            boundary.mean.ratio = mean(ratio[boundary]),
            boundary.expected.coverage = mean(cov.exp[boundary]),
            top.curv.expected.coverage = mean(cov.exp[top.curv]),
            interior.mean.abs.bias = mean(abs(bias[interior])),
            interior.mean.se = mean(se[interior])
        )
    }
    tab <- do.call(rbind, rows)

    pick.largest <- function(ok) {
        if (!any(ok)) NA_integer_ else max(tab$K[ok])
    }
    proposal <- list(
        target.ratio = target.ratio,
        largest.K.max.ratio =
            pick.largest(tab$interior.max.ratio <= target.ratio),
        largest.K.mean.ratio =
            pick.largest(tab$interior.mean.ratio <= target.ratio),
        largest.K.expected.coverage.0945 =
            pick.largest(tab$interior.expected.coverage >= 0.945)
    )

    git.head <- tryCatch(system("git rev-parse HEAD", intern = TRUE)[[1L]],
                         error = function(e) NA_character_)
    provenance <- list(
        session.info = capture.output(sessionInfo()),
        package.version =
            as.character(utils::packageVersion("geosmooth")),
        git.head = git.head,
        blas = tryCatch(extSoftVersion()[["BLAS"]], error = function(e) NA),
        lapack = tryCatch(La_library(), error = function(e) NA),
        working.directory = getwd(),
        dgp.binding = g3a$binding,
        dgp.content.sha256 = g3a$content.sha256,
        fit.lps.arguments.template = fit.args.template,
        parameters = list(K.grid = as.integer(K.grid), sigma = sigma,
                          level = level, target.ratio = target.ratio),
        started.utc = stamp.start,
        finished.utc = format(Sys.time(), "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
    )

    dir.create(out.dir, recursive = TRUE, showWarnings = FALSE)
    utils::write.csv(tab, file.path(out.dir, "e4_1_k_calibration_table.csv"),
                     row.names = FALSE)
    saveRDS(list(table = tab, proposal = proposal, provenance = provenance),
            file.path(out.dir, "e4_1_k_calibration_results.rds"))
    writeLines(c(
        paste0("dgp: ", g3a$binding$dataset.id, " @ ",
               substr(g3a$binding$dgp.commit, 1, 7),
               " (content sha verified: ", g3a$binding$verified, ")"),
        sprintf("target interior bias/se ratio: <= %.2f", target.ratio),
        sprintf("largest K with interior MAX  ratio <= target: %s",
                format(proposal$largest.K.max.ratio)),
        sprintf("largest K with interior MEAN ratio <= target: %s",
                format(proposal$largest.K.mean.ratio)),
        sprintf("largest K with expected interior coverage >= 0.945: %s",
                format(proposal$largest.K.expected.coverage.0945)),
        "status: PROPOSAL ONLY - the acceptance K awaits orchestrator ratification",
        paste0("out.dir: ", out.dir)
    ), file.path(out.dir, "e4_1_k_calibration_summary.txt"))
    cat(readLines(file.path(out.dir, "e4_1_k_calibration_summary.txt")),
        sep = "\n")
    cat("\ncalibration table:\n")
    print(tab, row.names = FALSE, digits = 4)
    invisible(list(table = tab, proposal = proposal,
                   provenance = provenance))
}

## ---- CLI ---------------------------------------------------------------------
if (sys.nframe() == 0L) {
    args <- commandArgs(trailingOnly = TRUE)
    overrides <- list()
    for (a in args) {
        kv <- strsplit(a, "=", fixed = TRUE)[[1L]]
        if (length(kv) != 2L) stop("arguments must be key=value, got: ", a)
        key <- kv[[1L]]
        val <- kv[[2L]]
        overrides[[key]] <- if (identical(key, "K.grid")) {
            as.integer(strsplit(val, ",", fixed = TRUE)[[1L]])
        } else {
            utils::type.convert(val, as.is = TRUE)
        }
    }
    do.call(run.e4.1.k.calibration, overrides)
}
