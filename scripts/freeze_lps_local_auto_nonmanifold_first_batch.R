#!/usr/bin/env Rscript

`%||%` <- function(x, y) if (is.null(x)) y else x

## Freeze auditable first-batch assets for comparing LPS
## chart.dim = "auto" versus chart.dim = "local.auto".

file.arg <- grep("^--file=", commandArgs(FALSE), value = TRUE)
script.path <- if (length(file.arg)) {
  sub("^--file=", "", file.arg[[1L]])
} else {
  "scripts/freeze_lps_local_auto_nonmanifold_first_batch.R"
}
repo <- normalizePath(file.path(dirname(script.path), ".."), mustWork = TRUE)
out.dir <- file.path(
  repo,
  "split_handoffs",
  "lps_local_auto_nonmanifold_first_batch_2026-06-05"
)
asset.dir <- file.path(out.dir, "assets")
dir.create(asset.dir, recursive = TRUE, showWarnings = FALSE)
freeze.id <- "2026-06-05_lps_local_auto_nonmanifold_first_batch"

sha256.file <- function(path) {
  out <- system2("shasum", c("-a", "256", shQuote(path)), stdout = TRUE)
  sub("[[:space:]].*$", "", out[[1L]])
}

write.csv.safe <- function(x, path) {
  utils::write.csv(x, file = path, row.names = FALSE, quote = TRUE)
}

load_linf <- function() {
  if (!exists("linf.hypercube.embedding", mode = "function")) {
    if (!requireNamespace("pkgload", quietly = TRUE)) {
      stop("pkgload is required to load linf from source.", call. = FALSE)
    }
    pkgload::load_all("/Users/pgajer/current_projects/linf", quiet = TRUE)
  }
}

load_rda_object <- function(path) {
  e <- new.env(parent = emptyenv())
  nm <- load(path, envir = e)
  if (length(nm) != 1L) {
    stop("Expected exactly one object in ", path, call. = FALSE)
  }
  e[[nm[[1L]]]]
}

l1_normalize <- function(X, keep.zero = FALSE) {
  X <- as.matrix(X)
  rs <- rowSums(X)
  keep <- if (keep.zero) is.finite(rs) else is.finite(rs) & rs > 0
  out <- X[keep, , drop = FALSE]
  rs <- rs[keep]
  out <- sweep(out, 1L, rs, "/")
  out[!is.finite(out)] <- 0
  out
}

stratified_sample <- function(labels, n, seed) {
  set.seed(seed)
  labels <- as.character(labels)
  tab <- table(labels)
  if (n > sum(tab)) {
    stop("Requested sample size exceeds available rows.", call. = FALSE)
  }
  raw <- as.numeric(tab) / sum(tab) * n
  capacity <- as.integer(tab)
  alloc <- pmin(floor(raw), capacity)
  while (sum(alloc) < n) {
    remaining <- capacity - alloc
    eligible <- which(remaining > 0L)
    if (!length(eligible)) break
    score <- raw - alloc
    score[remaining <= 0L] <- -Inf
    jj <- which.max(score)
    alloc[[jj]] <- alloc[[jj]] + 1L
  }
  if (sum(alloc) != n) {
    stop("Could not allocate requested stratified sample size.", call. = FALSE)
  }
  names(alloc) <- names(tab)
  sampled <- integer(0L)
  for (lab in names(alloc)) {
    idx <- which(labels == lab)
    if (alloc[[lab]] > 0L) {
      sampled <- c(sampled, sample(idx, alloc[[lab]]))
    }
  }
  sort(sampled)
}

farthest_centers <- function(X, k = 3L, seed = 1L) {
  set.seed(seed)
  n <- nrow(X)
  first <- sample.int(n, 1L)
  centers <- first
  dmin <- rowSums((X - matrix(X[first, ], n, ncol(X), byrow = TRUE))^2)
  while (length(centers) < k) {
    next.idx <- which.max(dmin)
    centers <- c(centers, next.idx)
    dnew <- rowSums((X - matrix(X[next.idx, ], n, ncol(X), byrow = TRUE))^2)
    dmin <- pmin(dmin, dnew)
  }
  centers
}

