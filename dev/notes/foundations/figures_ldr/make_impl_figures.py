#!/usr/bin/env python3
"""Original schematic figures for the LPS local-dimension-regularization
implementation notes. All figures are illustrative schematics produced for this
note (NOT computed from the VALENCIA data, which is not used here); they show the
*shape* of the quantities the specified experiments will measure."""
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyArrowPatch, FancyBboxPatch, Polygon as MPolygon

OUT = os.path.dirname(os.path.abspath(__file__))
plt.rcParams.update({
    "figure.dpi": 120, "savefig.bbox": "tight", "font.size": 11,
    "axes.titlesize": 12, "axes.labelsize": 11, "axes.spines.top": False,
    "axes.spines.right": False, "legend.frameon": False, "font.family": "DejaVu Sans"})
C = {"blue": "#2563eb", "orange": "#d97706", "green": "#15803d", "red": "#b91c1c",
     "gray": "#64748b", "purple": "#7c3aed", "lgray": "#cbd5e1", "teal": "#0d9488"}
def save(fig, name):
    fig.savefig(os.path.join(OUT, name)); plt.close(fig); print("wrote", name)
rng = np.random.default_rng(20260610)
TRI = np.array([[0,0],[1,0],[0.5,np.sqrt(3)/2]])
def bary(w): return w @ TRI

# ----------------------------------------------- 1. naive strata enumeration
def fig_strata_enum():
    fig = plt.figure(figsize=(13,4.2))
    gs = fig.add_gridspec(1,3, width_ratios=[1.05,1,1])
    ax = fig.add_subplot(gs[0])
    ax.add_patch(MPolygon(TRI, closed=True, fill=True, color=C["lgray"], alpha=0.22, ec=C["gray"]))
    # interior cloud (all present)
    w = rng.dirichlet([6,6,6], 120); P = bary(w)
    ax.scatter(P[:,0],P[:,1],s=8,color=C["blue"],label="all 3 present (2-face)")
    # edge AB cloud (C absent)
    s = rng.uniform(0.1,0.9,60); e = bary(np.c_[1-s, s, np.zeros(60)]) + 0.006*rng.standard_normal((60,2))
    ax.scatter(e[:,0],e[:,1],s=10,color=C["orange"],label="C absent (1-face)")
    # vertex A cluster
    wv = rng.dirichlet([20,1.2,1.2],30); Pv = bary(wv)
    ax.scatter(Pv[:,0],Pv[:,1],s=12,color=C["green"],label="A-dominated (near 0-face)")
    for (vx,vy),lab in zip(TRI,["A","B","C"]):
        ax.scatter([vx],[vy],s=40,color=C["red"],zorder=5)
        ax.text(vx, vy-0.06 if vy<0.1 else vy-0.11, lab, ha="center", color=C["red"], fontsize=11)
    ax.set_aspect("equal"); ax.axis("off"); ax.legend(fontsize=7.5, loc="upper right")
    ax.set_title("(a) samples carry a support pattern\n= which face they sit on")
    # occupancy bar (schematic: a few big strata + long tail)
    ax = fig.add_subplot(gs[1])
    labels = ["{A}","{A,B}","{B}","{A,B,C}","{B,C}","{A,C}","{C}","...tail"]
    occ = np.array([3100,2400,1900,1500,1100,700,300,331])
    ax.barh(range(len(labels))[::-1], occ, color=C["blue"], alpha=0.8)
    ax.set_yticks(range(len(labels))[::-1]); ax.set_yticklabels(labels, fontsize=8.5)
    ax.set_xlabel("samples"); ax.set_title("(b) occupancy of the naive strata\n(support patterns), schematic")
    for i,o in enumerate(occ): ax.text(o+40, len(labels)-1-i, str(o), va="center", fontsize=7, color=C["gray"])
    # face-dimension distribution
    ax = fig.add_subplot(gs[2])
    dims = [0,1,2,3]; frac = [0.18,0.34,0.33,0.15]
    ax.bar(dims, frac, color=C["teal"], alpha=0.85)
    ax.set_xticks(dims); ax.set_xlabel("naive face dimension $|A|-1$"); ax.set_ylabel("fraction of samples")
    ax.set_title("(c) distribution of naive\nface dimension, schematic")
    # figure-level title removed (overlaps panel titles); LaTeX caption carries it
    save(fig,"fig_strata_enum.pdf")

