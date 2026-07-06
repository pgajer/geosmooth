make.state.density.path.graph <- function(lengths) {
    n <- length(lengths) + 1L
    adj <- vector("list", n)
    wt <- vector("list", n)
    for (i in seq_along(lengths)) {
        j <- i + 1L
        ell <- as.double(lengths[[i]])
        adj[[i]] <- c(adj[[i]], j)
        wt[[i]] <- c(wt[[i]], ell)
        adj[[j]] <- c(adj[[j]], i)
        wt[[j]] <- c(wt[[j]], ell)
    }
    list(
        adj.list = lapply(adj, as.integer),
        weight.list = lapply(wt, as.double)
    )
}

test_that("OD1 graph random walk preserves mass and handles zero and one step", {
    X <- matrix(seq(0, 1, length.out = 4), ncol = 1L)
    graph <- make.state.density.path.graph(c(1, 1, 1))
    weights <- c(1, 0, 0, 0)

    zero <- fit.density.graph.random.walk(
        X = X,
        weights = weights,
        graph = graph,
        graph.control = list(walk.steps = 0L)
    )
    expect_identical(zero$status, "ok")
    expect_equal(zero$rho, weights, tolerance = 1e-12)
    expect_equal(zero$accounting$mass, 1, tolerance = 1e-12)

    one <- fit.density.graph.random.walk(
        X = X,
        weights = weights,
        graph = graph,
        graph.control = list(walk.step = 1L)
    )
    expect_identical(one$status, "ok")
    expect_equal(one$rho, c(0, 1, 0, 0), tolerance = 1e-12)
    expect_equal(sum(one$rho), 1, tolerance = 1e-12)
    expect_equal(
        max(abs(Matrix::rowSums(one$diagnostics$transition) - 1)),
        0,
        tolerance = 1e-12
    )
})

test_that("OD1 graph random walk matches the community-typing prototype helper", {
    ref.file <- file.path(
        "/Users/pgajer/current_projects/vaginal_community_trajectory_types",
        "R", "occupation_measures.R"
    )
    skip_if_not(file.exists(ref.file))

    ref.env <- new.env(parent = globalenv())
    sys.source(ref.file, envir = ref.env)

    X <- cbind(seq(0, 1, length.out = 5), 0)
    graph <- make.state.density.path.graph(c(1, 2, 1, 3))
    graph.ref <- list(
        adj_list = graph$adj.list,
        weight_list = graph$weight.list,
        n_vertices = nrow(X)
    )
    weights <- c(2, 0, 1, 0, 1)

    transition.ref <- ref.env$build_graph_transition_matrix(
        graph.ref,
        affinity_method = "exp_neg_length_over_median"
    )
    empirical.ref <- Matrix::Matrix(weights / sum(weights),
                                    nrow = 1L,
                                    sparse = TRUE)
    occupation.ref <- ref.env$propagate_occupation_measures(
        empirical.ref,
        transition.ref$transition,
        walk_steps = c(0L, 2L)
    )

    fit <- fit.density.graph.random.walk(
        X = X,
        weights = weights,
        graph = graph.ref,
        graph.control = list(
            walk.steps = c(0L, 2L),
            affinity.method = "exp_neg_length_over_median"
        )
    )

    expect_identical(fit$status, "ok")
    expect_equal(fit$rho, as.numeric(as.matrix(occupation.ref[["r02"]])),
                 tolerance = 1e-12)
    expect_equal(fit$diagnostics$transition,
                 transition.ref$transition,
                 tolerance = 1e-12)
})

test_that("OD1 metric graph low-pass becomes a density through normalize.density", {
    X <- cbind(seq(0, 1, length.out = 5), 0)
    graph <- make.state.density.path.graph(c(1, 1, 1, 1))
    weights <- c(1, 0, 2, 0, 1)

    lowpass <- fit.metric.graph.lowpass(
        adj.list = graph$adj.list,
        weight.list = graph$weight.list,
        y = weights,
        conductance.rule = "inverse.length.power",
        n.eigenpairs = 5L,
        eigen.solver = "dense",
        filter.type = "heat_kernel",
        eta.grid = 0.5
    )
    density <- normalize.density(lowpass, X = X, keep.source.fit = FALSE)

    expect_identical(density$status, "ok")
    expect_s3_class(density, "density_fit")
    expect_true(all(is.finite(density$rho)))
    expect_true(all(density$rho >= -1e-12))
    expect_equal(sum(density$rho), 1, tolerance = 1e-12)
    expect_identical(density$method.id, "normalized_metric_graph_lowpass")
    expect_identical(density$diagnostics$source.class,
                     "metric.graph.lowpass.fit")
})

test_that("OD1 graph methods validate graph inputs", {
    X <- matrix(seq(0, 1, length.out = 3), ncol = 1L)
    weights <- c(1, 0, 1)
    bad <- list(adj.list = list(2L, integer(), 2L),
                weight.list = list(1, numeric(), 1))

    expect_error(
        fit.density.graph.random.walk(X, weights, graph = bad),
        "no isolated vertices"
    )

    zero.length <- make.state.density.path.graph(c(0, 1))
    expect_silent(
        fit.density.graph.random.walk(X, weights, graph = zero.length)
    )
    graph.with.isolate <- list(adj.list = list(2L, integer(), integer()),
                               weight.list = list(1, numeric(), numeric()))
    expect_error(
        fit.density.graph.random.walk(X, weights, graph = graph.with.isolate),
        "no isolated vertices"
    )
})
