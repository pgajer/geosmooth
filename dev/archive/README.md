# Development archive

This directory holds retained historical development artifacts that are useful
for auditability or reconstruction, but that are not yet decomposed into a
method-specific `dev/methods/<method>/...` home or a shared `dev/shared/...`
home.

Use this directory for migration snapshots and legacy bundles only. New work
should not normally be created here. When a retained artifact becomes active
evidence for new work, move it with `git mv` into the appropriate method,
shared, or project-brief location and update references.

Current archive bundles:

- `split_handoffs_retained/`: selected durable artifacts retained from the
  formerly ignored root `split_handoffs/` tree during the Phase-4 development
  layout migration. The inventory CSV records retained files and intentionally
  externalized files.
