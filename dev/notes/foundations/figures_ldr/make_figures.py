#!/usr/bin/env python3
"""Original illustrative figures for the LPS local-dimension-regularization note.
All figures are produced from scratch (numpy + matplotlib only); none are
reproductions of figures from any paper."""
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import Ellipse, FancyArrowPatch, Circle
from mpl_toolkits.mplot3d import Axes3D  # noqa
from mpl_toolkits.mplot3d.art3d import Poly3DCollection

OUT = os.path.dirname(os.path.abspath(__file__))
plt.rcParams.update({
    "figure.dpi": 120, "savefig.bbox": "tight", "font.size": 11,
    "axes.titlesize": 12, "axes.labelsize": 11, "axes.spines.top": False,
    "axes.spines.right": False, "legend.frameon": False, "font.family": "DejaVu Sans",
})
C = {"blue": "#2563eb", "orange": "#d97706", "green": "#15803d", "red": "#b91c1c",
     "gray": "#64748b", "purple": "#7c3aed", "lgray": "#cbd5e1", "teal": "#0d9488"}

def save(fig, name):
    p = os.path.join(OUT, name)
    fig.savefig(p)
    plt.close(fig)
    print("wrote", name)

rng = np.random.default_rng(7)

# ---------------------------------------------------------------- 1. pipeline
def fig_pipeline():
    fig, axs = plt.subplots(1, 5, figsize=(13, 2.9))
    # cloud
    t = rng.uniform(0, 2*np.pi, 60); X = np.c_[np.cos(t), np.sin(t)] + 0.12*rng.standard_normal((60,2))
    ax = axs[0]; ax.scatter(X[:,0], X[:,1], s=10, color=C["gray"]); ax.set_title("1. data cloud")
    # graph
    ax = axs[1]; ax.scatter(X[:,0], X[:,1], s=10, color=C["gray"])
    from itertools import combinations
    D = np.linalg.norm(X[:,None,:]-X[None,:,:], axis=2)
    for i in range(len(X)):
        for j in np.argsort(D[i])[1:4]:
            ax.plot([X[i,0],X[j,0]],[X[i,1],X[j,1]], color=C["lgray"], lw=0.6, zorder=0)
    ax.set_title("2. neighbor graph")
    # local chart
    ax = axs[2]; c = np.array([1.0,0.0]); idx = np.argsort(np.linalg.norm(X-c,axis=1))[:12]
    ax.scatter(X[:,0], X[:,1], s=8, color=C["lgray"])
    ax.scatter(X[idx,0], X[idx,1], s=22, color=C["blue"])
    nb = X[idx]-X[idx].mean(0); u,s,vt = np.linalg.svd(nb, full_matrices=False)
    d0 = vt[0]; p0 = X[idx].mean(0)
    ax.annotate("", p0+0.6*d0, p0-0.6*d0, arrowprops=dict(arrowstyle="<->", color=C["red"], lw=2))
    ax.text(*(p0+0.5*d0+np.array([0,0.18])), "tangent\n(local PCA)", color=C["red"], fontsize=8, ha="center")
    ax.set_title("3. local chart")
    # local fit
    ax = axs[3]
    z = np.linspace(-1,1,40); ytrue = 0.6*z; yobs = ytrue + 0.12*rng.standard_normal(40)
    zz = z[np.abs(z)<0.5]; w = np.exp(-(zz/0.3)**2)
    A = np.c_[np.ones_like(zz), zz]; W=np.diag(w)
    beta = np.linalg.solve(A.T@W@A, A.T@W@(ytrue[np.abs(z)<0.5]+0.12*rng.standard_normal(zz.size)))
    ax.scatter(z, yobs, s=10, color=C["gray"])
    ax.plot(zz, A@beta, color=C["blue"], lw=2.2, label="local line")
    ax.scatter([0],[beta[0]], color=C["red"], s=45, zorder=5, label="prediction")
    ax.set_title("4. local polynomial"); ax.legend(fontsize=7, loc="upper left")
    ax.set_xlabel("chart coord $z$")
    # combine
    ax = axs[4]
    xx = np.linspace(0,2*np.pi,200)
    ax.plot(np.cos(xx), np.sin(xx), color=C["green"], lw=2.4)
    ax.scatter(X[:,0], X[:,1], s=6, color=C["lgray"])
    ax.set_title("5. smoother $\\hat f$")
    for ax in axs:
        ax.set_xticks([]); ax.set_yticks([]); ax.set_aspect("equal")
        for s_ in ["left","bottom"]: ax.spines[s_].set_visible(False)
    fig.suptitle("The LPS pipeline: neighbor graph $\\rightarrow$ local chart $\\rightarrow$ local polynomial $\\rightarrow$ smoother", y=1.04, fontsize=12)
    save(fig, "fig_pipeline.pdf")

