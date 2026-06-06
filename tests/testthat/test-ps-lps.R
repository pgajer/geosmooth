test_that("PS-LPS normalized product overlap weights have pair mass equal to overlap size", {
    set.seed(11)
    X <- matrix(runif(80), ncol = 2)
    y <- sin(X[, 1])
    frames <- .ps.lps.prepare.frames(
        X = X,
        y = y,
        support.size = 10L,
        degree = 2L,
        kernel = "gaussian",
        chart.dim.by.anchor = rep(2L, nrow(X))
    )
    sync.rows <- .ps.lps.prepare.sync.rows(
        frames = frames,
        sync.neighbor.size = 3L,
        overlap.weight = "normalized.product"
    )
    expect_gt(length(sync.rows), 0L)
    mass.error <- vapply(sync.rows, function(sr) {
        abs(sum(sr$omega) - length(sr$point))
    }, numeric(1L))
    expect_lt(max(mass.error), 1e-6)
})

test_that("PS-LPS with zero synchronization and zero ridge reproduces ordinary LPS fitted values", {
    set.seed(12)
    X <- matrix(runif(120), ncol = 2)
    y <- sin(4 * X[, 1]) + X[, 2]^2
    foldid <- rep(seq_len(5L), length.out = nrow(X))
    lps <- fit.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = 18L,
        degree.grid = 2L,
        kernel.grid = "gaussian",
        coordinate.method = "local.pca",
        chart.dim = 2L,
        backend = "R"
    )
    ps <- fit.ps.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.size = 18L,
        degree = 2L,
        kernel = "gaussian",
        chart.dim = 2L,
        lambda.sync.grid = 0,
        lambda.ridge = 0,
        sync.neighbor.size = 3L
    )
    expect_equal(ps$selected$lambda.ridge[[1L]], 0)
    expect_equal(max(abs(lps$fitted.values - ps$fitted.values)), 0,
                 tolerance = 1e-10)
})

test_that("PS-LPS zero synchronization and zero ridge reproduces LPS local.auto vector-chart fitted values", {
    set.seed(1)
    X <- matrix(runif(150), ncol = 3)
    X[seq_len(25L), 3L] <- 0.02 * runif(25L)
    y <- sin(4 * X[, 1]) + X[, 2]^2 - 0.5 * X[, 3]
    foldid <- rep(seq_len(5L), length.out = nrow(X))
    lps <- fit.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = 18L,
        degree.grid = 2L,
        kernel.grid = "gaussian",
        coordinate.method = "local.pca",
        chart.dim = "local.auto",
        backend = "R"
    )
    ps <- fit.ps.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.size = lps$selected$support.size[[1L]],
        degree = lps$selected$degree[[1L]],
        kernel = lps$selected$kernel[[1L]],
        chart.dim = lps$chart.dim.by.eval,
        lambda.sync.grid = 0,
        lambda.ridge = 0,
        sync.neighbor.size = 3L
    )
    expect_equal(length(lps$chart.dim.by.eval), nrow(X))
    expect_gt(length(unique(lps$chart.dim.by.eval)), 1L)
    expect_equal(max(abs(lps$fitted.values - ps$fitted.values)), 0,
                 tolerance = 1e-10)
})

test_that("PS-LPS chart.dim auto matches explicit resolved scalar dimension", {
    set.seed(21)
    X <- matrix(runif(150), ncol = 3)
    y <- sin(3 * X[, 1]) + 0.5 * X[, 2]^2 - X[, 3]
    foldid <- rep(seq_len(5L), length.out = nrow(X))
    fit.auto <- fit.ps.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.size = 18L,
        degree = 2L,
        kernel = "gaussian",
        chart.dim = "auto",
        lambda.sync.grid = c(0, 0.1),
        lambda.ridge = 0,
        sync.neighbor.size = 3L
    )
    fit.explicit <- fit.ps.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.size = 18L,
        degree = 2L,
        kernel = "gaussian",
        chart.dim = fit.auto$auto.chart.dim,
        lambda.sync.grid = c(0, 0.1),
        lambda.ridge = 0,
        sync.neighbor.size = 3L
    )
    expect_identical(fit.auto$requested.chart.dim, "auto")
    expect_identical(fit.auto$chart.dim.mode, "global.auto")
    expect_true(all(fit.auto$chart.dim.by.anchor == fit.auto$auto.chart.dim))
    expect_equal(fit.auto$fitted.values, fit.explicit$fitted.values,
                 tolerance = 1e-10)
    expect_equal(fit.auto$selected$lambda.sync,
                 fit.explicit$selected$lambda.sync)
})

