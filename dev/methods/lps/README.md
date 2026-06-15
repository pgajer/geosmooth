# LPS method workspace

Use this directory for local polynomial smoothing execution history.

- `dev/methods/lps/audit_artifacts/`: generated audit bundles and supporting evidence.
- `audit_contracts/`: work orders, acceptance criteria, and audit contracts.
- `audits/`: audit reports and audit responses.
- `handoffs/`: implementer, auditor, and phase handoffs.
- `reports/`: rendered analysis reports.
- `runs/`: run directories, manifests, and launch records.
- `results/`: durable result tables or serialized outputs.
- `status/`: progress notes and operational status.

Large audit and contract sets should be grouped by tier, event, or named gate
instead of added to the top-level `audits/` or `audit_contracts/` directory.
Current group keys include:

- `tier0/`, `tier2/`: tier-level gates and responses.
- `e1_9/`, `e1_10/`, `e4_1/`: event-specific gates.
- `dgp/`: DGP-library audit material.
- `phase3/`: phase-level reconciliation audits.
- `tiers1to4/`: multi-tier contracts and spec-question records.

Keep only method-wide indexes or temporary unclassified files at the immediate
subdirectory root.
