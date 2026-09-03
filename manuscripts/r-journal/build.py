#!/usr/bin/env python3
"""Render manuscript planning documents and enforce their citation gate."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
from datetime import datetime
from zoneinfo import ZoneInfo


ROOT = Path(__file__).resolve().parent
DOCUMENTS = ("gap_statement", "r_graph_regression_review")
STYLE = """<style>
body { max-width: 920px; margin: 2.5rem auto; padding: 0 1.4rem;
       color: #203047; background: #fff; font: 17px/1.65 system-ui, sans-serif; }
h1 { line-height: 1.2; } h2 { margin-top: 2.2rem; line-height: 1.3; }
li { margin-bottom: .65rem; } a { color: #145e89; overflow-wrap: anywhere; }
code { font-size: .9em; overflow-wrap: anywhere; }
.subtitle, .date, .meta { color: #536174; }
article { margin: 1.5rem 0; padding: 1rem 1.2rem; border: 1px solid #d8dde6;
          border-left: 4px solid #31744d; border-radius: 4px; }
dt { font-weight: 650; } dd { margin: 0 0 .8rem; }
@media print { body { max-width: none; font-size: 11pt; } }
</style>"""


def run(*args):
    subprocess.run(args, cwd=ROOT, check=True)


def main():
    pandoc = os.environ.get("PANDOC", "pandoc")
    timestamp = datetime.now(ZoneInfo("America/New_York")).strftime(
        "%Y-%m-%d %H:%M:%S %Z")
    evidence = (ROOT / "citation_verification.html.in").read_text()
    evidence = evidence.replace("@@BUILD_DATETIME@@", timestamp)
    evidence = evidence.replace("@@STYLE@@", STYLE)
    (ROOT / "citation_verification.html").write_text(evidence)

    with tempfile.TemporaryDirectory(prefix="geosmooth-rjournal-") as temp:
        temp = Path(temp)
        header = temp / "style.html"
        header.write_text(STYLE)
        # The shared gate reads TeX citation commands. Generate them from the
        # actual Markdown through Pandoc rather than scanning prose with regex.
        citation_args = []
        for stem in DOCUMENTS:
            tex = temp / (stem + "_citations.tex")
            run(pandoc, stem + ".md", "--to=latex", "--natbib", "-o", str(tex))
            citation_args.extend(("--tex", str(tex)))
        run(sys.executable, "tools/check_citation_verification.py",
            *citation_args, "--bib", "references.bib",
            "--html", "citation_verification.html")
        for stem in DOCUMENTS:
            run(pandoc, stem + ".md", "--standalone", "--citeproc",
                "--mathml", "--fail-if-warnings", "--include-in-header", str(header),
                "--metadata", "date=Built " + timestamp,
                "-o", stem + ".html")
    print("Rendered " + ", ".join(stem + ".html" for stem in DOCUMENTS)
          + " and citation_verification.html")


if __name__ == "__main__":
    main()
