args <- commandArgs(TRUE)
pkgload::load_all(args[1], quiet=TRUE)
options(digits=17, warn=1)
adj <- list(2L, c(1L,3L), c(2L,4L), 3L)
weights <- list(1, c(1,1e-8), c(1e-8,1), 1)
grid <- c(.01,.1,1,1000)
b <- metric.graph.lowpass.basis(adj,weights,weight.type='conductance',
    spectrum='full',numerical.policy='verified.fallback')
cat('BLAS:', extSoftVersion()[['BLAS']], '\n')
results <- list()
for (offset in c(0,10,1000)) {
    y <- c(offset,NA,NA,offset+1)
    path <- apply.metric.graph.lowpass.path(b,y,grid)
    fit <- try(fit.metric.graph.lowpass(adj,weights,y,
        weight.type='conductance',spectrum='full',eta.grid=grid,
        numerical.policy='verified.fallback'),silent=TRUE)
    results[[as.character(offset)]] <- list(offset=offset,grid=grid,
        observed=y[!is.na(y)],gcv=path$gcv.scores,
        exact.gcv=rep(1,length(grid)),tuning=path$tuning[[1]],
        diagnostics=path$numerical$diagnostics,
        automatic.fit=if (inherits(fit,'try-error')) as.character(fit) else
            list(eta=fit$spectral$eta.optimal,tuning=fit$gcv$tuning))
}
print(results)
jsonlite::write_json(results,args[2],pretty=TRUE,auto_unbox=TRUE,digits=17,na='null')