gaussian_mixture_truth <- function(X, seed = 1L) {
  X <- as.matrix(X)
  centers <- farthest_centers(X, k = 3L, seed = seed)
  D <- as.matrix(stats::dist(X))
  nonzero <- D[upper.tri(D)]
  nonzero <- nonzero[is.finite(nonzero) & nonzero > 0]
  base.scale <- if (length(nonzero)) {
    stats::quantile(nonzero, probs = 0.35, names = FALSE, type = 7)
  } else {
    1
  }
  if (!is.finite(base.scale) || base.scale <= 0) base.scale <- 1
  amps <- c(1.0, 0.75, 0.55)
  scales <- base.scale * c(0.75, 1.00, 1.25)
  f <- rep(0, nrow(X))
  for (j in seq_along(centers)) {
    d2 <- rowSums((X - matrix(X[centers[[j]], ], nrow(X), ncol(X),
                             byrow = TRUE))^2)
    f <- f + amps[[j]] * exp(-d2 / (2 * scales[[j]]^2))
  }
  f <- as.numeric(scale(f, center = TRUE, scale = FALSE))
  list(
    f = f,
    params = list(
      truth.id = "euclidean_three_gaussian_mixture",
      center.indices = centers,
      amplitudes = amps,
      scales = scales,
      base.scale = base.scale
    )
  )
}

make_foldid <- function(n, k = 5L, seed = 20260605L) {
  set.seed(seed)
  sample(rep(seq_len(k), length.out = n))
}

add_response <- function(asset, sigma = 0.10, response.seed = 1L,
                         fold.seed = 20260605L) {
  truth <- gaussian_mixture_truth(asset$X, seed = response.seed)
  set.seed(response.seed)
  eps <- stats::rnorm(nrow(asset$X), sd = sigma)
  asset$f <- truth$f
  asset$y <- truth$f + eps
  asset$sigma <- sigma
  asset$foldid <- make_foldid(nrow(asset$X), seed = fold.seed)
  asset$truth.params <- truth$params
  asset$response.seed <- response.seed
  asset$fold.seed <- fold.seed
  asset
}

save_asset <- function(asset) {
  path <- file.path(asset.dir, paste0(asset$dataset.id, ".rds"))
  saveRDS(asset, path, compress = "xz")
  info <- file.info(path)
  data.frame(
    batch.id = asset$batch.id,
    dataset.id = asset$dataset.id,
    geometry.family = asset$geometry.family,
    n = nrow(asset$X),
    p = ncol(asset$X),
    asset.path = path,
    bytes = as.numeric(info$size),
    sha256 = sha256.file(path),
    source.kind = asset$source.kind,
    stringsAsFactors = FALSE
  )
}

make_asset <- function(batch.id, dataset.id, geometry.family, X, labels,
                       source.kind, metadata = data.frame(), latent = NULL,
                       construction = list()) {
  X <- as.matrix(X)
  rownames(X) <- rownames(X) %||% sprintf("%s_%04d", dataset.id, seq_len(nrow(X)))
  stopifnot(nrow(X) == length(labels))
  list(
    batch.id = batch.id,
    dataset.id = dataset.id,
    geometry.family = geometry.family,
    X = X,
    latent = latent,
    region.label = as.character(labels),
    metadata = metadata,
    source.kind = source.kind,
    construction = construction,
    freeze.id = freeze.id
  )
}

source_paths <- list(
  valencia_tx = "/Users/pgajer/current_projects/valencia/tx.13k.rds",
  valencia_cst = "/Users/pgajer/current_projects/valencia/cst.tx.13k.rds",
  linf_depth2 = "/Users/pgajer/current_projects/linf/data/valencia13k_dcst_depth2_merged.rda",
  linf_depth3 = "/Users/pgajer/current_projects/linf/data/valencia13k_dcst_depth3_merged.rda",
  linf_hypercube_1k = "/Users/pgajer/current_projects/linf/data/valencia_linf_hypercube_1k.rda"
)
missing <- names(source_paths)[!file.exists(unlist(source_paths))]
if (length(missing)) {
  stop("Missing source paths: ", paste(missing, collapse = ", "), call. = FALSE)
}

load_linf()
tx <- readRDS(source_paths$valencia_tx)
cst <- readRDS(source_paths$valencia_cst)
depth2 <- load_rda_object(source_paths$linf_depth2)
depth3 <- load_rda_object(source_paths$linf_depth3)

cst$sample_id <- as.character(cst$sample_id)
stopifnot(identical(cst$sample_id, rownames(tx)))

component.map <- c(
  Li = "Lactobacillus_iners",
  Lc = "Lactobacillus_crispatus",
  Gv = "Gardnerella_vaginalis",
  Bv = "BVAB1"
)

