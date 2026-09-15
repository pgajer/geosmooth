args <- commandArgs(trailingOnly = TRUE)
library.path <- if (length(args)) args[1L] else "geosmooth.Rcheck"
if (!dir.exists(file.path(library.path, "geosmooth")))
    stop("Run make check first, or supply a library containing the checked package.")
library.path <- normalizePath(library.path)
ns <- loadNamespace("geosmooth", lib.loc = library.path)
exports <- getNamespaceExports(ns)
methods <- getNamespaceInfo(ns, "S3methods")
method.names <- paste(methods[, 1], methods[, 2], sep = ".")
for (topic in c(exports, method.names, "geosmooth", "geosmooth-package", "model-values", "model-summary")) {
    if (!length(utils::help(topic, package = "geosmooth", lib.loc = library.path)))
        stop("Missing installed help: ", topic)
}
index <- utils::vignette(package = "geosmooth", lib.loc = library.path)$results
expected <- c("function-guide", "synthetic-datasets")
stopifnot(all(expected %in% index[, "Item"]))
for (name in expected) {
    path <- file.path(library.path, "geosmooth", "doc", paste0(name, ".html"))
    stopifnot(file.exists(path))
    html <- paste(readLines(path, warn = FALSE), collapse = "\n")
    # Essential figures are embedded in the installed HTML and need no network.
    stopifnot(grepl("data:image/png;base64,", html, fixed = TRUE))
    images <- regmatches(html, gregexpr("<img[^>]+>", html))[[1L]]
    stopifnot(all(grepl('alt="[^"]+"', images)))
}
cat("Installed help resolves for", length(exports), "exports and", nrow(methods),
    "methods; both guides and their labeled figures are available offline.\n")
