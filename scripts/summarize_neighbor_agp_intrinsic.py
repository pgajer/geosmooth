#!/usr/bin/env python3
"""Summarize the bounded surface pilot without reading individual outcomes."""
import argparse, csv, json, statistics
from pathlib import Path
p=argparse.ArgumentParser()
p.add_argument('output',type=Path)
a=p.parse_args()
rows=list(csv.DictReader((a.output/'timings.tsv').open(),delimiter='\t'))
checks=json.loads((a.output/'checks.json').read_text())
assert len(rows)==18 and len(checks)==6
assert sum(v['probabilities'] for v in checks.values())==6912
assert all(v['max.absolute.error']==0 and v['max.radius.error']==0 and v['integer.diagnostics.identical'] for v in checks.values())
summary=[]
print('| Outcome | kNN (s) | Raw nearest-case (s) | Corrected nearest-case (s) |')
print('|---|---:|---:|---:|')
for outcome in ['seasonal_allergies','ibd']:
    med=[]
    for method in ['knn','case_raw','case_corrected']:
        block=[x for x in rows if x['outcome']==outcome and x['method']==method]
        assert len(block)==3 and sorted(int(x['repeat.id']) for x in block)==[1,2,3]
        times=[float(x['predict.seconds']) for x in block]
        record={'outcome':outcome,'method':method,'queries':64,
                'median.seconds':statistics.median(times),'min.seconds':min(times),'max.seconds':max(times)}
        summary.append(record);med.append(record['median.seconds'])
    label='Seasonal allergies' if outcome=='seasonal_allergies' else 'IBD'
    print(f'| {label} | {med[0]:.3f} | {med[1]:.3f} | {med[2]:.3f} |')
(a.output/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
print('\nPreparation range:',min(float(x['prepare.seconds']) for x in rows),max(float(x['prepare.seconds']) for x in rows),'seconds')
print('Validated 6,912 probabilities and all diagnostic fields against exhaustive distances.')