# ---------------------------------------------------------- 2. local polynomial 1D
def fig_local_poly():
    fig, axs = plt.subplots(1, 2, figsize=(11, 3.6))
    x = np.linspace(0,1,160); f = np.sin(2.2*np.pi*x)*np.exp(-x)
    y = f + 0.10*rng.standard_normal(x.size)
    x0 = 0.5; h = 0.12
    for ax, deg, name in [(axs[0],0,"degree 0 (local mean)"),(axs[1],1,"degree 1 (local line)")]:
        w = np.exp(-0.5*((x-x0)/h)**2)
        if deg==0:
            pred = np.sum(w*y)/np.sum(w); fit_x=np.array([x0-2*h,x0+2*h]); fit_y=np.array([pred,pred])
        else:
            A=np.c_[np.ones_like(x), x-x0]; W=np.diag(w); b=np.linalg.solve(A.T@W@A, A.T@W@y)
            pred=b[0]; fit_x=np.linspace(x0-2.2*h,x0+2.2*h,20); fit_y=b[0]+b[1]*(fit_x-x0)
        ax.fill_between(x, -1.4, -1.4+0.9*w/w.max(), color=C["blue"], alpha=0.12)
        ax.scatter(x,y,s=8,color=C["lgray"])
        ax.plot(x,f,color=C["green"],lw=1.6,label="truth $f$")
        ax.plot(fit_x,fit_y,color=C["blue"],lw=2.4,label="local fit")
        ax.scatter([x0],[pred],color=C["red"],s=55,zorder=6,label="$\\hat f(x_0)$")
        ax.scatter([x0],[f[np.argmin(abs(x-x0))]],facecolors="none",edgecolors=C["green"],s=55,zorder=6)
        ax.axvline(x0,color=C["gray"],ls=":",lw=1)
        ax.set_title(name); ax.set_xlabel("$x$"); ax.set_ylim(-1.5,1.4); ax.legend(fontsize=8,loc="upper right")
        ax.text(0.02,-1.33,"kernel weights $w(x)$",color=C["blue"],fontsize=8)
    fig.suptitle("Local polynomial regression: a weighted line fit in a moving window; the prediction is its value at $x_0$", y=1.02)
    save(fig,"fig_local_poly.pdf")

# ---------------------------------------------------- 3. manifold + tangent chart
def fig_manifold_tangent():
    fig = plt.figure(figsize=(7.2,5.2)); ax = fig.add_subplot(111, projection="3d")
    uu,vv = np.meshgrid(np.linspace(-1.4,1.4,40), np.linspace(-1.4,1.4,40))
    R=2.2; zz=(uu**2+vv**2)/(2*R)
    ax.plot_surface(uu,vv,zz, alpha=0.35, color=C["lgray"], linewidth=0, antialiased=True)
    # neighborhood near a point
    u0,v0=0.7,0.5
    tu = rng.uniform(-0.45,0.45,40)+u0; tv=rng.uniform(-0.45,0.45,40)+v0
    tz=(tu**2+tv**2)/(2*R)
    ax.scatter(tu,tv,tz, color=C["blue"], s=14, depthshade=True)
    # fitted tangent plane at (u0,v0)
    gx=u0/R; gy=v0/R; z0=(u0**2+v0**2)/(2*R)
    pu,pv=np.meshgrid(np.linspace(u0-0.5,u0+0.5,2), np.linspace(v0-0.5,v0+0.5,2))
    pz=z0+gx*(pu-u0)+gy*(pv-v0)
    ax.plot_surface(pu,pv,pz, alpha=0.5, color=C["red"], linewidth=0)
    ax.scatter([u0],[v0],[z0], color=C["red"], s=50)
    ax.text(u0+0.1,v0,z0+0.25,"tangent chart\n(local PCA plane)",color=C["red"],fontsize=9)
    ax.set_title("A curved 2-D surface in 3-D; near a point the data look flat.\nLocal PCA finds that tangent plane = the chart LPS fits in.", fontsize=10)
    ax.set_xlabel("ambient $x_1$"); ax.set_ylabel("$x_2$"); ax.set_zlabel("$x_3$")
    ax.view_init(elev=22, azim=-60); ax.set_box_aspect((1,1,0.5))
    save(fig,"fig_manifold_tangent.pdf")

