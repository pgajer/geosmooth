"""Create small synthetic fixtures by executing the original sPTB functions.

No cohort data, estimator fitting pipeline or main() from that study is run.
Usage: python3 scripts/neighbor_python_oracle.py /path/to/compare.py output.json
"""
import ast
import hashlib
import json
import sys
from pathlib import Path
import numpy as np

source = Path(sys.argv[1])
destination = Path(sys.argv[2])
text = source.read_text()
wanted = {"identity_order", "distances", "ordered_training", "predictions",
          "choose", "tune", "diagnostics"}
tree = ast.parse(text)
nodes = [node for node in tree.body
         if isinstance(node, ast.FunctionDef) and node.name in wanted]
assert {node.name for node in nodes} == wanted
namespace = {"np": np, "hashlib": hashlib,
             "METHODS": ("case_raw", "case_corrected", "knn")}
exec(compile(ast.Module(body=nodes, type_ignores=[]), str(source), "exec"), namespace)
rng = np.random.default_rng(20261105)
fixtures = []
for scenario in range(3):
    n = 18 + scenario * 2
    X = rng.integers(1, 12, size=(n, 4)).astype(float)
    if scenario == 1:
        X[1::3] = X[0]  # Exact duplicated profiles and normalized ties.
    if scenario == 2:
        X = rng.integers(1, 4, size=(n, 4)).astype(float)
    y = (np.arange(n) % 3 != 0).astype(float)
    ids = np.array([f"oracle-{scenario}-{j:03}" for j in rng.permutation(n)])
    train, query = np.arange(n - 4), np.arange(n - 4, n)
    fold = np.arange(len(train)) % 4
    # A second repeat tests the study's pooling of repeated predictions.
    folds = np.column_stack([fold, (np.arange(len(train)) // 2) % 3])
    for metric in ("l1_euclidean", "max_euclidean", "max_linf"):
        D = namespace["distances"](X, metric)
        priority = namespace["identity_order"](ids)
        case_max = int(y[train].sum())
        result = namespace["predictions"](D, y, train, query, priority, case_max, len(train))
        selected, grids, scores = namespace["tune"](D, y, train, folds, priority)
        fixtures.append(dict(scenario=scenario, metric=metric, X=X.tolist(),
            y=y.tolist(), ids=ids.tolist(), D=D.tolist(), train=(train+1).tolist(),
            query=(query+1).tolist(), folds=folds.tolist(),
            priority=(priority+1).tolist(),
            predictions={k:v.tolist() for k,v in result.items()}, selected=selected,
            grids={k:v.tolist() for k,v in grids.items()}, scores=scores,
            diagnostics={m:namespace["diagnostics"](D, y, train, query, priority, m, 2)
                         for m in namespace["METHODS"]}))
payload = dict(source_name=source.name,
               source_sha256=hashlib.sha256(source.read_bytes()).hexdigest(),
               extracted_functions=sorted(wanted), numpy_version=np.__version__,
               scenarios="synthetic only; no sPTB or AGP data", fixtures=fixtures)
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text(json.dumps(payload, indent=2, allow_nan=False) + "\n")
print(f"Wrote {len(fixtures)} Python reference fixtures to {destination}")