test_that("PS-LPS chart.dim local.auto matches explicit resolved vector dimensions", {
    set.seed(22)
    X <- matrix(runif(180), ncol = 4)
    X[seq_len(40L), 4L] <- 0.005 * runif(40L)
    y <- cos(3 * X[, 1]) + X[, 2] - 0.2 * X[, 3]^2
    foldid <- rep(seq_len(5L), length.out = nrow(X))
    fit.local <- fit.ps.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.size = 20L,
        degree = 2L,
        kernel = "tricube",
        chart.dim = "local.auto",
        lambda.sync.grid = c(0, 0.1),
        lambda.ridge = 0,
        sync.neighbor.size = 3L
    )
    fit.explicit <- fit.ps.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.size = 20L,
        degree = 2L,
        kernel = "tricube",
        chart.dim = fit.local$chart.dim.by.anchor,
        lambda.sync.grid = c(0, 0.1),
        lambda.ridge = 0,
        sync.neighbor.size = 3L
    )
    expect_identical(fit.local$requested.chart.dim, "local.auto")
    expect_identical(fit.local$chart.dim.mode, "local.auto")
    expect_equal(length(fit.local$chart.dim.by.anchor), nrow(X))
    expect_gt(length(unique(fit.local$chart.dim.by.anchor)), 1L)
    expect_equal(fit.local$fitted.values, fit.explicit$fitted.values,
                 tolerance = 1e-10)
    expect_equal(fit.local$selected$lambda.sync,
                 fit.explicit$selected$lambda.sync)
})

test_that("PS-LPS local grid selection matches explicit fixed-candidate search", {
    set.seed(23)
    X <- matrix(runif(120), ncol = 3)
    y <- sin(2 * X[, 1]) + X[, 2]^2 - 0.25 * X[, 3]
    foldid <- rep(seq_len(5L), length.out = nrow(X))
    support.grid <- c(14L, 18L)
    kernel.grid <- c("gaussian", "tricube")
    grid.fit <- fit.ps.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.grid = support.grid,
        degree.grid = 2L,
        kernel.grid = kernel.grid,
        chart.dim = "auto",
        lambda.sync.grid = c(0, 0.1),
        lambda.ridge = 0,
        sync.neighbor.size = 3L
    )
    explicit <- do.call(rbind, lapply(support.grid, function(k) {
        do.call(rbind, lapply(kernel.grid, function(ker) {
            fit <- fit.ps.lps(
                X = X,
                y = y,
                foldid = foldid,
                support.size = k,
                degree = 2L,
                kernel = ker,
                chart.dim = "auto",
                lambda.sync.grid = c(0, 0.1),
                lambda.ridge = 0,
                sync.neighbor.size = 3L
            )
            data.frame(
                support.size = k,
                kernel = ker,
                cv.rmse.observed = fit$selected$cv.rmse.observed[[1L]],
                lambda.sync = fit$selected$lambda.sync[[1L]],
                stringsAsFactors = FALSE
            )
        }))
    }))
    explicit.best <- explicit[order(explicit$cv.rmse.observed,
                                    explicit$lambda.sync,
                                    explicit$support.size,
                                    explicit$kernel), ][1L, ]
    expect_equal(nrow(grid.fit$local.candidate.table), 4L)
    expect_equal(nrow(grid.fit$lambda.cv.table), 8L)
    expect_equal(grid.fit$support.size, explicit.best$support.size)
    expect_identical(grid.fit$kernel, explicit.best$kernel)
    expect_equal(grid.fit$selected$cv.rmse.observed[[1L]],
                 explicit.best$cv.rmse.observed)
    expect_equal(grid.fit$selected$lambda.sync[[1L]],
                 explicit.best$lambda.sync)
})