make_component_profile <- function(labels, tx, sep = "__") {
  labels <- as.character(labels)
  out <- matrix(0, nrow = nrow(tx), ncol = length(labels))
  colnames(out) <- make.names(labels, unique = TRUE)
  rownames(out) <- rownames(tx)
  used <- vector("list", length(labels))
  for (j in seq_along(labels)) {
    parts <- unique(strsplit(labels[[j]], sep, fixed = TRUE)[[1L]])
    cols <- intersect(parts, colnames(tx))
    if (!length(cols)) {
      stop("No taxa matched dCST label: ", labels[[j]], call. = FALSE)
    }
    out[, j] <- rowSums(tx[, cols, drop = FALSE])
    used[[j]] <- cols
  }
  attr(out, "label_taxa") <- used
  l1_normalize(out)
}

records <- list()

## FB01-FB05: depth-1 raw and four hypercube charts on the same frozen n=500.
rel4.raw <- as.matrix(tx[, unname(component.map), drop = FALSE])
colnames(rel4.raw) <- names(component.map)
mass4 <- rowSums(rel4.raw)
keep4 <- mass4 > 0
rel4 <- sweep(rel4.raw[keep4, , drop = FALSE], 1L, mass4[keep4], "/")
meta4 <- cst[keep4, , drop = FALSE]
dominant4 <- colnames(rel4)[max.col(rel4, ties.method = "first")]
idx4 <- stratified_sample(dominant4, n = 500L, seed = 20260605L)
rel4.500 <- rel4[idx4, , drop = FALSE]
meta4.500 <- data.frame(
  sample_id = sprintf("fb_d1_%04d", seq_len(nrow(rel4.500))),
  source_row = which(keep4)[idx4],
  Val_CST = as.character(meta4$Val_CST[idx4]),
  Val_subCST = as.character(meta4$Val_subCST[idx4]),
  dominant_component = dominant4[idx4],
  selected_mass = mass4[keep4][idx4],
  stringsAsFactors = FALSE
)
rownames(rel4.500) <- meta4.500$sample_id

asset <- make_asset(
  "FB01", "LA-D1-RAW-N500", "VALENCIA depth-1 dCST",
  rel4.500, meta4.500$dominant_component, "valencia_depth1_raw",
  metadata = meta4.500,
  construction = list(component.map = component.map, sample.seed = 20260605L)
)
records[[length(records) + 1L]] <- save_asset(add_response(asset))

for (ref in names(component.map)) {
  emb <- linf.hypercube.embedding(rel4.500, reference = ref)
  batch <- switch(ref, Li = "FB02", Lc = "FB03", Gv = "FB04", Bv = "FB05")
  asset <- make_asset(
    batch, paste0("LA-D1-HC-", ref, "-N500"),
    "VALENCIA depth-1 hypercube",
    emb, meta4.500$dominant_component, "valencia_depth1_hypercube",
    metadata = meta4.500,
    construction = list(reference = ref, source.dataset = "LA-D1-RAW-N500")
  )
  records[[length(records) + 1L]] <- save_asset(add_response(asset))
}

## FB06-FB08: depth-2/depth-3 profiles and depth-2 TOP1 embedding.
make_depth_asset <- function(depth.object, depth.name, batch.id, dataset.id,
                             n = 500L, seed = 20260605L) {
  assign <- depth.object$assignments
  assignment.column <- paste0("dcst_", depth.name)
  if (!assignment.column %in% names(assign)) {
    stop("Missing assignment column: ", assignment.column, call. = FALSE)
  }
  labels <- depth.object$summaries[[depth.name]]$dcst_label
  Xall <- make_component_profile(labels, tx, sep = depth.object$params$sep)
  lab <- assign[[assignment.column]]
  idx <- stratified_sample(lab, n = n, seed = seed)
  X <- Xall[idx, , drop = FALSE]
  meta <- assign[idx, , drop = FALSE]
  rownames(X) <- sprintf("%s_%04d", dataset.id, seq_len(nrow(X)))
  meta$sample_id <- rownames(X)
  asset <- make_asset(
    batch.id, dataset.id, paste0("VALENCIA ", depth.name, " dCST"),
    X, lab[idx], paste0("valencia_", depth.name, "_raw"),
    metadata = meta,
    construction = list(
      dcst.labels = labels,
      sample.seed = seed,
      profile = "sum abundance over taxa named in each merged dCST label, then L1-normalize"
    )
  )
  add_response(asset)
}

