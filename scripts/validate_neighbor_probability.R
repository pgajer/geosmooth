#!/usr/bin/env Rscript
# Run from this package root. Uses synthetic tests only, never AGP or sPTB data.
Sys.setenv(OMP_NUM_THREADS = "1", OMP_THREAD_LIMIT = "1",
           OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
           VECLIB_MAXIMUM_THREADS = "1", MAKEFLAGS = "-j1")
root <- normalizePath(".")
stopifnot(file.exists(file.path(root, "src", "neighbor_probability.cpp")))
dependency <- file.path(dirname(root), "dgraphs")
if (!dir.exists(dependency)) stop("Local authoritative dgraphs source is required.")
pkgload::load_all(dependency, recompile = FALSE, quiet = TRUE)
Rcpp::compileAttributes(root)
pkgbuild::compile_dll(root, debug = FALSE, force = FALSE, quiet = FALSE)
roxygen2::roxygenise(root, load = function(path) {
    pkgload::load_all(path, recompile = FALSE, quiet = TRUE)
    asNamespace("geosmooth")
})
pkgload::load_all(root, recompile = FALSE, quiet = TRUE)
source("tests/testthat/helper-source-tree.R")
summaries <- list()
for (file in c("test-neighbor-probability.R",
               "test-neighbor-documentation.R",
               "test-geosmooth-native-naming.R")) {
    result <- testthat::test_file(file.path("tests", "testthat", file),
                                 reporter = "summary", stop_on_failure = TRUE)
    summaries[[file]] <- as.data.frame(result)[, c("test", "passed", "failed", "error", "warning")]
}
dir.create("tmp/neighbor-validation", recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(summaries, "tmp/neighbor-validation/test-summary.json",
                     pretty = TRUE, auto_unbox = TRUE)
cat("Validated optimized source at", root, "\n")
print(sessionInfo())