test_that("PS-LPS with positive ridge and zero synchronization nests ridge-LPS", {
    set.seed(13)
    X <- matrix(runif(90), ncol = 3)
    y <- cos(3 * X[, 1]) + 0.2 * X[, 2]
    lambda.ridge <- 1e-8
    frames <- .ps.lps.prepare.frames(
        X = X,
        y = y,
        support.size = 15L,
        degree = 2L,
        kernel = "tricube",
        chart.dim.by.anchor = rep(2L, nrow(X))
    )
    ridge.lps <- .ps.lps.solve(
        frames = frames,
        y = y,
        response.weights = rep(1, length(y)),
        lambda.sync = 0,
        lambda.ridge = lambda.ridge,
        sync.rows = list()
    )
    ps <- fit.ps.lps(
        X = X,
        y = y,
        foldid = rep(seq_len(5L), length.out = nrow(X)),
        support.size = 15L,
        degree = 2L,
        kernel = "tricube",
        chart.dim = 2L,
        lambda.sync.grid = 0,
        lambda.ridge = lambda.ridge,
        sync.neighbor.size = 3L
    )
    expect_equal(ps$fitted.values, ridge.lps$fitted.values,
                 tolerance = 1e-12)
    expect_gt(ps$ridge.max, 0)
})

test_that("PS-LPS cached solve reproduces direct positive-synchronization solve", {
    set.seed(15)
    X <- matrix(runif(120), ncol = 3)
    y <- sin(3 * X[, 1]) + X[, 2]^2 - 0.25 * X[, 3]
    frames <- .ps.lps.prepare.frames(
        X = X,
        y = y,
        support.size = 16L,
        degree = 2L,
        kernel = "gaussian",
        chart.dim.by.anchor = rep(2L, nrow(X))
    )
    sync.rows <- .ps.lps.prepare.sync.rows(
        frames = frames,
        sync.neighbor.size = 4L,
        overlap.weight = "normalized.product"
    )
    cache <- .ps.lps.prepare.system.cache(frames, sync.rows)
    response.weights <- rep(1, length(y))
    direct <- .ps.lps.solve(
        frames = frames,
        y = y,
        response.weights = response.weights,
        lambda.sync = 3,
        lambda.ridge = 1e-8,
        sync.rows = sync.rows
    )
    cached <- .ps.lps.solve.cached(
        cache = cache,
        y = y,
        response.weights = response.weights,
        lambda.sync = 3,
        lambda.ridge = 1e-8
    )
    expect_equal(cached$fitted.values, direct$fitted.values,
                 tolerance = 1e-10)
    expect_equal(cached$coefficients, direct$coefficients,
                 tolerance = 1e-10)
    expect_equal(cached$sync.energy, direct$sync.energy,
                 tolerance = 1e-10)
    expect_equal(cached$n.system.rows, direct$n.system.rows)
    expect_equal(cached$n.system.cols, direct$n.system.cols)
})

test_that("PS-LPS cached solve reproduces direct fold-weighted and coefficients-only solves", {
    set.seed(16)
    X <- matrix(runif(160), ncol = 4)
    y <- cos(2 * X[, 1]) + X[, 2] - X[, 3]^2
    chart.dim <- rep(c(2L, 3L), length.out = nrow(X))
    frames <- .ps.lps.prepare.frames(
        X = X,
        y = y,
        support.size = 18L,
        degree = 2L,
        kernel = "tricube",
        chart.dim.by.anchor = chart.dim
    )
    sync.rows <- .ps.lps.prepare.sync.rows(
        frames = frames,
        sync.neighbor.size = 3L,
        overlap.weight = "normalized.product"
    )
    cache <- .ps.lps.prepare.system.cache(frames, sync.rows)
    foldid <- rep(seq_len(5L), length.out = length(y))
    response.weights <- as.numeric(foldid != 2L)
    direct <- .ps.lps.solve(
        frames = frames,
        y = y,
        response.weights = response.weights,
        lambda.sync = 10,
        lambda.ridge = 1e-8,
        sync.rows = sync.rows
    )
    cached <- .ps.lps.solve.cached(
        cache = cache,
        y = y,
        response.weights = response.weights,
        lambda.sync = 10,
        lambda.ridge = 1e-8
    )
    expect_equal(cached$fitted.values, direct$fitted.values,
                 tolerance = 1e-10)
    direct.diag <- .ps.lps.solve(
        frames = frames,
        y = y,
        response.weights = response.weights,
        lambda.sync = 10,
        lambda.ridge = 1e-8,
        sync.rows = sync.rows,
        coefficients.only = TRUE
    )
    cached.diag <- .ps.lps.solve.cached(
        cache = cache,
        y = y,
        response.weights = response.weights,
        lambda.sync = 10,
        lambda.ridge = 1e-8,
        coefficients.only = TRUE
    )
    expect_equal(cached.diag$total.local.gcv.ps,
                 direct.diag$total.local.gcv.ps,
                 tolerance = 1e-10)
    expect_equal(cached.diag$mean.sync.squared.disagreement,
                 direct.diag$mean.sync.squared.disagreement,
                 tolerance = 1e-10)
})

