#!/usr/bin/env python3
"""Original figures for the 'Effective Degrees of Freedom' note.
All schematics and simulations are produced from scratch; nothing is reproduced
from any external source. Most panels are genuine computations (optimism
simulation, Stein verification, smoother-matrix trace, the two-route df check)."""
import os
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch

OUT = os.path.dirname(os.path.abspath(__file__))
rng = np.random.default_rng(7)
plt.rcParams.update({
    "figure.dpi": 120, "savefig.bbox": "tight", "font.size": 10.5,
    "font.family": "DejaVu Sans", "axes.spines.top": False,
    "axes.spines.right": False})
C = {"ink": "#22303c", "blue": "#2563eb", "red": "#c0392b", "green": "#15803d",
     "purple": "#7c3aed", "teal": "#0d9488", "orange": "#b45309",
     "gray": "#64748b", "lgray": "#cbd5e1"}


def kernel_S(x, bw):
    """Gaussian kernel smoother matrix S (rows sum to 1); linear: yhat = S y."""
    D = (x[:, None] - x[None, :]) ** 2
    W = np.exp(-0.5 * D / bw ** 2)
    return W / W.sum(1, keepdims=True)


# ---- Fig 1: optimism / covariance penalty --------------------------------------
def fig_optimism():
    n, sigma = 40, 0.6
    xs = np.linspace(-1, 1, n)
    f = lambda x: np.sin(2.2 * x) + 0.4 * x
    degs = np.arange(0, 12)
    tr, te = [], []
    reps = 500
    for d in degs:
        e_tr, e_te = [], []
        Xp = np.vander(xs, d + 1)
        for _ in range(reps):
            y = f(xs) + rng.normal(0, sigma, n)
            beta, *_ = np.linalg.lstsq(Xp, y, rcond=None)
            yhat = Xp @ beta
            e_tr.append(np.mean((y - yhat) ** 2))
            ystar = f(xs) + rng.normal(0, sigma, n)
            e_te.append(np.mean((ystar - yhat) ** 2))
        tr.append(np.mean(e_tr)); te.append(np.mean(e_te))
    tr, te, df = np.array(tr), np.array(te), degs + 1
    fig, ax = plt.subplots(figsize=(7, 4.3))
    ax.plot(df, tr, "-o", color=C["blue"], ms=4, label=r"in-sample error  $E[\mathrm{err}]$")
    ax.plot(df, te, "-o", color=C["red"], ms=4, label=r"out-of-sample error  $E[\mathrm{Err}]$")
    ax.fill_between(df, tr, te, color=C["lgray"], alpha=0.55)
    k = 7
    ax.annotate(r"optimism $=\dfrac{2}{n}\sum_i\mathrm{Cov}(\hat y_i,y_i)=\dfrac{2\sigma^2}{n}\,\mathrm{df}$",
                xy=(df[k], (tr[k] + te[k]) / 2), xytext=(df[k] - 5.4, te.max() * 0.97),
                fontsize=9, color=C["ink"],
                arrowprops=dict(arrowstyle="->", color=C["gray"]))
    ax.axhline(sigma ** 2, ls=":", color=C["gray"])
    ax.text(df[-1], sigma ** 2 * 1.05, r"$\sigma^2$ (irreducible noise)", ha="right",
            fontsize=8, color=C["gray"])
    ax.set_xlabel("model complexity  =  degrees of freedom  (polynomial df = degree + 1)")
    ax.set_ylabel("mean squared error")
    ax.legend(fontsize=8.5, loc="upper center")
    fig.savefig(os.path.join(OUT, "fig_optimism.pdf")); plt.close(fig)


