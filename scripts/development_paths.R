# Locations for optional development datasets and external research outputs.
# This helper is not loaded by the installed package.
geosmooth_dev_path <- function(location, ...) {
    script <- grep("^--file=", commandArgs(FALSE), value = TRUE)
    default.root <- if (length(script)) {
        file.path(dirname(sub("^--file=", "", script[[1L]])), "..")
    } else {
        "."
    }
    repo <- normalizePath(Sys.getenv("GEOSMOOTH_SOURCE", default.root),
                          mustWork = TRUE)
    description <- file.path(repo, "DESCRIPTION")
    if (!file.exists(description) ||
        read.dcf(description, fields = "Package")[[1L]] != "geosmooth") {
        stop("Set GEOSMOOTH_SOURCE to the geosmooth source directory.", call. = FALSE)
    }
    base <- switch(location,
        repo = repo,
        output = Sys.getenv("GEOSMOOTH_RESEARCH_OUTPUT_DIR",
            file.path(path.expand("~"), ".codex", "private", "geosmooth", "development")),
        trend_filtering = Sys.getenv("TREND_FILTERING_SOURCE",
            file.path(dirname(repo), "trend_filtering")),
        dgraphs = Sys.getenv("DGRAPHS_SOURCE", file.path(dirname(repo), "dgraphs")),
        linf = Sys.getenv("LINF_SOURCE", file.path(dirname(repo), "linf")),
        valencia = Sys.getenv("VALENCIA_DATA_DIR", file.path(dirname(repo), "valencia")),
        stop("Unknown development location: ", location, call. = FALSE)
    )
    if (!nzchar(base)) stop("Development location must not be empty.", call. = FALSE)
    base <- path.expand(base)
    if (!grepl("^/|^[A-Za-z]:[/\\\\]", base)) base <- file.path(getwd(), base)
    base <- normalizePath(base, mustWork = FALSE)
    if (location == "output" &&
        (base == repo || startsWith(base, paste0(repo, "/")))) {
        stop("Research outputs must be outside the package checkout.", call. = FALSE)
    }
    file.path(base, ...)
}
