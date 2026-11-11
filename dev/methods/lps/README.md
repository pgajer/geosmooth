# LPS method workspace

Use this directory for local polynomial smoothing method material that is
appropriate to keep in the repository.

Strategic context: [LPS / LCov / Omics Program](../../programs/lps_lcov_omics_program/README.md).

Research lineage: [provenance.md](provenance.md).

- `reports/`: rendered analysis reports.
- `runs/`: reusable run specifications; generated records belong outside the checkout.
- `results/`: durable result tables or serialized outputs.
- `specs/`: method specifications and scientific design plans.
- `status/`: concise method-development summaries.

Keep operational run records outside the package checkout. Retain reproducible
methods, validation tools and scientific summaries here.

Keep only method-wide indexes or temporary unclassified files at the immediate
subdirectory root.
