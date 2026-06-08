#!/usr/bin/env bash
set -euo pipefail
RUN_DIR='/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_light_20260607_001'
N_WORKERS=${N_WORKERS:-10}
TASK_TIMEOUT_SEC=${TASK_TIMEOUT_SEC:-7200}
cd '/Users/pgajer/current_projects/geosmooth'
python3 scripts/launch_ps_lps_s3r_light_run.py \
  --run_dir "${RUN_DIR}" \
  --workers "${N_WORKERS}" \
  --task_timeout_sec "${TASK_TIMEOUT_SEC}"
