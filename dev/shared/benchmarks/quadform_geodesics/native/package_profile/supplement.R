args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) >= 2L)
mode <- args[1]; output <- normalizePath(args[2])
library(geosmooth)
solve <- getFromNamespace("quadform_geodesics_solver","geosmooth")
native <- getFromNamespace("rcpp_quadform_geodesics_solver","geosmooth")
A <- diag(c(8,8)); from <- c(-.45,-.2); to <- c(.4,-.1)
domain <- list(kind = "ball",center = c(0,0),radius = 1)
if (mode == "micro") {
  rows <- list()
  for (scenario in c("identical_endpoints","initialization_only")) {
    end <- if (scenario == "identical_endpoints") from else to
    input <- list(A = A,from = from,to = end,domain = domain,max_epochs = 0L,cache_edges = 0L)
    options <- do.call(solve,input)$configuration
    calls <- list(
      ordinary = function() solve(A,from,end,domain,max_epochs = 0L,cache_edges = 0L),
      do_call = function() do.call(solve,input),
      registered = function() native(A,from,end,domain,options))
    answers <- lapply(calls,function(f) f())
    strip <- function(x) { x$counters$elapsed_seconds <- NULL; x }
    stopifnot(identical(strip(answers[[1]]),strip(answers[[2]])),
      identical(strip(answers[[1]]),strip(answers[[3]])))
    n <- if (scenario == "identical_endpoints") 5000L else 500L
    for (repetition in 1:5) for (i in ((seq_len(3)+repetition-2L) %% 3L)+1L) {
      call <- calls[[i]]; gc(FALSE)
      seconds <- system.time(for (j in seq_len(n)) x <- call())[["elapsed"]]/n
      rows[[length(rows)+1L]] <- data.frame(scenario,mode = names(calls)[i],repetition,n,seconds)
    }
  }
  write.csv(do.call(rbind,rows),file.path(output,"micro.csv"),row.names = FALSE)
} else if (mode == "memory") {
  stopifnot(length(args) == 5L)
  method <- args[3]; cache <- as.integer(args[4]); trace <- as.logical(args[5])
  x <- solve(A,from,to,domain,method = method,seed = 50001,
    length_scale = 32.0624390837628,initial_edges = 64L,candidates = 128L,
    max_epochs = 8L,plateau_epochs = 9L,max_edge_calls = Inf,
    cache_edges = cache,trace = trace)
  stopifnot(x$termination == "epoch_limit",x$counters$completed_epochs == 8L,!x$trace_truncated)
  jsonlite::write_json(list(method = method,cache_edges = cache,trace = trace,
    length = x$length,vertices = nrow(x$path),result_bytes = as.numeric(object.size(x)),
    counters = x$counters),file.path(output,paste0("memory-",method,"-",cache,"-",trace,".json")),
    auto_unbox = TRUE,pretty = TRUE,digits = NA)
} else stop("Unknown supplementary measurement")
