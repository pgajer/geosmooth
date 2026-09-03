# geosmooth: R Journal manuscript

This is the canonical home for the planned R Journal software paper. It is
excluded from the R source package through the root `.Rbuildignore`.

## Current document

- [Statement of the gap: bullet-point draft](gap_statement.md) is the
  author-facing starting point for the introduction and contribution statement.
- [Readable HTML version](gap_statement.html) is generated from that Markdown.
- [R graph-regression software review](r_graph_regression_review.md) assesses
  ten neighboring packages and maps geosmooth's methods to published work;
  its [HTML version](r_graph_regression_review.html) is generated alongside
  the gap draft. This is a source review, not a benchmark.
- [References](references.bib) contain the sources actually cited in the draft.
- [Citation verification](citation_verification.html) records what each source
  supports in both documents. Its canonical source is `citation_verification.html.in`.

The draft distinguishes documented capabilities from proposed comparative
claims. It is not a completed novelty review or a submission-ready manuscript.
Its scientific framing is outcome estimation on data-derived geometry, with
separate targets for conditional means, local probabilities, co-variation of
mean fields, and residual association. The association layer is a broader
research direction, not a claim about the current exported API.
The source baseline inspected is geosmooth 0.1.0 at commit
`9af73498f6e56c9ad9caf9d3b30b169d94eb8de2`. The earlier CRAN-submission tag
remains unchanged; the paper's release baseline will be selected separately.

## Rebuild and verify

From the repository root, run:

```sh
make -C manuscripts/r-journal
```

Requirements: Python 3.9 or newer and Pandoc with citeproc support. The build
does not execute package examples or benchmarks. It renders the bullet-point
draft, checks citations against the bibliography and verification record,
and inserts a build-time timestamp in Eastern local time. Neither package
installation nor the manuscript build depends on the private agent workspace.
Equations are embedded as MathML, without a remote math-rendering dependency.

`tools/check_citation_verification.py` is a verbatim local copy of the shared
Codex citation checker inspected on 2026-09-02. Its original location was
`/Users/pgajer/.codex/notes/agent_instructions/reports/scripts/check_citation_verification.py`.
It is included here to make this document's verification portable.
The verification template is adapted from the shared citation-verification
HTML template, using stacked entries instead of a wide table.

## Scope and next step

The first task is to agree on the paper's central contribution, then conduct
a targeted comparison of neighboring software. Manuscript source, citations,
figures, and reproducibility materials belong here. Internal agent reviews,
temporary rewrites, and coordination notes belong outside the repository in
the private geosmooth workspace.

No abstract, author list, results, or acceptance claim is implied by this
initial scaffold. A later full paper should use the R Journal's current
article template rather than treating this planning document as that template.
