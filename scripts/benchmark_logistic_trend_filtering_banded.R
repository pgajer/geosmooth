#!/usr/bin/env Rscript
# One independent, seeded synthetic scaling run. Invoke with /usr/bin/time -l
# to record process peak RSS; do not confuse estimated workspace with RSS.
args <- commandArgs(TRUE)
if (!length(args) %in% 3:4) stop('Usage: Rscript scripts/benchmark_logistic_trend_filtering_banded.R N SCENARIO NEW_OUTPUT_DIR [CURRENT_SOURCE_INSTALL_LIBRARY]')
n <- as.integer(args[1]); scenario <- match.arg(args[2],c('smooth','rare_adjusted','ties_adjusted')); output <- args[3]
if (is.na(n)||n<100||dir.exists(output)) stop('Need n>=100 and a new output directory.')
dir.create(output,recursive=TRUE)
Sys.setenv(OMP_NUM_THREADS=1,OPENBLAS_NUM_THREADS=1,MKL_NUM_THREADS=1,VECLIB_MAXIMUM_THREADS=1)
if (length(args)==4L) {
    library(geosmooth,lib.loc=args[4]);mode<-'installed_optimized_current_source'
} else {
    pkgload::load_all('/Users/pgajer/current_projects/dgraphs',recompile=FALSE,quiet=TRUE)
    pkgload::load_all('.',recompile=FALSE,quiet=TRUE);mode<-'source_optimized'
}
seed <- 31007L+n+match(scenario,c('smooth','rare_adjusted','ties_adjusted'))-1L
set.seed(seed);x<-sort(runif(n));z<-NULL;offset<-NULL;nr<-cr<-0
if (scenario=='smooth') {
    truth<-plogis(-1+.8*sin(6*pi*x)+1.3*(x-.5))
} else {
    if (scenario=='ties_adjusted') x<-round(x*99)/99
    z<-cbind(rnorm(n),rbinom(n,1,.4));offset<-.15*cos(3*pi*x)
    truth<-plogis((if(scenario=='rare_adjusted') -3.5 else -1)+.8*sin(6*pi*x)+.25*z[,1]-.4*z[,2]+offset)
    nr<-.16;cr<-.04
}
y<-rbinom(n,1,truth);lambda<-c(1,.1,.01,.001)
timing<-system.time(fit<-fit.logistic.trend.filtering(x,y,lambda,covariates=z,offset=offset,
    nuisance.ridge=nr,curve.ridge=cr,backend='banded',warn=FALSE))
# Prediction is a separate timed check, including points off the training grid.
grid<-seq(min(x)-.1,max(x)+.1,length.out=n)
newz<-if(is.null(z))NULL else cbind(rep(0,n),rep(0,n))
new.offset<-if(is.null(offset))NULL else rep(0,n)
prediction.time<-system.time(prediction<-predict(fit,grid,covariates=newz,offset=new.offset))
saveRDS(list(n=n,seed=seed,scenario=scenario,timing=timing,prediction.time=prediction.time,fit=fit,truth=truth),file.path(output,'result.rds'))
write.csv(fit$diagnostics,file.path(output,'diagnostics.csv'),row.names=FALSE)
source.files<-c('R/logistic_trend_filtering.R','src/logistic_trend_filtering.cpp','src/logistic_trend_filtering_banded.cpp',
    'scripts/benchmark_logistic_trend_filtering_banded.R')
dll<-getLoadedDLLs()[['geosmooth']][['path']]
write.csv(data.frame(file=c(source.files,dll),sha256=vapply(c(source.files,dll),function(p)digest::digest(file=p,algo='sha256'),character(1))),file.path(output,'hashes.csv'),row.names=FALSE)
for(p in source.files)file.copy(p,file.path(output,basename(p)))
writeLines(capture.output(sessionInfo()),file.path(output,'sessionInfo.txt'))
summary<-list(n=n,distinct=length(unique(x)),cases=sum(y),scenario=scenario,seed=seed,
    lambda=lambda,converged=sum(fit$diagnostics$converged),fits=length(lambda),
    fit.elapsed.seconds=unname(timing['elapsed']),prediction.elapsed.seconds=unname(prediction.time['elapsed']),
    workspace.estimate.bytes=fit$workspace.estimate.bytes,max.stationarity=max(fit$diagnostics$stationarity),
    max.complementarity=max(fit$diagnostics$complementarity),max.working.knots=max(fit$diagnostics$working.knots),
    load.mode=mode,threads=1L,scope='Synthetic scaling test, not an AGP clinical analysis or a worst-case runtime guarantee.')
jsonlite::write_json(summary,file.path(output,'summary.json'),pretty=TRUE,auto_unbox=TRUE,digits=NA)
print(summary)
if(!all(fit$diagnostics$converged)||any(!is.finite(prediction)))stop('Scaling validation failed; preserve diagnostics.')
