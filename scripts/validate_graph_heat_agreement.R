#!/usr/bin/env Rscript
# From the package root, after an optimized native build:
# Rscript scripts/validate_graph_heat_agreement.R /path/to/new/output-directory
# No fits are tuned and no reference inputs are downloaded.
args <- commandArgs(trailingOnly = TRUE)
if (length(args) != 1L) stop("Supply one new output directory.", call. = FALSE)
out <- args[[1L]]
if (dir.exists(out) || file.exists(out)) stop("Output already exists; use a new directory.", call. = FALSE)
if (!file.exists("R/metric_graph_verified_heat.R")) stop("Run from the geosmooth source root.")
pkgload::load_all(".", recompile = FALSE, quiet = TRUE)

# Full-precision, frozen version of the original nine-vertex failure.
w <- c(1.5688437015051022, 1.1511129526188597, 1.6180565424729139,
       1.3063838336383924, 1e-8, 1.0687164461705834,
       1.0344469987321645, 1.3884741966612637)
n <- length(w) + 1L
adj <- lapply(seq_len(n), function(j) as.integer(c(j-1L,j+1L)[c(j>1L,j<n)]))
times <- 10^seq(-3,4,length.out=12)
O <- c(1L,n); U <- setdiff(seq_len(n),O)
y <- rep(NA_real_,n); y[O] <- c(0,1)
centered <- y[O] - mean(y[O])
rows <- list()
for (factor in c(1,.1,10,1e-4,1e4)) {
    weights <- lapply(seq_len(n), function(j) factor*w[pmin(j,adj[[j]])])
    b <- metric.graph.lowpass.basis(adj,weights,weight.type="conductance",
                                   spectrum="full",numerical.policy="verified.fallback")
    grid <- times/factor
    current <- apply.metric.graph.lowpass.path(b,y,grid)
    V <- b$spectral$eigenvectors
    for (j in seq_along(grid)) {
        a <- -expm1(-grid[j]*b$spectral$eigenvalues)
        a <- a/max(a)
        A <- tcrossprod(sweep(V,2L,a,`*`),V)
        A <- (A+t(A))/2
        B <- A[U,U,drop=FALSE]; C <- A[U,O,drop=FALSE]
        ch <- chol(B)
        X <- backsolve(ch,forwardsolve(t(ch),C))
        removed <- crossprod(C,X)
        # Reconstruct the pre-fix subtraction from the same spectrum and solve.
        old <- A[O,O,drop=FALSE]-removed
        old <- (old+t(old))/2
        old.score <- length(O)*sum((old%*%centered/sum(diag(old)))^2)
        F <- sweep(t(V),1L,sqrt(a),`*`)
        K <- crossprod(F[,O,drop=FALSE]-F[,U,drop=FALSE]%*%X)
        d <- current$numerical$diagnostics[j,,drop=FALSE]
        rows[[length(rows)+1L]] <- data.frame(
            conductance.factor=factor, eta=grid[j],
            subtractand.max=max(abs(A[O,O,drop=FALSE]),abs(removed)),
            old.trace=sum(diag(old)), energy.trace=sum(diag(K)),
            old.nullspace.error=max(abs(rowSums(old))),
            energy.nullspace.error=max(abs(rowSums(K))),
            analytic.gcv=1, old.gcv=old.score,
            current.gcv=current$gcv.scores[j],
            reference.gcv=current$numerical$reference.gcv.scores[j,1],
            standardized.agreement.error=d$gcv.scaled.error,
            final.agreement.error=d$gcv.final.scaled.error)
    }
    stopifnot(identical(current$tuning[[1L]]$status,"unresolved_flat_gcv"),
              !current$tuning[[1L]]$selection.allowed)
}
result <- do.call(rbind,rows)
stopifnot(all(is.finite(as.matrix(result))),
          max(abs(result$current.gcv-1)) < 1e-11,
          all(result$standardized.agreement.error <= 1),
          all(result$final.agreement.error <= 1))
dir.create(out,recursive=TRUE)
# Preserve roundoff-scale differences; write.csv's default numeric formatting
# can round a score such as 1 - 4e-16 back to exactly one.
precise <- as.data.frame(lapply(result,function(x) sprintf("%.17g",x)))
write.table(precise,file.path(out,"comparison.csv"),sep=",",quote=FALSE,row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(out,"session.txt"))
writeLines(c(
    "Current native source loaded with pkgload::load_all(recompile=FALSE).",
    paste("Source root:",normalizePath(".")),
    paste("Git revision:",paste(system2("git",c("rev-parse","HEAD"),stdout=TRUE),collapse=" ")),
    "The old formula is reconstructed from the same current spectrum and solve.",
    "No assertion that all hypothetical inputs must pass agreement is made."
),file.path(out,"provenance.txt"))
cat("All",nrow(result),"fixed-time comparisons passed.\n")
cat("Maximum old analytic GCV error:",format(max(abs(result$old.gcv-1)),digits=12),"\n")
cat("Maximum current analytic GCV error:",format(max(abs(result$current.gcv-1)),digits=12),"\n")
cat("Maximum standardized agreement-budget fraction:",
    format(max(result$standardized.agreement.error),digits=12),"\n")