# --------------------------------------------------------- 4. local PCA ellipse
def fig_localpca():
    fig, axs = plt.subplots(1,2, figsize=(10,4))
    for ax, ratio, title in [(axs[0],0.08,"intrinsically 1-D neighborhood"),(axs[1],0.7,"intrinsically 2-D neighborhood")]:
        pts = rng.standard_normal((120,2))*np.array([0.6, 0.6*ratio])
        th=0.5; Rm=np.array([[np.cos(th),-np.sin(th)],[np.sin(th),np.cos(th)]]); pts=pts@Rm.T
        cov=np.cov(pts.T); ev,evec=np.linalg.eigh(cov); order=np.argsort(ev)[::-1]; ev=ev[order]; evec=evec[:,order]
        ax.scatter(pts[:,0],pts[:,1],s=10,color=C["gray"])
        for k in range(2):
            ax.add_patch(Ellipse((0,0), 2*2*np.sqrt(ev[0]), 2*2*np.sqrt(ev[1]),
                         angle=np.degrees(np.arctan2(evec[1,0],evec[0,0])),
                         fill=False, color=C["blue"], lw=1.4, alpha=0.7) if k==0 else Ellipse((0,0),0,0))
        for k,(col) in enumerate([C["red"],C["orange"]]):
            v=evec[:,k]*2*np.sqrt(ev[k])
            ax.annotate("",xy=v,xytext=(0,0),arrowprops=dict(arrowstyle="->",color=col,lw=2.4))
            ax.text(*(v*1.12),f"$\\lambda_{k+1}$",color=col,fontsize=11)
        ax.set_title(title+f"\n$\\lambda_1/\\lambda_2 \\approx {ev[0]/ev[1]:.0f}$")
        ax.set_aspect("equal"); ax.set_xlim(-1.6,1.6); ax.set_ylim(-1.6,1.6); ax.set_xticks([]); ax.set_yticks([])
    # figure-level title removed (overlapped panel titles); LaTeX caption carries it
    save(fig,"fig_localpca.pdf")

# --------------------------------------------------------------- 5. scree / gap
def fig_scree():
    fig, axs = plt.subplots(1,3, figsize=(12,3.3), sharey=True)
    specs = [([1.0,0.04,0.03,0.02,0.015], "clean 1-D\n(gap after $\\lambda_1$)", 1),
             ([1.0,0.8,0.05,0.03,0.02], "clean 2-D\n(gap after $\\lambda_2$)", 2),
             ([1.0,0.55,0.34,0.22,0.16], "ambiguous\n(no clear gap)", None)]
    for ax,(ev,t,k) in zip(axs,specs):
        bars=ax.bar(range(1,len(ev)+1), ev, color=C["lgray"], edgecolor=C["gray"])
        if k is not None:
            for i in range(k): bars[i].set_color(C["blue"])
            ax.annotate("gap", xy=(k+0.5,(ev[k-1]+ev[k])/2), xytext=(k+1.2,0.55),
                        arrowprops=dict(arrowstyle="->",color=C["red"]), color=C["red"], fontsize=10)
        ax.set_title(t); ax.set_xlabel("component"); ax.set_xticks(range(1,len(ev)+1))
    axs[0].set_ylabel("eigenvalue $\\lambda_i$")
    # figure-level title removed (overlapped panel titles); LaTeX caption carries it
    save(fig,"fig_scree.pdf")

