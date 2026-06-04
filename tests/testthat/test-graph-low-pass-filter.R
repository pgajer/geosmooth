test_that("graph.low.pass.filter reconstructs selected graph-Fourier modes", {
    evectors <- matrix(
        c(1 / sqrt(2), 1 / sqrt(2), 1 / sqrt(2), -1 / sqrt(2)),
        nrow = 2,
        ncol = 2
    )
    y.gft <- matrix(c(3, 1), nrow = 2, ncol = 1)

    expect_equal(
        graph.low.pass.filter(1, evectors, y.gft),
        as.numeric(evectors %*% y.gft[, 1]),
        tolerance = 1e-12
    )
    expect_equal(
        graph.low.pass.filter(2, evectors, y.gft),
        as.numeric(y.gft[2, 1] * evectors[, 2]),
        tolerance = 1e-12
    )
    expect_error(graph.low.pass.filter(3, evectors, y.gft),
                 "cannot exceed")
})
