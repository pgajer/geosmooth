args <- commandArgs(TRUE)
pkgload::load_all(args[1],quiet=TRUE)
options(digits=17)
runtime <- args[3]
set.seed(6172026)
for (i in seq_len(72)) {
    n <- sample(4:9,1)
    w <- runif(n-1,.5,2)
    w[sample.int(n-1,1)] <- 10^sample(c(-3,-5,-6,-7,-8,-9),1)
}
a <- lapply(seq_len(n),function(j) as.integer(c(j-1,j+1)[c(j>1,j<n)]))
weights <- lapply(seq_len(n),function(j) w[pmin(j,a[[j]])])
times <- 10^seq(-3,4,length.out=12)
y <- rep(NA_real_,n); y[c(1,n)] <- c(0,1)
b <- metric.graph.lowpass.basis(a,weights,weight.type='conductance',spectrum='full',
                              numerical.policy='verified.fallback')
p <- apply.metric.graph.lowpass.path(b,y,times)
runfit <- function(grid) fit.metric.graph.lowpass(a,weights,y,weight.type='conductance',
    spectrum='full',numerical.policy='verified.fallback',eta.grid=grid)
fit <- try(runfit(times),silent=TRUE)
seed <- runfit(times[1])
r <- try(refit(seed,y,per.column.gcv=TRUE,eta.grid=times),silent=TRUE)
result <- list(runtime=runtime,weights=w,times=times,observations=y,
    scores=p$gcv.scores,exact.scores=rep(1,length(times)),tuning=p$tuning[[1]],
    max.error=max(abs(p$gcv.scores-1)),score.range=diff(range(p$gcv.scores)),
    diagnostics=p$numerical$diagnostics,
    fit=if(inherits(fit,'try-error')) as.character(fit) else list(eta=fit$spectral$eta.optimal,tuning=fit$gcv$tuning),
    refit=if(inherits(r,'try-error')) as.character(r) else list(eta=r$eta.optimal,tuning=r$tuning))
print(result)
jsonlite::write_json(result,args[2],pretty=TRUE,digits=17,auto_unbox=TRUE,na='null')
