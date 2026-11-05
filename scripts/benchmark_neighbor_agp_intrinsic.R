#!/usr/bin/env Rscript
# Bounded surface-distance timing and independent rank validation; no AGP fits.
Sys.setenv(OMP_NUM_THREADS="1",OMP_THREAD_LIMIT="1",OPENBLAS_NUM_THREADS="1",
           MKL_NUM_THREADS="1",VECLIB_MAXIMUM_THREADS="1",MAKEFLAGS="-j1")
args <- commandArgs(TRUE)
if(length(args)!=2L) stop("Usage: Rscript benchmark_neighbor_agp_intrinsic.R FROZEN OUTPUT")
root <- normalizePath("."); frozen <- normalizePath(args[1]); out <- normalizePath(args[2])
if(file.exists(file.path(out,"plan.json"))) stop("Choose a new output directory.")
.libPaths(c(file.path(root,"tmp","neighbor-validation","library"),.libPaths()))
dependency <- file.path(dirname(root),"dgraphs")
header <- file.path(dependency,"inst","include","dgraphs","linf_simplex_distance.hpp")
installed <- system.file("include/dgraphs/linf_simplex_distance.hpp",package="dgraphs")
stopifnot(nzchar(installed),identical(unname(tools::md5sum(header)),unname(tools::md5sum(installed))))
pkgload::load_all(dependency,recompile=FALSE,quiet=TRUE)
pkgload::load_all(root,recompile=FALSE,quiet=TRUE)
cohort <- readRDS(file.path(frozen,"cohort.rds"))
labels <- read.delim(file.path(out,"labels.tsv"),stringsAsFactors=FALSE,check.names=FALSE)
ix <- match(cohort$sample.ids,labels$sample)
stopifnot(!anyNA(ix),nrow(cohort$counts)==24421,ncol(cohort$counts)==340)
labels <- labels[ix,]; keep <- nzchar(labels$group)
X <- cohort$counts[keep,,drop=FALSE]; labels <- labels[keep,]; rm(cohort);gc()
stopifnot(nrow(X)==24411,length(unique(labels$group))==21323)
rank <- vapply(labels$sample,function(s) digest::digest(paste0("agp-ann-pilot-v1|",s),
                                                       algo="sha256",serialize=FALSE),"")
ord <- order(rank,labels$sample); q <- ord[!duplicated(labels$group[ord])][1:64]
stopifnot(length(q)==64,!anyDuplicated(labels$group[q]))
write.table(labels[q,c("sample","group")],file.path(out,"queries.tsv"),sep="\t",quote=FALSE,row.names=FALSE)
files <- c("DESCRIPTION","R/neighbor_probability.R","src/neighbor_probability.cpp",
           "scripts/benchmark_neighbor_agp_intrinsic.R","scripts/prepare_neighbor_agp_timing.py")
plan <- list(scope="64 fixed queries only; no full AGP predictions or tuning",queries=64L,
    reference.records=nrow(X),reference.participants=length(unique(labels$group)),features=ncol(X),
    excluded.unlinked.records=10L,query.rule="first 64 unique people in frozen agp-ann-pilot-v1|sample SHA256 order",
    k=3:20,outcomes=c("seasonal_allergies","ibd"),methods=c("knn","case_raw","case_corrected"),
    metric="linf.simplex",normalization="max",search="brute",eps=0,repeats=3L,
    reference="public dgraphs query-to-reference distances, independently ranked in R",
    distance.workspace.rows=1L,reference.distance.rows=64L,
    compute.threads=1L,authorized.thread.ceiling=4L,memory.ceiling.GiB=10,
    source.path=root,load.mode="source_optimized",build="pkgbuild::compile_dll(debug=FALSE,force=TRUE)",
    revision=system2("git",c("rev-parse","HEAD"),stdout=TRUE),
    source.sha256=setNames(lapply(files,function(p)digest::digest(file=p,algo="sha256")),files),
    dgraphs.source=dependency,dgraphs.revision=system2("git",c("-C",dependency,"rev-parse","HEAD"),stdout=TRUE),
    dgraphs.header=header,dgraphs.header.sha256=digest::digest(file=header,algo="sha256"),
    started=format(Sys.time(),tz="America/New_York",usetz=TRUE),session=capture.output(sessionInfo()))
jsonlite::write_json(plan,file.path(out,"plan.json"),pretty=TRUE,auto_unbox=TRUE)
# Only 64 by n_ref, never n_ref by n_ref. The streaming implementation does not use Dq.
cat("Computing exhaustive reference distances for 64 queries.\n");flush.console()
start <- proc.time()[["elapsed"]]
Dq <- dgraphs::linf.simplex.distances(X,sources=q,targets=seq_len(nrow(X)))
reference.seconds <- proc.time()[["elapsed"]]-start
stopifnot(identical(dim(Dq),c(64L,nrow(X))),all(is.finite(Dq)))
saveRDS(Dq,file.path(out,"reference-query-distances.rds"))
jsonlite::write_json(list(elapsed.seconds=reference.seconds,bytes=as.numeric(object.size(Dq))),
                     file.path(out,"reference.json"),pretty=TRUE,auto_unbox=TRUE)
