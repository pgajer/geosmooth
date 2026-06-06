geosmooth.test.package.root <- function() {
    root <- normalizePath(getwd(), mustWork = TRUE)
    while (!file.exists(file.path(root, "DESCRIPTION"))) {
        parent <- dirname(root)
        if (identical(parent, root)) {
            stop("Could not find package root")
        }
        root <- parent
    }
    root
}

test_that("native symbols use the geosmooth package prefix", {
    root <- geosmooth.test.package.root()
    rcpp <- readLines(file.path(root, "src", "RcppExports.cpp"), warn = FALSE)
    namespace <- readLines(file.path(root, "NAMESPACE"), warn = FALSE)
    omp.compat <- readLines(file.path(root, "src", "omp_compat.h"), warn = FALSE)
    metric.lowpass <- readLines(
        file.path(root, "src", "metric_graph_lowpass.cpp"),
        warn = FALSE
    )

    expect_true(any(grepl("_geosmooth_", rcpp)))
    expect_false(any(grepl("_gflow_", rcpp)))
    expect_false(any(grepl("_gflow_", namespace)))
    expect_true(any(grepl("geosmooth_get_max_threads", omp.compat)))
    expect_true(any(grepl("geosmooth_get_max_threads", metric.lowpass)))
    expect_false(any(grepl("gflow_", omp.compat)))
    expect_false(any(grepl("gflow_", metric.lowpass)))
})

test_that("dgraphs exports the shortest-path contract required by geosmooth", {
    expect_true("shortest.path" %in% getNamespaceExports("dgraphs"))
})
