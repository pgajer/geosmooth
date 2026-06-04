.geosmooth.test.package.root <- function() {
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

.geosmooth.load.gflow.reference <- function() {
    source.path <- Sys.getenv(
        "GEOSMOOTH_GFLOW_SOURCE",
        "/Users/pgajer/current_projects/gflow"
    )
    if (dir.exists(source.path) &&
        file.exists(file.path(source.path, "DESCRIPTION")) &&
        requireNamespace("pkgload", quietly = TRUE)) {
        pkgload::load_all(source.path, quiet = TRUE)
    } else {
        testthat::skip_if_not_installed("gflow")
    }

    needed <- c(
        "kernel.local.polynomial.cv",
        "fit.malps",
        "lpl.tf.operator",
        "slpl.tf.operator"
    )
    missing <- needed[!vapply(
        needed,
        exists,
        logical(1),
        envir = asNamespace("gflow"),
        inherits = FALSE
    )]
    if (length(missing)) {
        testthat::skip(
            paste(
                "gflow reference lacks split-era functions:",
                paste(missing, collapse = ", ")
            )
        )
    }
    invisible(TRUE)
}

.geosmooth.ref <- function(name) {
    get(name, envir = asNamespace("geosmooth"), inherits = FALSE)
}

.gflow.ref <- function(name) {
    get(name, envir = asNamespace("gflow"), inherits = FALSE)
}

.expect.numeric.close <- function(x, y, tol = 1e-10) {
    testthat::expect_equal(as.numeric(x), as.numeric(y), tolerance = tol)
}
