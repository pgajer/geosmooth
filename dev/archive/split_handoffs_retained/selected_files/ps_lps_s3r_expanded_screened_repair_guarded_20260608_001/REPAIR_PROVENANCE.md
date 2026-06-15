# PS-LPS S3R-Expanded Screened Repair Bundle

Source run: `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_seedmatched_20260607_001`
Repair bundle: `/Users/pgajer/current_projects/geosmooth/split_handoffs/ps_lps_s3r_expanded_screened_repair_guarded_20260608_001`

This bundle reruns only the 51 screened-policy tasks that had non-ok status in the original expanded run.
The task rows preserve the original S3R-expanded manifest settings so the repair remains comparable to the original full-search rows.
The repaired package source changes the internal LPS prefilter failure path so ill-conditioned degree-2 screens use the guarded orthogonal-polynomial/drop solver and degree-1 fallback before classifying a screen failure.

Expected downstream use: create a separate combined report directory that points full rows and already-ok screened rows to the source run, and failed screened rows to this repair bundle.
