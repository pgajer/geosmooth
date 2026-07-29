# geosmooth synthetic registry

This directory is the package-owned registry for reusable synthetic statistical
datasets. It separates reusable recipes from frozen dataset instances.

## Tables

- `recipes.csv` binds each recipe ID to one geometry, sampling, truth, and
  response component and to the complete canonical specification SHA-256.
- `geometries.csv`, `samplings.csv`, `truths.csv`, and `responses.csv` are
  normalized component ledgers. Component implementations remain versioned R
  code; the tables provide stable IDs and hashes rather than executable text.
- `instances.csv` records the sample size, seed, RNG policy, and expected
  content checksum for each frozen instance.
- `checksums.csv` states the checksum payload, XDR serialization, and
  environment scope for frozen instances.
- `gaussian_mixture_1d_shapes.csv` contains the maintained S01--S16 scientific
  shape definitions.
- `gaussian_mixture_1d_variants.csv` contains the maintained V1--V3
  sampling/noise mechanisms.

## Identity and regeneration

Ordinary materializations are identified by the full specification hash,
sample size, seed, and RNG policy in `dataset.id`. Frozen instance IDs are the
only shorter exception, and `materialize.synthetic.instance()` verifies their
content checksums.

Regenerate normalized ledgers from the package source and catalog assets with:

```sh
Rscript scripts/update_synthetic_registry.R
```

Tests require every foreign key to resolve, every recipe hash to reproduce,
and every active frozen checksum to replay. Do not edit generated normalized
ledgers without also changing their owning component or catalog source.

The legacy G1--G7 source was frozen from geosmooth revision
`5ecf721eae2765d8cde01d7fb82b17ff8bde8599`. The shared SSRHE source is
`trend_filtering/development/ssrhe_hessian_energy/ssrhe_order3_l1_validation_helpers.R`;
its source SHA-256 is stored on the committed parity fixture.
