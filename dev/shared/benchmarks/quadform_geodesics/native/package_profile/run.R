args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 2L)
repo <- normalizePath(args[1]); output <- normalizePath(args[2])
stopifnot(!startsWith(paste0(output,"/"),paste0(repo,"/")),!file.exists(file.path(output,"measurements.rds")))
home <- file.path(repo,"dev/shared/benchmarks/quadform_geodesics/native/package_profile")
source(file.path(home,"prepare.R"))
library(geosmooth)
solve <- getFromNamespace("quadform_geodesics_solver","geosmooth")
native <- getFromNamespace("rcpp_quadform_geodesics_solver","geosmooth")
profile <- qgp.load(file.path(output,"instrumented/instrumented.cpp"),file.path(output,"build-cache"))
Sys.setenv(RETICULATE_PYTHON = "/intentionally-unavailable-python")
disk <- list(kind = "ball",center = c(0,0),radius = 1)
box <- list(kind = "box",lower = c(-1,-1),upper = c(1,1))
cases <- list(
  flat = list(A = matrix(0,2,2),from = c(-.45,-.2),to = c(.4,-.1),domain = box),
  gentle_bowl = list(A = diag(c(1,1)),from = c(-.45,-.2),to = c(.4,-.1),domain = disk),
  steep_bowl = list(A = diag(c(8,8)),from = c(-.45,-.2),to = c(.4,-.1),domain = disk),
  saddle = list(A = diag(c(8,-2)),from = c(-.45,-.2),to = c(.4,-.1),domain = disk),
  rectangle_boundary = list(A = diag(c(8,8)),from = c(-.9,.99),to = c(.9,.99),domain = box))
base <- expand.grid(case = names(cases),method = c("single_point","local_network"),
  neighborhood = c("neighbors","fixed_disk","fixed_span"),cache_edges = c(0L,256L,4096L,65536L),
  seed = 50001:50003,stringsAsFactors = FALSE)
base$candidates <- 32L; base$initial_edges <- 16L; base$trace <- FALSE; base$family <- "cache"
scaling <- expand.grid(case = "steep_bowl",method = c("single_point","local_network"),
  neighborhood = "fixed_span",cache_edges = 65536L,seed = 50001:50003,
  candidates = c(8L,32L,128L),initial_edges = c(8L,16L,64L),stringsAsFactors = FALSE)
scaling <- scaling[!(scaling$candidates == 32L & scaling$initial_edges == 16L),]
scaling$trace <- FALSE; scaling$family <- "scaling"
tracing <- rbind(base[base$case == "steep_bowl" & base$neighborhood == "fixed_span" & base$cache_edges == 65536L,],
  scaling[scaling$candidates == 128L & scaling$initial_edges == 64L,])
tracing$trace <- TRUE; tracing$family <- "tracing"
plan <- rbind(base,scaling[,names(base)],tracing[,names(base)])
plan$id <- seq_len(nrow(plan))
order_key <- vapply(plan$id,function(id) digest::digest(paste("single-process-profile-v1",id),algo="sha256"),"")
plan <- plan[order(order_key),]; rownames(plan) <- NULL
write.csv(plan,file.path(output,"plan.csv"),row.names = FALSE)
jsonlite::write_json(cases,file.path(output,"cases.json"),auto_unbox = TRUE,pretty = TRUE,digits = NA)
files <- c(file.path(repo,"src",c("quadform_geodesics_solver.cpp","quadform_geodesics_solver_rcpp.cpp",
  "quadform_geodesics_solver.h","Makevars")),file.path(repo,"R/quadform_geodesics_solver.R"),
  list.files(home,full.names = TRUE),getLoadedDLLs()[["geosmooth"]][["path"]],
  system.file("R","geosmooth.rdb",package = "geosmooth"))
