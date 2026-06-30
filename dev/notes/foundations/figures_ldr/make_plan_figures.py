#!/usr/bin/env python3
"""Original schematics for the LPS/PS-LPS program plan: a dependency DAG and a
parallel-track timeline. Produced from scratch; nothing reproduced from any source."""
import os, numpy as np, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Polygon as MPoly
OUT=os.path.dirname(os.path.abspath(__file__))
plt.rcParams.update({"figure.dpi":120,"savefig.bbox":"tight","font.size":10.5,
    "font.family":"DejaVu Sans"})
C={"ink":"#24303d","p0":"#2563eb","p1":"#7c3aed","p2":"#0d9488","p3":"#b45309",
   "term":"#b91c1c","data":"#15803d","gray":"#64748b","lgray":"#cbd5e1"}

def box(ax,x,y,w,h,t,ec,fc,fs=9):
    ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle="round,pad=0.02",lw=1.6,ec=ec,fc=fc,zorder=3))
    ax.text(x+w/2,y+h/2,t,ha="center",va="center",fontsize=fs,color=C["ink"],zorder=4)
def arrow(ax,p1,p2,col=C["gray"],style="-|>",lw=1.6,ls="-"):
    ax.add_patch(FancyArrowPatch(p1,p2,arrowstyle=style,mutation_scale=13,lw=lw,color=col,ls=ls,zorder=2))

def fig_dag():
    fig,ax=plt.subplots(figsize=(13,6.6)); ax.axis("off"); ax.set_xlim(0,15); ax.set_ylim(0,9)
    # Phase 0
    box(ax,0.3,6.2,2.7,1.5,"PHASE 0\nLPS validation\n(Tier 0 $\\to$ full plan)",C["p0"],"#eff6ff")
    box(ax,0.3,4.5,2.7,1.1,"Toolkit emitted:\n$S$, $\\mathrm{tr}\\,S$, analytic\nLOO/CV, error bands",C["p0"],"#dbeafe",fs=8)
    # cross-cutting data enabler (bottom band)
    box(ax,0.3,0.3,11.2,1.2,"CROSS-CUTTING DATA ENABLER:  toy stratified generators  $\\to$  VALENCIA E1/E2/E3 exploration  $\\to$  realistic 16S generators (known ground-truth components)",C["data"],"#f0fdf4",fs=8.5)
    # Phase 1 (parallel)
    box(ax,3.9,7.1,3.0,1.2,"1a. PS-LPS\nprediction synchronization",C["p1"],"#f5f3ff")
    box(ax,3.9,5.4,3.0,1.2,"1b. Local-dimension\nregularization ($\\ell_1$ field)",C["p1"],"#f5f3ff")
    # Phase 2
    box(ax,7.7,7.1,3.1,1.2,"2a. Local covariance /\nassociation (compositional)",C["p2"],"#f0fdfa")
    box(ax,7.7,5.4,3.1,1.2,"2b. Simplicial complex (nerve)\n$=$ INTEGRATION of 1a+1b+2a",C["p2"],"#ccfbf1")
    # Phase 3
    box(ax,11.5,6.2,3.1,1.5,"PHASE 3 (capstone)\nQuasi-equilibrium / occupancy /\nsupport decomposition",C["p3"],"#fffbeb")
    # terminal
    box(ax,11.5,3.7,3.1,1.2,"TERMINAL\nReal 16S / omics\napplication",C["term"],"#fef2f2")
    # arrows: phase0 -> 1a,1b,2a
    arrow(ax,(3.0,7.0),(3.9,7.7),C["p0"]); arrow(ax,(3.0,6.6),(3.9,6.0),C["p0"])
    arrow(ax,(3.0,6.9),(7.7,7.7),C["p0"],lw=1.1,ls=":")
    # toolkit -> 1a (df-match), 2b
    arrow(ax,(3.0,5.0),(3.9,5.9),C["p0"],ls="--",lw=1.1)
    # data -> 1b, 2a, 3
    arrow(ax,(5.4,1.5),(5.4,5.4),C["data"],ls=":",lw=1.1)
    arrow(ax,(9.2,1.5),(9.2,5.4),C["data"],ls=":",lw=1.1)
    arrow(ax,(11.5,1.2),(12.8,6.2),C["data"],ls=":",lw=1.1)
    # 1a,1b,2a -> 2b
    arrow(ax,(6.9,7.5),(7.7,6.2),C["p1"]); arrow(ax,(6.9,6.0),(7.7,6.0),C["p1"])
    arrow(ax,(9.25,7.1),(9.25,6.6),C["p2"])
    # 2a,2b -> 3
    arrow(ax,(10.8,7.5),(11.5,7.2),C["p2"]); arrow(ax,(10.8,6.0),(11.5,6.9),C["p2"])
    # 3 -> app ; phase0 -> app
    arrow(ax,(13.05,6.2),(13.05,4.9),C["p3"])
    ax.text(7.5,8.7,"Dependency DAG: arrows point from prerequisite to dependent.  Solid = direct dependency,  dashed = reuses the Phase-0 toolkit,  dotted = uses synthetic data.",
            ha="center",fontsize=9.5,color=C["ink"])
    save=os.path.join(OUT,"fig_program_dag.pdf"); fig.savefig(save); plt.close(fig); print("wrote fig_program_dag.pdf")

