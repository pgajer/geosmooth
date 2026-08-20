# CRAN submission checklist for geosmooth 0.1.0

The exact tarball produced by `R CMD build .` is the release candidate. Do not
submit a tarball built before the final commit.

## Local release gate

- [x] `dgraphs` version 0.1.0 or later is installable from the standard CRAN
      repository in a clean library.
- [x] The working tree is clean and the release commit is identified.
- [x] `make test` passes.
- [x] `make test-all` passes, with only intentional dependency/platform skips.
- [x] `R CMD check --as-cran` passes on the exact source tarball with 0 errors,
      0 warnings, and no unexplained notes.
- [x] The tarball inventory contains no `.github`, `audit_artifacts`, `dev`,
      `scripts`, `tmp`, `tests/migration`, compiled objects, shared libraries,
      check directories, or local release files.
- [x] Installed-package tests run with `waldo` available and do not mask
      failures through dependency skips.
- [x] `cran-comments.md` contains the local environment and check result; the
      pending external environments are identified explicitly.

## External release gate

- [x] GitHub Actions R CMD check matrix is green on Linux, macOS, and Windows.
- [ ] win-builder R-devel result is 0 errors, 0 warnings, and 0 notes.
- [x] R-hub checks include Linux and a non-Linux platform and have no
      unexplained failures.
- [x] Reverse dependency checks are reviewed (none are expected for the first
      release).
- [x] CRAN package-name availability and the current CRAN Repository Policy are
      rechecked on submission day.

Win-builder remained unreachable on 2026-08-20: HTTPS connections to its
upload service timed out, so no job could be created. Do not mark that gate
complete without a result from the service.

## Submission

- [ ] Version and release notes match the submitted tarball.
- [ ] Submit the exact validated tarball through the CRAN web form.
- [ ] Archive the submitted tarball, check logs, external-check URLs, and the
      release commit identifier.