# ---- Fig 2: self-sensitivity dy_i/dy_i = S_ii ----------------------------------
def fig_selfsens():
    n = 30
    xs = np.linspace(0, 1, n)
    r2 = np.random.default_rng(3)
    y = np.sin(3 * xs) + r2.normal(0, 0.25, n)
    i, Delta = 15, 1.0
    fig, axes = plt.subplots(1, 2, figsize=(10, 4), sharey=True)
    specs = [(0.025, r"small bandwidth (chases data): $S_{ii}\approx 1$"),
             (0.20,  r"large bandwidth (smooths): $S_{ii}\approx 0$")]
    for ax, (bw, lab) in zip(axes, specs):
        S = kernel_S(xs, bw)
        yhat = S @ y
        y2 = y.copy(); y2[i] += Delta
        yhat2 = S @ y2
        ax.plot(xs, y, "o", color=C["gray"], ms=4, alpha=0.6, label=r"data $y$")
        ax.plot(xs, yhat, "-", color=C["blue"], lw=2, label=r"fit $\hat y$")
        ax.plot(xs, yhat2, "--", color=C["red"], lw=2, label=r"fit after nudging $y_i{+}1$")
        ax.annotate("", xy=(xs[i], yhat2[i]), xytext=(xs[i], yhat[i]),
                    arrowprops=dict(arrowstyle="->", color=C["red"], lw=2))
        ax.text(xs[i] + 0.02, (yhat[i] + yhat2[i]) / 2,
                rf"$\partial\hat y_i/\partial y_i = S_{{ii}} = {S[i, i]:.2f}$",
                fontsize=8.5, color=C["red"])
        ax.set_title(lab, fontsize=9.5); ax.set_xlabel("$x$")
    axes[0].set_ylabel(r"$y,\ \hat y$")
    axes[0].legend(fontsize=8, loc="upper left")
    fig.savefig(os.path.join(OUT, "fig_selfsens.pdf")); plt.close(fig)


# ---- Fig 3: smoother matrix S and tr S -----------------------------------------
def fig_smatrix():
    n = 22
    xs = np.linspace(0, 1, n)
    S = kernel_S(xs, 0.075)
    df = np.trace(S)
    fig, axes = plt.subplots(1, 2, figsize=(10, 4.2))
    im = axes[0].imshow(S, cmap="viridis")
    axes[0].plot(range(n), range(n), color=C["red"], lw=0.9, ls=":")
    axes[0].set_title(rf"smoother matrix $S$ ($\hat y=Sy$);  $\mathrm{{df}}=\mathrm{{tr}}\,S={df:.2f}$",
                      fontsize=9.5)
    axes[0].set_xlabel("$j$ (data index)"); axes[0].set_ylabel("$i$ (fitted index)")
    fig.colorbar(im, ax=axes[0], fraction=0.046, pad=0.04)
    for r, c in zip([4, 11, 18], [C["blue"], C["green"], C["purple"]]):
        axes[1].plot(xs, S[r], color=c, lw=2, label=rf"row $i={r}$")
        axes[1].axvline(xs[r], color=c, ls=":", lw=0.8)
    axes[1].set_title("rows of $S$ = equivalent kernels (weights sum to 1)", fontsize=9.5)
    axes[1].set_xlabel("$x_j$"); axes[1].set_ylabel(r"weight $S_{ij}$")
    axes[1].legend(fontsize=8)
    fig.savefig(os.path.join(OUT, "fig_smatrix.pdf")); plt.close(fig)


# ---- Fig 4: Stein's lemma (identity + numeric verification) --------------------
def fig_stein():
    z = np.linspace(-4, 4, 400)
    phi = np.exp(-0.5 * z ** 2) / np.sqrt(2 * np.pi)
    fig, axes = plt.subplots(1, 2, figsize=(10, 4.1))
    axes[0].plot(z, phi, color=C["ink"], lw=2, label=r"$\varphi(z)$")
    axes[0].plot(z, z * phi, color=C["blue"], lw=2, label=r"$z\,\varphi(z)=-\varphi'(z)$")
    axes[0].axhline(0, color=C["gray"], lw=0.6)
    axes[0].set_title(r"integration-by-parts identity ($\mu{=}0,\sigma{=}1$):"
                      "\n" r"$(z-\mu)\varphi(z)=-\sigma^2\varphi'(z)$", fontsize=9)
    axes[0].set_xlabel("$z$"); axes[0].legend(fontsize=8.5)
    lam, sigma, N = 1.0, 1.0, 300000
    mus = np.linspace(-3, 3, 25)
    cov, sde = [], []
    for mu in mus:
        Z = rng.normal(mu, sigma, N)
        g = np.sign(Z) * np.maximum(np.abs(Z) - lam, 0.0)   # soft-threshold
        cov.append(np.cov(Z, g)[0, 1])
        sde.append(sigma ** 2 * np.mean((np.abs(Z) > lam).astype(float)))  # sigma^2 E[g']
    axes[1].plot(mus, cov, "o", color=C["red"], ms=4, label=r"$\mathrm{Cov}(Z,g(Z))$  (simulated)")
    axes[1].plot(mus, sde, "-", color=C["blue"], lw=2, label=r"$\sigma^2\,E[g'(Z)]$  (Stein)")
    axes[1].set_title(r"Stein check for soft-threshold $g$:" "\n"
                      r"covariance $=\sigma^2 E[g']$", fontsize=9)
    axes[1].set_xlabel(r"mean $\mu$"); axes[1].legend(fontsize=8.5)
    fig.savefig(os.path.join(OUT, "fig_stein.pdf")); plt.close(fig)


