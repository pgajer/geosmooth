#!/usr/bin/env python3
"""Extract private, bounded AGP timing inputs; never commit the output labels/IDs."""
import argparse, csv, gzip, hashlib, json, re
from pathlib import Path
p = argparse.ArgumentParser()
p.add_argument('--frozen', type=Path, required=True)
p.add_argument('--linkage', type=Path, required=True)
p.add_argument('--survey', type=Path, required=True)
p.add_argument('--output', type=Path, required=True)
a = p.parse_args()
a.output.mkdir(parents=True, exist_ok=True)
if (a.output/'labels.tsv').exists():
    raise SystemExit('Output exists; choose a new directory to preserve the earlier timing run.')
with gzip.open(a.frozen/'assignments.tsv.gz', 'rt') as f:
    ids = [r['Run'] for r in csv.DictReader(f, delimiter='\t')]
assert len(ids) == 24421 and len(set(ids)) == len(ids)
wanted = set(ids)
with gzip.open(a.linkage, 'rt') as f:
    linkage = {r['sample_name']: r['host_subject_id'] for r in csv.DictReader(f, delimiter='\t')}
assert set(linkage) == wanted
subjects = {}
for sample, raw in linkage.items():
    m = re.fullmatch(r"(?:\['([0-9a-f]{128})'\]|([0-9a-f]{128}))", raw)
    if m: subjects[sample] = m[1] or m[2]
    else: assert raw == 'not collected'
assert len(subjects) == 24411 and len(set(subjects.values())) == 21323
positive = {'Diagnosed by a medical professional (doctor, physician assistant)',
            'Diagnosed by an alternative medicine practitioner', 'Self-diagnosed'}
unknown = {'not provided', 'not collected', '', 'Not sure'}
labels = {}
with a.survey.open() as f:
    for r in csv.DictReader(f, delimiter='\t'):
        key = r['#SampleID']
        if key not in wanted: continue
        assert key not in labels
        ibd, allergy = r['ibd'], r['seasonal_allergies']
        assert ibd in positive | unknown | {'I do not have this condition'}
        assert allergy in unknown | {'Yes', 'No'}
        labels[key] = {'sample': key, 'group': subjects.get(key, ''),
            'ibd': 1 if ibd in positive else 0 if ibd == 'I do not have this condition' else 'NA',
            'seasonal_allergies': 1 if allergy == 'Yes' else 0 if allergy == 'No' else 'NA'}
assert set(labels) == wanted
with (a.output/'labels.tsv').open('w') as f:
    w = csv.DictWriter(f, fieldnames=['sample','group','ibd','seasonal_allergies'],delimiter='\t')
    w.writeheader();w.writerows(labels[key] for key in ids)
paths = [a.frozen/'cohort.rds', a.frozen/'assignments.tsv.gz', a.linkage, a.survey]
provenance = {'inputs': [{'path': str(x), 'sha256': hashlib.file_digest(x.open('rb'),'sha256').hexdigest()} for x in paths],
    'frozen_samples': 24421, 'identified_samples': 24411, 'participants': 21323,
    'outcomes': ['seasonal_allergies', 'ibd'],
    'positive_ibd': sorted(positive), 'negative_ibd': ['I do not have this condition'],
    'negative_allergies': ['No'], 'positive_allergies': ['Yes']}
(a.output/'inputs.json').write_text(json.dumps(provenance, indent=2)+'\n')
print('Prepared 24,421 private label rows; 24,411 have verified participant linkage.')