# ----------------------------------------------- helpers: local dim estimate
def local_dim_estimate(X, idx, thresh=6.0):
    nb = X[idx]; nb = nb - nb.mean(0)
    if nb.shape[0] < 3: return 1
    s = np.linalg.svd(nb, compute_uv=False)
    ev = s**2
    ev = ev/ev[0]
    # dimension = count until a big relative gap
    k = 1
    for i in range(len(ev)-1):
        if ev[i]/max(ev[i+1],1e-9) > thresh and ev[i+1] < 0.25:
            k = i+1; break
        k = i+2
    return int(min(k, X.shape[1]))

# ---------------------------------------- 6 & 7. noisy dimension map + variance
def make_strat_data(n=900, noise=0.03, seed=3):
    r = np.random.default_rng(seed)
    # 2-D sheet on the right, 1-D curve on the left, glued at x=0
    n2 = int(n*0.6); n1 = n-n2
    s = r.uniform(0,1.4,(n2,2)); sheet = np.c_[s[:,0], s[:,1]-0.7, np.zeros(n2)]
    t = r.uniform(-1.4,0,n1); curve = np.c_[t, np.zeros(n1), np.zeros(n1)]
    X = np.vstack([sheet, curve]).astype(float)
    Xn = X + noise*r.standard_normal(X.shape)
    truth = np.r_[np.full(n2,2), np.full(n1,1)]
    return Xn, truth

def fig_noisy_dim():
    fig, axs = plt.subplots(1,3, figsize=(13,4))
    X, truth = make_strat_data()
    D = np.linalg.norm(X[:,None,:]-X[None,:,:],axis=2)
    cmap={1:C["orange"],2:C["blue"],3:C["red"]}
    # truth
    ax=axs[0]
    for d in [1,2]: m=truth==d; ax.scatter(X[m,0],X[m,1],s=8,color=cmap[d],label=f"dim {d}")
    ax.set_title("true local dimension"); ax.legend(fontsize=8,loc="lower right")
    # small k estimate (noisy)
    for ax,k,t in [(axs[1],8,"estimate, $k=8$ (noisy)"),(axs[2],35,"estimate, $k=35$ (calmer)")]:
        est=np.array([local_dim_estimate(X, np.argsort(D[i])[:k]) for i in range(len(X))])
        for d in [1,2,3]:
            m=est==d
            if m.any(): ax.scatter(X[m,0],X[m,1],s=8,color=cmap.get(d,C["purple"]))
        err=np.mean(est!=truth)
        ax.set_title(t+f"\nmisclassified: {err*100:.0f}%")
    for ax in axs: ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([]); ax.set_xlim(-1.6,1.6); ax.set_ylim(-1.0,0.9)
    # figure-level title removed (overlapped panel titles); LaTeX caption carries it
    save(fig,"fig_noisy_dim.pdf")

def fig_variance_k():
    X, truth = make_strat_data()
    D = np.linalg.norm(X[:,None,:]-X[None,:,:],axis=2)
    ks=np.array([5,8,12,18,25,35,50,70])
    err=[];
    for k in ks:
        est=np.array([local_dim_estimate(X, np.argsort(D[i])[:k]) for i in range(len(X))])
        err.append(np.mean(est!=truth))
    fig,ax=plt.subplots(figsize=(6.4,4))
    ax.plot(ks,np.array(err)*100,"-o",color=C["blue"])
    ax.set_xlabel("neighborhood size $k$"); ax.set_ylabel("dimension misclassification (%)")
    ax.set_title("Bias–variance for the dimension estimate.\nToo small $k$: high variance. Too large $k$: blurs strata (bias).")
    ax.axvspan(5,12,color=C["red"],alpha=0.07); ax.axvspan(50,70,color=C["orange"],alpha=0.07)
    ax.text(8,max(err)*100*0.85,"noisy",color=C["red"],ha="center",fontsize=9)
    ax.text(60,max(err)*100*0.5,"over-smoothed",color=C["orange"],ha="center",fontsize=9)
    save(fig,"fig_variance_k.pdf")