# --------------------------------- 2. mass concentration around lower faces
def fig_mass_conc():
    fig, axs = plt.subplots(1,3, figsize=(13,4))
    # left: a 2-face (triangle) with data hugging edge AB (a tube near a 1-face)
    ax = axs[0]
    ax.add_patch(MPolygon(TRI, closed=True, fill=True, color=C["lgray"], alpha=0.20, ec=C["gray"]))
    s = rng.uniform(0.12,0.88,300); h = np.abs(rng.normal(0,0.045,300))
    w = np.c_[(1-s)*(1-h), s*(1-h), h]; w = w/w.sum(1,keepdims=True); P = bary(w)
    ax.scatter(P[:,0],P[:,1],s=7,color=C["blue"])
    # epsilon band near edge AB
    band = MPolygon(np.array([[0,0],[1,0],[0.85,0.13],[0.15,0.13]]), closed=True, fill=True, color=C["red"], alpha=0.10)
    ax.add_patch(band)
    ax.text(0.5,0.16,"$\\epsilon$-band near the 1-face",color=C["red"],ha="center",fontsize=8.5)
    for (vx,vy),lab in zip(TRI,["A","B","C"]):
        ax.text(vx, vy-0.06 if vy<0.1 else vy-0.11, lab, ha="center", color=C["red"], fontsize=10)
    ax.set_aspect("equal"); ax.axis("off")
    ax.set_title("a naive 2-face whose mass\nhugs a lower 1-face (a tube)")
    # middle: min present-abundance distribution (peaks near detection limit)
    ax = axs[1]
    mn = np.minimum(np.minimum(w[:,0],w[:,1]),w[:,2])
    ax.hist(mn, bins=30, color=C["orange"], alpha=0.85)
    ax.axvline(0.01, color=C["red"], ls=":"); ax.text(0.012, ax.get_ylim()[1]*0.8,"detection\nlimit $\\tau$",color=C["red"],fontsize=8)
    ax.set_xlabel("min present abundance $\\min_{i\\in A} x_i$"); ax.set_ylabel("count")
    ax.set_title("how often a present taxon\nis near zero (mass near a sub-face)")
    # right: effective dimension within the stratum (below nominal)
    ax = axs[2]
    ax.bar([1,2], [0.74,0.26], color=[C["blue"],C["lgray"]])
    ax.set_xticks([1,2]); ax.set_xlabel("estimated effective dimension $k_A$")
    ax.set_ylabel("fraction of anchors")
    ax.axvline(2.0, color=C["green"], ls="--"); ax.text(2.02,0.5,"nominal $|A|-1=2$",color=C["green"],rotation=90,fontsize=8,va="center")
    ax.set_title("effective dimension $<$ nominal:\nthe gap the field must capture")
    # figure-level title removed (overlaps panel titles); LaTeX caption carries it
    save(fig,"fig_mass_conc.pdf")

# ------------------------------------ 3. effective rank vs nominal dimension
def fig_eff_dim_vs_nominal():
    fig, ax = plt.subplots(figsize=(7.2,4.2))
    nominal = np.array([1,2,2,3,3,4,4,5])
    eff =      np.array([1,1,2,2,3,2,3,3]) + rng.normal(0,0.05,8)
    ax.plot([0,5.5],[0,5.5],color=C["gray"],ls=":",label="effective = nominal (manifold)")
    ax.scatter(nominal, eff, s=70, color=C["blue"], zorder=5)
    for x,y in zip(nominal,eff):
        ax.plot([x,x],[y,x],color=C["red"],lw=1.4,alpha=0.6)
    ax.text(4.0,2.0,"gap = nominal $-$ effective\n(the room the data leave empty)",color=C["red"],fontsize=8.5)
    ax.set_xlabel("nominal face dimension $|A|-1$ (from support)")
    ax.set_ylabel("estimated effective rank $k_A$")
    ax.set_xlim(0,5.6); ax.set_ylim(0,5.6); ax.set_aspect("equal"); ax.legend(fontsize=8.5, loc="upper left")
    ax.set_title("Per-stratum: support gives the cap, the data fill less.\nThe gap is what local-dimension regularization recovers (schematic).")
    save(fig,"fig_eff_dim_vs_nominal.pdf")

