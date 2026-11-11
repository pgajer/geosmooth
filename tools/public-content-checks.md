# Public content checks

Run `make check-public-content` before publishing source changes. Package build
targets also check the built source archive, including generated vignette HTML.
Run `make test-public-content` to exercise the detector's regression fixtures.
Python 3.9 or later and Git are required; no Python packages are needed.

For an archive built outside Make, run:

```sh
python3 tools/check-public-content.py --archive path/to/package_version.tar.gz
```

For generated website or documentation output, use `--tree path/to/output`.
Every invocation also checks the working repository: tracked files (including
tracked ignored files) and untracked files that Git does not ignore. R build
exclusions do not remove files from this source review. Ignored generated output
is checked when explicitly supplied with `--tree` or included in the archive.

The checks identify personal filesystem references, task-coordination prose,
prompt fragments and misplaced working records. They inspect text, HTML comments
and entity/URL-escaped links. Ordinary scientific discussion of benchmarks,
audits, literature reviews and limitations is allowed. Reports distinguish
reference errors from wording that needs contextual review; both produce a
nonzero exit status until addressed.

Detailed JSON reports are written outside the checkout in the user's private
report directory, grouped by package. Set `R_PACKAGE_CONTENT_REPORT_DIR` or pass
`--report-dir` to choose another external directory. Reports inside the checkout
are rejected. CI does not upload these reports as public artifacts.

Fix the maintained source and regenerate its derived output. When a match is a
legitimate test fixture or documented tooling behavior, add a narrowly scoped
entry to `tools/public-content-allowlist.json`: the report's exact `scope`,
`path`, `rule` and `fingerprint`, plus a meaningful `reason`. Do not copy the
matched text into the exception file. Wildcard paths are rejected; changed or
removed exception content fails the next check and requires a fresh review.
Exceptions do not transfer between the repository, archive and rendered tree.

This is a targeted text check, not a replacement for scientific or editorial
review. Binary formats such as PDF and serialized R objects are counted but
not decoded; retain the package's format-specific checks and inspect published
figures and documents. A missing input, unreadable archive, external symbolic
link or incomplete scan fails the check rather than being treated as a pass.