# --------------------------------------------------- 8. scale / tubular nbhd
def fig_scale_tube():
    fig, axs = plt.subplots(1,2, figsize=(11,4))
    r=np.random.default_rng(1)
    t=np.linspace(-1.3,1.3,400); rho=0.06
    x=t; y=0.25*np.sin(2*t)+rho*r.standard_normal(t.size)
    ax=axs[0]; ax.scatter(x,y,s=6,color=C["gray"])
    c=np.array([0.0,0.0])
    for R,col,lab in [(0.45,C["blue"],"coarse $h$: looks 1-D"),(0.09,C["red"],"fine $h$: looks 2-D")]:
        ax.add_patch(Circle(c,R,fill=False,color=col,lw=2))
        ax.text(c[0]+R*0.1,c[1]+R+0.02,lab,color=col,fontsize=9,ha="center")
    ax.set_aspect("equal"); ax.set_title("A thin tube around a curve"); ax.set_xticks([]); ax.set_yticks([])
    ax.set_xlim(-1.4,1.4); ax.set_ylim(-0.6,0.7)
    ax=axs[1]
    h=np.logspace(-2,0,100); dim=1+1/(1+(h/rho)**3)  # smooth 2 -> 1 as h grows past rho
    ax.semilogx(h,dim,color=C["purple"],lw=2.4)
    ax.axvline(rho,color=C["gray"],ls=":"); ax.text(rho*1.1,1.15,"tube radius $\\rho$",fontsize=9,color=C["gray"])
    ax.axhline(1,color=C["lgray"],lw=0.8); ax.axhline(2,color=C["lgray"],lw=0.8)
    ax.set_xlabel("scale / bandwidth $h$"); ax.set_ylabel("effective dimension"); ax.set_ylim(0.8,2.2)
    ax.set_title("There is no single 'true' dimension:\nit depends on the scale you look at")
    # figure-level title removed (overlapped panel titles); LaTeX caption carries it
    save(fig,"fig_scale_tube.pdf")

# --------------------------------------------------------- 9. stratified space
def fig_stratified():
    fig=plt.figure(figsize=(7.6,4.2)); ax=fig.add_subplot(111, projection="3d")
    r=np.random.default_rng(5)
    s=r.uniform(0,1.2,(400,2)); ax.scatter(s[:,0],s[:,1]-0.6,0*s[:,0],s=7,color=C["blue"],label="2-D face")
    t=r.uniform(-1.2,0,160); ax.scatter(t,0*t,0*t,s=10,color=C["orange"],label="1-D face")
    ax.scatter([0],[0],[0],color=C["red"],s=60,label="singular junction")
    ax.set_title("A stratified (non-manifold) object: a 1-D edge meeting a 2-D sheet.\nThe intrinsic dimension is piecewise constant with a sudden jump.",fontsize=10)
    ax.legend(fontsize=8,loc="upper left"); ax.view_init(elev=55,azim=-65)
    ax.set_xticks([]); ax.set_yticks([]); ax.set_zticks([]); ax.set_box_aspect((1,1,0.35))
    save(fig,"fig_stratified.pdf")

# ----------------------------------------------------- TV / L2 1D solvers
def l2_smooth(y, lam):
    n=len(y); Dm=np.zeros((n-1,n))
    for i in range(n-1): Dm[i,i]=-1; Dm[i,i+1]=1
    return np.linalg.solve(np.eye(n)+lam*Dm.T@Dm, y)

def tv_denoise(y, lam, rho=1.0, it=400):
    n=len(y); Dm=np.zeros((n-1,n))
    for i in range(n-1): Dm[i,i]=-1; Dm[i,i+1]=1
    d=y.copy(); z=Dm@d; u=np.zeros(n-1)
    M=np.eye(n)+rho*Dm.T@Dm; Minv=np.linalg.inv(M)
    for _ in range(it):
        d=Minv@(y+rho*Dm.T@(z-u))
        a=Dm@d+u; z=np.sign(a)*np.maximum(np.abs(a)-lam/rho,0); u=u+Dm@d-z
    return d

