#!/usr/bin/env Rscript

root <- normalizePath(file.path(Sys.getenv("HOME"), "current_projects", "geosmooth"),
                      mustWork = TRUE)
out.dir <- file.path(root, "split_handoffs", "experiment_catalogue_20260608")
dir.create(out.dir, recursive = TRUE, showWarnings = FALSE)

timestamp <- function() {
    format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z", tz = "America/New_York")
}

read.csv.safe <- function(path) {
    if (!file.exists(path)) return(data.frame())
    utils::read.csv(path, stringsAsFactors = FALSE, check.names = FALSE)
}

html.escape <- function(x) {
    x <- as.character(x)
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    x <- gsub(">", "&gt;", x, fixed = TRUE)
    x <- gsub('"', "&quot;", x, fixed = TRUE)
    x
}

rel.home <- function(path) {
    path <- as.character(path)
    gsub(paste0("^", normalizePath(Sys.getenv("HOME"), mustWork = TRUE)),
         "~", path)
}

file.link <- function(path, label = NULL) {
    if (is.null(label)) label <- basename(path)
    sprintf('<a href="file://%s">%s</a>', html.escape(path), html.escape(label))
}

small.table <- function(x, max.rows = 20, digits = 4, raw.cols = character()) {
    if (is.null(x) || !nrow(x)) return("<p class=\"muted\">No rows available.</p>")
    y <- x
    if (nrow(y) > max.rows) y <- y[seq_len(max.rows), , drop = FALSE]
    for (nm in names(y)) {
        if (is.numeric(y[[nm]])) y[[nm]] <- signif(y[[nm]], digits)
    }
    header <- paste(sprintf("<th>%s</th>", html.escape(names(y))), collapse = "")
    rows <- apply(y, 1L, function(row) {
        cells <- mapply(
            function(value, name) {
                if (name %in% raw.cols) {
                    sprintf("<td>%s</td>", as.character(value))
                } else {
                    sprintf("<td>%s</td>", html.escape(value))
                }
            },
            row,
            names(row),
            USE.NAMES = FALSE
        )
        paste0("<tr>", paste(cells, collapse = ""), "</tr>")
    })
    more <- if (nrow(x) > nrow(y)) {
        sprintf("<p class=\"muted\">Showing %d of %d rows.</p>", nrow(y), nrow(x))
    } else ""
    paste0("<table><thead><tr>", header, "</tr></thead><tbody>",
           paste(rows, collapse = "\n"), "</tbody></table>", more)
}

p7.dir <- file.path(Sys.getenv("HOME"), "current_projects", "trend_filtering",
                    "development", "slpl_tf", "experiments",
                    "p7_prospective_synthetic_suite")
codex.asset.note <- file.path(Sys.getenv("HOME"), ".codex", "notes", "references",
                              "evaluation_datasets",
                              "method_evaluation_dataset_asset_index.md")
codex.ff.note <- file.path(Sys.getenv("HOME"), ".codex", "notes", "references",
                           "evaluation_datasets",
                           "frank_friedman_style_factorial_design_for_method_evaluation.md")

p7.geom <- read.csv.safe(file.path(p7.dir, "config", "p7_geometry_registry.csv"))
p7.truth <- read.csv.safe(file.path(p7.dir, "config", "p7_synthetic_truth_registry.csv"))
p7.methods <- read.csv.safe(file.path(p7.dir, "config", "p7_baseline_method_registry.csv"))
p7x.geom <- read.csv.safe(file.path(p7.dir, "config", "p7x_geometry_registry.csv"))
p7x.truth <- read.csv.safe(file.path(p7.dir, "config", "p7x_truth_registry.csv"))
p7x.methods <- read.csv.safe(file.path(p7.dir, "config", "p7x_method_registry.csv"))

first.batch.dir <- file.path(root, "split_handoffs",
                             "lps_local_auto_nonmanifold_first_batch_2026-06-05")
