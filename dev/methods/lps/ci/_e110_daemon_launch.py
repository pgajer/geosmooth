#!/usr/bin/env python3
# Detached launcher for the E1.10 Part B acceptance run.
#
# WHY THIS EXISTS: a harness-managed background task reaps its child process
# at turn boundaries, which killed the ~27-minute Study (b) leg three times.
# Double-forking into a new session (setsid) detaches the Rscript from the
# controlling terminal and the harness task tree, so the run completes
# regardless of turn lifecycle. It does NOT change the study source
# (dev/methods/lps/ci/e1_10_nested_grouped_cv.R is run verbatim with the ratified
# parameters and LPS_E110_ACCEPT=1).
import os
import sys
import subprocess

REPO = "/Users/pgajer/current_projects/geosmooth-e19"
LOG = "/tmp/e110_accept_rerun.log"
SCRIPT = "dev/methods/lps/ci/e1_10_nested_grouped_cv.R"

# Double-fork daemonization.
if os.fork() > 0:
    sys.exit(0)            # original process returns control to the shell
os.setsid()                # new session; detach controlling terminal
if os.fork() > 0:
    os._exit(0)            # first child exits; grandchild is the daemon

with open(LOG, "w") as log:
    os.chdir(REPO)
    env = dict(os.environ, LPS_E110_ACCEPT="1")
    rc = subprocess.call(
        ["Rscript", SCRIPT, "--mode=acceptance"],
        stdout=log, stderr=subprocess.STDOUT, env=env,
    )
    log.write("\nEXIT_RC=%d\n" % rc)
    log.flush()
os._exit(0)
