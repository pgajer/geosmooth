# Phase-4 stale-path sweep report

Date: 2026-06-14

This report records the old-root path sweep requested by the Phase-4
development-document reorganization work order.

## Sweep definition

The active-source sweep searched only executable or package-active locations:

```sh
rg -n '(^|[^A-Za-z0-9_./-])(audits|phase_handoffs|project_briefs|split_handoffs|audit_artifacts|audit_contracts|validation|reports)/' \
  .github R tests/testthat dev/methods/lps/ci --glob '!*.html'
```

Result:

- unresolved active old-root references: 0

The broader repository sweep searched all non-ignored repository content except
generated dashboards and compressed/check artifacts:

```sh
rg -n '(^|[^A-Za-z0-9_./-])(audits|phase_handoffs|project_briefs|split_handoffs|audit_artifacts|audit_contracts|validation|reports)/' \
  --glob '!split_handoffs/**' --glob '!dev/html/**' --glob '!dev/index.html' \
  --glob '!*.Rcheck/**' --glob '!*.tar.gz' .
```

Result:

- historical or archival old-root mentions: 536

## Review outcome

The active references that would affect current execution were updated:

- GitHub Tier-0 workflow paths now use `dev/methods/lps/ci/` and the ignored
  method-local audit-artifact location.
- LPS CI scripts now source method-specific validation scripts from
  `dev/methods/lps/ci/`.
- Committed LPS run outputs referenced by gates now live under
  `dev/methods/lps/runs/`.
- Generated audit bundles now default to
  `dev/methods/lps/audit_artifacts/`, which is ignored except for `.gitkeep`.
- Active tests and source comments now point to the new authoritative
  `dev/methods/lps/...` locations.

The remaining broader-sweep hits are retained as archival context inside
migrated audits, handoffs, generated reports, historical manifests, and the
target-structure design document. They describe where an artifact lived at the
time it was generated or audited. They are not active runtime dependencies and
are intentionally not rewritten in bulk, because doing so would alter the
historical record.

Conclusion: zero unresolved active old-root references remain.