first.assets <- read.csv.safe(file.path(first.batch.dir, "asset_manifest.csv"))
binary.compact.dir <- file.path(root, "split_handoffs",
                                "lps_binary_p7x_density_comparison_20260608_001")
binary.factorial.dir <- file.path(root, "split_handoffs",
                                  "lps_binary_p7x_factorial_comparison_20260608_001")
binary.compact.tasks <- read.csv.safe(file.path(binary.compact.dir, "task_manifest.csv"))
binary.factorial.tasks <- read.csv.safe(file.path(binary.factorial.dir, "task_manifest.csv"))
binary.factorial.profiles <- read.csv.safe(file.path(binary.factorial.dir,
                                                     "probability_surface_manifest.csv"))
s3r.dir <- file.path(root, "split_handoffs",
                     "ps_lps_s3r_expanded_seedmatched_repaired_20260608_001")
s3r.tasks <- read.csv.safe(file.path(s3r.dir, "task_manifest.csv"))

truth.summary <- function(x) {
    if (!nrow(x)) return(data.frame())
    aggregate(
        list(n.truths = rep(1L, nrow(x))),
        by = list(truth.family = x$truth.family,
                  component.count = x$component.count),
        FUN = sum
    )
}

method.status.summary <- function(x) {
    if (!nrow(x)) return(data.frame())
    if (!("status" %in% names(x))) return(data.frame())
    aggregate(list(n.methods = rep(1L, nrow(x))),
              by = list(status = x$status, method.family = x$method.family),
              FUN = sum)
}

task.factor.summary <- function(x, cols) {
    if (!nrow(x)) return(data.frame())
    cols <- cols[cols %in% names(x)]
    if (!length(cols)) return(data.frame())
    aggregate(list(n.tasks = rep(1L, nrow(x))),
              by = x[, cols, drop = FALSE],
              FUN = sum)
}

