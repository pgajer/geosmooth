version <- read.dcf("DESCRIPTION")[1L, "Version"]
tarball <- paste0("geosmooth_", version, ".tar.gz")
if (!file.exists(tarball)) stop("Run make build first.")
staging <- tempfile("geosmooth-previews-")
dir.create(staging)
tryCatch({
    names <- paste0(c("function-guide", "synthetic-datasets"), ".html")
    files <- file.path("geosmooth", "inst", "doc", names)
    utils::untar(tarball, files = files, exdir = staging)
    for (destination in c("validation/vignettes", "validation/api-guide")) {
        dir.create(destination, recursive = TRUE, showWarnings = FALSE)
        stopifnot(all(file.copy(file.path(staging, files), destination, overwrite = TRUE)))
    }
}, finally = unlink(staging, recursive = TRUE))
cat("Refreshed both preview aliases from the built package vignettes.\n")
