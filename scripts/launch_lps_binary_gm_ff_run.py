#!/usr/bin/env python3
"""Failure-isolated launcher for LPS-BIN-GM-FF task runs."""

from __future__ import annotations

import argparse
import csv
import json
import pathlib
import socket
import subprocess
import time
from datetime import datetime


def now() -> str:
    return datetime.now().astimezone().strftime("%Y-%m-%d %H:%M:%S %Z")


def read_status(path: pathlib.Path) -> dict:
    try:
        return json.loads(path.read_text())
    except Exception:
        return {}


def write_error_status(
    row: dict,
    message: str,
    error_class: str,
    status: str,
    elapsed_sec: float | None,
    returncode: int | None,
) -> None:
    path = pathlib.Path(row["status_path"])
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "task_id": row["task_id"],
        "pair_id": row["pair_id"],
        "scenario_id": row["scenario_id"],
        "geometry_block": row["geometry_block"],
        "sample_n": int(row["sample_n"]),
        "method_id": row["method_id"],
        "chart_dim_rule": row["chart_dim_rule"],
        "status": status,
        "started_at": None,
        "finished_at": now(),
        "elapsed_sec": elapsed_sec,
        "hostname": socket.gethostname(),
        "pid": None,
        "returncode": returncode,
        "result_path": row["result_path"],
        "error_message": message,
        "error_class": error_class,
    }
    path.write_text(json.dumps(payload, indent=2) + "\n")


def is_complete(row: dict) -> bool:
    status_path = pathlib.Path(row["status_path"])
    result_path = pathlib.Path(row["result_path"])
    status = read_status(status_path)
    return (
        status.get("status") in {"ok", "nonfinite_fit"}
        and result_path.exists()
        and str(row.get("skip_if_complete", "")).lower() == "true"
    )


def launch_one(row: dict, worker: pathlib.Path) -> tuple[subprocess.Popen, object]:
    log_path = pathlib.Path(row["log_path"])
    log_path.parent.mkdir(parents=True, exist_ok=True)
    log_file = log_path.open("w")
    rscript = pathlib.Path("/usr/local/bin/Rscript")
    rscript_bin = str(rscript) if rscript.exists() else "Rscript"
    proc = subprocess.Popen(
        [
            rscript_bin,
            str(worker),
            f"--task_manifest={row['task_manifest']}",
            f"--task_id={row['task_id']}",
        ],
        stdout=log_file,
        stderr=subprocess.STDOUT,
    )
    return proc, log_file


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run_dir", required=True)
    parser.add_argument("--workers", type=int, default=14)
    parser.add_argument("--poll_sec", type=float, default=2.0)
    parser.add_argument("--task_timeout_sec", type=float, default=3600.0)
    args = parser.parse_args()

    run_dir = pathlib.Path(args.run_dir).resolve()
    task_manifest = run_dir / "task_manifest.csv"
    worker = pathlib.Path(
        "/Users/pgajer/current_projects/geosmooth/scripts/"
        "run_lps_binary_gm_ff_task.R"
    )
    summary = pathlib.Path(
        "/Users/pgajer/current_projects/geosmooth/scripts/"
        "summarize_lps_binary_gm_ff_run.R"
    )
    launcher_log = run_dir / "logs" / "python_launcher.log"
    launcher_log.parent.mkdir(parents=True, exist_ok=True)

    with task_manifest.open(newline="") as f:
        rows = list(csv.DictReader(f))
    for row in rows:
        row["task_manifest"] = str(task_manifest)

    pending = [row for row in rows if not is_complete(row)]
    running: list[tuple[dict, subprocess.Popen, object, float]] = []

    with launcher_log.open("a") as log:
        log.write(
            f"[{now()}] start workers={args.workers} "
            f"pending={len(pending)} total={len(rows)} "
            f"timeout_sec={args.task_timeout_sec:.1f}\n"
        )
        log.flush()

        while pending or running:
            while pending and len(running) < args.workers:
                row = pending.pop(0)
                proc, log_file = launch_one(row, worker)
                running.append((row, proc, log_file, time.time()))
                log.write(f"[{now()}] launched {row['task_id']} pid={proc.pid}\n")
                log.flush()

            still_running = []
            for row, proc, log_file, start in running:
                elapsed = time.time() - start
                if elapsed > args.task_timeout_sec and proc.poll() is None:
                    proc.kill()
                    log.write(
                        f"[{now()}] timeout {row['task_id']} "
                        f"elapsed_sec={elapsed:.1f} "
                        f"limit_sec={args.task_timeout_sec:.1f}\n"
                    )
                    log.flush()
                rc = proc.poll()
                if rc is None:
                    still_running.append((row, proc, log_file, start))
                    continue

                log_file.close()
                timed_out = elapsed > args.task_timeout_sec
                status = read_status(pathlib.Path(row["status_path"]))
                if rc != 0 and status.get("status") not in {"ok", "nonfinite_fit"}:
                    write_error_status(
                        row,
                        message=(
                            "worker exceeded task timeout; see task log"
                            if timed_out
                            else
                            "worker process exited nonzero or was killed; "
                            "see task log"
                        ),
                        error_class=(
                            f"task_timeout_{int(args.task_timeout_sec)}s"
                            if timed_out
                            else f"worker_exit_{rc}"
                        ),
                        status="timeout" if timed_out else "error",
                        elapsed_sec=elapsed,
                        returncode=rc,
                    )
                log.write(
                    f"[{now()}] finished {row['task_id']} rc={rc} "
                    f"elapsed_sec={elapsed:.1f}\n"
                )
                log.flush()
            running = still_running
            time.sleep(args.poll_sec)

        log.write(f"[{now()}] all workers complete; summarizing\n")
        log.flush()
        with (run_dir / "logs" / "summary_after_launch.log").open("w") as summary_log:
            subprocess.run(
                ["Rscript", str(summary), f"--run_dir={run_dir}"],
                stdout=summary_log,
                stderr=subprocess.STDOUT,
                check=False,
            )
        log.write(f"[{now()}] complete\n")
        log.flush()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
