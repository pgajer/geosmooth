test_that("perform.harmonic.smoothing returns native smoothing diagnostics", {
    adj.list <- list(2L, c(1L, 3L), c(2L, 4L), 3L)
    weight.list <- list(1, c(1, 1), c(1, 1), 1)
    values <- c(0, 10, -10, 1)

    out <- suppressWarnings(perform.harmonic.smoothing(
        adj.list = adj.list,
        weight.list = weight.list,
        values = values,
        region.vertices = 1:3,
        max.iterations = 10,
        tolerance = 1e-10
    ))

    expect_named(out, c(
        "harmonic_predictions", "converged", "num_region", "num_boundary",
        "num_interior", "num_iterations", "max_change", "max_residual"
    ))
    expect_length(out$harmonic_predictions, length(values))
    expect_equal(out$num_region, 3L)
    expect_equal(out$num_iterations, 10L)
})
