#!/bin/zsh
set -u
cd /Users/pgajer/current_projects/geosmooth
RUN_DIR=/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/runs/lps_local_auto_fb_20260605_001
exec python3 scripts/launch_lps_local_auto_first_batch_run.py --run_dir="$RUN_DIR" --workers=4 >> "$RUN_DIR/logs/python_launcher.nohup.log" 2>&1