make.binary.core.design <- function() {
    geometries <- data.frame(
        geometry.block = c(
            "1d_native_interval",
            "1d_highdim_pad100",
            "2d_native_square",
            "2d_curved_paraboloid",
            "2d_curved_saddle",
            "2d_highdim_diag100",
            "3d_native_cube",
            "3d_highdim_diag99"
        ),
        source.geometry.id = c(
            "p7c_ctrl_1d_unit_interval_n200_seed101 / regenerate at requested n",
            "p7c_hd_1d_noisy_embed100_n200_seed401 / regenerate at requested n",
            "p7c_ctrl_2d_unit_square_n400_seed201 / regenerate at requested n",
            "p7c_ctrl_2d_paraboloid_n400_seed202 / regenerate at requested n",
            "p7c_ctrl_2d_saddle_n400_seed203 / regenerate at requested n",
            "p7c_hd_2d_diagonal_embed100_n400_seed402 / regenerate at requested n",
            "p7c_ctrl_3d_unit_cube_n600_seed301 / regenerate at requested n",
            "p7c_hd_3d_diagonal_embed99_n600_seed403 / regenerate at requested n"
        ),
        intrinsic.dimension = c(1, 1, 2, 2, 2, 2, 3, 3),
        ambient.dimension = c(1, 100, 2, 3, 3, 100, 3, 99),
        embedding.family = c(
            "identity",
            "latent coordinate plus 99 nuisance coordinates",
            "identity",
            "paraboloid x=(u,v,u^2+v^2)",
            "saddle x=(u,v,u^2-v^2)",
            "diagonal 2D-to-100 embedding with small noise",
            "identity",
            "diagonal 3D-to-99 embedding with small noise"
        ),
        stringsAsFactors = FALSE
    )
    profiles <- data.frame(
        probability.profile = c(
            "balanced_signed_smooth",
            "low_prevalence_signed_smooth",
            "balanced_tail_smooth",
            "low_prevalence_central_smooth"
        ),
        profile.transform = c("signed", "signed", "tail", "central"),
        target.prevalence = c(0.50, 0.20, 0.50, 0.20),
        profile.score = c("z", "z", "|z|", "-|z|"),
        stringsAsFactors = FALSE
    )
    truth.components <- data.frame(
        gaussian.components = c(2L, 3L, 4L),
        truth.family = c("latent_two_gaussian_mixture",
                         "latent_three_gaussian_mixture",
                         "latent_four_gaussian_mixture"),
        amplitude.rule = c("1.00|0.70",
                           "1.00|0.75|0.55",
                           "1.00|0.78|0.60|0.45"),
        bandwidth.rule = c("dimension-specific smooth, non-spiky",
                           "dimension-specific smooth, non-spiky",
                           "dimension-specific smooth, non-spiky"),
        stringsAsFactors = FALSE
    )
    sample.sizes <- data.frame(
        sample.size.policy = c("n250", "n500", "n1000"),
        sample.n.target = c(250L, 500L, 1000L),
        sample.notes = c("small but informative", "medium routine run",
                         "larger stress run where feasible"),
        stringsAsFactors = FALSE
    )
    out <- merge(merge(merge(geometries, truth.components), profiles), sample.sizes)
    out <- out[order(out$geometry.block, out$gaussian.components,
                     out$probability.profile, out$sample.n.target), ]
    out$suite.id <- "LPS-BIN-GM-FF"
    out$scenario.id <- sprintf(
        "LPS-BIN-GM-FF-%s-K%d-%s-%s",
        toupper(gsub("[^A-Za-z0-9]+", "-", out$geometry.block)),
        out$gaussian.components,
        toupper(gsub("[^A-Za-z0-9]+", "-", out$probability.profile)),
        toupper(out$sample.size.policy)
    )
    out$materialization.status <- "planned"
    out$profile.formula <- "p_i = eps + (1 - 2 eps) logit^{-1}(alpha + beta h_i), alpha chosen to match target prevalence"
    out$profile.parameters <- "eps=0.02; beta=1.25; z=clip((f-median(f))/MAD(f), -4, 4)"
    out$method.arms <- "lps_bernoulli_brier; lps_binomial_logistic"
    out$chart.rules <- "auto; local.auto"
    out$replicates.recommended <- 10L
    out[, c("suite.id", "scenario.id", "geometry.block", "source.geometry.id",
            "intrinsic.dimension", "ambient.dimension", "embedding.family",
            "gaussian.components", "truth.family", "amplitude.rule",
            "bandwidth.rule", "probability.profile", "profile.transform",
            "target.prevalence", "profile.score", "sample.size.policy",
            "sample.n.target", "materialization.status", "profile.formula",
            "profile.parameters", "method.arms", "chart.rules",
            "replicates.recommended", "sample.notes")]
}

binary.core.design <- make.binary.core.design()
utils::write.csv(binary.core.design,
                 file.path(out.dir, "lps_binary_gaussian_factorial_design_manifest.csv"),
                 row.names = FALSE)

core.scenarios <- nrow(binary.core.design)
core.tasks <- core.scenarios * 10L * 2L * 2L
core.pairs <- core.scenarios * 10L * 2L

