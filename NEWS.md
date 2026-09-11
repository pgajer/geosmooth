# geosmooth 0.1.0

- Delegate reusable synthetic geometry and point generation to dgraphs
  (>= 0.2.1.9000), with temporary reexports for the existing geometry APIs.
  Statistical recipes, responses, dataset identities and legacy G4 remain
  here. Geometry Lab and maintained geometry reference tools now live in
  the dgraphs development tree.

* Initial CRAN release.
* Provides local polynomial and model-averaged local polynomial smoothing,
  local polynomial lifting trend filtering, synchronized local polynomial
  lifting trend filtering, and occupation-density adapters.
* Provides metric-graph low-pass filtering and Hessian-energy regression with
  compiled backends.
* Provides reproducible synthetic geometry and response generators for method
  evaluation.
* Makes synthetic-registry identity verification stable across supported R
  versions by excluding the serializer's producer-version header from the
  checksum contract.