# ---- Fig 5: three lenses schematic ---------------------------------------------
def fig_threelenses():
    fig, ax = plt.subplots(figsize=(9, 5.3)); ax.axis("off")
    ax.set_xlim(0, 10); ax.set_ylim(0, 7)

    def box(x, y, w, h, t, ec, fc, fs=9):
        ax.add_patch(FancyBboxPatch((x, y), w, h, boxstyle="round,pad=0.03",
                                    lw=1.8, ec=ec, fc=fc, zorder=3))
        ax.text(x + w / 2, y + h / 2, t, ha="center", va="center",
                fontsize=fs, color=C["ink"], zorder=4)

    box(3.2, 5.1, 3.6, 1.45, "COVARIANCE\n" r"$\mathrm{df}=\sigma^{-2}\sum_i\mathrm{Cov}(\hat y_i,y_i)$",
        C["blue"], "#eff6ff", 8.7)
    box(0.2, 1.0, 3.7, 1.7, "DIVERGENCE\n" r"$\mathrm{df}=E[\sum_i\partial\hat y_i/\partial y_i]$"
        "\n" r"$=E[\mathrm{tr}\,J(y)]$", C["purple"], "#f5f3ff", 8.5)
    box(6.1, 1.0, 3.7, 1.7, "LINEAR SMOOTHER\n" r"$\mathrm{df}=\mathrm{tr}\,S$"
        "\n" r"($\hat y = Sy$)", C["teal"], "#f0fdfa", 8.5)
    ax.add_patch(FancyArrowPatch((3.7, 5.1), (2.1, 2.7), arrowstyle="<->",
                 mutation_scale=14, lw=1.6, color=C["gray"]))
    ax.text(2.0, 4.0, "Stein's lemma\n(Gaussian $y$)", fontsize=8.2, color=C["ink"], ha="center")
    ax.add_patch(FancyArrowPatch((6.3, 5.1), (7.9, 2.7), arrowstyle="<->",
                 mutation_scale=14, lw=1.6, color=C["gray"]))
    ax.text(8.2, 4.0, r"$\mathrm{Cov}(\hat y_i,y_i)=\sigma^2 S_{ii}$" "\n(any error dist.)",
            fontsize=8.2, color=C["ink"], ha="center")
    ax.add_patch(FancyArrowPatch((3.9, 1.85), (6.1, 1.85), arrowstyle="<->",
                 mutation_scale=14, lw=1.6, color=C["gray"]))
    ax.text(5.0, 2.2, r"linear $\Rightarrow J(y)=S$" "\n(constant Jacobian)",
            fontsize=8.2, color=C["ink"], ha="center")
    ax.text(5.0, 6.8, "three faces of one number", ha="center", fontsize=10.5,
            color=C["ink"], style="italic")
    fig.savefig(os.path.join(OUT, "fig_threelenses.pdf")); plt.close(fig)