# -------------------------------------------- 10. KEY: L1 vs L2 dimension field
def fig_l1_vs_l2():
    r=np.random.default_rng(11)
    n=120; x=np.linspace(0,1,n)
    truth=np.where(x<0.5,1.0,2.0)
    noisy=truth+r.normal(0,0.45,n)  # noisy continuous "dimension score"
    l2=l2_smooth(noisy,18.0)
    l1=tv_denoise(noisy,3.0)
    fig,ax=plt.subplots(figsize=(9.5,4.4))
    ax.scatter(x,noisy,s=12,color=C["lgray"],label="noisy per-anchor estimates")
    ax.plot(x,truth,color=C["green"],lw=2.2,ls="--",label="true dimension (a sharp jump)")
    ax.plot(x,l2,color=C["orange"],lw=2.6,label="$\\ell_2$ / Laplacian smoothing  (blurs the boundary)")
    ax.plot(x,l1,color=C["blue"],lw=2.6,label="$\\ell_1$ / total variation  (keeps the jump)")
    ax.axvline(0.5,color=C["gray"],ls=":",lw=1)
    ax.set_xlabel("position along a path crossing a stratum boundary")
    ax.set_ylabel("local dimension")
    ax.set_ylim(0,3); ax.legend(fontsize=9,loc="upper left")
    ax.set_title("Why $\\ell_1$, not $\\ell_2$: smoothing the dimension field with squared differences\nsmears the stratum boundary into a ramp; total variation preserves the clean step.")
    save(fig,"fig_l1_vs_l2.pdf")

# ---------------------------------------------- 11. graph field before/after
def graph_median_smooth(vals, nbrs, it=6):
    v=vals.copy()
    for _ in range(it):
        v=np.array([np.median(np.r_[v[i], v[nbrs[i]]]) for i in range(len(v))])
    return np.round(v).astype(int)

def fig_graph_field():
    r=np.random.default_rng(2)
    # 2D grid of anchors, true region split by a wavy boundary
    gx,gy=np.meshgrid(np.linspace(0,1,22), np.linspace(0,1,18))
    P=np.c_[gx.ravel(), gy.ravel()]
    boundary=0.5+0.12*np.sin(2*np.pi*P[:,1]*1.3)
    truth=np.where(P[:,0]<boundary,1,2)
    noisy=truth.copy()
    flip=r.random(len(P))<0.28; noisy=np.where(flip, 3-noisy, noisy)  # speckle
    D=np.linalg.norm(P[:,None,:]-P[None,:,:],axis=2)
    nbrs=[np.argsort(D[i])[1:7] for i in range(len(P))]
    reg=graph_median_smooth(noisy.astype(float),nbrs)
    fig,axs=plt.subplots(1,3,figsize=(13,3.8))
    cmap={1:C["orange"],2:C["blue"],3:C["red"]}
    for ax,vals,t in [(axs[0],truth,"true field"),(axs[1],noisy,"independent estimates (noisy)"),(axs[2],reg,"graph-regularized field")]:
        for d in [1,2]:
            m=vals==d; ax.scatter(P[m,0],P[m,1],s=42,color=cmap[d],marker="s")
        ax.set_title(t); ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([])
    em0=np.mean(noisy!=truth)*100; em1=np.mean(reg!=truth)*100
    axs[1].set_xlabel(f"{em0:.0f}% wrong"); axs[2].set_xlabel(f"{em1:.0f}% wrong")
    fig.suptitle("Borrowing strength over the neighbor graph: a TV/graph-cut field cleans the speckle while keeping the boundary sharp.", y=1.03)
    save(fig,"fig_graph_field.pdf")

