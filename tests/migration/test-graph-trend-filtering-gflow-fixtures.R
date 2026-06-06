load_ssrhe_all_labeled_validation_definitions <- function() {
    runner <- paste0(
        "/Users/pgajer/current_projects/trend_filtering/development/",
        "ssrhe_hessian_energy/ssrhe_all_labeled_comparator_validation.R"
    )
    testthat::skip_if_not(
        file.exists(runner),
        "SSRHE all-labeled validation runner is not available."
    )
    testthat::skip_if_not_installed("pkgload")
    testthat::skip_if_not_installed("dgraphs")
    env <- new.env(parent = globalenv())
    exprs <- parse(runner, keep.source = FALSE)
    for (expr in exprs) {
        txt <- paste(deparse(expr), collapse = "\n")
        if (grepl("^manifest <- build\\.dataset\\.manifest", txt)) break
        if (grepl("pkgload::load_all\\(gflow.dir", txt, fixed = FALSE)) next
        eval(expr, envir = env)
    }
    env$create.rknn.graph <- dgraphs::create.rknn.graph
    env$quadform.embed <- gflow::quadform.embed
    env$quadform.edge.lengths <- gflow::quadform.edge.lengths
    env
}

fit_ssrhe_graph_trend_filtering_case <- function(dataset.id, order, variant) {
    testthat::skip_if_not_installed("gflow")
    env <- load_ssrhe_all_labeled_validation_definitions()
    manifest <- env$build.dataset.manifest()
    row <- manifest[manifest$dataset.id == dataset.id, , drop = FALSE]
    testthat::expect_equal(nrow(row), 1L)
    ds <- env$materialize.dataset(row)
    graph.info <- env$make.graph.payload(ds)
    weights <- if (identical(variant, "unit")) {
        graph.info$metric.weight.list
    } else {
        graph.info$conductance.weight.list
    }
    fit.graph.trend.filtering(
        adj.list = graph.info$metric.adj.list,
        weight.list = weights,
        y = ds$y,
        order = order,
        lambda.selection = "cv",
        weight.rule = variant,
        n.lambda = 20L,
        nfolds = 4L,
        maxsteps = 500L
    )
}

testthat::test_that("SSRHE affected graph trend-filtering migration cases run", {
    testthat::skip_if_not_installed("genlasso")
    testthat::skip_if_not_installed("Matrix")
    testthat::skip_if_not_installed("gflow")

    cases <- list(
        list(
            dataset.id = "flat_d2_rep1",
            order = 0L,
            variant = "sqrt.conductance"
        ),
        list(
            dataset.id = "quadform_d2_idx1_curv035_rep1",
            order = 2L,
            variant = "conductance"
        )
    )

    for (case in cases) {
        fit <- fit_ssrhe_graph_trend_filtering_case(
            dataset.id = case$dataset.id,
            order = case$order,
            variant = case$variant
        )
        testthat::expect_s3_class(fit, "graph.trend.filtering.fit")
        testthat::expect_true(all(is.finite(fit$fitted.values)))
        testthat::expect_true(is.finite(fit$lambda))
        testthat::expect_equal(length(fit$fitted.values), fit$graph$n.vertices)
    }
})