cat("Reference distances ready; beginning estimator checks and timings.\n");flush.console()

# This oracle uses no geosmooth native ranking or prediction helper.
reference <- function(fit, method) {
    nr <- nrow(Dq); sizes <- 3:20; ns <- length(sizes)
    ans <- list(probability=matrix(NA_real_,nr,ns),neighbors=matrix(NA_integer_,nr,ns),
                cases=matrix(NA_integer_,nr,ns),radius=matrix(NA_real_,nr,ns),
                boundary.ties=matrix(NA_integer_,nr,ns),split.tie=matrix(NA,nr,ns),
                available.people=integer(nr),available.cases=integer(nr))
    for(i in seq_len(nr)) {
        train <- which(!is.na(fit$y) & fit$group!=labels$group[q[i]])
        ord <- train[order(Dq[i,train],fit$priority[train])]
        ord <- ord[!duplicated(fit$group[ord])]
        positives <- cumsum(fit$y[ord]); stops <- which(fit$y[ord]==1)
        ans$available.people[i] <- length(ord); ans$available.cases[i] <- length(stops)
        for(z in seq_along(sizes)) {
            k <- sizes[z]
            if((method=="knn" && k>length(ord)) || (method!="knn" && k>length(stops))) next
            t <- if(method=="knn")k else stops[k]
            ans$probability[i,z] <- if(method=="case_corrected")(k-1)/(t-1) else positives[t]/t
            ans$neighbors[i,z] <- t; ans$cases[i,z] <- as.integer(positives[t])
            radius <- Dq[i,ord[t]]; shell <- which(abs(Dq[i,ord]-radius)<=1e-12)
            ans$radius[i,z] <- radius; ans$boundary.ties[i,z] <- length(shell)
            ans$split.tie[i,z] <- any(shell>t)
        }
    }
    ans
}
results <- list(); checks <- list(); predictions <- list(); count <- 0L
cells <- expand.grid(outcome=plan$outcomes,method=plan$methods,stringsAsFactors=FALSE)
set.seed(20261105)
for(repeat.id in 1:3) for(cell in sample(seq_len(nrow(cells)))) {
    outcome <- cells$outcome[cell]; method <- cells$method[cell]; key <- paste(outcome,method,sep="/")
    gc(); start <- proc.time()[["elapsed"]]
    fit <- fit.neighbor.probability(X,labels[[outcome]],method=method,k=3,
        id=labels$sample,group=labels$group,metric="linf.simplex",normalization="max")
    prepare <- proc.time()[["elapsed"]]-start
    start <- proc.time()[["elapsed"]]
    pred <- predict(fit,X[q,,drop=FALSE],query.group=labels$group[q],k=3:20)
    elapsed <- proc.time()[["elapsed"]]-start
    count <- count+1L
    results[[count]] <- data.frame(outcome=outcome,method=method,repeat.id=repeat.id,
        queries=64L,prepare.seconds=prepare,predict.seconds=elapsed)
    if(repeat.id==1L) {
        expected <- reference(fit,method)
        stopifnot(identical(unname(pred),expected$probability))
        diag <- predict(fit,X[q,,drop=FALSE],query.group=labels$group[q],k=3:20,type="diagnostics")
        for(field in setdiff(names(expected),"radius")) stopifnot(identical(unname(diag[[field]]),expected[[field]]))
        radius.error <- max(abs(diag$radius-expected$radius),na.rm=TRUE)
        stopifnot(radius.error<1e-13,diag$boundary.complete,diag$distance.backend=="dgraphs")
        checks[[key]] <- list(probabilities=length(pred),max.absolute.error=max(abs(unname(pred)-expected$probability)),
            max.radius.error=radius.error,integer.diagnostics.identical=TRUE,
            training.responding.records=sum(!is.na(fit$y)),training.positive.records=sum(fit$y==1,na.rm=TRUE))
        predictions[[key]] <- pred
    } else stopifnot(identical(pred,predictions[[key]]))
    cat(outcome,method,repeat.id,round(elapsed,3),"seconds for 64 queries\n");flush.console()
    write.table(do.call(rbind,results),file.path(out,"timings.partial.tsv"),sep="\t",quote=FALSE,row.names=FALSE)
    jsonlite::write_json(checks,file.path(out,"checks.partial.json"),pretty=TRUE,auto_unbox=TRUE)
}
write.table(do.call(rbind,results),file.path(out,"timings.tsv"),sep="\t",quote=FALSE,row.names=FALSE)
jsonlite::write_json(checks,file.path(out,"checks.json"),pretty=TRUE,auto_unbox=TRUE)
saveRDS(predictions,file.path(out,"predictions.rds"))
cat("Completed: all streamed probabilities and integer diagnostics match exhaustive reference.\n")
