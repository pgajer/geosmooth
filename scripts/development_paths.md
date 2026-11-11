# Paths for development studies

Historical LPS/PS-LPS and logistic trend-filtering scripts retain their original
datasets, seeds, candidate grids and numerical settings. They are optional
research tools, not package build inputs. Run them from the package root with
`Rscript`; some historical scripts also read package-relative source files.

The scripts using `development_paths.R` accept these environment variables:

| Variable | Meaning | Default |
| --- | --- | --- |
| `GEOSMOOTH_SOURCE` | geosmooth source directory | Parent of the invoked script directory; current directory when sourced interactively |
| `DGRAPHS_SOURCE` | dgraphs source directory | Sibling `dgraphs` checkout |
| `LINF_SOURCE` | linf source directory | Sibling `linf` checkout |
| `TREND_FILTERING_SOURCE` | External trend-filtering study repository | Sibling `trend_filtering` checkout |
| `VALENCIA_DATA_DIR` | Directory containing the original VALENCIA input files | Sibling `valencia` directory |
| `GEOSMOOTH_RESEARCH_OUTPUT_DIR` | Root for historical study inputs and new result directories | External private development directory, grouped by package |

For historical LPS studies, the output root replaces the former
`split_handoffs` directory. Preserve each study's relative directory layout and
use an external copy of its original assets when reproducing a run. Point the
variable at that copy; the scripts do not move or regenerate missing inputs.
Keep previous runs separate from reruns. Missing external datasets remain
missing-data errors; no substitute datasets are selected automatically.

Python launchers locate their R workers beside the launcher script. Migration
comparisons additionally support `GEOSMOOTH_GFLOW_SOURCE` for the historical
gflow checkout and `GEOSMOOTH_SSRHE_VALIDATION` for the external SSRHE validation
runner. These comparisons skip when their reference implementation is absent.
