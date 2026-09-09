#!/usr/bin/env python3
"""Build and render the method proposal; never run a geodesic solver."""
from datetime import datetime
from pathlib import Path
from zoneinfo import ZoneInfo
import hashlib
import json
import re
import shutil
import subprocess
import sys

ROOT = Path(__file__).resolve().parent
BUILD = ROOT / 'build'
STEM = 'adaptive_quadform_geodesic_refinement'
BUILD.mkdir(exist_ok=True)
now = datetime.now(ZoneInfo('America/New_York'))
(BUILD / 'refinement_timestamp.tex').write_text(
    now.strftime('Prepared %B %d, %Y at %H:%M %Z') + '\n')
(BUILD / 'citation_verification.html').write_text('''<!doctype html>
<html lang="en"><meta charset="utf-8"><title>Citation verification: quadform refinement</title>
<style>body{font:16px/1.5 system-ui;max-width:1000px;margin:40px auto;padding:0 20px}
table{border-collapse:collapse}td,th{border:1px solid #bbb;padding:12px;vertical-align:top}</style>
<h1>Citation verification</h1>
<p>Evidence reviewed 2026-09-09. This record concerns the cited preprint version,
not a separate journal version. The document's connector formulas, bounds, and grid
counterexample are direct derivations; no experiments are reported.</p>
<table><tr><th>Source</th><th>Claim and evidence</th></tr>
<tr data-citation-key="karaman2011" data-status="verified"><td>
<b>karaman2011</b><br>Sertac Karaman and Emilio Frazzoli.<br>
<i>Sampling-based Algorithms for Optimal Motion Planning.</i> 2011.
Venue/version: arXiv:1105.1186v1 [cs.RO], submitted 5 May 2011.
DOI: 10.48550/arXiv.1105.1186.<br>
<a data-source-link href="https://arxiv.org/abs/1105.1186v1">Version and metadata</a><br>
<a data-source-link href="https://arxiv.org/pdf/1105.1186v1">Full-text preprint</a>
</td><td><b>Location:</b> Section 6, second paragraph.<br>
<b>Claim:</b> Karaman and Frazzoli prove asymptotic optimality for specified PRM* and
RRT* constructions under their hypotheses, and non-optimality for several alternative constructions.<br>
<b>Full-text evidence:</b> Section 4.2.1, printed pp. 24–28, distinguishes optimal
and non-optimal sampling-based constructions. Section 4.2.2, printed pp. 28–29,
states Theorem 34 for PRM* and Theorem 38 for RRT*, including connection-parameter
conditions. Appendix C (printed pp. 54–61) develops the PRM* argument using a
robustly optimal path and a covering sequence; Lemma 56 states cost convergence
under Theorem 34's assumptions.<br>
<b>Verifier notes:</b> Metadata checked against the versioned arXiv record; claim
checked in the full text. These are literature-context statements only. The
proposal expressly does not transfer those theorems to the local-disk method,
the pullback surface metric, or boundary endpoints. No local source PDF is bundled.
</td></tr></table></html>''')

for executable in ('latexmk', 'pdftoppm', 'pdftotext'):
    if shutil.which(executable) is None:
        raise SystemExit(f'Missing build dependency: {executable}')
checker = Path('/Users/pgajer/.codex/notes/agent_instructions/reports/scripts/check_citation_verification.py')
if not checker.is_file():
    raise SystemExit(f'Missing citation checker: {checker}')

def run(args, log_name):
    with (BUILD / log_name).open('w') as log:
        result = subprocess.run(args, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    if result.returncode:
        print((BUILD / log_name).read_text()[-8000:])
        raise SystemExit(result.returncode)

run(['latexmk', '-pdf', '-interaction=nonstopmode', '-halt-on-error',
     '-outdir=build', STEM + '.tex'], 'refinement_build.log')
run([sys.executable, str(checker), '--tex', str(ROOT / (STEM + '.tex')),
     '--bib', str(ROOT / (STEM + '.bib')), '--html', str(BUILD / 'citation_verification.html'),
     '--log', str(BUILD / (STEM + '.log'))], 'citation_check.log')
log_text = (BUILD / (STEM + '.log')).read_text()
issues = [line for line in log_text.splitlines()
          if re.search(r'Overfull|Underfull|undefined|LaTeX Warning:', line)]
if issues:
    raise SystemExit('Review LaTeX warnings before release:\n' + '\n'.join(issues))
render = BUILD / 'rendered'
render.mkdir(exist_ok=True)
for old in render.glob('page-*.png'):
    old.unlink()
run(['pdftoppm', '-r', '110', '-png', str(BUILD / (STEM + '.pdf')),
     str(render / 'page')], 'refinement_render.log')
run(['pdftotext', '-layout', str(BUILD / (STEM + '.pdf')),
     str(BUILD / 'refinement_text.txt')], 'refinement_text.log')
report = {'built_at': now.isoformat(), 'solver_experiments_executed': False,
          'citation_check': 'passed', 'latex_warning_check': 'passed',
          'pages_rendered': len(list(render.glob('page-*.png'))),
          'visual_inspection': 'requires human or agent review of rendered pages',
          'sha256': {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest()
                     for name in (STEM + '.tex', STEM + '.bib')},
          'pdf_sha256': hashlib.sha256((BUILD / (STEM + '.pdf')).read_bytes()).hexdigest()}
(BUILD / 'refinement_build_manifest.json').write_text(json.dumps(report, indent=2) + '\n')
print(f'Built {BUILD / (STEM + ".pdf")}')
print(f'Rendered {report["pages_rendered"]} pages; inspect before release.')
