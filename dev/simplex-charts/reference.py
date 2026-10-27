"""Research reference implementation: local surface charts and binary prediction.
No cohort outcomes are used here. Not a modification of the geosmooth package.
"""
import os
for k in ('OMP_NUM_THREADS','OPENBLAS_NUM_THREADS','MKL_NUM_THREADS','VECLIB_MAXIMUM_THREADS'):
    os.environ[k]='1'
import numpy as np
from scipy.special import expit
from scipy.spatial.distance import cdist


def unfold(U, reference, faces=None):
    """Rotate at most one neighboring face into a reference-face plane.
    U includes the query for face classification; ties require a separate chart.
    Retain the constant reference coordinate, harmless for centered PCA.
    """
    U=np.asarray(U,float)
    if np.any(U < -1e-12) or not np.allclose(U.max(axis=1),1,atol=1e-12,rtol=0):
        raise ValueError('Points must lie on the nonnegative max-one surface')
    active=np.isclose(U,1,atol=1e-12,rtol=0)
    if np.any(active.sum(axis=1)>1): raise ValueError('Tied maximal coordinates')
    f=U.argmax(axis=1) if faces is None else np.asarray(faces)
    others=set(f)-{int(reference)}
    if len(others)>1: raise ValueError('More than two faces: separate charts required')
    V=U.copy()
    if others:
        j=next(iter(others)); hit=f==j
        V[hit,j]=2-U[hit,reference]; V[hit,reference]=1
    return V


def components(X,w,kind,y=None,maximum=3):
    """Weighted PCA or PLS1 rotations; weighted centering, no feature rescaling.
    PLS deflation stores R = W(P'W)^-1, so new points use training coefficients.
    """
    w=w/w.sum(); mean=w@X; Z=X-mean
    if kind=='pca':
        cov=Z.T@(w[:,None]*Z)
        vals,V=np.linalg.eigh(cov); ix=np.argsort(vals)[::-1]
        vals=vals[ix]; V=V[:,ix]
        take=min(maximum,int((vals>max(1e-14,vals[0]*1e-10)).sum()))
        return mean,V[:,:take]
    E=Z.copy(); f=np.asarray(y,float)-w@y; W=[]; P=[]
    for _ in range(maximum):
        a=E.T@(w*f); norm=np.linalg.norm(a)
        if norm<1e-12: break
        a/=norm; t=E@a; tt=w@(t*t)
        if tt<1e-14: break
        p=E.T@(w*t)/tt; q=w@(f*t)/tt
        W.append(a);P.append(p);E-=np.outer(t,p);f-=q*t
    if not W:return mean,np.zeros((X.shape[1],0))
    W=np.array(W).T;P=np.array(P).T
    return mean,W@np.linalg.inv(P.T@W)


def logistic(A,y,w,ridge,query):
    """Strictly convex ridge likelihood plus half-success/half-failure intercept.
    The pseudo-observation is at the local weighted center (all score values 0).
    """
    p=A.shape[1]; b=np.zeros(p); b[0]=np.log((w@y+.5)/(w@(1-y)+.5))
    penalty=np.r_[0.,np.full(p-1,ridge)]
    def objective(b):
        eta=A@b
        return np.sum(w*(np.logaddexp(0,eta)-y*eta))+.5*np.sum(penalty*b*b)+np.logaddexp(0,b[0])-.5*b[0]
    status=False
    for _ in range(70):
        pr=expit(A@b); pi=expit(b[0]); g=A.T@(w*(pr-y))+penalty*b;g[0]+=pi-.5
        if np.max(np.abs(g))<1e-7:status=True;break
        H=A.T@((w*pr*(1-pr))[:,None]*A)+np.diag(penalty);H[0,0]+=pi*(1-pi)
        step=np.linalg.solve(H,g); loss=objective(b); rate=1.
        for _ in range(30):
            candidate=b-rate*step
            trial=objective(candidate)
            if trial<=loss-1e-4*rate*(g@step):break
            # At machine-precision loss differences, use gradient improvement.
            # This does not relax the final residual threshold.
            if abs(trial-loss)<=32*np.finfo(float).eps*max(1.,abs(loss)):
                pp=expit(A@candidate); gg=A.T@(w*(pp-y))+penalty*candidate;gg[0]+=expit(candidate[0])-.5
                if np.max(np.abs(gg))<np.max(np.abs(g)):break
            rate*=.5
        b=candidate
    return float(expit(query@b)),status,float(np.max(np.abs(g)))


GRID=[(d,r) for d in (1,2,3) for r in (.1,1.,10.)]
METHODS=['ambient_pca','unfolded_pca','unfolded_pls']


def predict_grid(Utrain,Ztrain,y,Uquery,Zquery,K=60):
    """All geometry, directions and scores use training only; query has no y."""
    D=cdist(Zquery,Ztrain); ans=np.zeros((len(Uquery),len(METHODS),len(GRID)))
    const=np.zeros(len(Uquery));fail=np.zeros_like(ans,dtype=bool); maxgrad=0.
    for q in range(len(Uquery)):
        nn=np.argsort(D[q],kind='stable')[:K]; h=D[q,nn[-1]]
        w=np.exp(-.5*(D[q,nn]/h)**2) if h>0 else np.ones(K)
        w*=K/w.sum(); yy=y[nn];const[q]=(w@yy+.5)/(K+1)
        for m,method in enumerate(METHODS):
            if method=='ambient_pca': X=Utrain[nn]; query=Uquery[q]
            else: X=Ztrain[nn];query=Zquery[q]
            mean,R=components(X,w,'pls' if method.endswith('pls') else 'pca',yy)
            T=(X-mean)@R; tq=(query-mean)@R
            scale=np.sqrt((w[:,None]*T*T).sum(axis=0)/K)
            scale=np.maximum(scale,1e-12);T/=scale;tq/=scale
            for g,(d,ridge) in enumerate(GRID):
                d=min(d,T.shape[1]); A=np.column_stack([np.ones(K),T[:,:d]]);aq=np.r_[1.,tq[:d]]
                pred,ok,grad=logistic(A,yy,w,ridge,aq);maxgrad=max(maxgrad,grad)
                ans[q,m,g]=pred if ok else const[q];fail[q,m,g]=not ok
    return ans,const,fail,maxgrad