test_that("PS-LPS normal cache reproduces direct positive-synchronization solve", {
    set.seed(18)
    X <- matrix(runif(140), ncol = 4)
    y <- sin(2 * X[, 1]) - 0.3 * X[, 2] + X[, 3]^2
    chart.dim <- rep(c(2L, 3L), length.out = nrow(X))
    frames <- .ps.lps.prepare.frames(
        X = X,
        y = y,
        support.size = 17L,
        degree = 2L,
        kernel = "gaussian",
        chart.dim.by.anchor = chart.dim
    )
    sync.rows <- .ps.lps.prepare.sync.rows(
        frames = frames,
        sync.neighbor.size = 4L,
        overlap.weight = "normalized.product"
    )
    cache <- .ps.lps.prepare.system.cache(frames, sync.rows)
    response.weights <- rep(1, length(y))
    normal.cache <- .ps.lps.prepare.normal.cache(
        cache = cache,
        y = y,
        response.weights = response.weights,
        lambda.sync = 4
    )
    direct <- .ps.lps.solve(
        frames = frames,
        y = y,
        response.weights = response.weights,
        lambda.sync = 4,
        lambda.ridge = 1e-7,
        sync.rows = sync.rows
    )
    normal.cached <- .ps.lps.solve.normal.cached(
        normal.cache = normal.cache,
        lambda.ridge = 1e-7
    )
    expect_s3_class(normal.cache, "ps_lps_normal_cache")
    expect_gt(normal.cache$n.system.rows, 0L)
    expect_equal(normal.cached$fitted.values, direct$fitted.values,
                 tolerance = 1e-10)
    expect_equal(normal.cached$coefficients, direct$coefficients,
                 tolerance = 1e-10)
    expect_true(is.finite(
        normal.cached$solve.phase.timings$phase_normal_cache_sec
    ))
})

test_that("PS-LPS normal cache can be reused across ridge values", {
    set.seed(19)
    X <- matrix(runif(180), ncol = 3)
    y <- cos(2 * X[, 1]) + X[, 2] - 0.1 * X[, 3]
    frames <- .ps.lps.prepare.frames(
        X = X,
        y = y,
        support.size = 18L,
        degree = 2L,
        kernel = "tricube",
        chart.dim.by.anchor = rep(2L, nrow(X))
    )
    sync.rows <- .ps.lps.prepare.sync.rows(
        frames = frames,
        sync.neighbor.size = 3L,
        overlap.weight = "normalized.product"
    )
    cache <- .ps.lps.prepare.system.cache(frames, sync.rows)
    response.weights <- as.numeric(rep(seq_len(5L), length.out = length(y)) != 3L)
    normal.cache <- .ps.lps.prepare.normal.cache(
        cache = cache,
        y = y,
        response.weights = response.weights,
        lambda.sync = 2
    )
    for (ridge in c(0, 1e-10, 1e-6)) {
        direct <- .ps.lps.solve(
            frames = frames,
            y = y,
            response.weights = response.weights,
            lambda.sync = 2,
            lambda.ridge = ridge,
            sync.rows = sync.rows
        )
        cached <- .ps.lps.solve.normal.cached(
            normal.cache = normal.cache,
            lambda.ridge = ridge
        )
        expect_equal(cached$fitted.values, direct$fitted.values,
                     tolerance = 1e-10)
        expect_equal(cached$total.local.gcv.ps, direct$total.local.gcv.ps,
                     tolerance = 1e-10)
    }
})

