# PCA/PLS teaching vignette — 27 October 2026

The executable vignette `pca-pls-chart-comparison` compares ambient PCA,
unfolded PCA and unfolded PLS for binary responses on a two-face simplex.
Five scenarios and five predetermined seeds per scenario produce 25 independent
datasets. Each uses 180 training, 60 tuning and 120 held-out test observations.
Rank one is compared with ranks 1–3 selected by tuning Brier loss. Local/global
smoothed constants provide baselines. No cohort observations or fits are used.

## Measured examples

For the narrow signal, rank-one unfolded PCA and PLS have mean true-probability
MSE 0.047224 and 0.047291. After tuning dimension, they have MSE 0.044248 and
0.016198, respectively. All five tuned PLS fits select dimension three in this
scenario. Response-informed directions alone do not guarantee recovery at rank
one. The global constant is best by probability MSE in the constant scenario;
tuned PCA outperforms tuned PLS on average in the broad-signal scenario. These
are compact examples, not a powered simulation study or a universal ranking.

## Checks and outputs

`validate.R` verifies 200 unique result rows, complete method/scenario/repetition
coverage, finite probabilities, selection ranges, and independent score
arithmetic for 40 first-repetition result rows. All 900 displayed slice
predictions are finite probabilities. Reported rank-one/selected fits have zero
chart or optimizer fallbacks. Figure inspection confirms readable axes,
legends and known-truth references; browser inspection confirms the HTML layout,
navigation and interpretation. The rendered figures have descriptive alt text.

The source and package-navigation entries are tracked. Generated HTML, figures,
RDS audit data, all-repetition CSV, summary CSV and logs are under the ignored
`dev/html/pca-pls-vignette/` directory. Prose was refreshed from the saved
results without refitting unchanged models. The package build then checks the
complete vignette from source. This is not a full CRAN submission check.

Run from the package root with one numerical thread:

```sh
OMP_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 VECLIB_MAXIMUM_THREADS=1 \
  Rscript --vanilla dev/pca-pls-vignette/render.R
Rscript --vanilla dev/pca-pls-vignette/validate.R
```

`render.R` uses the verified optimized local builds of dgraphs and geosmooth
without recompiling; recompile optimized first if native sources have changed.
The user allowed six workers/30 GiB alongside other jobs; the vignette used one
numerical worker, with an observed resident footprint around 0.45 GiB during
fitting. No runtime-performance claim is made.

The full source-package build (`R CMD build --no-manual`) succeeded, executing
the vignette independently from the final Rmd. Its installed-document HTML
contains all four embedded figures and reproduces every displayed numerical
table exactly. Browser viewing over localhost and static link checks passed;
the API inventory remains complete. No full CRAN check was requested or run.