experiment.rows <- data.frame(
    design = c(
        "S7 Smoke 1D dense surface",
        "S7 multishape / hard nonquadform 1D",
        "S7 RRT constant probe",
        "S7 2D geometry support sweep",
        "P7 prospective synthetic suite",
        "P7e full controlled run",
        "P7X-GS registry and GS2-light",
        "LPS local.auto non-manifold first batch",
        "PS-LPS S3R expanded repaired",
        "Binary LPS compact draft",
        "Binary LPS factorial draft",
        "Proposed binary Gaussian factorial"
    ),
    role = c(
        "SLPLiFT parameter-surface smoke",
        "1D selector robustness",
        "risk-response transform sanity check",
        "2D selector transfer",
        "prospective smoother/baseline comparison",
        "controlled P7 execution report",
        "realism-oriented geometry suite",
        "local/global chart-dim LPS comparison",
        "PS-LPS full versus screened policy",
        "small binary outcome draft",
        "expanded binary outcome draft over first-batch assets",
        "recommended next binary outcome study"
    ),
    primary.assets = c(
        "/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/validation/phase_s7_smoke_outputs/",
        "/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/validation/phase_s7_smoke_outputs/stage_c1_hard_nonquadform_nbhd10/",
        "/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/validation/phase_s7_rrt_c0a_constant_probe_outputs/",
        "/Users/pgajer/current_projects/trend_filtering/development/slpl_tf/validation/phase_s7_2d_geometry_outputs/",
        p7.dir,
        file.path(p7.dir, "reports", "p7e_full_controlled", "slplitf_p7e_full_controlled_report.html"),
        file.path(p7.dir, "reports", "p7x_gs2_light_full_20260606", "p7x_gs2_light_paired_method_comparison.html"),
        first.batch.dir,
        file.path(s3r.dir, "reports", "ps_lps_s3r_expanded_repaired_results_report.html"),
        binary.compact.dir,
        binary.factorial.dir,
        file.path(out.dir, "lps_binary_gaussian_factorial_design_manifest.csv")
    ),
    status = c(
        "materialized",
        "materialized",
        "materialized",
        "materialized",
        "registry/materialized subsets",
        "materialized report",
        "registry/materialized GS2-light",
        "materialized",
        "materialized repaired report",
        "draft manifest",
        "draft manifest",
        "planned design"
    ),
    stringsAsFactors = FALSE
)
utils::write.csv(experiment.rows,
                 file.path(out.dir, "experiment_catalogue_index.csv"),
                 row.names = FALSE)

p7.truth.view <- p7.truth[, intersect(c("truth.id", "geometry.id", "truth.family",
                                        "coordinate.domain", "component.count",
                                        "center.spec", "amplitude.spec",
                                        "bandwidth.spec", "notes"),
                                      names(p7.truth)), drop = FALSE]
p7x.truth.view <- p7x.truth[, intersect(c("truth.id", "dataset.id", "block.id",
                                          "truth.family", "coordinate.domain",
                                          "component.count", "materialization.status",
                                          "gs1.eligible", "reuse.status", "notes"),
                                        names(p7x.truth)), drop = FALSE]
first.assets.view <- first.assets[, intersect(c("batch.id", "dataset.id",
                                                "geometry.family", "n", "p",
                                                "source.kind", "sha256"),
                                              names(first.assets)), drop = FALSE]

