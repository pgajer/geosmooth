#' geosmooth package
#'
#' Geometric smoothing and conditional expectation methods split from gflow.
#'
#' @keywords internal
#' @useDynLib geosmooth, .registration = TRUE
#' @importFrom Rcpp evalCpp
#' @importFrom utils head modifyList
"_PACKAGE"

.geosmooth.ge0.status <- function() {
    list(
        package = "geosmooth",
        phase = "GE0",
        native.stub = .Call(S_geosmooth_native_stub),
        vendored.ann = file.exists(system.file("licenses", "ANN-Copyright-Notice.txt",
                                               package = "geosmooth")),
        vendored.eigen = file.exists(system.file("include", "Eigen", "Core",
                                                 package = "geosmooth"))
    )
}
