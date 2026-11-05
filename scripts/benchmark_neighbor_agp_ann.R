#!/usr/bin/env Rscript
# Bounded query timing only: no all-cohort predictions or outcome tuning.
Sys.setenv(OMP_NUM_THREADS="1", OMP_THREAD_LIMIT="1", OPENBLAS_NUM_THREADS="1",
           MKL_NUM_THREADS="1", VECLIB_MAXIMUM_THREADS="1", MAKEFLAGS="-j1")
args <- commandArgs(TRUE)
if (length(args)!=2L) stop("Usage: Rscript benchmark_neighbor_agp_ann.R FROZEN OUTPUT")
frozen <- normalizePath(args[1]); out <- normalizePath(args[2]); root <- normalizePath(".")
if (file.exists(file.path(out,"timings.tsv"))) stop("Choose a fresh output directory.")
pkgload::load_all(file.path(dirname(root),"dgraphs"), recompile=FALSE, quiet=TRUE)
pkgload::load_all(root,recompile=FALSE,quiet=TRUE)
cohort <- readRDS(file.path(frozen,"cohort.rds"))
labels <- read.delim(file.path(out,"labels.tsv"),stringsAsFactors=FALSE,check.names=FALSE)
ix <- match(cohort$sample.ids,labels$sample)
stopifnot(!anyNA(ix),nrow(cohort$counts)==24421,ncol(cohort$counts)==340)
labels <- labels[ix,]; keep <- nzchar(labels$group)
X <- cohort$counts[keep,,drop=FALSE]; labels <- labels[keep,]; rm(cohort);gc()
stopifnot(nrow(X)==24411,length(unique(labels$group))==21323)
# Freeze outcome-blind query representatives, then select 128 distinct people.
rank <- vapply(labels$sample,function(s) digest::digest(paste0("agp-ann-pilot-v1|",s),
                                                       algo="sha256",serialize=FALSE),"")
ord <- order(rank,labels$sample); q <- ord[!duplicated(labels$group[ord])][1:128]
stopifnot(length(q)==128,!anyDuplicated(labels$group[q]))
write.table(labels[q,c("sample","group")],file.path(out,"queries.tsv"),sep="\t",quote=FALSE,row.names=FALSE)
source.files <- c("R/neighbor_probability.R","src/neighbor_probability.cpp","src/ANN/kd_search.cpp",
                  "scripts/benchmark_neighbor_agp_ann.R","scripts/prepare_neighbor_agp_timing.py")
plan <- list(scope="128 fixed queries only; no full AGP fits or tuning",queries=128L,
    reference.records=nrow(X),reference.participants=length(unique(labels$group)),features=ncol(X),
    excluded.unlinked.records=10L,query.rule="first unique participant in SHA256 agp-ann-pilot-v1|sample order",
    k=3:20,normalizations=c("sum","max"),outcomes=c("seasonal_allergies","ibd"),
    methods=c("knn","case_raw","case_corrected"),search=list(brute=0,ann=c(0,.1,.5)),repeats=3L,
    compute.threads=1L,authorized.thread.ceiling=4L,memory.ceiling.GiB=10,
    source.path=root,load.mode="source_optimized",build="pkgbuild::compile_dll(debug=FALSE)",
    revision=system2("git",c("rev-parse","HEAD"),stdout=TRUE),
    source.sha256=setNames(lapply(source.files,function(p)digest::digest(file=p,algo="sha256")),source.files),
    date=as.character(Sys.time()),session=capture.output(sessionInfo()))
jsonlite::write_json(plan,file.path(out,"plan.json"),pretty=TRUE,auto_unbox=TRUE)
options <- data.frame(search=c("brute","ann","ann","ann"),eps=c(0,0,.1,.5))
results <- list(); errors <- list(); saved <- list(); i <- 0L
set.seed(20261105)
for (norm in plan$normalizations) for (outcome in plan$outcomes) for (method in plan$methods) {
    key <- paste(norm,outcome,method,sep="/"); first <- list()
    for (repeat.id in 1:3) for (j in sample(1:4)) {
        gc()
        start <- proc.time()[["elapsed"]]
        fit <- fit.neighbor.probability(X,labels[[outcome]],method=method,k=3,
            id=labels$sample,group=labels$group,normalization=norm,
            search=options$search[j],eps=options$eps[j])
        prepare <- proc.time()[["elapsed"]]-start
        start <- proc.time()[["elapsed"]]
        pred <- predict(fit,X[q,,drop=FALSE],query.group=labels$group[q],k=3:20)
        elapsed <- proc.time()[["elapsed"]]-start
        i <- i+1L
        results[[i]] <- data.frame(normalization=norm,outcome=outcome,method=method,
            search=options$search[j],eps=options$eps[j],repeat.id=repeat.id,
            prepare.seconds=prepare,predict.seconds=elapsed)
        if (repeat.id==1L) first[[as.character(j)]] <- pred
        else stopifnot(identical(first[[as.character(j)]],pred))
        cat(key, options$search[j],options$eps[j],repeat.id,round(elapsed,3),"s\n");flush.console()
        rm(fit,pred)
    }
    stopifnot(identical(first[["1"]],first[["2"]]))
    for (j in 2:4) {
        delta <- abs(first[[as.character(j)]]-first[["1"]])
        errors[[length(errors)+1L]] <- data.frame(normalization=norm,outcome=outcome,method=method,
            eps=options$eps[j],probabilities=length(delta),max.absolute.error=max(delta),
            mean.absolute.error=mean(delta),changed.fraction=mean(delta>0))
    }
    saved[[key]] <- first
    write.table(do.call(rbind,results),file.path(out,"timings.partial.tsv"),sep="\t",quote=FALSE,row.names=FALSE)
    saveRDS(saved,file.path(out,"predictions.partial.rds"))
}
write.table(do.call(rbind,results),file.path(out,"timings.tsv"),sep="\t",quote=FALSE,row.names=FALSE)
write.table(do.call(rbind,errors),file.path(out,"errors.tsv"),sep="\t",quote=FALSE,row.names=FALSE)
saveRDS(saved,file.path(out,"predictions.rds"))
cat("Completed bounded timing; exact ANN probabilities equal brute force in every cell.\n")