d2.asset <- make_depth_asset(depth2, "depth2", "FB06", "LA-D2-RAW-N500")
records[[length(records) + 1L]] <- save_asset(d2.asset)
d2.top <- depth2$summaries$depth2$dcst_label[[which.max(depth2$summaries$depth2$n)]]
d2.ref <- make.names(d2.top, unique = TRUE)
d2.emb <- linf.hypercube.embedding(d2.asset$X, reference = d2.ref)
d2.hc <- make_asset(
  "FB07", "LA-D2-HC-TOP1-N500", "VALENCIA depth-2 hypercube",
  d2.emb, d2.asset$region.label, "valencia_depth2_hypercube",
  metadata = d2.asset$metadata,
  construction = list(reference = d2.ref, reference.original.label = d2.top,
                      source.dataset = "LA-D2-RAW-N500")
)
records[[length(records) + 1L]] <- save_asset(add_response(d2.hc))

d3.asset <- make_depth_asset(depth3, "depth3", "FB08", "LA-D3-RAW-N500")
records[[length(records) + 1L]] <- save_asset(d3.asset)

## FB09: full phylotype subsample.
idx.full <- stratified_sample(cst$Val_CST, n = 500L, seed = 20260605L)
Xfull <- as.matrix(tx[idx.full, , drop = FALSE])
nonzero.cols <- colSums(Xfull) > 0
Xfull <- l1_normalize(Xfull[, nonzero.cols, drop = FALSE], keep.zero = FALSE)
meta.full <- cst[idx.full, , drop = FALSE]
meta.full <- meta.full[seq_len(nrow(Xfull)), , drop = FALSE]
rownames(Xfull) <- sprintf("fb_full_%04d", seq_len(nrow(Xfull)))
meta.full$sample_id <- rownames(Xfull)
asset <- make_asset(
  "FB09", "LA-13K-SUB-N500", "VALENCIA full phylotype matrix",
  Xfull, meta.full$Val_CST, "valencia_full_phylotype",
  metadata = meta.full,
  construction = list(sample.seed = 20260605L,
                      transform = "relative abundance, no CLR, all-zero sampled columns removed")
)
records[[length(records) + 1L]] <- save_asset(add_response(asset))

## Synthetic geometry helpers.
sample_square <- function(n) cbind(stats::runif(n, -1, 1), stats::runif(n, -1, 1))

make_para_line <- function() {
  set.seed(1001)
  ns <- 375L; nl <- 125L
  uv <- sample_square(ns)
  surf <- cbind(uv[, 1], uv[, 2], uv[, 1]^2 + uv[, 2]^2)
  t <- stats::runif(nl, -1, 1)
  line <- cbind(t, rep(0, nl), 0.5 * t)
  X <- rbind(surf, line)
  labels <- c(rep("surface", ns), rep("line", nl))
  latent <- rbind(cbind(component = "surface", uv),
                  cbind(component = "line", u = t, v = 0))
  make_asset("FB10", "SYN-PARA-LINE-N500",
             "synthetic stratified surface/curve",
             X, labels, "synthetic", latent = latent,
             construction = list(seed = 1001L, surface.fraction = 0.75))
}

make_saddle_line <- function() {
  set.seed(1002)
  ns <- 375L; nl <- 125L
  uv <- sample_square(ns)
  surf <- cbind(uv[, 1], uv[, 2], uv[, 1]^2 - uv[, 2]^2)
  t <- stats::runif(nl, -1, 1)
  line <- cbind(t, rep(0, nl), t^2)
  X <- rbind(surf, line)
  labels <- c(rep("surface", ns), rep("line", nl))
  latent <- rbind(cbind(component = "surface", uv),
                  cbind(component = "line", u = t, v = 0))
  make_asset("FB11", "SYN-SADDLE-LINE-N500",
             "synthetic stratified surface/curve",
             X, labels, "synthetic", latent = latent,
             construction = list(seed = 1002L, surface.fraction = 0.75))
}

make_two_planes <- function() {
  set.seed(1003)
  n1 <- 300L; n2 <- 300L
  uv1 <- sample_square(n1)
  uv2 <- sample_square(n2)
  X1 <- cbind(uv1[, 1], uv1[, 2], 0)
  X2 <- cbind(uv2[, 1], 0, uv2[, 2])
  X <- rbind(X1, X2)
  labels <- c(rep("plane_1", n1), rep("plane_2", n2))
  make_asset("FB12", "SYN-TWO-PLANES-N600",
             "synthetic singular sheet union",
             X, labels, "synthetic",
             construction = list(seed = 1003L, planes = c("z=0", "y=0")))
}