test_that("PS-LPS component cache reproduces direct solves across lambda.sync values", {
    set.seed(20)
    X <- matrix(runif(210), ncol = 3)
    y <- sin(3 * X[, 1]) + 0.5 * X[, 2]^2 - X[, 3]
    frames <- .ps.lps.prepare.frames(
        X = X,
        y = y,
        support.size = 19L,
        degree = 2L,
        kernel = "gaussian",
        chart.dim.by.anchor = rep(2L, nrow(X))
    )
    sync.rows <- .ps.lps.prepare.sync.rows(
        frames = frames,
        sync.neighbor.size = 4L,
        overlap.weight = "normalized.product"
    )
    cache <- .ps.lps.prepare.system.cache(frames, sync.rows)
    foldid <- rep(seq_len(5L), length.out = length(y))
    response.weights <- as.numeric(foldid != 4L)
    component.cache <- .ps.lps.prepare.component.cache(
        cache = cache,
        y = y,
        response.weights = response.weights
    )
    expect_s3_class(component.cache, "ps_lps_component_cache")
    expect_gt(component.cache$data.nrow, 0L)
    expect_gt(component.cache$sync.nrow, 0L)
    for (lambda.sync in c(0.25, 1, 8)) {
        direct <- .ps.lps.solve(
            frames = frames,
            y = y,
            response.weights = response.weights,
            lambda.sync = lambda.sync,
            lambda.ridge = 1e-8,
            sync.rows = sync.rows
        )
        cached <- .ps.lps.solve.component.cached(
            component.cache = component.cache,
            lambda.sync = lambda.sync,
            lambda.ridge = 1e-8
        )
        expect_equal(cached$fitted.values, direct$fitted.values,
                     tolerance = 1e-10)
        expect_equal(cached$coefficients, direct$coefficients,
                     tolerance = 1e-10)
        expect_equal(cached$total.local.gcv.ps, direct$total.local.gcv.ps,
                     tolerance = 1e-10)
    }
})

test_that("fit.ps.lps component-cache integration matches direct mixed-grid tuning loop", {
    set.seed(22)
    X <- matrix(runif(150), ncol = 3)
    y <- sin(2 * X[, 1]) + X[, 2]^2 - 0.2 * X[, 3]
    foldid <- rep(seq_len(5L), length.out = length(y))
    lambda.grid <- c(0, 0.2, 1, 5)
    support.size <- 15L
    degree <- 2L
    kernel <- "gaussian"
    chart.dim <- 2L
    lambda.ridge <- 1e-8
    frames <- .ps.lps.prepare.frames(
        X = X,
        y = y,
        support.size = support.size,
        degree = degree,
        kernel = kernel,
        chart.dim.by.anchor = rep(chart.dim, nrow(X))
    )
    sync.rows <- .ps.lps.prepare.sync.rows(
        frames = frames,
        sync.neighbor.size = 3L,
        overlap.weight = "normalized.product"
    )
    direct.cv <- data.frame(
        lambda.sync = lambda.grid,
        cv.rmse.observed = NA_real_
    )
    for (ll in seq_along(lambda.grid)) {
        pred <- rep(NA_real_, length(y))
        for (fold in sort(unique(foldid))) {
            fit.fold <- .ps.lps.solve(
                frames = frames,
                y = y,
                response.weights = as.numeric(foldid != fold),
                lambda.sync = lambda.grid[[ll]],
                lambda.ridge = lambda.ridge,
                sync.rows = sync.rows
            )
            pred[foldid == fold] <- fit.fold$fitted.values[foldid == fold]
        }
        direct.cv$cv.rmse.observed[[ll]] <- .klp.rmse(pred, y)
    }
    direct.best <- order(direct.cv$cv.rmse.observed,
                         direct.cv$lambda.sync)[[1L]]
    direct.final <- .ps.lps.solve(
        frames = frames,
        y = y,
        response.weights = rep(1, length(y)),
        lambda.sync = direct.cv$lambda.sync[[direct.best]],
        lambda.ridge = lambda.ridge,
        sync.rows = sync.rows
    )
    fitted.cached <- fit.ps.lps(
        X = X,
        y = y,
        foldid = foldid,
        support.size = support.size,
        degree = degree,
        kernel = kernel,
        chart.dim = chart.dim,
        lambda.sync.grid = lambda.grid,
        lambda.ridge = lambda.ridge,
        sync.neighbor.size = 3L
    )
    expect_equal(fitted.cached$cache.backend, "component")
    expect_equal(fitted.cached$cv.table$cv.rmse.observed,
                 direct.cv$cv.rmse.observed,
                 tolerance = 1e-10)
    expect_equal(fitted.cached$selected$lambda.sync[[1L]],
                 direct.cv$lambda.sync[[direct.best]])
    expect_equal(fitted.cached$fitted.values, direct.final$fitted.values,
                 tolerance = 1e-10)
    expect_true(is.finite(
        fitted.cached$solve.phase.timings$phase_component_cache_sec
    ))
})

