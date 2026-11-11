# Scan weakly connected chains for unresolved heat-score tuning paths.
library(geosmooth)
args <- commandArgs(TRUE)
if (length(args) != 1L || !nzchar(args[1L]))
    stop('Supply an output TSV path outside the package checkout.')
set.seed(6172026)
rows <- list()
for (i in seq_len(80)) {
    n <- sample(4:9,1)
    w <- runif(n-1,.5,2)
    w[sample.int(n-1,1)] <- 10^sample(c(-3,-5,-6,-7,-8,-9),1)
    a <- lapply(seq_len(n),function(j) as.integer(c(j-1,j+1)[c(j>1,j<n)]))
    weights <- lapply(seq_len(n),function(j) w[pmin(j,a[[j]])])
    times <- 10^seq(-3,4,length.out=12)
    y <- rep(NA_real_,n); y[c(1,n)] <- c(0,1)
    b <- metric.graph.lowpass.basis(a,weights,weight.type='conductance',spectrum='full',
                                  numerical.policy='verified.fallback')
    r <- try(apply.metric.graph.lowpass.path(b,y,times),silent=TRUE)
    rows[[i]] <- if (inherits(r,'try-error')) {
        data.frame(case=i,n=n,weights=paste(w,collapse=','),accepted=FALSE,status=as.character(r),error=NA,range=NA)
    } else {
        data.frame(case=i,n=n,weights=paste(w,collapse=','),accepted=TRUE,status=r$tuning[[1]]$status,
                   error=max(abs(r$gcv.scores-1)),range=diff(range(r$gcv.scores)))
    }
}
result <- do.call(rbind,rows)
write.table(result,args[1],sep='\t',row.names=FALSE)
print(table(result$accepted,result$status))
print(subset(result,accepted & status!='unresolved_flat_gcv'))

stopifnot(all(!result$accepted | result$status=="unresolved_flat_gcv"))
