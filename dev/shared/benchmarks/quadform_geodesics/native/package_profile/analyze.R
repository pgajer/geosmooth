args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L)
output <- normalizePath(args[1])
raw <- readRDS(file.path(output,"measurements.rds"))
m <- raw$measurements; p <- raw$plan
stopifnot(nrow(p) == 420L,nrow(m) == 1260L,!anyNA(m$ordinary_seconds),
  all(m$agreement),all(m$completed_epochs == 8),all(m$failed_windows == 0),
  all(m$sampling_shortfalls == 0))
jobs <- m[m$repetition == 1,]
for (field in c("ordinary_seconds","direct_seconds","instrumentation_disabled_seconds")) {
  values <- tapply(m[[field]],m$id,median)
  jobs[[field]] <- unname(values[as.character(jobs$id)])
}
method_names <- c(single_point = "Single-point",local_network = "Local-network")
rule_names <- c(neighbors = "Immediate neighbors",fixed_disk = "Fixed disk",fixed_span = "Disk + distance section")
case_names <- c(flat = "Flat surface",gentle_bowl = "Gentle bowl",steep_bowl = "Steep bowl",
  saddle = "Saddle",rectangle_boundary = "Near rectangle boundary")
group <- function(d,keys,f) {
  z <- split(d,interaction(d[keys],drop = TRUE,lex.order = TRUE))
  out <- do.call(rbind,lapply(z,function(x) cbind(x[1,keys,drop = FALSE],f(x))))
  rownames(out) <- NULL; out
}
default <- jobs[jobs$family == "cache" & jobs$cache_edges == 65536,]
timing <- group(default,c("case","method","neighborhood"),function(x) data.frame(
  median_ms = 1000*median(x$ordinary_seconds),min_ms = 1000*min(x$ordinary_seconds),
  max_ms = 1000*max(x$ordinary_seconds),edge_calls = median(x$edge_calls),
  visits = median(x$visited_points),vertices = median(x$vertices),
  sampling_attempts_per_candidate = median(x$sampling_attempts/(x$visited_points*x$candidates))))
cache <- jobs[jobs$family == "cache",]
pair <- merge(cache,cache[cache$cache_edges == 0,c("case","method","neighborhood","seed",
  "ordinary_seconds","edge_calls","cache_signature")],by = c("case","method","neighborhood","seed"),
  suffixes = c("","_uncached"))
pair$time_ratio <- pair$ordinary_seconds/pair$ordinary_seconds_uncached
pair$avoided_fraction <- 1-pair$edge_calls/pair$edge_calls_uncached
pair$same_path_and_decisions <- pair$cache_signature == pair$cache_signature_uncached
cache_summary <- group(pair,c("method","cache_edges"),function(x) data.frame(
  comparisons = nrow(x),median_time_ratio = median(x$time_ratio),min_time_ratio = min(x$time_ratio),
  max_time_ratio = max(x$time_ratio),median_avoided_percent = 100*median(x$avoided_fraction),
  equal_results = sum(x$same_path_and_decisions)))
c <- merge(raw$components,p,by="id")
totals <- setNames(c$inclusive_seconds[c$component == "Rcpp input/output"],c$id[c$component == "Rcpp input/output"])
c$total_seconds <- unname(totals[as.character(c$id)])
c$percent <- 100*c$exclusive_seconds/c$total_seconds
selected <- c[c$case == "steep_bowl" & c$neighborhood == "fixed_span" &
  c$cache_edges == 65536 & c$candidates == 32 & c$initial_edges == 16 & !c$trace,]
components <- group(selected,c("method","component"),function(x) data.frame(
  mean_percent = mean(x$percent),mean_ms = 1000*mean(x$exclusive_seconds),
  mean_calls = mean(x$calls)))
stopifnot(all(abs(tapply(components$mean_percent,components$method,sum)-100) < 1e-6))
scaling <- group(jobs[jobs$case == "steep_bowl" & jobs$neighborhood == "fixed_span" &
  jobs$cache_edges == 65536 & !jobs$trace,],c("method","candidates","initial_edges"),function(x) data.frame(
    median_ms = 1000*median(x$ordinary_seconds),min_ms = 1000*min(x$ordinary_seconds),
    max_ms = 1000*max(x$ordinary_seconds),edge_calls = median(x$edge_calls),visits = median(x$visited_points)))
trace <- merge(jobs[jobs$trace,],jobs[!jobs$trace & jobs$case == "steep_bowl" &
  jobs$neighborhood == "fixed_span" & jobs$cache_edges == 65536,],
  by = c("case","method","neighborhood","cache_edges","seed","candidates","initial_edges"),
  suffixes = c("_trace","_off"))
stopifnot(nrow(trace) == 12L,all(trace$length_trace == trace$length_off),
  all(trace$edge_calls_trace == trace$edge_calls_off),
  all(trace$accepted_replacements_trace == trace$accepted_replacements_off))
trace$time_ratio <- trace$ordinary_seconds_trace/trace$ordinary_seconds_off
tracing <- group(trace,c("method","candidates","initial_edges"),function(x) data.frame(
  median_time_ratio = median(x$time_ratio),min_time_ratio = min(x$time_ratio),
  max_time_ratio = max(x$time_ratio),median_trace_kib = median(x$result_bytes_trace)/1024,
  median_off_kib = median(x$result_bytes_off)/1024,median_events = median(x$trace_events_trace)))
overhead <- group(jobs,c("method"),function(x) data.frame(
  profile_ratio = median(x$profiled_seconds/x$ordinary_seconds),
  disabled_copy_ratio = median(x$instrumentation_disabled_seconds/x$ordinary_seconds),
  direct_ratio = median(x$direct_seconds/x$ordinary_seconds)))
fine <- merge(do.call(rbind,raw$fine),p,by = "id")
fine_totals <- setNames(fine$inclusive_seconds[fine$component == "Rcpp input/output"],
  fine$id[fine$component == "Rcpp input/output"])
fine$percent <- 100*fine$exclusive_seconds/unname(fine_totals[as.character(fine$id)])
all <- list(timing = timing,cache_summary = cache_summary,cache_pairs = pair,components = components,
  scaling = scaling,tracing = tracing,overhead = overhead,fine = fine,jobs = jobs)
for (name in names(all)) write.csv(all[[name]],file.path(output,paste0("summary-",name,".csv")),row.names = FALSE)
saveRDS(all,file.path(output,"summary.rds"))
print(timing,digits = 4); print(cache_summary,digits = 4)
print(components[components$mean_percent > 1,],digits = 4)
print(scaling,digits = 4); print(tracing,digits = 4); print(overhead,digits = 4)