# ---- Fig 6: non-integer df (ridge) ---------------------------------------------
def fig_ridge():
    d = np.array([3.0, 2.1, 1.3, 0.8, 0.45, 0.25, 0.12, 0.05])
    lams = np.logspace(-3, 2, 200)
    dfr = np.array([np.sum(d ** 2 / (d ** 2 + l)) for l in lams])
    fig, ax = plt.subplots(figsize=(7, 4.3))
    ax.plot(lams, dfr, color=C["teal"], lw=2.4)
    ax.set_xscale("log")
    ax.axhline(len(d), ls=":", color=C["gray"])
    ax.text(lams[0], len(d) + 0.12, rf"OLS df $=p={len(d)}$  ($\lambda\to0$)",
            fontsize=8.5, color=C["gray"])
    ax.axhline(0, ls=":", color=C["gray"])
    ax.text(lams[-1], 0.18, r"df $\to 0$  ($\lambda\to\infty$)", fontsize=8.5,
            color=C["gray"], ha="right")
    l0 = 1.0; df0 = np.sum(d ** 2 / (d ** 2 + l0))
    ax.plot([l0], [df0], "o", color=C["red"])
    ax.annotate(rf"non-integer df $={df0:.2f}$", (l0, df0), (l0 * 3, df0 + 1.2),
                fontsize=9, color=C["red"], arrowprops=dict(arrowstyle="->", color=C["red"]))
    ax.set_xlabel(r"ridge penalty $\lambda$")
    ax.set_ylabel(r"$\mathrm{df}(\lambda)=\sum_j d_j^2/(d_j^2+\lambda)$")
    ax.set_title("ridge: degrees of freedom vary continuously between $p$ and $0$", fontsize=9.5)
    fig.savefig(os.path.join(OUT, "fig_ridge.pdf")); plt.close(fig)


# ---- Fig 7: the E0.2 two-route falsification test ------------------------------
def fig_tworoute():
    n = 18
    xs = np.linspace(0, 1, n)
    r3 = np.random.default_rng(11)
    y0 = np.sin(3 * xs) + r3.normal(0, 0.2, n)

    def fit_linear(y, bw=0.10):
        return kernel_S(xs, bw) @ y

    def fit_nonlin(y):
        # bandwidth depends on the response -> hidden y-dependence -> NOT linear
        bw = 0.05 + 0.13 * np.abs(y - y.mean()) / (y.std() + 1e-9)
        out = np.zeros(n)
        for i in range(n):
            w = np.exp(-0.5 * ((xs - xs[i]) / bw[i]) ** 2); w /= w.sum()
            out[i] = w @ y
        return out

    def route_A_trS(fit):
        S = np.column_stack([fit(np.eye(n)[:, j]) for j in range(n)])
        return np.trace(S)

    def route_B_bumptrace(fit, y):
        f0 = fit(y); tr = 0.0
        for i in range(n):
            yb = y.copy(); yb[i] += 1.0
            tr += fit(yb)[i] - f0[i]
        return tr

    aL, bL = route_A_trS(lambda v: fit_linear(v)), route_B_bumptrace(lambda v: fit_linear(v), y0)
    aN, bN = route_A_trS(fit_nonlin), route_B_bumptrace(fit_nonlin, y0)
    fig, ax = plt.subplots(figsize=(7.5, 4.3))
    xpos = [0, 1.5]; w = 0.34
    ax.bar([x - w / 2 for x in xpos], [aL, aN], width=w, color=C["blue"],
           label=r"route A: $\mathrm{tr}\,S$ from $\mathrm{fit}(e_j)$")
    ax.bar([x + w / 2 for x in xpos], [bL, bN], width=w, color=C["orange"],
           label="route B: finite-difference trace (bump $y$)")
    for x, a, b in zip(xpos, [aL, aN], [bL, bN]):
        ax.text(x - w / 2, a + 0.05, f"{a:.2f}", ha="center", fontsize=8.5)
        ax.text(x + w / 2, b + 0.05, f"{b:.2f}", ha="center", fontsize=8.5)
    ax.text(xpos[0], max(aL, bL) + 0.35, "agree", ha="center", color=C["green"], fontsize=9.5)
    ax.text(xpos[1], max(aN, bN) + 0.35, "disagree", ha="center", color=C["red"], fontsize=9.5)
    ax.set_xticks(xpos)
    ax.set_xticklabels(["linear smoother\n(correct)", "y-dependent bandwidth\n(hidden nonlinearity)"])
    ax.set_ylabel("degrees of freedom")
    ax.set_title("E0.2 test: the two routes agree iff the code is truly linear", fontsize=9.5)
    ax.legend(fontsize=8.3, loc="upper center")
    ax.set_ylim(0, max(aL, bL, aN, bN) + 1.0)
    fig.savefig(os.path.join(OUT, "fig_tworoute.pdf")); plt.close(fig)


for fn in (fig_optimism, fig_selfsens, fig_smatrix, fig_stein,
           fig_threelenses, fig_ridge, fig_tworoute):
    fn(); print("wrote", fn.__name__)
print("done")
