#!/usr/bin/env Rscript

# Resolve optional research inputs and keep generated results outside the package.
.dev.script <- sub("^--file=", "", grep("^--file=", commandArgs(FALSE), value = TRUE)[1L])
source(file.path(if (!is.na(.dev.script)) dirname(.dev.script) else "scripts",
                 "development_paths.R"))
# Read-only comparison with frozen, private clinical solver evidence.
# Run after one optimized compilation. No Python or glmgen runtime is needed:
# the original and stricter corrected-glmgen outputs remain independent fixtures.
args <- commandArgs(TRUE)
if (!length(args) %in% 2:3) stop("Usage: Rscript scripts/validate_logistic_trend_filtering.R REFERENCE_ROOT NEW_OUTPUT_DIR [CURRENT_SOURCE_INSTALL_LIBRARY]")
reference <- normalizePath(args[1], mustWork = TRUE)
output <- args[2]
if (dir.exists(output)) stop("Output directory already exists; preserve previous validation.")
dir.create(output, recursive = TRUE)
for (key in c("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "VECLIB_MAXIMUM_THREADS"))
    do.call(Sys.setenv, setNames(list("1"), key))
package <- normalizePath(".")
if (length(args) == 3L) {
    library(geosmooth, lib.loc = args[3])
    load.mode <- "installed_optimized_current_source"
} else {
    pkgload::load_all(geosmooth_dev_path("dgraphs"), recompile = FALSE, quiet = TRUE)
    pkgload::load_all(package, recompile = FALSE, quiet = TRUE)
    load.mode <- "source_optimized"
}
hash <- function(file) digest::digest(file = file, algo = "sha256")
source.files <- file.path(package, c("R/logistic_trend_filtering.R", "src/logistic_trend_filtering.cpp",
    "R/RcppExports.R", "src/RcppExports.cpp", "scripts/validate_logistic_trend_filtering.R"))
initial.source.hashes <- vapply(source.files, hash, character(1))
for (file in source.files) file.copy(file, file.path(output, basename(file)))
dll <- getLoadedDLLs()[["geosmooth"]][["path"]]
file.copy(dll, file.path(output, basename(dll)))
dll.hash <- hash(dll)
readjson <- function(file) jsonlite::fromJSON(file, simplifyVector = FALSE)
inputs <- character(); rows <- list(); failures <- list(); saved <- list()
tasks <- readjson(file.path(reference, "tasks.json"))
lambda <- 10^seq(0, -3, length.out = 7L)
for (task in tasks) {
    key <- task$key; root <- file.path(reference, "plain", key)
    files <- file.path(root, c("observations.csv", "comparison.json", "custom_train.csv",
        "glmgen_fixed_train.csv", "glmgen_fixed_knots.csv", "glmgen_fixed_D.csv",
        "glmgen_fixed_status.csv"))
    stopifnot(all(file.exists(files)))
    inputs <- c(inputs, files)
    d <- read.csv(files[1]); custom <- readjson(files[2])
    cp <- as.matrix(read.csv(files[3])[, -1L])
    fixed <- as.matrix(read.csv(files[4])[, -1L])
    knots <- read.csv(files[5]); D <- as.matrix(read.csv(files[6], header = FALSE))
    stopifnot(nrow(cp) == nrow(d), identical(as.numeric(read.csv(files[3])[, 1L]), d$value))
    fit <- tryCatch(fit.logistic.trend.filtering(d$value, d$y, lambda, warn = FALSE),
        error = function(e) e)
    if (inherits(fit, "error")) {
        failures[[key]] <- conditionMessage(fit); next
    }
    saved[[key]] <- fit
    native <- matrix(predict(fit, type = "response", allow.unconverged = TRUE), nrow(d))
    eta <- matrix(predict(fit, type = "link", allow.unconverged = TRUE), nrow(d))
    index <- match(sort(unique(d$value)), d$value)
    strict.file <- file.path(root, "glmgen_strict_train.csv")
    strict <- NULL
    if (file.exists(strict.file)) {
        strict <- as.matrix(read.csv(strict.file)[, -1L])
        inputs <- c(inputs, strict.file)
    }
    for (j in seq_along(lambda)) {
        custom.obj <- custom$fits[[j]]$objective
        objective <- function(link) sum(pmax(link, 0) - d$y * link + log1p(exp(-abs(link)))) +
            lambda[j] * sum(abs(D %*% link[index]))
        fixed.obj <- objective(fixed[, j]); native.reconstructed <- objective(eta[, j])
        ndiff <- max(abs(native[, j] - cp[, j]))
        gap <- (fit$fits[[j]]$objective - custom.obj)/nrow(d)
        fdiff <- max(abs(native[, j] - plogis(fixed[, j])))
        fgap <- (fit$fits[[j]]$objective - fixed.obj)/nrow(d)
        sd <- if (is.null(strict)) NA_real_ else max(abs(native[, j] - plogis(strict[, j])))
        sg <- if (is.null(strict)) NA_real_ else (fit$fits[[j]]$objective - objective(strict[, j]))/nrow(d)
        old <- custom$comparison[[j]]
        row <- cbind(data.frame(key = key, n = nrow(d), distinct = length(unique(d$value)),
            lambda.index = j, custom.probability.difference = ndiff,
            custom.objective.difference.per.observation = gap,
            custom.agreement = ndiff <= .001 && abs(gap) <= 1e-5 && fit$fits[[j]]$converged,
            corrected.glmgen.probability.difference = fdiff,
            corrected.glmgen.objective.difference.per.observation = fgap,
            corrected.glmgen.agreement = fdiff <= .001 && abs(fgap) <= 1e-5,
            strict.glmgen.probability.difference = sd,
            strict.glmgen.objective.difference.per.observation = sg,
            objective.reconstruction.difference = native.reconstructed-fit$fits[[j]]$objective,
            original.glmgen.agreement = old$concordant), fit$diagnostics[j, ])
        rows[[length(rows)+1L]] <- row
    }
    saveRDS(fit, file.path(output, paste0(key, ".rds")))
    write.csv(do.call(rbind, rows), file.path(output, "comparison.csv"), row.names = FALSE)
    cat(key, ":", sum(fit$diagnostics$converged), "/", length(lambda), "converged\n")
    flush.console()
}
jsonlite::write_json(failures, file.path(output, "failures.json"), pretty = TRUE, auto_unbox = TRUE, digits = NA)
results <- do.call(rbind, rows)
stopifnot(identical(initial.source.hashes, vapply(source.files, hash, character(1))))
write.csv(data.frame(file = c(unique(inputs), source.files, dll),
    sha256 = c(vapply(c(unique(inputs), source.files), hash, character(1)), dll.hash)),
    file.path(output, "hashes.csv"), row.names = FALSE)
writeLines(capture.output(sessionInfo()), file.path(output, "sessionInfo.txt"))
writeLines(system2("git", c("-C", shQuote(package), "rev-parse", "HEAD"), stdout = TRUE), file.path(output, "base_commit.txt"))
writeLines(system2("git", c("-C", shQuote(package), "status", "--short"), stdout = TRUE), file.path(output, "source_status.txt"))
writeLines(system2("git", c("-C", shQuote(package), "diff", "--", "R/logistic_trend_filtering.R", "src/logistic_trend_filtering.cpp"), stdout = TRUE), file.path(output, "tracked_source_diff.patch"))
summary <- list(datasets = length(tasks), fits = nrow(results), failed.datasets = length(failures),
    converged = sum(results$converged), custom.agreement = sum(results$custom.agreement),
    corrected.glmgen.agreement = sum(results$corrected.glmgen.agreement),
    max.custom.probability.difference = max(results$custom.probability.difference),
    max.custom.objective.difference.per.observation = max(abs(results$custom.objective.difference.per.observation)),
    max.stationarity = max(results$stationarity), max.complementarity = max(results$complementarity),
    load.mode = load.mode, threads = 1L,
    scope = "Numerical validation on frozen unadjusted objectives, not a new clinical analysis.")
jsonlite::write_json(summary, file.path(output, "summary.json"), pretty = TRUE, auto_unbox = TRUE, digits = NA)
print(summary)
if (length(failures) || nrow(results) != 210L || !all(results$custom.agreement))
    stop("Validation incomplete or native/custom agreement gate failed; inspect preserved evidence.")
