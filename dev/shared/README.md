# Shared development assets

This directory is for cross-method development assets that should have one
canonical home and be referenced by method workspaces.

- `data/`: shared dataset specifications, frozen input manifests, and data
  access notes.
- `dgp/`: canonical data-generating-process designs and generators used by
  more than one method.
- `fixtures/`: small reusable fixtures or fixture definitions.
- `registries/`: frozen catalogues, asset indexes, benchmark registries, and
  manifest schemas.
- `specs/`: cross-method binding specifications and benchmark contracts.
- `experiments/`: experiment designs or manifests that compare multiple
  methods.
- `benchmarks/`: benchmark protocols, scoring conventions, and reusable
  reporting templates.

Do not copy shared specs into method directories. Method-specific documents
should link to this shared source of truth.
