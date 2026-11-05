#!/usr/bin/env Rscript
# Validate saved full-data adjusted objectives, without repeating clinical CV.
args <- commandArgs(TRUE)
if (!length(args) %in% 3:4) stop("Usage: Rscript scripts/validate_logistic_trend_filtering_adjusted.R REFERENCE_ROOT NEW_OUTPUT_DIR CHECK_LIBRARY [BACKEND]")
backend <- if (length(args) == 4L) match.arg(args[4], c("dense", "banded")) else "dense"
reference <- normalizePath(args[1], mustWork = TRUE); output <- args[2]
if (dir.exists(output)) stop("Preserve existing validation; use a new directory.")
dir.create(output, recursive = TRUE)
library(geosmooth, lib.loc = args[3])
readjson <- function(path) jsonlite::fromJSON(path, simplifyVector = FALSE)
tasks <- jsonlite::fromJSON(file.path(reference, "tasks.json"))
rows <- list(); inputs <- character()
for (i in seq_len(nrow(tasks))) {
    key <- tasks$key[i]; root <- file.path(reference, "custom", "fits", key)
    old.file <- file.path(root, "fit.json"); old <- readjson(old.file)
    inputs <- c(inputs, old.file)
    if (old$status == "complete") {
        dfile <- file.path(root, "observations.csv")
        d <- read.csv(dfile); design <- old$full_design
        f <- old$full_fits[[old$chosen + 3L]]
    } else {
        dfile <- file.path(reference, "plain", key, "observations.csv")
        descriptive.file <- file.path(root, "descriptive_full.json")
        descriptive <- jsonlite::fromJSON(descriptive.file, simplifyVector = FALSE)
        stopifnot(descriptive$status == "complete")
        inputs <- c(inputs, descriptive.file)
        d <- read.csv(dfile); design <- descriptive$design; f <- descriptive$fit
    }
    inputs <- c(inputs, dfile)
    vec <- function(x) unlist(x, use.names = FALSE)
    age <- (d$match_age - design$age_center)/design$age_scale
    k <- vec(design$age_knots)
    spline <- (pmax(age-k[1], 0)^3 - (k[3]-k[1])/(k[3]-k[2])*pmax(age-k[2], 0)^3 +
                   (k[2]-k[1])/(k[3]-k[2])*pmax(age-k[3], 0)^3)/(k[3]-k[1])^2
    batch <- outer(as.character(d$batch), vec(design$batch_levels), "==") * 1
    raw <- cbind(age, spline, batch)
    z <- sweep(sweep(raw, 2, vec(design$nuisance_mean)), 2, vec(design$nuisance_scale), "/")
    z <- z[, vec(design$nuisance_keep)+1L, drop = FALSE]
    x <- (d$value - design$lo)/design$span; knots <- vec(design$knots)
    H <- cbind(x, x*x)
    for (j in 3:(length(knots)-1)) H <- cbind(H, .5*(x-knots[j-1])*(x-knots[j])*(x>knots[j]))
    H <- sweep(sweep(H, 2, vec(design$fmean)), 2, vec(design$fscale), "/")
    custom.eta <- f$intercept + as.vector(z %*% vec(f$gamma)) +
        as.vector(H[, seq_along(f$beta), drop = FALSE] %*% vec(f$beta))
    lambda <- if (f$kind == "quadratic") Inf else f$lambda_
    fit <- fit.logistic.trend.filtering(d$value, d$y, lambda, covariates = z,
        nuisance.ridge = .16, curve.ridge = .04, warn = FALSE, backend = backend)
    difference <- max(abs(as.numeric(fitted(fit)) - plogis(custom.eta)))
    objective.difference <- (fit$fits[[1]]$objective - f$objective)/nrow(d)
    rows[[i]] <- data.frame(key = key, original.validation.status = old$status,
        n = nrow(d), lambda = lambda, converged = fit$fits[[1]]$converged,
        probability.difference = difference, objective.difference.per.observation = objective.difference,
        agreement = isTRUE(fit$fits[[1]]$converged && difference <= .001 && abs(objective.difference) <= 1e-5),
        stationarity = fit$fits[[1]]$stationarity, complementarity = fit$fits[[1]]$complementarity)
    saveRDS(fit, file.path(output, paste0(key, ".rds")))
    write.csv(do.call(rbind, rows), file.path(output, "comparison.csv"), row.names = FALSE)
    cat(key, ":", fit$fits[[1]]$status, "\n"); flush.console()
}
r <- do.call(rbind, rows)
jsonlite::write_json(list(backend = backend, fits = nrow(r), converged = sum(r$converged), agreement = sum(r$agreement),
    max.probability.difference = max(r$probability.difference),
    max.objective.difference.per.observation = max(abs(r$objective.difference.per.observation)),
    scope = "Saved selected full-data adjusted fits only; original nested-validation failures remain unchanged."),
    file.path(output, "summary.json"), pretty = TRUE, auto_unbox = TRUE, digits = NA)
write.csv(data.frame(file = unique(inputs), sha256 = vapply(unique(inputs), function(p)
    digest::digest(file = p, algo = "sha256"), character(1))), file.path(output, "hashes.csv"), row.names = FALSE)
writeLines(capture.output(sessionInfo()), file.path(output, "sessionInfo.txt"))
stopifnot(nrow(r) == 30L, all(r$agreement))
