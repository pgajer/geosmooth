# Independent arithmetic and completeness checks; no models are fitted here.
out <- 'dev/html/pca-pls-vignette'
a <- readRDS(file.path(out,'results.rds'))
r <- a$results
stopifnot(nrow(r)==200L, length(unique(r$scenario))==5L,
          all(table(r$scenario,r$repetition)==8L),
          !anyDuplicated(r[c('scenario','repetition','method','mode')]),
          all(is.finite(as.matrix(r[c('probability.mse','brier','log.loss','fallbacks')]))),
          all(r$probability.mse>=0 & r$brier>=0 & r$log.loss>=0),
          all(r$dimension[r$mode=='One dimension']==1L),
          all(r$dimension[r$mode=='Tuned dimension'] %in% 1:3),
          all(r$fallbacks>=0 & r$fallbacks<=120))
for (scenario in names(a$illustrations)) {
    item <- a$illustrations[[scenario]]
    stopifnot(nrow(item$data$X)==360L, length(item$data$y)==360L,
              all(item$data$y %in% 0:1), all(apply(item$data$X,1,max)==1))
    subset <- r[r$scenario==scenario & r$repetition==1L,]
    for (i in seq_len(nrow(subset))) {
        row <- subset[i,]
        key <- if (row$mode=='Constant') row$method else paste(row$method,row$mode)
        p <- item$predictions[[key]]
        y <- item$data$y[241:360]; truth <- item$data$probability[241:360]
        stopifnot(length(p)==120L,
            abs(mean((p-truth)^2)-row$probability.mse)<1e-12,
            abs(mean((p-y)^2)-row$brier)<1e-12,
            abs(-mean(y*log(p)+(1-y)*log1p(-p))-row$log.loss)<1e-12)
    }
}
stopifnot(length(a$slices)==5L)
for(s in a$slices) stopifnot(nrow(s$prediction)==60L,ncol(s$prediction)==3L,
                            all(is.finite(s$prediction)),all(s$prediction>0 & s$prediction<1))
write.csv(r,file.path(out,'all-repetitions.csv'),row.names=FALSE)
write.csv(a$summary,file.path(out,'summary.csv'),row.names=FALSE)
cat('Verified 200 results, 25 datasets, 40 independent first-repetition score calculations, and 900 slice predictions.\n')
print(a$summary,row.names=FALSE)
cat('Reported-mode fallback totals (modes overlap):\n')
print(aggregate(fallbacks~method+mode,r,sum),row.names=FALSE)