css <- "
body{font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;margin:0;color:#1f2933;background:#f7f8fa;}
main{max-width:1180px;margin:0 auto;padding:32px 28px 60px;background:white;box-shadow:0 0 0 1px #e5e7eb;}
h1{font-size:32px;margin:0 0 8px;}
h2{font-size:22px;margin-top:34px;border-top:1px solid #e5e7eb;padding-top:22px;}
h3{font-size:17px;margin-top:24px;}
p,li{line-height:1.55;}
.muted{color:#5f6b7a;}
.callout{background:#eef6ff;border-left:4px solid #2f6fed;padding:12px 16px;margin:18px 0;}
.warn{background:#fff7ed;border-left:4px solid #f59e0b;padding:12px 16px;margin:18px 0;}
.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(210px,1fr));gap:12px;margin:18px 0;}
.card{border:1px solid #d8dee6;border-radius:8px;padding:14px;background:#fbfcfd;}
.metric{font-size:24px;font-weight:700;margin-bottom:4px;}
table{border-collapse:collapse;width:100%;font-size:13px;margin:12px 0 18px;}
th,td{border:1px solid #d8dee6;padding:7px 8px;text-align:left;vertical-align:top;}
th{background:#f0f3f7;}
code{background:#f2f4f7;padding:1px 4px;border-radius:4px;}
a{color:#1f5fbf;text-decoration:none;} a:hover{text-decoration:underline;}
"

catalogue.table <- experiment.rows
catalogue.table$design <- mapply(
    function(design, path) file.link(path, design),
    catalogue.table$design,
    catalogue.table$primary.assets,
    USE.NAMES = FALSE
)
catalogue.table$primary.assets <- NULL

html <- paste0(
'<!doctype html><html><head><meta charset="utf-8"><title>Experimental Design Catalogue</title>',
'<style>', css, '</style></head><body><main>',
'<h1>Experimental Design Catalogue</h1>',
'<p class="muted">Generated ', html.escape(timestamp()), '. This dashboard indexes past smoothing, local-chart, SLPLiFT, LPS, PS-LPS, and binary-outcome experimental designs and records the proposed binary Gaussian factorial study.</p>',
'<div class="callout"><strong>Main correction.</strong> The current binary factorial draft transforms only one frozen first-batch continuous truth family, the Euclidean three-Gaussian mixture. The next binary study should cross two-, three-, and four-Gaussian latent truth families with the four binary probability transforms across 1D, 2D, 3D, and high-dimensional embeddings.</div>',
'<h2>Notes Consulted</h2><ul>',
'<li>', file.link(codex.asset.note, rel.home(codex.asset.note)), '</li>',
'<li>', file.link(codex.ff.note, rel.home(codex.ff.note)), '</li>',
'</ul>',
'<h2>Catalogue Overview</h2>', small.table(catalogue.table, max.rows = 30,
                                          raw.cols = "design"),
'<h2>Past Design Snapshots</h2>',
'<h3>P7 Prospective Synthetic Suite</h3>',
'<p>P7 is the controlled prospective suite that already contains the desired continuous truth diversity: quadratic controls, two-Gaussian 1D/HD1 truths, three-Gaussian 2D/HD2/16S truths, and four-Gaussian 3D/HD3 truths.</p>',
'<div class="grid">',
'<div class="card"><div class="metric">', nrow(p7.geom), '</div><div>P7 geometries</div></div>',
'<div class="card"><div class="metric">', nrow(p7.truth), '</div><div>P7 truth rows</div></div>',
'<div class="card"><div class="metric">', nrow(p7.methods), '</div><div>P7 baseline/primary methods</div></div>',
'</div>',
'<h4>P7 truth-family summary</h4>', small.table(truth.summary(p7.truth), max.rows = 50),
'<h4>P7 truth registry excerpt</h4>', small.table(p7.truth.view, max.rows = 20),
'<h3>P7X-GS Registry</h3>',
'<p>P7X-GS is the realism-oriented geometry suite. It records controlled manifolds, high-dimensional embeddings, heterogeneous/non-manifold examples, and 16S-derived geometries. It is broader in geometry than P7, but its currently reused first-batch assets are not broad in continuous truth family.</p>',
'<div class="grid">',
'<div class="card"><div class="metric">', nrow(p7x.geom), '</div><div>P7X geometry rows</div></div>',
'<div class="card"><div class="metric">', nrow(p7x.truth), '</div><div>P7X truth rows</div></div>',
'<div class="card"><div class="metric">', nrow(p7x.methods), '</div><div>P7X method rows</div></div>',
'</div>',
'<h4>P7X truth-family summary</h4>', small.table(truth.summary(p7x.truth), max.rows = 60),
'<h4>P7X truth registry excerpt</h4>', small.table(p7x.truth.view, max.rows = 24),
'<h3>LPS Local-Auto Non-Manifold First Batch</h3>',
'<p>This first-batch asset set is excellent for local/global dimension behavior and non-manifold geometry, but all 14 frozen assets use the same continuous truth family: <code>euclidean_three_gaussian_mixture</code>. That makes it insufficient by itself for the requested binary Gaussian truth-family study.</p>',
'<div class="grid">',
'<div class="card"><div class="metric">', nrow(first.assets), '</div><div>frozen assets</div></div>',
'<div class="card"><div class="metric">14</div><div>three-Gaussian truth assets</div></div>',
'<div class="card"><div class="metric">1</div><div>continuous truth family</div></div>',
'</div>',
small.table(first.assets.view, max.rows = 20),
'<h3>Existing Binary LPS Drafts</h3>',
'<p>The compact binary draft had fewer probability profiles and no explicit sample-size factor. The richer factorial draft adds four probability transforms and two sample-size policies, but still inherits only the first-batch three-Gaussian continuous truth family.</p>',
'<div class="grid">',
'<div class="card"><div class="metric">', nrow(binary.compact.tasks), '</div><div>compact draft tasks</div></div>',
'<div class="card"><div class="metric">', nrow(binary.factorial.tasks), '</div><div>factorial draft tasks</div></div>',
'<div class="card"><div class="metric">', length(unique(binary.factorial.tasks$probability_profile)), '</div><div>probability profiles</div></div>',
'<div class="card"><div class="metric">', paste(unique(binary.factorial.tasks$sample_policy), collapse = ', '), '</div><div>sample-size policies</div></div>',
'</div>',
'<h4>Binary factorial draft task factors</h4>',
small.table(task.factor.summary(binary.factorial.tasks,
                                c("probability_profile", "sample_policy",
                                  "method_id", "chart_dim_rule")), max.rows = 50),
'<h2>Proposed Study: LPS-BIN-GM-FF</h2>',
'<p>The proposed next study uses a Frank/Friedman-style controlled factorial design. Its purpose is to test binary-outcome LPS modes under genuine truth-family diversity, not merely probability transforms of one three-Gaussian surface.</p>',
'<div class="warn"><strong>Design target.</strong> Cross latent Gaussian component count <code>K in {2,3,4}</code> with the four probability profiles, sample size, chart-dimension rule, and binary LPS method, across native and high-dimensional 1D/2D/3D geometries.</div>',
'<div class="grid">',
'<div class="card"><div class="metric">', core.scenarios, '</div><div>planned scenario cells before repetitions/methods</div></div>',
'<div class="card"><div class="metric">', core.tasks, '</div><div>planned tasks at 10 reps, 2 methods, 2 chart rules</div></div>',
'<div class="card"><div class="metric">', core.pairs, '</div><div>paired method comparisons at 10 reps</div></div>',
'</div>',
'<h3>Probability Profiles</h3>',
'<p>For a continuous latent truth vector <code>f</code>, define <code>z = clip((f - median(f))/MAD(f), -4, 4)</code>. Then set <code>p_i = eps + (1 - 2 eps) logit^{-1}(alpha + beta h_i)</code>, with <code>eps = 0.02</code>, <code>beta = 1.25</code>, and <code>alpha</code> chosen so that the mean probability equals the target prevalence.</p>',
small.table(unique(binary.core.design[, c("probability.profile", "profile.transform",
                                          "target.prevalence", "profile.score",
                                          "profile.parameters")]), max.rows = 10),
'<h3>Core Scenario Registry</h3>',
'<p>The full planned registry is saved as ',
file.link(file.path(out.dir, "lps_binary_gaussian_factorial_design_manifest.csv"),
          "lps_binary_gaussian_factorial_design_manifest.csv"), '.</p>',
small.table(binary.core.design[, c("scenario.id", "geometry.block",
                                   "intrinsic.dimension", "ambient.dimension",
                                   "gaussian.components", "probability.profile",
                                   "sample.size.policy")], max.rows = 36),
'<h3>Recommended Execution Tiers</h3>',
'<ul>',
'<li><strong>Smoke:</strong> one sample size, 2 repetitions, all geometry blocks, all K values, all four profiles, both methods, both chart rules.</li>',
'<li><strong>Overnight:</strong> sample sizes <code>n250</code> and <code>n500</code>, 5 repetitions, failure-isolated workers.</li>',
'<li><strong>Full:</strong> sample sizes <code>n250</code>, <code>n500</code>, and <code>n1000</code>, 10 repetitions, plus optional 16S real-geometry graph-Gaussian extension.</li>',
'</ul>',
'<h3>Open Implementation Notes</h3>',
'<ul>',
'<li>The generator should reuse P7 materialization helpers where possible, but regenerate synthetic geometries at the requested sample sizes rather than forcing old <code>n=200/400/600</code> assets into a sample-size study.</li>',
'<li>The real-geometry 16S extension should remain separate from the core latent Gaussian design, because graph-Gaussian truth over VALENCIA geometries is not the same object as a latent Euclidean Gaussian mixture.</li>',
'<li>Every task must record status, response seed, fold seed, sample seed, probability-surface ID, selected tuning parameters, Brier score, log loss, Truth RMSE to probability, runtime, and fallback/convergence telemetry.</li>',
'</ul>',
'<h2>Source Links</h2><ul>',
'<li>', file.link(file.path(out.dir, "experiment_catalogue_index.csv"), "experiment_catalogue_index.csv"), '</li>',
'<li>', file.link(file.path(out.dir, "lps_binary_gaussian_factorial_design_manifest.csv"), "lps_binary_gaussian_factorial_design_manifest.csv"), '</li>',
'<li>', file.link(file.path(p7.dir, "config", "p7_geometry_registry.csv"), "p7_geometry_registry.csv"), '</li>',
'<li>', file.link(file.path(p7.dir, "config", "p7_synthetic_truth_registry.csv"), "p7_synthetic_truth_registry.csv"), '</li>',
'<li>', file.link(file.path(p7.dir, "config", "p7x_geometry_registry.csv"), "p7x_geometry_registry.csv"), '</li>',
'<li>', file.link(file.path(p7.dir, "config", "p7x_truth_registry.csv"), "p7x_truth_registry.csv"), '</li>',
'<li>', file.link(file.path(binary.factorial.dir, "experiment_spec.md"), "current binary factorial draft spec"), '</li>',
'</ul>',
'</main></body></html>')

html.path <- file.path(out.dir, "experiment_catalogue_dashboard.html")
writeLines(html, html.path)

md <- c(
    "# Experimental Design Catalogue",
    "",
    paste0("Generated: ", timestamp()),
    "",
    "Primary HTML dashboard:",
    "",
    paste0("- `", html.path, "`"),
    "",
    "Core generated files:",
    "",
    paste0("- `", file.path(out.dir, "experiment_catalogue_index.csv"), "`"),
    paste0("- `", file.path(out.dir, "lps_binary_gaussian_factorial_design_manifest.csv"), "`"),
    "",
    "Main correction recorded in the dashboard:",
    "",
    "- The existing binary factorial draft transforms one frozen first-batch continuous truth family: Euclidean three-Gaussian mixture.",
    "- The proposed next binary study, `LPS-BIN-GM-FF`, crosses two-, three-, and four-Gaussian latent truth families with four probability transforms across native and high-dimensional 1D/2D/3D settings.",
    "",
    "Planned core design size:",
    "",
    paste0("- Scenario cells before repetitions/methods: ", core.scenarios),
    paste0("- Tasks at 10 repetitions, two chart rules, and two methods: ", core.tasks),
    paste0("- Paired method comparisons at that size: ", core.pairs),
    "",
    "Notes consulted:",
    "",
    paste0("- `", codex.asset.note, "`"),
    paste0("- `", codex.ff.note, "`")
)
writeLines(md, file.path(out.dir, "README.md"))

cat("Wrote dashboard:", html.path, "\n")
cat("Wrote manifest:", file.path(out.dir, "lps_binary_gaussian_factorial_design_manifest.csv"), "\n")
