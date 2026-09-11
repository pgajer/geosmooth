args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
repo <- normalizePath(args[1]); output <- normalizePath(args[2])
script <- file.path(repo,"dev/shared/benchmarks/quadform_geodesics/native/package_profile/supplement.R")
plan <- expand.grid(method = c("single_point","local_network"),cache_edges = c(0L,65536L),
  trace = c(FALSE,TRUE),stringsAsFactors = FALSE)
rows <- list()
for (i in seq_len(nrow(plan))) {
  job <- plan[i,]; name <- paste0("memory-",job$method,"-",job$cache_edges,"-",job$trace)
  log <- file.path(output,paste0(name,".log"))
  status <- system2("/usr/bin/time",c("-l",shQuote(file.path(R.home("bin"),"Rscript")),
    "--vanilla",shQuote(script),"memory",shQuote(output),job$method,job$cache_edges,job$trace),
    stdout = log,stderr = log,wait = TRUE)
  stopifnot(status == 0L)
  lines <- readLines(log)
  peak <- lines[grepl("maximum resident set size",lines,fixed = TRUE)]
  stopifnot(length(peak) == 1L)
  bytes <- as.numeric(strsplit(trimws(peak)," +")[[1]][1])
  info <- jsonlite::fromJSON(file.path(output,paste0(name,".json")))
  rows[[i]] <- cbind(job,peak_rss_bytes = bytes,result_bytes = info$result_bytes,
    edge_calls = info$counters$edge_calls,elapsed_seconds = info$counters$elapsed_seconds)
}
write.csv(do.call(rbind,rows),file.path(output,"memory.csv"),row.names = FALSE)
