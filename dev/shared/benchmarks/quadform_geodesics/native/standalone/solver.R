# Compatibility helper for development scripts; never compiles a second solver.
qgn.load <- function(home = NULL) {
  if (!requireNamespace("geosmooth", quietly = TRUE) ||
      !exists("quadform_geodesics_solver", envir = asNamespace("geosmooth"), inherits = FALSE))
    stop("Install the current geosmooth development package before running these checks")
  list(solve = getFromNamespace("quadform_geodesics_solver", "geosmooth"),
    test_uniforms = getFromNamespace("rcpp_quadform_geodesics_reference_uniforms", "geosmooth"))
}