def fig_timeline():
    fig,ax=plt.subplots(figsize=(12.5,5.2)); ax.set_xlim(0,10); ax.set_ylim(0,8.4)
    phases=["Phase 0","Phase 1","Phase 2","Phase 3","Terminal"]
    xb=[0.6,2.6,4.8,7.0,8.8]; xe=[2.4,4.6,6.8,8.6,9.8]
    for i,(p,a,b) in enumerate(zip(phases,xb,xe)):
        ax.axvspan(a,b,color=C["lgray"],alpha=0.10 if i%2 else 0.18)
        ax.text((a+b)/2,8.05,p,ha="center",fontsize=9.5,color=C["ink"],fontweight="bold")
    tracks=[("Validation (LPS Tier 0 $\\to$ plan)",C["p0"],[(0.6,2.4)]),
            ("Data: VALENCIA $\\to$ generators",C["data"],[(0.9,8.6)]),
            ("1a PS-LPS synchronization",C["p1"],[(2.6,4.6)]),
            ("1b Local-dimension $\\ell_1$ field",C["p1"],[(2.6,4.6)]),
            ("2a Local covariance (compositional)",C["p2"],[(4.8,6.8)]),
            ("2b Nerve integration (combine)",C["p2"],[(5.4,6.8)]),
            ("Occupancy / quasi-equilibrium",C["p3"],[(7.0,8.6)]),
            ("Real 16S / omics application",C["term"],[(8.8,9.8)])]
    ys=np.linspace(7.2,0.7,len(tracks))
    for (name,col,spans),y in zip(tracks,ys):
        ax.text(0.5,y,name,ha="right",va="center",fontsize=8.6,color=C["ink"])
        for (a,b) in spans:
            ax.add_patch(FancyBboxPatch((a,y-0.22),b-a,0.44,boxstyle="round,pad=0.01",lw=0,fc=col,alpha=0.8))
    # gates (diamonds) at phase boundaries
    for gx in [2.5,4.7,6.9,8.7]:
        ax.add_patch(MPoly([[gx,8.0],[gx+0.13,7.8],[gx,7.6],[gx-0.13,7.8]],closed=True,color=C["ink"]))
    ax.text(2.5,7.35,"gate",ha="center",fontsize=7,color=C["ink"])
    ax.text(0.5,-0.2,"Bars show when each track is active. The two Phase-1 tracks (PS-LPS, dimension field) run in PARALLEL on the validated base; the data track runs throughout; diamonds are independent-audit go/no-go gates.",
            fontsize=8.3,color=C["ink"],ha="left")
    ax.set_xticks([]); ax.set_yticks([])
    for s in ax.spines.values(): s.set_visible(False)
    save=os.path.join(OUT,"fig_program_timeline.pdf"); fig.savefig(save); plt.close(fig); print("wrote fig_program_timeline.pdf")

fig_dag(); fig_timeline(); print("done")
