#!/usr/bin/env python3
"""Summarize the bounded timing output; requires no individual outcome data."""
import argparse, csv, json, statistics
from pathlib import Path
p = argparse.ArgumentParser()
p.add_argument('output',type=Path)
a = p.parse_args()
with (a.output/'timings.tsv').open() as f:
    rows = list(csv.DictReader(f,delimiter='\t'))
with (a.output/'errors.tsv').open() as f:
    errors = list(csv.DictReader(f,delimiter='\t'))
assert len(rows)==144 and len(errors)==36
summary = []
print('| Normalization | Outcome | Estimator | Brute (s) | Exact ANN (s) | eps 0.1 (s) | eps 0.5 (s) | Exact speedup |')
print('|---|---|---|---:|---:|---:|---:|---:|')
for norm in ['sum','max']:
    for outcome in ['seasonal_allergies','ibd']:
        for method in ['knn','case_raw','case_corrected']:
            block = [x for x in rows if (x['normalization'],x['outcome'],x['method'])==(norm,outcome,method)]
            med = {}
            for search,eps,key in [('brute','0','brute'),('ann','0','exact'),('ann','0.1','eps.1'),('ann','0.5','eps.5')]:
                v=[float(x['predict.seconds']) for x in block if x['search']==search and x['eps']==eps]
                assert len(v)==3
                med[key]=statistics.median(v)
            record={'normalization':norm,'outcome':outcome,'method':method,**med,'speedup':med['brute']/med['exact']}
            summary.append(record)
            label = 'Max (ambient)' if norm=='max' else 'Sum'
            name = 'Allergies' if outcome=='seasonal_allergies' else 'IBD'
            print(f"| {label} | {name} | `{method}` | {med['brute']:.3f} | {med['exact']:.3f} | {med['eps.1']:.3f} | {med['eps.5']:.3f} | {record['speedup']:.1f}x |")
error_summary=[]
for eps in ['0','0.1','0.5']:
    block=[x for x in errors if x['eps']==eps]
    assert len(block)==12 and all(int(x['probabilities'])==2304 for x in block)
    error_summary.append({'eps':float(eps),'max.absolute.error':max(float(x['max.absolute.error']) for x in block),
        'mean.absolute.error':statistics.mean(float(x['mean.absolute.error']) for x in block),
        'changed.fraction':statistics.mean(float(x['changed.fraction']) for x in block)})
(a.output/'summary.json').write_text(json.dumps({'timings':summary,'errors':error_summary},indent=2)+'\n')
print('\nApproximation errors:',json.dumps(error_summary))
