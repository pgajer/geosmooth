"""Read-only conversion of accepted revision-4 arrays for public R API replay."""
from pathlib import Path
import numpy as np, json, csv, sys, hashlib
source, output = map(Path,sys.argv[1:3])
output.mkdir(parents=True,exist_ok=False)
manifest=[]
def record(p):
    manifest.append({'path':str(p),'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
for cohort in ['ZAPPS','PreSSMat']:
    p=source/cohort; d=output/cohort; d.mkdir()
    for f in ['masks.json','basis.rds','numerics/grid.npy']:
        record(p/f)
    masks=json.loads((p/'masks.json').read_text())
    n=json.loads((p/'vectors.json').read_text())['rows']
    columns=[];Y=[];scores=[];df=[]
    grids=[json.loads((p/'numerics'/f'grid-{i:02d}.json').read_text()) for i in range(1,41)]
    for i in range(1,41):record(p/'numerics'/f'grid-{i:02d}.json')
    for mi,m in enumerate(masks,1):
        z=np.load(p/f'mask-{m["mask_id"]}.npz'); record(p/f'mask-{m["mask_id"]}.npz')
        lookup=[{(r['mask_id'],r['feature'],str(r['heldout_fold'])):r for r in g['responses']} for g in grids]
        ds=[next(r['reference_df'] for r in g['diagnostics'] if r['mask_id']==m['mask_id']) for g in grids]
        for ci,r in enumerate(m['responses']):
            y=np.full(n,np.nan);y[z['observed']]=z['Y'][:,ci];Y.append(y)
            fold=str(r.get('heldout_fold','probe'))
            columns.append(dict(column=len(Y),mask=mi,mask_id=m['mask_id'],feature=r['feature'],heldout_fold=fold))
            scores.append([l[(m['mask_id'],r['feature'],fold)]['reference_gcv'] for l in lookup]);df.append(ds)
    def binary(name,array):
        a=np.asarray(array,dtype='<f8'); a.ravel(order='F').tofile(d/f'{name}.bin')
        (d/f'{name}.json').write_text(json.dumps({'shape':list(a.shape)}))
    binary('responses',np.asarray(Y).T);binary('reference-gcv',np.asarray(scores).T);binary('reference-df',np.asarray(df).T)
    np.savetxt(d/'grid.txt',np.load(p/'numerics/grid.npy'),fmt='%.17g')
    with (d/'columns.tsv').open('w') as f:
        w=csv.DictWriter(f,fieldnames=columns[0].keys(),delimiter='\t');w.writeheader();w.writerows(columns)
    for ti in [1,20,40]:
        path=p/'numerics'/f'checkpoint-{ti}.npz';record(path);z=np.load(path)
        O=z['O'];U=np.setdiff1d(np.arange(n),O)
        f=np.empty((n,z['Y'].shape[1]));f[O]=z['reference_observed'];f[U]=z['reference_unobserved']
        binary(f'checkpoint-{ti}',f)
    print(cohort,n,len(Y),len(masks),flush=True)
(output/'source-manifest.json').write_text(json.dumps(manifest,indent=2))