# ----------------------------------------------- 12. Ishikawa schematic
def fig_ishikawa():
    fig,ax=plt.subplots(figsize=(8,4.3))
    nodes=4; levels=4
    for i in range(nodes):
        for l in range(levels):
            ax.scatter(i, l, s=120, color=C["lgray"], edgecolor=C["gray"], zorder=3)
        # vertical (data) edges
        for l in range(levels-1):
            ax.annotate("",xy=(i,l+1),xytext=(i,l),arrowprops=dict(arrowstyle="->",color=C["gray"],lw=1))
    # horizontal (smoothness) edges between adjacent nodes at each level
    for i in range(nodes-1):
        for l in range(levels):
            ax.plot([i,i+1],[l,l],color=C["blue"],lw=1.0,alpha=0.6,zorder=1)
    # source/sink
    ax.scatter([-0.9],[1.5],s=200,color=C["green"],zorder=4); ax.text(-0.9,1.5,"s",ha="center",va="center",color="white",fontweight="bold")
    ax.scatter([nodes-0.1+0.9],[1.5],s=200,color=C["red"],zorder=4); ax.text(nodes-0.1+0.9,1.5,"t",ha="center",va="center",color="white",fontweight="bold")
    # a cut (staircase)
    cut_y=[0.5,1.5,1.5,2.5]
    ax.plot(range(nodes),cut_y,color=C["red"],lw=2.4,ls="--",zorder=5)
    ax.text(1.5,3.3,"min cut  =  the chosen dimension at each node",color=C["red"],ha="center",fontsize=10)
    ax.set_xlabel("graph nodes (anchors)"); ax.set_ylabel("ordered labels (dimension $1,2,3,4$)")
    ax.set_title("Ishikawa's construction: an ordered-label field with a convex penalty\nbecomes a min-cut on a layered graph — solved exactly, fast.")
    ax.set_xticks(range(nodes)); ax.set_yticks(range(levels)); ax.set_yticklabels([1,2,3,4])
    ax.set_xlim(-1.6,nodes+0.6); ax.set_ylim(-0.6,3.6)
    save(fig,"fig_ishikawa.pdf")

# ------------------------------------------------------ 13. simplex faces
def fig_simplex():
    fig,axs=plt.subplots(1,2,figsize=(11,4.6))
    V=np.array([[0,0],[1,0],[0.5,np.sqrt(3)/2]])
    for ax in axs:
        tri=plt.Polygon(V,fill=True,color=C["lgray"],alpha=0.25,ec=C["gray"],lw=1.5); ax.add_patch(tri)
        ax.scatter(V[:,0],V[:,1],s=60,color=C["red"],zorder=5)
        for (vx,vy),lab in zip(V,["$e_A$","$e_B$","$e_C$"]):
            ax.text(vx,vy-0.07 if vy<0.1 else vy-0.12,lab,ha="center",fontsize=11,color=C["red"])
        ax.set_aspect("equal"); ax.set_xticks([]); ax.set_yticks([]); ax.axis("off")
    # left: face lattice labels
    ax=axs[0]
    ax.text(0.5,-0.13,"edge: $C$ absent (a 1-face)",ha="center",color=C["orange"],fontsize=9)
    ax.text(0.5,0.30,"interior:\nall present (2-face)",ha="center",color=C["blue"],fontsize=9)
    ax.set_title("The face lattice of the 2-simplex\n(which taxa are present = which face)")
    # right: data concentration near an edge (tube), full support but near a face
    ax=axs[1]
    r=np.random.default_rng(4)
    s=r.uniform(0.12,0.88,300); tube=0.04*r.standard_normal(300)
    P=np.outer(1-s,V[0])+np.outer(s,V[1])+np.outer(tube,(V[2]-(V[0]+V[1])/2))
    ax.scatter(P[:,0],P[:,1],s=7,color=C["blue"])
    ax.set_title("Data with full support but concentrated in a thin\ntube near the edge: naive dim 2, effective dim 1")
    save(fig,"fig_simplex.pdf")

