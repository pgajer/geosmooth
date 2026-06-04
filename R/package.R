# geosmooth package skeleton.
#
# GE0 intentionally exports no user-facing functions. Public smoother APIs are
# moved in later phases after the native support skeleton is loadable.

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
