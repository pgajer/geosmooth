#!/usr/bin/env python3
"""Original schematics for the chart-nerve substrate note. All figures are
produced from scratch (numpy + matplotlib); none are reproduced from any source."""
import os, numpy as np, matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Circle, Ellipse, FancyArrowPatch, FancyBboxPatch, Polygon as MPoly
OUT = os.path.dirname(os.path.abspath(__file__))
plt.rcParams.update({"figure.dpi":120,"savefig.bbox":"tight","font.size":11,
    "axes.titlesize":11.5,"axes.spines.top":False,"axes.spines.right":False,
    "legend.frameon":False,"font.family":"DejaVu Sans"})
C={"blue":"#2563eb","orange":"#d97706","green":"#15803d","red":"#b91c1c",
   "gray":"#64748b","purple":"#7c3aed","lgray":"#cbd5e1","teal":"#0d9488"}
def save(fig,n): fig.savefig(os.path.join(OUT,n)); plt.close(fig); print("wrote",n)
rng=np.random.default_rng(11)

# a wavy 1-D-ish cloud with a small 2-D thickening (a junction)
t=np.linspace(0,1,90); cx=2*t; cy=0.55*np.sin(2.4*np.pi*t)
X=np.c_[cx,cy]+0.025*rng.standard_normal((90,2))
# chart centers + variable radii (bigger where sparse)
ci=np.array([2,14,26,38,50,62,74,86]); centers=X[ci].copy()
radii=np.array([0.34,0.30,0.40,0.30,0.30,0.40,0.30,0.34])

def overlaps(c,r):
    E=[]; n=len(c)
    for i in range(n):
        for j in range(i+1,n):
            if np.linalg.norm(c[i]-c[j])<0.95*(r[i]+r[j]): E.append((i,j))
    return E

# ----------------------------------------------- 1. substrate progression
def fig_substrate():
    fig,axs=plt.subplots(1,3,figsize=(13.5,4.0))
    # (a) kNN scaffold
    ax=axs[0]; ax.scatter(X[:,0],X[:,1],s=9,color=C["gray"])
    D=np.linalg.norm(X[:,None]-X[None],axis=2)
    for i in range(len(X)):
        for j in np.argsort(D[i])[1:4]:
            ax.plot([X[i,0],X[j,0]],[X[i,1],X[j,1]],color=C["lgray"],lw=0.6,zorder=0)
    ax.set_title("(a) input scaffold:\nadaptive-radius kNN graph (pairwise)")
    # (b) variable-size chart cover
    ax=axs[1]; ax.scatter(X[:,0],X[:,1],s=6,color=C["lgray"])
    for c,r in zip(centers,radii):
        ax.add_patch(Circle(c,r,fill=True,color=C["blue"],alpha=0.10,ec=C["blue"],lw=1.1))
    ax.scatter(centers[:,0],centers[:,1],s=26,color=C["blue"],zorder=5)
    ax.set_title("(b) variable-size local charts\n(a cover, sized to the local geometry)")
    # (c) nerve
    ax=axs[2]
    E=overlaps(centers,radii)
    # find a mutually-overlapping triple for a 2-simplex
    tri=None
    for a in range(len(centers)):
        for b in range(a+1,len(centers)):
            for d in range(b+1,len(centers)):
                if (a,b) in E and (b,d) in E and (a,d) in E: tri=(a,b,d); break
            if tri: break
        if tri: break
    if tri:
        ax.add_patch(MPoly(centers[list(tri)],closed=True,color=C["orange"],alpha=0.25,zorder=0))
    for (i,j) in E:
        ax.plot([centers[i,0],centers[j,0]],[centers[i,1],centers[j,1]],color=C["gray"],lw=1.6,zorder=1)
    ax.scatter(centers[:,0],centers[:,1],s=70,color=C["blue"],zorder=5,ec="white")
    if tri:
        cc=centers[list(tri)].mean(0); ax.text(cc[0],cc[1]+0.05,"2-simplex\n(triple overlap)",
            ha="center",fontsize=7.5,color=C["orange"])
    ax.set_title("(c) nerve of the cover: nodes = charts,\nedges = overlaps, triangles = triple overlaps")
    for ax in axs:
        ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
        for s in ["left","bottom"]: ax.spines[s].set_visible(False)
        ax.set_xlim(-0.45,2.45); ax.set_ylim(-0.95,0.95)
    save(fig,"fig_substrate.pdf")

