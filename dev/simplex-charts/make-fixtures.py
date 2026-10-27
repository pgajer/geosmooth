"""Small independent Python reference fixtures; no cohort inputs."""
from pathlib import Path
import csv
import numpy as np
from scipy.special import expit
from reference import unfold, predict_grid, GRID, METHODS
out = Path(__file__).resolve().parents[2] / 'tests/testthat/fixtures/simplex-charts'
out.mkdir(parents=True, exist_ok=True)
results = []
for scenario in range(5):
    rng = np.random.default_rng(270100 + 1000 * scenario)
    n = 520
    t = rng.uniform(-.2, .2, n)
    U = np.empty((n, 8))
    U[:,0] = np.where(t <= 0, 1, 1-t)
    U[:,1] = np.where(t <= 0, 1+t, 1)
    U[:,2] = rng.uniform(.02, .5, n)
    U[:,3] = rng.uniform(.10, .18, n)
    U[:,4:] = rng.uniform(.02, .10, (n,4))
    Z = unfold(U, 0)[:,1:]
    eta = [-1.3862943611198906 + np.zeros(n), -1.6+2.2*t/.2,
           -1.6+2.2*(U[:,2]-.26)/.24, -1.6+2.2*(U[:,3]-.14)/.04,
           -2+3*(t/.2)**2][scenario]
    y = rng.binomial(1, expit(eta))
    pred, const, fail, grad = predict_grid(U[:320], Z[:320], y[:320], U[400:406], Z[400:406])
    assert not fail.any()
    take = np.r_[np.arange(320), np.arange(400,406)]
    np.savetxt(out / f'scenario-{scenario}.csv', np.c_[U[take], y[take]], delimiter=',',
               header=','.join([f'x{i}' for i in range(8)]+['y']), comments='')
    for m, method in enumerate(METHODS):
        for g, (d, ridge) in enumerate(GRID):
            for q in range(6):
                results.append([scenario, method, d, ridge, q+1, pred[q,m,g], const[q]])
with (out/'predictions.csv').open('w') as f:
    w=csv.writer(f, lineterminator='\n'); w.writerow(['scenario','method','dimension','ridge','query','prediction','constant']); w.writerows(results)
print(f'{len(results)} predictions across five scenarios')
