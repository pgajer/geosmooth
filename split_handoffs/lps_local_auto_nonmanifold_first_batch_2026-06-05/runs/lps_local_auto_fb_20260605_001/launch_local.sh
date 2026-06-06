#!/usr/bin/env bash
set -euo pipefail
RUN_DIR='/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/runs/lps_local_auto_fb_20260605_001'
TASK_MANIFEST='/Users/pgajer/current_projects/geosmooth/split_handoffs/lps_local_auto_nonmanifold_first_batch_2026-06-05/runs/lps_local_auto_fb_20260605_001/task_manifest.csv'
WORKER='/Users/pgajer/current_projects/geosmooth/scripts/run_lps_local_auto_first_batch_task.R'
MERGE_SCRIPT='/Users/pgajer/current_projects/geosmooth/scripts/merge_lps_local_auto_first_batch_run.R'
N_WORKERS=${N_WORKERS:-10}
export RUN_DIR TASK_MANIFEST WORKER MERGE_SCRIPT
mkdir -p "${RUN_DIR}/logs" "${RUN_DIR}/status" "${RUN_DIR}/results" "${RUN_DIR}/tables" "${RUN_DIR}/reports"
cut -d, -f1 "${TASK_MANIFEST}" | tail -n +2 | \
  xargs -n 1 -P "${N_WORKERS}" bash -c '
    set -u
    task_id="$1"
    log="${RUN_DIR}/logs/${task_id}.log"
    status_path="${RUN_DIR}/status/${task_id}.json"
    Rscript "${WORKER}" --task_manifest="${TASK_MANIFEST}" --task_id="${task_id}" > "${log}" 2>&1 || rc=$?
    rc=${rc:-0}
    if [ "${rc}" -ne 0 ]; then
      now=$(date +"%Y-%m-%d %H:%M:%S %Z")
      cat > "${status_path}" <<EOF
{
  "task_id": "${task_id}",
  "dataset_id": null,
  "chart_dim_rule": null,
  "status": "error",
  "started_at": null,
  "finished_at": "${now}",
  "elapsed_sec": null,
  "hostname": "$(hostname)",
  "pid": null,
  "result_path": null,
  "error_message": "worker process exited nonzero; see task log",
  "error_class": "worker_exit_${rc}"
}
EOF
    fi
    exit 0
  ' _
Rscript "${MERGE_SCRIPT}" --run_dir="${RUN_DIR}" > "${RUN_DIR}/logs/merge_after_launch.log" 2>&1 || true