# ------------------------------------------- 2. gluing on overlaps
def fig_glue():
    fig,axs=plt.subplots(1,2,figsize=(12,4.3))
    # left: two overlapping charts; local fits agree on the overlap
    ax=axs[0]
    c1=np.array([0.0,0.0]); c2=np.array([0.95,0.18]); r=0.7
    for c,col in [(c1,C["blue"]),(c2,C["green"])]:
        ax.add_patch(Circle(c,r,fill=True,color=col,alpha=0.08,ec=col,lw=1.3))
    # overlap lens region (schematic shading)
    ax.add_patch(Ellipse((0.48,0.09),0.5,0.95,angle=20,color=C["orange"],alpha=0.16))
    ax.text(0.48,0.62,"overlap = an edge of the nerve",ha="center",color=C["orange"],fontsize=8.5)
    # local linear fits (short segments) + covariance ellipses
    xs=np.linspace(-0.55,0.5,2); ax.plot(xs, -0.25+0.5*(xs-c1[0]),color=C["blue"],lw=2.2)
    xs=np.linspace(0.45,1.5,2); ax.plot(xs, -0.18+0.52*(xs-c2[0])+0.0,color=C["green"],lw=2.2)
    ax.add_patch(Ellipse(c1,0.5,0.22,angle=27,fill=False,ec=C["blue"],lw=1.3))
    ax.add_patch(Ellipse(c2,0.5,0.22,angle=28,fill=False,ec=C["green"],lw=1.3))
    ax.annotate("agree here:\nsame prediction\n& same covariance",xy=(0.48,0.0),xytext=(0.05,-0.7),
        arrowprops=dict(arrowstyle="->",color=C["red"]),color=C["red"],fontsize=8.5,ha="center")
    ax.scatter(*c1,s=40,color=C["blue"],zorder=5); ax.scatter(*c2,s=40,color=C["green"],zorder=5)
    ax.set_title("Pairwise overlap: neighboring charts must agree\non the shared region (PS-LPS + covariance)")
    ax.set_xlim(-0.8,1.7); ax.set_ylim(-0.95,0.85); ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
    # right: a 3-chart junction = a 2-simplex = higher-order agreement
    ax=axs[1]
    cc=np.array([[0,0],[0.9,0.05],[0.45,0.8]]); r=0.62
    cols=[C["blue"],C["green"],C["purple"]]
    for c,col in zip(cc,cols): ax.add_patch(Circle(c,r,fill=True,color=col,alpha=0.08,ec=col,lw=1.3))
    ax.add_patch(MPoly(cc,closed=True,color=C["orange"],alpha=0.22))
    for c,col in zip(cc,cols): ax.scatter(*c,s=46,color=col,zorder=5)
    ax.text(0.45,0.28,"triple overlap\n= a 2-simplex",ha="center",fontsize=8.5,color=C["orange"])
    ax.annotate("higher-order agreement\n(a junction of strata)",xy=(0.45,0.28),xytext=(1.35,0.75),
        arrowprops=dict(arrowstyle="->",color=C["red"]),color=C["red"],fontsize=8.5,ha="center")
    ax.set_title("Triple overlap: a constraint a pairwise graph\ncannot express, but the nerve can")
    ax.set_xlim(-0.8,2.1); ax.set_ylim(-0.75,1.55); ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
    save(fig,"fig_glue.pdf")

# ---------------------------------------------- 3. refinement loop
def fig_refine_loop():
    fig,ax=plt.subplots(figsize=(8.6,4.4)); ax.axis("off"); ax.set_xlim(0,10); ax.set_ylim(0,6)
    def box(x,y,w,h,t,col,fc):
        ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle="round,pad=0.08",lw=1.6,ec=col,fc=fc))
        ax.text(x+w/2,y+h/2,t,ha="center",va="center",fontsize=9.5,color="#24303d")
    box(0.5,3.7,3.0,1.5,"LOCAL CHARTS\n(size + local dimension\nper anchor)",C["blue"],"#eff6ff")
    box(6.5,3.7,3.0,1.5,"NERVE of the cover\n(who overlaps whom,\nand how much)",C["purple"],"#f5f3ff")
    box(6.5,0.6,3.0,1.5,"GLUED ESTIMATES\ncond. expectation +\nlocal covariance",C["green"],"#f0fdf4")
    box(0.5,0.6,3.0,1.5,"held-out accuracy\nselects the substrate",C["orange"],"#fff7ed")
    def arr(x1,y1,x2,y2,t,col):
        ax.add_patch(FancyArrowPatch((x1,y1),(x2,y2),arrowstyle="-|>",mutation_scale=15,lw=1.7,color=col))
        ax.text((x1+x2)/2,(y1+y2)/2+0.2,t,ha="center",fontsize=8,color=col)
    arr(3.5,4.45,6.5,4.45,"take the nerve",C["purple"])
    arr(8.0,3.7,8.0,2.1,"synchronize\nover overlaps",C["green"])
    arr(6.5,1.35,3.5,1.35,"score by\nprediction error",C["orange"])
    arr(2.0,2.1,2.0,3.7,"re-size / re-dim\ncharts",C["blue"])
    ax.set_title("The estimation problem chooses the substrate: charts $\\to$ nerve $\\to$ glued estimates $\\to$ refine,\nguided by held-out conditional-expectation accuracy (not by topology).",fontsize=10.5)
    save(fig,"fig_refine_loop.pdf")

for f in [fig_substrate, fig_glue, fig_refine_loop]:
    try: f()
    except Exception as e: print("FAILED",f.__name__,"->",repr(e))
print("done")