test_that("PS-LPS positive-sync caches reject nonpositive lambda.sync", {
    set.seed(21)
    X <- matrix(runif(90), ncol = 3)
    y <- X[, 1] - X[, 2]^2
    frames <- .ps.lps.prepare.frames(
        X = X,
        y = y,
        support.size = 15L,
        degree = 2L,
        kernel = "tricube",
        chart.dim.by.anchor = rep(2L, nrow(X))
    )
    sync.rows <- .ps.lps.prepare.sync.rows(
        frames = frames,
        sync.neighbor.size = 3L,
        overlap.weight = "normalized.product"
    )
    cache <- .ps.lps.prepare.system.cache(frames, sync.rows)
    component.cache <- .ps.lps.prepare.component.cache(
        cache = cache,
        y = y,
        response.weights = rep(1, length(y))
    )
    expect_error(
        .ps.lps.prepare.normal.cache(
            cache = cache,
            y = y,
            response.weights = rep(1, length(y)),
            lambda.sync = 0
        ),
        "must be positive"
    )
    expect_error(
        .ps.lps.solve.component.cached(
            component.cache = component.cache,
            lambda.sync = 0,
            lambda.ridge = 1e-8
        ),
        "must be positive"
    )
})

test_that("PS-LPS reports synchronization energy even when lambda.sync is zero", {
    set.seed(14)
    X <- matrix(runif(80), ncol = 2)
    y <- sin(5 * X[, 1]) + rnorm(nrow(X), sd = 0.01)
    ps <- fit.ps.lps(
        X = X,
        y = y,
        foldid = rep(seq_len(4L), length.out = nrow(X)),
        support.size = 12L,
        degree = 2L,
        kernel = "gaussian",
        chart.dim = 2L,
        lambda.sync.grid = 0,
        lambda.ridge = 0,
        sync.neighbor.size = 3L
    )
    expect_gt(ps$sync.energy, 0)
    expect_gt(ps$mean.sync.squared.disagreement, 0)
    expect_equal(ps$mean.sync.disagreement,
                 ps$mean.sync.squared.disagreement)
})

test_that("PS-LPS guarded lambda search recovers interior optimum", {
    evaluator <- function(lambda) {
        data.frame(
            lambda.sync = lambda,
            cv.rmse.observed = (log10(lambda) - log10(27))^2,
            stringsAsFactors = FALSE
        )
    }
    out <- .ps.lps.search.lambda.sync(
        evaluate = evaluator,
        lambda.grid = c(1, 3, 9, 27, 81, 243),
        control = list(rel.tol = 0, boundary.factor = 3)
    )
    expect_equal(out$selected$lambda.sync[[1L]], 27)
    expect_true("refine" %in% out$telemetry$stage)
})

test_that("PS-LPS guarded lambda search expands right boundary", {
    evaluator <- function(lambda) {
        data.frame(
            lambda.sync = lambda,
            cv.rmse.observed = (log10(lambda) - log10(27))^2,
            stringsAsFactors = FALSE
        )
    }
    out <- .ps.lps.search.lambda.sync(
        evaluate = evaluator,
        lambda.grid = c(0, 1, 3, 9),
        control = list(
            rel.tol = 0,
            boundary.factor = 3,
            max.boundary.expansions = 2L
        )
    )
    expect_equal(out$selected$lambda.sync[[1L]], 27)
    expect_true(any(out$telemetry$stage == "coarse" &
                    out$telemetry$lambda.sync == 0))
    expect_true(any(out$telemetry$stage == "boundary_expand_right" &
                    out$telemetry$lambda.sync == 27))
})