# ----------------------------------------------------------- 14. CLR trap
def fig_clr_trap():
    fig,axs=plt.subplots(1,2,figsize=(11,4))
    r=np.random.default_rng(8)
    base=np.linspace(0.02,0.6,200); xi=base+0.015*r.standard_normal(200)  # a taxon's relative abundance
    xi=np.clip(xi,1e-3,None)
    ax=axs[0]; ax.scatter(np.arange(200),xi,s=8,color=C["blue"]); ax.axhline(0,color=C["gray"],lw=0.8)
    ax.set_title("raw cube coordinate $\\xi=x_i/x_k$\nnear a face: small, variance collapses (thin)")
    ax.set_ylabel("$\\xi$"); ax.set_xlabel("sample"); ax.set_ylim(-0.05,0.7)
    ax.annotate("approaching the face",xy=(10,xi[10]),xytext=(40,0.45),
                arrowprops=dict(arrowstyle="->",color=C["red"]),color=C["red"],fontsize=9)
    ax=axs[1]; u=np.log(xi); ax.scatter(np.arange(200),u,s=8,color=C["orange"])
    ax.set_title("log-ratio $u=\\log\\xi$\nnear a face: $\\to-\\infty$, variance explodes (fat!)")
    ax.set_ylabel("$u$"); ax.set_xlabel("sample")
    ax.annotate("same points, now\nthe largest spread",xy=(10,u[10]),xytext=(40,-2.2),
                arrowprops=dict(arrowstyle="->",color=C["red"]),color=C["red"],fontsize=9)
    # figure-level title removed (overlapped panel titles); LaTeX caption carries it
    save(fig,"fig_clr_trap.pdf")

# --------------------------------------------------------- 15. boundary bias
def fig_boundary_bias():
    fig,ax=plt.subplots(figsize=(8,4))
    x=np.linspace(0,1,200); f=np.exp(1.3*x);
    r=np.random.default_rng(9); y=f+0.06*r.standard_normal(x.size)
    h=0.12
    def localfit(x0,deg):
        w=np.exp(-0.5*((x-x0)/h)**2)
        if deg==0: return np.sum(w*y)/np.sum(w)
        A=np.c_[np.ones_like(x),x-x0]; W=np.diag(w); b=np.linalg.solve(A.T@W@A,A.T@W@y); return b[0]
    grid=np.linspace(0.0,1.0,60)
    p0=[localfit(g,0) for g in grid]; p1=[localfit(g,1) for g in grid]
    ax.scatter(x,y,s=6,color=C["lgray"]); ax.plot(x,f,color=C["green"],lw=1.8,label="truth")
    ax.plot(grid,p0,color=C["orange"],lw=2,label="degree 0 (biased at edges)")
    ax.plot(grid,p1,color=C["blue"],lw=2,label="degree 1 (edge-corrected)")
    ax.axvspan(0,h,color=C["red"],alpha=0.06); ax.axvspan(1-h,1,color=C["red"],alpha=0.06)
    ax.text(h/2,1.1,"boundary",rotation=90,color=C["red"],fontsize=8,va="bottom",ha="center")
    ax.set_title("Boundary bias: at the edge of the data, a local mean lags the trend;\na local line removes that bias to first order.")
    ax.set_xlabel("$x$"); ax.legend(fontsize=8,loc="upper left")
    save(fig,"fig_boundary_bias.pdf")

# --------------------------------------------------------- 16. consistency rate
def fig_consistency():
    fig,ax=plt.subplots(figsize=(6.6,4))
    n=np.array([200,400,800,1600,3200,6400.])
    for d,col in [(1,C["blue"]),(2,C["orange"]),(3,C["red"])]:
        rate=n**(-2/(d+4)); rate=rate/rate[0]*0.3
        ax.loglog(n,rate,"-o",color=col,label=f"$d={d}$: slope $-2/(d+4)={-2/(d+4):.2f}$")
    ax.set_xlabel("sample size $n$"); ax.set_ylabel("Truth-RMSE (log scale)")
    ax.set_title("Why dimension is the whole game: the error rate is set by the\n*intrinsic* dimension $d$, not the ambient one. Smaller $d$ = faster learning.")
    ax.legend(fontsize=8.5)
    save(fig,"fig_consistency.pdf")

for f in [fig_pipeline, fig_local_poly, fig_manifold_tangent, fig_localpca, fig_scree,
          fig_noisy_dim, fig_variance_k, fig_scale_tube, fig_stratified, fig_l1_vs_l2,
          fig_graph_field, fig_ishikawa, fig_simplex, fig_clr_trap, fig_boundary_bias,
          fig_consistency]:
    try:
        f()
    except Exception as e:
        print("FAILED", f.__name__, "->", repr(e))
print("done")
