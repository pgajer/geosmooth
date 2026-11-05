#!/usr/bin/env Rscript
# Frozen dense/banded comparison; run after one optimized native compilation.
args <- commandArgs(TRUE)
if (!length(args) %in% 2:3) stop('Usage: Rscript scripts/validate_logistic_trend_filtering_banded.R REFERENCE_ROOT NEW_OUTPUT_DIR [CURRENT_SOURCE_INSTALL_LIBRARY]')
reference <- normalizePath(args[1], mustWork=TRUE); output <- args[2]
if (dir.exists(output)) stop('Preserve existing evidence; choose a new output directory.')
dir.create(output, recursive=TRUE)
Sys.setenv(OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1,VECLIB_MAXIMUM_THREADS=1)
if (length(args)==3L) {
    library(geosmooth,lib.loc=args[3]); mode <- 'installed_optimized_current_source'
} else {
    pkgload::load_all('/Users/pgajer/current_projects/dgraphs',recompile=FALSE,quiet=TRUE)
    pkgload::load_all('.',recompile=FALSE,quiet=TRUE); mode <- 'source_optimized'
}
hash <- function(p) digest::digest(file=p,algo='sha256')
sources <- c('R/logistic_trend_filtering.R','src/logistic_trend_filtering.cpp',
    'src/logistic_trend_filtering_banded.cpp','R/RcppExports.R','src/RcppExports.cpp',
    'scripts/validate_logistic_trend_filtering_banded.R')
