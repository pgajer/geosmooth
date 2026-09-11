# Build a private instrumented copy. Production package sources remain unchanged.
qgp.prepare <- function(repo, directory) {
  stopifnot(!dir.exists(directory))
  dir.create(directory,recursive = TRUE)
  home <- file.path(repo,"dev/shared/benchmarks/quadform_geodesics/native/package_profile")
  read <- function(p) paste(readLines(p,warn = FALSE),collapse = "\n")
  change <- function(x,anchor,replacement) {
    matches <- gregexpr(anchor,x,fixed = TRUE)[[1]]
    if (length(matches) != 1L || matches[1] < 0) stop("Instrumentation anchor is not unique: ",anchor)
    sub(anchor,replacement,x,fixed = TRUE)
  }
  header <- read(file.path(repo,"src/quadform_geodesics_solver.h"))
  engine <- read(file.path(repo,"src/quadform_geodesics_solver.cpp"))
  wrapper <- read(file.path(repo,"src/quadform_geodesics_solver_rcpp.cpp"))
  engine <- change(engine,'#include "quadform_geodesics_solver.h"',"")
  wrapper <- change(wrapper,'#include "quadform_geodesics_solver.h"',"")
  anchors <- c(
    "PointKey key(const Point& p) {" = "keys",
    "  void poll() {" = "polling",
    "  Measure integrate(Point a, Point b, bool tighter) {" = "integration",
    "  Measure measured_edge(Point a, Point b, const EdgeKey& k, bool tighter) {" = "cache",
    "  Batch batch(const EdgeTable& table, bool tighter, bool& ok) {" = "batch",
    "  static std::vector<Measure> records(const IndexPath& p, const EdgeTable& table, const Batch& b) {" = "records",
    "              const std::vector<int>& order = {}) {" = "tracing",
    "  void initialize(Point from, Point to) {" = "initialization",
    "  bool sample(const Point& anchor, double radius, Path& candidates) {" = "sampling",
    "  IndexPath shortest(const EdgeTable& table, const Batch& values, int from, int to) {" = "shortest",
    "  void window(int i) {" = "window",
    "  void solve(Point from, Point to) {" = "scheduling")
  for (anchor in names(anchors)) engine <- change(engine,anchor,paste0(anchor,
    "\n    qgp::Scope profile_scope(qgp::",anchors[[anchor]],");"))
  engine <- change(engine,"  Solver s(config,domain,A,seed);",
    "  qgp::Scope profile_core(qgp::core);\n  qgp::Scope profile_setup(qgp::setup);\n  Solver s(config,domain,A,seed);\n  profile_setup.finish();")
  engine <- change(engine,"    EdgeTable table(old,candidates); auto old_indices = table.indices(old);",
    "    qgp::Scope profile_construction(qgp::construction);\n    EdgeTable table(old,candidates); auto old_indices = table.indices(old);")
  engine <- change(engine,"    bool tighter = false, ok; Batch values = batch(table,false,ok);",
    "    profile_construction.finish();\n    bool tighter = false, ok; Batch values = batch(table,false,ok);")
  wrapper <- change(wrapper,"  using namespace qgn;",
    "  qgp::Scope profile_boundary(qgp::boundary);\n  using namespace qgn;")
  wrapper <- sub("rcpp_quadform_geodesics_solver(","qgp_solve(",wrapper,fixed = TRUE)
  wrapper <- sub("rcpp_quadform_geodesics_reference_uniforms(","qgp_reference_uniforms(",wrapper,fixed = TRUE)
  text <- paste(read(file.path(home,"timers.h")),header,engine,wrapper,sep = "\n")
  # Avoid symbol interposition with the ordinary installed package in the same process.
  text <- gsub("qgn","qgn_profile",text,fixed = TRUE)
  extras <- c(
    "// [[Rcpp::export(rng = false)]]",
    "void qgp_reset(bool enabled, bool fine = false) {",
    "  if (qgp::timers().top) Rcpp::stop(\"Active profiling scope\");",
    "  qgp::timers() = qgp::Timers(); qgp::timers().enabled = enabled; qgp::timers().fine = fine;",
    "}",
    "// [[Rcpp::export(rng = false)]]",
    "Rcpp::DataFrame qgp_metrics() { return qgp::metrics(); }",
    "// [[Rcpp::export(rng = false)]]",
    "bool qgp_test_timers() {",
    "  qgp_reset(true); auto& t = qgp::timers(); t.testing = true;",
    "  { qgp::Scope outer(qgp::boundary); t.test_time = 1;",
    "    try { qgp::Scope child(qgp::core); t.test_time = 3; throw 1; } catch (int) {}",
    "    t.test_time = 6; }",
    "  bool ok = !t.top && t.inclusive[qgp::boundary] == 6 && t.exclusive[qgp::boundary] == 4 &&",
    "    t.inclusive[qgp::core] == 2 && t.exclusive[qgp::core] == 2;",
    "  qgp_reset(false); { qgp::Scope off(qgp::boundary); }",
    "  return ok && qgp::timers().calls[qgp::boundary] == 0;",
    "}")
  path <- file.path(directory,"instrumented.cpp")
  writeLines(c("// [[Rcpp::plugins(cpp17)]]",text,extras),path)
  files <- c(file.path(repo,"src",c("quadform_geodesics_solver.h","quadform_geodesics_solver.cpp",
    "quadform_geodesics_solver_rcpp.cpp","Makevars")),file.path(repo,"R/quadform_geodesics_solver.R"),
    file.path(home,c("prepare.R","timers.h")),path)
  write.csv(data.frame(file = files,sha256 = vapply(files,function(p) digest::digest(file=p,algo="sha256"),"")),
    file.path(directory,"sources.csv"),row.names = FALSE)
  path
}
qgp.load <- function(path,cache) {
  old <- Sys.getenv("PKG_CXXFLAGS",unset = NA_character_)
  on.exit(if (is.na(old)) Sys.unsetenv("PKG_CXXFLAGS") else Sys.setenv(PKG_CXXFLAGS = old))
  Sys.setenv(PKG_CXXFLAGS = "-ffp-contract=off -fno-fast-math")
  e <- new.env(parent = globalenv())
  Rcpp::sourceCpp(path,env = e,cacheDir = cache,rebuild = FALSE,showOutput = FALSE)
  stopifnot(e$qgp_test_timers())
  e
}