hash <- function() vapply(files,function(p) digest::digest(file=p,algo="sha256"),"")
before <- hash()
write.csv(data.frame(file = files,sha256 = before),file.path(output,"sources.csv"),row.names = FALSE)
capture.output(sessionInfo(),file = file.path(output,"session-info.txt"))
strip_time <- function(x) { x$counters$elapsed_seconds <- NULL; x }
comparison <- function(x,y) identical(strip_time(x),strip_time(y))
signature <- function(x) {
  x$configuration$cache_edges <- NULL
  x$counters[c("edge_requests","edge_calls","cache_hits","cache_entries","cache_evictions",
    "integrand_evaluations","elapsed_seconds")] <- NULL
  # Error estimates may be tighter when cached initialization edges are reused.
  x$error_estimate <- NULL
  digest::digest(x,algo = "sha256")
}
audit <- function(x,example) {
  U <- x$path; A <- example$A; d <- example$domain
  stopifnot(x$status == "candidate",x$termination == "epoch_limit",x$counters$completed_epochs == 8,
    all(is.finite(U)),identical(unname(U[1,]),example$from),identical(unname(U[nrow(U),]),example$to))
  if (d$kind == "ball") stopifnot(all(rowSums(U^2) <= 1+1e-14))
  else stopifnot(all(U >= -1),all(U <= 1))
  values <- vapply(seq_len(nrow(U)-1L),function(i) {
    a <- U[i,]; h <- U[i+1L,]-a
    integrate(function(t) sqrt(sum(h*h)+(2*sum(a*(A%*%h))+2*t*sum(h*(A%*%h)))^2),
      0,1,rel.tol=1e-12,abs.tol=1e-13,subdivisions=1000L)$value
  },0)
  stopifnot(abs(sum(values)-x$length) <= x$error_estimate+1e-10,
    sum(values) <= x$initial_length+x$initial_error_estimate+1e-10)
  sum(values)
}
time_block <- function(call,n) {
  gc(FALSE)
  elapsed <- system.time(for (k in seq_len(n)) answer <- call())[["elapsed"]]
  c(seconds = elapsed/n,n = n)
}
rows <- profiles <- fine <- list(); completed <- 0L
for (k in seq_len(nrow(plan))) {
  job <- plan[k,]; example <- cases[[job$case]]
  input <- c(example,list(method = job$method,neighborhood = job$neighborhood,seed = job$seed,
    length_scale = 32.0624390837628,initial_edges = job$initial_edges,candidates = job$candidates,
    max_epochs = 8L,plateau_epochs = 9L,max_edge_calls = Inf,max_seconds = 60,
    cache_edges = job$cache_edges,trace = job$trace))
  plain <- function() do.call(solve,input)
  original <- plain(); checked_length <- audit(original,example)
  options <- original$configuration
  profiled <- function() profile$qgp_solve(input$A,input$from,input$to,input$domain,options)
  direct <- function() native(input$A,input$from,input$to,input$domain,options)
  stopifnot(comparison(original,direct()))
  profile$qgp_reset(FALSE); disabled <- profiled()
  stopifnot(comparison(original,disabled))
  profile$qgp_reset(TRUE); instrumented <- profiled(); component <- profile$qgp_metrics()
  stopifnot(comparison(original,instrumented),min(component$exclusive_seconds) >= -1e-9,
    abs(sum(component$exclusive_seconds)-component$inclusive_seconds[1]) < 1e-8)
  # Validate the complete accepted trajectory separately from ordinary timings.
  traced_input <- input; traced_input$trace <- TRUE; traced_input$trace_limit <- 10000L
  original_trace <- do.call(solve,traced_input)
  stopifnot(!original_trace$trace_truncated)
  profile$qgp_reset(TRUE)
  traced <- profile$qgp_solve(input$A,input$from,input$to,input$domain,original_trace$configuration)
  stopifnot(comparison(original_trace,traced))
  component$id <- job$id; profiles[[k]] <- component
  n <- max(1L,min(50L,ceiling(.08/max(original$counters$elapsed_seconds,.0001))))
  # Rotate call order across the three measurement blocks; times include R returns.
  times <- matrix(NA_real_,3,3,dimnames = list(NULL,c("ordinary","direct","disabled")))
  for (repeat_id in 1:3) {
    sequence <- ((seq_len(3)+repeat_id-2L) %% 3L)+1L
    for (mode in sequence) {
      profile$qgp_reset(FALSE)
      times[repeat_id,mode] <- time_block(switch(mode,plain,direct,profiled),n)[["seconds"]]
    }
  }
  extra <- list(length = original$length,audited_length = checked_length,vertices = nrow(original$path),
    result_bytes = as.numeric(object.size(original)),trace_events = length(original$trace),
    cache_signature = signature(original),result_hash = digest::digest(strip_time(original),algo="sha256"),
    trajectory_hash = digest::digest(strip_time(original_trace),algo="sha256"),
    profiled_seconds = component$inclusive_seconds[1],batch_calls = n)
  for (repeat_id in 1:3) rows[[length(rows)+1L]] <- cbind(job,repetition = repeat_id,
    as.data.frame(extra),as.data.frame(original$counters),
    ordinary_seconds = times[repeat_id,1],direct_seconds = times[repeat_id,2],
    instrumentation_disabled_seconds = times[repeat_id,3],agreement = TRUE)
  if (job$seed == 50001 && job$case == "steep_bowl" && job$candidates == 32 &&
      job$initial_edges == 16 && job$cache_edges == 65536 && !job$trace) {
    profile$qgp_reset(TRUE,TRUE); detailed <- profiled()
    stopifnot(comparison(original,detailed))
    z <- profile$qgp_metrics(); z$id <- job$id; fine[[length(fine)+1L]] <- z
  }
  profile$qgp_reset(FALSE)
  completed <- completed+1L
  if (completed %% 10L == 0L || completed == nrow(plan)) {
    jsonlite::write_json(list(completed = completed,total = nrow(plan),last_id = job$id),
      file.path(output,"progress.json"),auto_unbox = TRUE,pretty = TRUE)
    cat(completed,"/",nrow(plan),"configurations complete\n"); flush.console()
  }
}
stopifnot(identical(before,hash()))
measurements <- do.call(rbind,rows); components <- do.call(rbind,profiles)
write.csv(measurements,file.path(output,"measurements.csv"),row.names = FALSE)
write.csv(components,file.path(output,"components.csv"),row.names = FALSE)
write.csv(do.call(rbind,fine),file.path(output,"fine-components.csv"),row.names = FALSE)
saveRDS(list(plan = plan,measurements = measurements,components = components,fine = fine,cases = cases),
  file.path(output,"measurements.rds"))
jsonlite::write_json(list(status = "complete",configurations = nrow(plan),timing_rows = nrow(measurements),
  all_instrumentation_comparisons_passed = TRUE,all_independent_length_checks_passed = TRUE,
  source_hashes_unchanged = TRUE),file.path(output,"completion.json"),auto_unbox = TRUE,pretty = TRUE)
cat("Profiling completed successfully.\n")
