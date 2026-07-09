#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT" || exit 1

DATE_TAG="$(date +%Y%m%d)"
REPORT_ROOT="$ROOT/dev/methods/lps/reports"
LOG_ROOT="$ROOT/dev/methods/lps/runs/csd_deg2_${DATE_TAG}"
mkdir -p "$LOG_ROOT"

CSD5_DIR="$REPORT_ROOT/csd5_deg2_coupled_kd_evaluation_${DATE_TAG}"
CSD6_DIR="$REPORT_ROOT/csd6_deg2_expanded_relative_regret_${DATE_TAG}"
CSD7_DIR="$REPORT_ROOT/csd7_deg2_task_failure_diagnostics_${DATE_TAG}"
CSD8_DIR="$REPORT_ROOT/csd8_deg2_candidate_cv_surface_audit_${DATE_TAG}"
CSD9_DIR="$REPORT_ROOT/csd9_deg2_robust_cv_selection_policy_audit_${DATE_TAG}"
STATUS_CSV="$LOG_ROOT/csd_deg2_step_status.csv"

printf "step,status,start,end,elapsed_sec,log,report_dir\n" > "$STATUS_CSV"

run_step() {
    local step="$1"
    local report_dir="$2"
    shift 2
    local log="$LOG_ROOT/${step}.log"
    local start_epoch end_epoch elapsed status
    local start_iso end_iso

    start_epoch="$(date +%s)"
    start_iso="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    echo "[$start_iso] START $step" | tee "$log"
    echo "Command: $*" >> "$log"
    "$@" >> "$log" 2>&1
    status="$?"
    end_epoch="$(date +%s)"
    end_iso="$(date '+%Y-%m-%d %H:%M:%S %Z')"
    elapsed=$((end_epoch - start_epoch))
    if [ "$status" -eq 0 ]; then
        echo "[$end_iso] OK $step (${elapsed}s)" | tee -a "$log"
        printf "%s,ok,%s,%s,%s,%s,%s\n" "$step" "$start_iso" "$end_iso" \
            "$elapsed" "$log" "$report_dir" >> "$STATUS_CSV"
    else
        echo "[$end_iso] ERROR $step (${elapsed}s), exit=$status" | tee -a "$log"
        printf "%s,error,%s,%s,%s,%s,%s\n" "$step" "$start_iso" "$end_iso" \
            "$elapsed" "$log" "$report_dir" >> "$STATUS_CSV"
    fi
    return "$status"
}

run_step csd5_deg2_run "$CSD5_DIR" \
    Rscript dev/methods/lps/ci/csd5_coupled_kd_evaluation_run.R \
    --degree=2 --report-dir="$CSD5_DIR"
if [ -d "$CSD5_DIR/tables" ]; then
    run_step csd5_deg2_render "$CSD5_DIR" \
        Rscript dev/methods/lps/ci/csd5_coupled_kd_evaluation_render.R \
        --report-dir="$CSD5_DIR"
fi

run_step csd6_deg2_run "$CSD6_DIR" \
    Rscript dev/methods/lps/ci/csd6_expanded_relative_regret_run.R \
    --degree=2 --report-dir="$CSD6_DIR"
if [ -d "$CSD6_DIR/tables" ]; then
    run_step csd6_deg2_render "$CSD6_DIR" \
        Rscript dev/methods/lps/ci/csd6_expanded_relative_regret_render.R \
        --report-dir="$CSD6_DIR"
    run_step csd7_deg2_render "$CSD7_DIR" \
        Rscript dev/methods/lps/ci/csd7_task_failure_diagnostics_render.R \
        --input-dir="$CSD6_DIR" --report-dir="$CSD7_DIR"
fi

run_step csd8_deg2_run "$CSD8_DIR" \
    Rscript dev/methods/lps/ci/csd8_candidate_cv_surface_audit_run.R \
    --degree=2 --report-dir="$CSD8_DIR"
if [ -d "$CSD8_DIR/tables" ] && [ -d "$CSD6_DIR/tables" ]; then
    run_step csd8_deg2_render "$CSD8_DIR" \
        Rscript dev/methods/lps/ci/csd8_candidate_cv_surface_audit_render.R \
        --report-dir="$CSD8_DIR" --csd6-dir="$CSD6_DIR"
    run_step csd9_deg2_render "$CSD9_DIR" \
        Rscript dev/methods/lps/ci/csd9_robust_cv_selection_policy_audit_render.R \
        --input-dir="$CSD8_DIR" --report-dir="$CSD9_DIR"
fi

echo "CSD-deg2 suite status: $STATUS_CSV"
