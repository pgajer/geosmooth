test_that("GE5 coordinate and fixed-k paths are package-local geosmooth paths", {
    skip_if_not_installed("Matrix")

    X <- cbind(seq(0, 1, length.out = 18),
               seq(0, 1, length.out = 18)^2)
    y <- sin(2 * pi * X[, 1]) + 0.1 * X[, 2]

    malps.fit <- fit.malps(
        X = X,
        y = y,
        degree = 1L,
        support.type = "knn",
        support.size = 7L,
        support.metric = "coordinates",
        support.selection = "fixed",
        coordinate.method = "local.pca",
        chart.dim = 1L
    )
    expect_s3_class(malps.fit, "malps")
    expect_equal(malps.fit$support.metric, "coordinates")

    lpl.op <- lpl.tf.operator(
        X = X,
        degree = 1L,
        support.type = "knn",
        support.size = 7L,
        support.metric = "coordinates",
        coordinate.method = "local.pca",
        chart.dim = 1L
    )
    expect_s3_class(lpl.op, "lpl_tf_operator")
    expect_equal(lpl.op$settings$support.metric, "coordinates")

    ssrhe.op <- ssrhe.hessian.operator(
        X = X,
        k = 9L,
        tangent.dim = 1L,
        neighborhood.type = "knn",
        return.BS = FALSE,
        return.local.diagnostics = FALSE
    )
    expect_s3_class(ssrhe.op, "ssrhe.hessian.operator")
    expect_equal(ssrhe.op$parameters$neighborhood.type, "knn")
})

test_that("GE5 gflow bridge gives explicit graph-boundary errors", {
    skip_if_not_installed("gflow")

    expect_error(
        .geosmooth.gflow.bridge(
            "__definitely_not_a_gflow_helper__",
            feature = "graph boundary test"
        ),
        "Required gflow helper '__definitely_not_a_gflow_helper__'"
    )
})

test_that("GE5 adaptive-radius support construction is deliberately bridged", {
    skip_if_not_installed("Matrix")
    skip_if_not_installed("gflow")

    create.graph <- .geosmooth.gflow.bridge(
        "create.rknn.graph",
        feature = "adaptive-radius SSRHE support construction"
    )
    expect_true(is.function(create.graph))

    X <- cbind(seq(0, 1, length.out = 20),
               0.1 * sin(seq(0, 2 * pi, length.out = 20)))
    op <- ssrhe.hessian.operator(
        X = X,
        tangent.dim = 1L,
        neighborhood.type = "adaptive.radius",
        adaptive.k.scale = 2L,
        min.support = 5L,
        max.support = 7L,
        return.BS = FALSE,
        return.local.diagnostics = FALSE
    )

    expect_s3_class(op, "ssrhe.hessian.operator")
    expect_equal(op$parameters$neighborhood.type, "adaptive.radius")
    expect_equal(op$neighborhoods$adaptive.k.scale, 2L)
    expect_true(all(op$neighborhoods$support.size >= 5L))
})