make_simplex_faces <- function() {
  set.seed(1004)
  p <- 5L
  counts <- c(vertex = 120L, edge = 180L, face = 180L, interior = 120L)
  rows <- list(); labels <- character(0)
  for (kind in names(counts)) {
    for (i in seq_len(counts[[kind]])) {
      support.size <- switch(kind, vertex = 1L, edge = 2L, face = 3L,
                             interior = p)
      supp <- sample.int(p, support.size)
      alpha <- rep(0.25, support.size)
      vals <- stats::rgamma(support.size, shape = alpha, rate = 1)
      x <- rep(0, p)
      x[supp] <- vals / sum(vals)
      rows[[length(rows) + 1L]] <- x
      labels <- c(labels, kind)
    }
  }
  X <- do.call(rbind, rows)
  colnames(X) <- paste0("comp", seq_len(p))
  make_asset("FB13", "SYN-SIMPLEX-FACES-N600",
             "synthetic compositional strata",
             X, labels, "synthetic",
             construction = list(seed = 1004L, p = p, counts = counts))
}

make_rank_blocks <- function() {
  set.seed(1005)
  p <- 100L; n.per <- 200L
  Q <- qr.Q(qr(matrix(stats::rnorm(p * 4L), nrow = p)))
  make_block <- function(rank, label) {
    Z <- matrix(stats::rnorm(n.per * rank), nrow = n.per)
    X <- Z %*% t(Q[, seq_len(rank), drop = FALSE]) +
      matrix(stats::rnorm(n.per * p, sd = 0.03), nrow = n.per)
    list(X = X, label = rep(label, n.per), Z = Z)
  }
  b1 <- make_block(1L, "rank1")
  b2 <- make_block(2L, "rank2")
  b4 <- make_block(4L, "rank4")
  X <- rbind(b1$X, b2$X, b4$X)
  labels <- c(b1$label, b2$label, b4$label)
  colnames(X) <- paste0("x", seq_len(p))
  make_asset("FB14", "SYN-RANK-BLOCKS-N600-P100",
             "synthetic high-dimensional rank strata",
             X, labels, "synthetic",
             construction = list(seed = 1005L, p = p,
                                 n.per.region = n.per,
                                 effective.ranks = c(1L, 2L, 4L),
                                 noise.sd = 0.03))
}

for (asset in list(
  make_para_line(),
  make_saddle_line(),
  make_two_planes(),
  make_simplex_faces(),
  make_rank_blocks()
)) {
  records[[length(records) + 1L]] <- save_asset(add_response(asset))
}

manifest <- do.call(rbind, records)
manifest <- manifest[order(manifest$batch.id), ]
manifest.path <- file.path(out.dir, "asset_manifest.csv")
write.csv.safe(manifest, manifest.path)

source.path.vector <- unname(unlist(source_paths, use.names = FALSE))
source.manifest <- data.frame(
  source.name = names(source_paths),
  source.path = source.path.vector,
  bytes = as.numeric(file.info(source.path.vector)$size),
  sha256 = vapply(source.path.vector, sha256.file, character(1L)),
  stringsAsFactors = FALSE
)
write.csv.safe(source.manifest, file.path(out.dir, "source_manifest.csv"))

summary.path <- file.path(out.dir, "freeze_summary.md")
cat(
  "# LPS Local-Auto Non-Manifold First-Batch Freeze\n\n",
  "Freeze ID: `", freeze.id, "`\n\n",
  "Assets: ", nrow(manifest), "\n\n",
  "Output directory: `", out.dir, "`\n\n",
  "Each asset is an `.rds` list with geometry `X`, labels, metadata, ",
  "truth vector `f`, noisy response `y`, `sigma = 0.10`, and `foldid`.\n\n",
  "The `.rds` assets are intentionally ignored by git; this directory's ",
  "CSV manifests and this summary provide auditable file paths and hashes.\n\n",
  sep = "",
  file = summary.path
)

cat("Frozen", nrow(manifest), "assets in", out.dir, "\n")
print(manifest[, c("batch.id", "dataset.id", "n", "p", "sha256")],
      row.names = FALSE)
