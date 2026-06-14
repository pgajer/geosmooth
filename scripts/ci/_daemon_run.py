#!/usr/bin/env python3
# General detached launcher: double-fork into a new session and run argv[2:],
# redirecting stdout/stderr to the log file argv[1] and appending EXIT_RC.
#
# WHY: a harness-managed background task reaps its child at turn boundaries,
# which kills multi-hour runs (see phase_handoffs/e1_10_partB_implementer_handoff
# for the original diagnosis). Daemonizing detaches the command from the harness
# task tree so it completes regardless of turn lifecycle. It runs the command
# verbatim and inherits the environment (e.g. LPS_E110_ACCEPT); it does not
# alter parameters or bypass any script gate.
#
# Usage: [ENV=...] python3 scripts/ci/_daemon_run.py <log_path> <cmd> [args...]
import os
import sys
import subprocess

REPO = "/Users/pgajer/current_projects/geosmooth-e19"
LOG = sys.argv[1]
CMD = sys.argv[2:]
if not CMD:
    sys.stderr.write("usage: _daemon_run.py <log_path> <cmd> [args...]\n")
    sys.exit(2)

if os.fork() > 0:
    sys.exit(0)
os.setsid()
if os.fork() > 0:
    os._exit(0)
with open(LOG, "w") as log:
    os.chdir(REPO)
    rc = subprocess.call(CMD, stdout=log, stderr=subprocess.STDOUT)
    log.write("\nEXIT_RC=%d\n" % rc)
    log.flush()
os._exit(0)
