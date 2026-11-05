#!/usr/bin/env Rscript
# Run from this package root. Uses synthetic tests only, never AGP or sPTB data.
Sys.setenv(OMP_NUM_THREADS = "1", OMP_THREAD_LIMIT = "1",
           OPENBLAS_NUM_THREADS = "1", MKL_NUM_THREADS = "1",
           VECLIB_MAXIMUM_THREADS = "1", MAKEFLAGS = "-j1")
root <- normalizePath(".")
stopifnot(file.exists(file.path(root, "src", "neighbor_probability.cpp")))
dependency <- file.path(dirname(root), "dgraphs")
if (!dir.exists(dependency)) stop("Local authoritative dgraphs source is required.")
# LinkingTo must use the authoritative dgraphs header, not an older installation.
lib <- file.path(root, "tmp", "neighbor-validation", "library")
dir.create(lib, recursive = TRUE, showWarnings = FALSE)
.libPaths(c(lib, .libPaths()))
Sys.setenv(R_LIBS = paste(.libPaths(), collapse = .Platform$path.sep))
header <- "include/dgraphs/linf_simplex_distance.hpp"
installed.header <- system.file(header, package = "dgraphs", lib.loc = lib)
source.header <- file.path(dependency, "inst", header)
if (!nzchar(installed.header) ||
    unname(tools::md5sum(installed.header)) != unname(tools::md5sum(source.header))) {
    status <- system2(file.path(R.home("bin"), "R"), c("CMD", "INSTALL", "--no-docs",
        "--no-multiarch", shQuote(paste0("--library=", lib)), shQuote(dependency)))
    if (status != 0L) stop("Installing the local dgraphs build dependency failed.")
}
pkgload::load_all(dependency, recompile = FALSE, quiet = TRUE)
Rcpp::compileAttributes(root)
pkgbuild::compile_dll(root, debug = FALSE, force = identical(Sys.getenv("NEIGHBOR_FORCE_BUILD"), "true"), quiet = FALSE)
roxygen2::roxygenise(root, load = function(path) {
    pkgload::load_all(path, recompile = FALSE, quiet = TRUE)
    asNamespace("geosmooth")
})
pkgload::load_all(root, recompile = FALSE, quiet = TRUE)
source("tests/testthat/helper-source-tree.R")
summaries <- list()
for (file in c("test-neighbor-probability.R",
               "test-neighbor-documentation.R",
               "test-neighbor-ann.R",
               "test-neighbor-intrinsic.R",
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
