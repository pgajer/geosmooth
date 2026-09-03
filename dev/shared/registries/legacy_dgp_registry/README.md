# Legacy DGP Registry Archive

This directory preserves the retired DGP-library freeze bundle that previously
lived under `inst/dgp_registry/`, plus its root-level freeze script. It is kept
as development provenance only: the current package-owned synthetic registry is
`inst/synthetic_registry/`, and installed package code should not depend on the
retired `dgp.*` API names documented in this archive.

Former locations:

- `inst/dgp_registry/dgp_registry.csv`
- `inst/dgp_registry/dgp_registry_manifest.md`
- `inst/dgp_registry/sessionInfo.txt`
- `scripts/freeze_dgp_registry.R`

Disposition: retained as historical evidence for the LPS DGP consolidation, not
as a current regeneration contract.