# -------------------------------------------- 4. synthetic generative model
def fig_synth_model():
    fig, axs = plt.subplots(1,3, figsize=(13,4))
    # (a) pick a stratum
    ax = axs[0]
    labels = ["{A,B,C}","{A,B}","{B,C}","{A}"]; p=[0.4,0.3,0.2,0.1]
    ax.bar(range(4), p, color=C["purple"], alpha=0.8); ax.set_xticks(range(4)); ax.set_xticklabels(labels, fontsize=8)
    ax.set_ylabel("$p(A)$"); ax.set_title("(1) draw a stratum $A\\sim p(A)$\n(from E1 occupancy)")
    # (b) sample on the face with controlled rank
    ax = axs[1]
    ax.add_patch(MPolygon(TRI, closed=True, fill=True, color=C["lgray"], alpha=0.2, ec=C["gray"]))
    t = np.linspace(0.12,0.88,200); curve = np.c_[1-t, t, 0.10*np.sin(3*t)+0.12]
    curve = curve/curve.sum(1,keepdims=True); Pc = bary(curve) + 0.01*rng.standard_normal((200,2))
    ax.scatter(Pc[:,0],Pc[:,1],s=7,color=C["blue"])
    ax.set_aspect("equal"); ax.axis("off")
    ax.set_title("(2) sample on $F_A$ with\nrank $k_A<|A|-1$ (known tube)")
    # (c) the labeled output
    ax = axs[2]
    ax.text(0.5,0.78,"$\\{(x_j,\\;A_j,\\;k_j)\\}$",ha="center",fontsize=15,transform=ax.transAxes)
    ax.text(0.5,0.55,"composition $x_j$ on the simplex,\nwith its TRUE stratum $A_j$\nand TRUE local dimension $k_j$",
            ha="center",fontsize=9.5,transform=ax.transAxes,color=C["ink"] if "ink" in C else C["gray"])
    ax.text(0.5,0.22,"$\\Rightarrow$ a non-manifold dataset with\nknown ground-truth dimension field",
            ha="center",fontsize=10,transform=ax.transAxes,color=C["green"])
    ax.axis("off"); ax.set_title("(3) ground truth is known\n(we designed $k_A$)")
    # figure-level title removed (overlaps panel titles); LaTeX caption carries it
    save(fig,"fig_synth_model.pdf")

# --------------------------------------------- 5. tests vs experiments flow
def fig_flow():
    fig, ax = plt.subplots(figsize=(11.5,4.6)); ax.axis("off")
    ax.set_xlim(0,12); ax.set_ylim(0,6)
    def box(x,y,w,h,text,col,fc):
        ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle="round,pad=0.08",lw=1.6,ec=col,fc=fc))
        ax.text(x+w/2,y+h/2,text,ha="center",va="center",fontsize=9.5,color="#24303d")
    def arrow(x1,y1,x2,y2,text="",col=C["gray"]):
        ax.add_patch(FancyArrowPatch((x1,y1),(x2,y2),arrowstyle="-|>",mutation_scale=14,lw=1.6,color=col))
        if text: ax.text((x1+x2)/2,(y1+y2)/2+0.18,text,ha="center",fontsize=8,color=col)
    box(0.2,2.4,2.5,1.4,"VALENCIA 13k\n16S (simplex)\nrelative abundances",C["gray"],"#f1f5f9")
    box(3.4,3.5,3.0,1.6,"EXPERIMENTS (real data,\nno ground truth):\nE1 enumerate strata\nE2 mass concentration\nE3 structure",C["orange"],"#fff7ed")
    box(3.4,0.5,3.0,1.7,"SYNTHETIC GENERATORS\n(known dimension field):\nstratum mixture,\ntubes, cones, seams",C["purple"],"#f5f3ff")
    box(7.3,0.5,2.4,1.7,"TESTS (synthetic,\npass / fail):\nT1--T9\n(exact, deterministic)",C["blue"],"#eff6ff")
    box(10.0,2.4,1.8,1.5,"NEXT STEPS\n(decision\nrules)",C["green"],"#f0fdf4")
    arrow(2.7,3.2,3.4,3.9)
    arrow(4.9,3.5,4.9,2.2,"parameterize",C["purple"])
    arrow(6.4,1.35,7.3,1.35,"feed DGPs",C["blue"])
    arrow(6.4,4.3,10.0,3.4,"characterize",C["orange"])
    arrow(9.7,1.35,10.9,2.4,"pass/fail",C["green"])
    ax.set_title("How tests and experiments fit together: real data is explored (no truth) to build synthetic generators (known truth) that the tests run on.",fontsize=10.5)
    save(fig,"fig_flow.pdf")

for f in [fig_strata_enum, fig_mass_conc, fig_eff_dim_vs_nominal, fig_synth_model, fig_flow]:
    try: f()
    except Exception as e: print("FAILED", f.__name__, "->", repr(e))
print("done")