test_that("PS-LPS guarded lambda search expands near-best right boundary", {
    evaluator <- function(lambda) {
        cv <- c(
            "0" = 9,
            "1" = 2,
            "3" = 1,
            "9" = 1.005,
            "27" = 0.8,
            "81" = 0.7
        )[[as.character(lambda)]]
        data.frame(
            lambda.sync = lambda,
            cv.rmse.observed = cv,
            stringsAsFactors = FALSE
        )
    }
    out <- .ps.lps.search.lambda.sync(
        evaluate = evaluator,
        lambda.grid = c(0, 1, 3, 9),
        control = list(
            rel.tol = 0,
            boundary.guard.rel.tol = 0.01,
            boundary.factor = 3,
            max.boundary.expansions = 2L
        )
    )
    expect_equal(out$selected$lambda.sync[[1L]], 81)
    expect_equal(
        out$telemetry$lambda.sync[
            out$telemetry$stage == "boundary_expand_right"
        ],
        c(27, 81)
    )
})

test_that("PS-LPS guarded lambda search expands left positive boundary", {
    evaluator <- function(lambda) {
        data.frame(
            lambda.sync = lambda,
            cv.rmse.observed = (log10(lambda) - log10(1))^2,
            stringsAsFactors = FALSE
        )
    }
    out <- .ps.lps.search.lambda.sync(
        evaluate = evaluator,
        lambda.grid = c(0, 9, 27, 81),
        control = list(
            rel.tol = 0,
            boundary.factor = 3,
            max.boundary.expansions = 2L
        )
    )
    expect_equal(out$selected$lambda.sync[[1L]], 1)
    expect_true(any(out$telemetry$stage == "boundary_expand_left" &
                    out$telemetry$lambda.sync == 1))
})

test_that("PS-LPS guarded lambda search keeps zero as diagnostic", {
    evaluator <- function(lambda) {
        data.frame(
            lambda.sync = lambda,
            cv.rmse.observed = if (lambda == 0) 10 else (log10(lambda) + 1)^2,
            stringsAsFactors = FALSE
        )
    }
    out <- .ps.lps.search.lambda.sync(
        evaluate = evaluator,
        lambda.grid = c(0, 0.1, 1, 10),
        control = list(rel.tol = 0, boundary.factor = 10)
    )
    expect_equal(out$selected$lambda.sync[[1L]], 0.1)
    expect_true(0 %in% out$evaluated$lambda.sync)
})

test_that("PS-LPS guarded lambda search enforces max.candidates globally", {
    evaluator <- function(lambda) {
        data.frame(
            lambda.sync = lambda,
            cv.rmse.observed = (log10(lambda) - 1)^2,
            stringsAsFactors = FALSE
        )
    }
    out <- .ps.lps.search.lambda.sync(
        evaluate = evaluator,
        lambda.grid = c(1, 3, 10, 30, 100, 300),
        control = list(max.candidates = 2L, rel.tol = 0)
    )
    expect_lte(nrow(out$evaluated), 2L)
    expect_lte(length(unique(out$telemetry$lambda.sync)), 2L)
})

test_that("fit.ps.lps guarded lambda search returns telemetry", {
    set.seed(23)
    X <- matrix(runif(120), ncol = 3)
    y <- sin(2 * X[, 1]) + X[, 2]^2
    ps <- fit.ps.lps(
        X = X,
        y = y,
        foldid = rep(seq_len(5L), length.out = length(y)),
        support.size = 15L,
        degree = 2L,
        kernel = "gaussian",
        chart.dim = 2L,
        lambda.sync.grid = c(0, 0.1, 1, 10),
        lambda.sync.search = "guarded",
        lambda.sync.search.control = list(rel.tol = 0),
        lambda.ridge = 1e-8,
        sync.neighbor.size = 3L
    )
    expect_equal(ps$lambda.sync.search, "guarded")
    expect_true(nrow(ps$cv.table) <= 6L)
    expect_true(ps$selected$lambda.sync[[1L]] %in% ps$cv.table$lambda.sync)
    expect_true(all(c("stage", "lambda.sync", "boundary", "expansion",
                      "selected.after.stage") %in%
                    names(ps$lambda.sync.search.telemetry)))
})
