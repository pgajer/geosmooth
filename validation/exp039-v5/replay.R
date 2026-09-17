args <- commandArgs(TRUE)
cohort <- args[1]; source <- args[2]; inputs <- args[3]; output <- args[4]
dir.create(output,recursive=TRUE,showWarnings=FALSE)
pkgload::load_all('.',quiet=TRUE)
binary <- function(name) {
    spec <- jsonlite::fromJSON(file.path(inputs,cohort,paste0(name,'.json')))
    matrix(readBin(file.path(inputs,cohort,paste0(name,'.bin')),double(),prod(spec$shape)),
           spec$shape[1],spec$shape[2])
}
b <- readRDS(file.path(source,cohort,'basis.rds'))
Y <- binary('responses')
# The exporter uses IEEE NaN only as the transport marker for missing values.
# Its observed entries are required to be finite; R's public API requires NA.
Y[is.nan(Y)] <- NA_real_
reference.gcv <- binary('reference-gcv'); reference.df <- binary('reference-df')
grid <- scan(file.path(inputs,cohort,'grid.txt'),quiet=TRUE)
columns <- read.delim(file.path(inputs,cohort,'columns.tsv'),stringsAsFactors=FALSE)
sink(file.path(output,'session.txt'));print(sessionInfo()); print(extSoftVersion());sink()
cat(format(Sys.time()),cohort,'public package path:',nrow(Y),'vertices;',ncol(Y),'responses;',length(grid),'times\n')
tick <- proc.time()
path <- apply.metric.graph.lowpass.path(b,Y,grid,numerical.policy='verified.fallback')
seconds <- (proc.time()-tick)[['elapsed']]
saveRDS(path,file.path(output,'path.rds'),compress=FALSE)
write.table(path$numerical$diagnostics,file.path(output,'numerical-diagnostics.tsv'),sep='\t',row.names=FALSE,quote=FALSE)
checks <- list(gcv.difference=max(abs(path$gcv.scores-reference.gcv)),
               gcv.tolerance.ratio=max(abs(path$gcv.scores-reference.gcv)/(1e-10+1e-7*abs(reference.gcv))),
               df.difference=max(abs(path$effective.df-reference.df)))
stopifnot(checks$gcv.tolerance.ratio<=1,checks$df.difference<=1e-7)
checkpoint <- sapply(c(1L,20L,40L),function(j) {
    ref <- binary(paste0('checkpoint-',j))
    max(abs(path$fitted.values[,j,seq_len(ncol(ref))]-ref))
})
stopifnot(max(checkpoint)<=1e-7)
tuning <- do.call(rbind,lapply(seq_len(ncol(Y)),function(i) {
    x <- path$tuning[[i]]
    data.frame(columns[i,],status=x$status,best.idx=x$best.idx,lower.endpoint=x$lower.endpoint,
               upper.endpoint=x$upper.endpoint,bracketed=x$bracketed,
               near.minimum.indices=paste(x$near.minimum.indices,collapse=','))
}))
write.table(tuning,file.path(output,'tuning.tsv'),sep='\t',row.names=FALSE,quote=FALSE)
# Additional missingness patterns on the same graph, frozen independently of
# outcomes: index-evenly-spaced sets of 7 and 31 observations. Synthetic values
# ensure this is a numerical exercise, not a biological smoothing deliverable.
extra <- matrix(NA_real_,nrow(Y),2)
for (i in 1:2) {
    O <- unique(round(seq(1,nrow(Y),length.out=c(7,31)[i])))
    extra[O,i] <- sin(O/17)+cos(O/31)
}
extra.path <- apply.metric.graph.lowpass.path(b,extra,grid[c(1,20,40)],numerical.policy='verified.fallback')
saveRDS(extra.path,file.path(output,'additional-masks.rds'),compress=FALSE)
write.table(extra.path$numerical$diagnostics,file.path(output,'additional-diagnostics.tsv'),sep='\t',row.names=FALSE,quote=FALSE)
summary <- c(list(cohort=cohort,vertices=nrow(Y),responses=ncol(Y),mask.time.comparisons=nrow(path$numerical$diagnostics),
                  seconds=seconds,checkpoint.differences=checkpoint,additional.comparisons=nrow(extra.path$numerical$diagnostics),
                  fallback.used=sum(path$numerical$diagnostics$fallback.used)),checks)
jsonlite::write_json(summary,file.path(output,'summary.json'),pretty=TRUE,auto_unbox=TRUE,digits=16)
print(summary)
cat(format(Sys.time()),'completed\n')
