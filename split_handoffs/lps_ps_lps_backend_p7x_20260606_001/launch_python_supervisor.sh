#!/usr/bin/env bash
set -euo pipefail
RUN_DIR='/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_ps_lps_backend_p7x_20260606_001'
N_WORKERS=${N_WORKERS:-14}
cd '/Users/pgajer/current_projects/geosmooth'
python3 scripts/launch_lps_ps_lps_backend_broader_p7x_run.py \
  --run_dir "${RUN_DIR}" \
  --workers "${N_WORKERS}"