source.hashes <- vapply(sources,hash,character(1))
for (p in sources) file.copy(p,file.path(output,basename(p)))
dll <- getLoadedDLLs()[['geosmooth']][['path']]
file.copy(dll,file.path(output,basename(dll)))
tasks <- jsonlite::fromJSON(file.path(reference,'tasks.json'))
lambda <- 10^seq(0,-3,length.out=7)
worker <- function(i) {
    key <- tasks$key[i]; folder <- file.path(output,key);dir.create(folder)
    root <- file.path(reference,'plain',key)
    paths <- file.path(root,c('observations.csv','custom_train.csv','custom_grid.csv',
        'comparison.json','glmgen_fixed_train.csv','glmgen_fixed_D.csv'))
    inputs <- data.frame(file=paths,sha256=vapply(paths,hash,character(1)))
    d <- read.csv(paths[1]);cp <- as.matrix(read.csv(paths[2])[,-1])
    grid <- read.csv(paths[3]);gp <- plogis(as.matrix(read.csv(paths[5])[,-1]))
    D <- as.matrix(read.csv(paths[6],header=FALSE));unique.rows <- match(sort(unique(d$value)),d$value)
    result <- tryCatch({
        dt <- system.time(dense <- fit.logistic.trend.filtering(d$value,d$y,lambda,backend='dense',warn=FALSE))
        bt <- system.time(banded <- fit.logistic.trend.filtering(d$value,d$y,lambda,backend='banded',warn=FALSE))
        saveRDS(dense,file.path(folder,'dense.rds'));saveRDS(banded,file.path(folder,'banded.rds'))
        dp <- matrix(predict(dense,allow.unconverged=TRUE),nrow(d))
        bp <- matrix(predict(banded,allow.unconverged=TRUE),nrow(d))
        be <- matrix(predict(banded,type='link',allow.unconverged=TRUE),nrow(d))
        bg <- matrix(predict(banded,grid[,1],allow.unconverged=TRUE),nrow(grid))
        rows <- lapply(seq_along(lambda),function(j) {
            difference <- max(abs(bp[,j]-dp[,j]));gap <- (banded$fits[[j]]$objective-dense$fits[[j]]$objective)/nrow(d)
            reconstructed <- sum(pmax(be[,j],0)-d$y*be[,j]+log1p(exp(-abs(be[,j]))))+
                lambda[j]*sum(abs(D%*%be[unique.rows,j]))
            data.frame(key=key,n=nrow(d),distinct=length(unique(d$value)),lambda=lambda[j],
                banded.converged=banded$fits[[j]]$converged,dense.converged=dense$fits[[j]]$converged,
                status=banded$fits[[j]]$status,stationarity=banded$fits[[j]]$stationarity,
                complementarity=banded$fits[[j]]$complementarity,
                dense.probability.difference=difference,dense.objective.difference.per.observation=gap,
                custom.probability.difference=max(abs(bp[,j]-cp[,j])),
                custom.grid.probability.difference=max(abs(bg[,j]-grid[,j+1])),
                corrected.glmgen.probability.difference=max(abs(bp[,j]-gp[,j])),
                objective.reconstruction.difference=reconstructed-banded$fits[[j]]$objective,
                active.knots=length(banded$fits[[j]]$active.knots),iterations=banded$fits[[j]]$iterations,
                agreement=banded$fits[[j]]$converged && dense$fits[[j]]$converged && difference<=.001 && abs(gap)<=1e-5)
        })
        tab <- do.call(rbind,rows);write.csv(tab,file.path(folder,'comparison.csv'),row.names=FALSE)
        list(status='complete',key=key,rows=tab,inputs=inputs,dense.seconds=unname(dt['elapsed']),banded.seconds=unname(bt['elapsed']))
    },error=function(e)list(status='failed',key=key,reason=conditionMessage(e),inputs=inputs))
    saveRDS(result,file.path(folder,'result.rds'));result
}
# Each child uses one numerical thread. The user authorized three threads and
# 6 GiB aggregate; these small reference tasks stay below that memory ceiling.
results <- parallel::mclapply(seq_len(nrow(tasks)),worker,mc.cores=3L,mc.preschedule=FALSE)
saveRDS(results,file.path(output,'results.rds'))
complete <- Filter(function(x)is.list(x)&&identical(x$status,'complete'),results)
failed <- Filter(function(x)!is.list(x)||!identical(x$status,'complete'),results)
rows <- do.call(rbind,lapply(complete,'[[','rows'))
write.csv(rows,file.path(output,'comparison.csv'),row.names=FALSE)
inputs <- do.call(rbind,lapply(results,function(z)if(is.list(z))z$inputs else NULL))
write.csv(rbind(inputs,data.frame(file=sources,sha256=source.hashes),data.frame(file=dll,sha256=hash(dll))),
    file.path(output,'hashes.csv'),row.names=FALSE)
writeLines(capture.output(sessionInfo()),file.path(output,'sessionInfo.txt'))
writeLines(system2('git',c('rev-parse','HEAD'),stdout=TRUE),file.path(output,'base_commit.txt'))
stopifnot(identical(source.hashes,vapply(sources,hash,character(1))))
summary <- list(datasets=nrow(tasks),fits=nrow(rows),failed.datasets=length(failed),
    banded.converged=sum(rows$banded.converged),agreement=sum(rows$agreement),
    max.dense.probability.difference=max(rows$dense.probability.difference),
    max.dense.objective.difference.per.observation=max(abs(rows$dense.objective.difference.per.observation)),
    max.custom.probability.difference=max(rows$custom.probability.difference),
    max.custom.grid.probability.difference=max(rows$custom.grid.probability.difference),
    max.stationarity=max(rows$stationarity),max.complementarity=max(rows$complementarity),
    max.objective.reconstruction.difference=max(abs(rows$objective.reconstruction.difference)),
    max.active.knots=max(rows$active.knots),load.mode=mode,threads=3L,
    scope='Same frozen unadjusted objectives; no new clinical analysis or tuning.')
jsonlite::write_json(summary,file.path(output,'summary.json'),pretty=TRUE,auto_unbox=TRUE,digits=NA)
print(summary)
if(length(failed)||nrow(rows)!=210L||!all(rows$agreement))stop('Dense/banded validation failed; all evidence remains preserved.')
