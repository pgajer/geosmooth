#!/usr/bin/env Rscript
# Synthetic fixed-location comparisons using archived quadratic-residual TF data.
# Usage: Rscript benchmark_projection_trend_filtering.R prepare STUDY_ROOT OUTPUT
#        Rscript benchmark_projection_trend_filtering.R run OUTPUT CONFIG_RDS
#        Rscript benchmark_projection_trend_filtering.R summarize OUTPUT RUN_NAME
# Load current optimized source through GEOSMOOTH_SOURCE and DGRAPHS_SOURCE, or
# use installed packages. Preparation compiles the research backend once; run
# workers load its saved wrapper without compiling. Output is never overwritten.

btf.atomic <- function(x,path) {
    tmp <- paste0(path,".tmp-",Sys.getpid()); saveRDS(x,tmp)
    if (!file.rename(tmp,path)) stop("Cannot publish checkpoint: ",path)
}
btf.hash <- function(path) digest::digest(file=path,algo="sha256")
btf.provenance <- function() {
    sources <- character()
    for (p in c("dgraphs","geosmooth")) {
        root <- Sys.getenv(paste0(toupper(p),"_SOURCE"))
        if (nzchar(root)) sources <- c(sources,list.files(file.path(root,"R"),full.names=TRUE),
            list.files(file.path(root,"src"),pattern="[.](cpp|h|so)$",full.names=TRUE))
    }
    dlls <- vapply(getLoadedDLLs(),function(d)d[["path"]],character(1))
    script <- sub("^--file=","",grep("^--file=",commandArgs(),value=TRUE))
    paths <- unique(c(sources,dlls,script)); paths <- paths[file.exists(paths)&!dir.exists(paths)]
    list(files=setNames(vapply(paths,btf.hash,character(1)),paths),
        session=utils::sessionInfo(),threads=Sys.getenv(c("OMP_NUM_THREADS","OMP_THREAD_LIMIT",
            "OPENBLAS_NUM_THREADS","VECLIB_MAXIMUM_THREADS","MKL_NUM_THREADS")))
}
btf.load <- function() {
    for (p in c("dgraphs","geosmooth")) {
        path <- Sys.getenv(paste0(toupper(p),"_SOURCE"))
        if (nzchar(path)) pkgload::load_all(path,recompile=FALSE,quiet=TRUE) else
            library(p,character.only=TRUE)
    }
    library(Matrix)
}
btf.legacy <- function(out) {
    e <- new.env(parent=globalenv()); meta <- readRDS(file.path(out,"prepared.rds"))
    stopifnot(btf.hash(meta$wrapper)==meta$wrapper.hash)
    for (name in names(meta$source.hashes))
        stopifnot(btf.hash(file.path(out,"legacy",name))==meta$source.hashes[[name]])
    sys.source(meta$wrapper,envir=e)
    for (name in c("quadratic_residual.R","null_face_polish.R","projector_variants.R","certificate_checker.R"))
        sys.source(file.path(out,"legacy",name),envir=e)
    e
}
btf.prepare <- function(study,out) {
    stopifnot(!file.exists(file.path(out,"prepared.rds")))
    for (d in c("inputs","operators","legacy","backend","runs")) dir.create(file.path(out,d),recursive=TRUE,showWarnings=FALSE)
    study <- normalizePath(study); out <- normalizePath(out)
    later <- file.path(study,"practical_validation/step4_confirmation")
    frozen <- file.path(later,"frozen_sources")
    names <- c("residual_solver.cpp","quadratic_residual.R","null_face_polish.R","projector_variants.R","certificate_checker.R")
    sources <- vapply(names,function(n) file.path(frozen,n),character(1))
    stopifnot(all(file.exists(sources)))
    for (f in sources) stopifnot(file.copy(f,file.path(out,"legacy",basename(f))))
    cpp <- file.path(out,"legacy/residual_solver.cpp")
    flags <- file.path(out,"backend/Makevars")
    writeLines(c("CXXFLAGS = -O2","CXX17FLAGS = -O2"),flags)
    Sys.setenv(R_MAKEVARS_USER=flags,
        PKG_CPPFLAGS=paste0("-I",shQuote(system.file("include",package="geosmooth"))," -DEIGEN_DONT_PARALLELIZE"))
    env <- new.env(parent=globalenv())
    built <- Rcpp::sourceCpp(cpp,env=env,cacheDir=file.path(out,"backend"),rebuild=TRUE,showOutput=FALSE)
    wrappers <- list.files(built$buildDirectory,pattern="residual_solver[.]cpp[.]R$",full.names=TRUE)
    stopifnot(length(wrappers)==1L)
    meta <- list(wrapper=wrappers,wrapper.hash=btf.hash(wrappers),study=study,
        source.hashes=setNames(vapply(sources,btf.hash,character(1)),names),
        package.source=Sys.getenv("GEOSMOOTH_SOURCE"),prepared=as.character(Sys.time()))
    btf.atomic(meta,file.path(out,"prepared.rds"))
    legacy <- btf.legacy(out); rows <- list()
    original <- expand.grid(surface=c("quadratic","hinge","bump","interaction"),
        design=c("regular","irregular"),family=c("gaussian","binomial"),stringsAsFactors=FALSE)
    original <- original[original$family=="gaussian" | original$surface %in% c("hinge","bump"),]
    for (i in seq_len(nrow(original))) {
        r <- original[i,]; id <- paste("main",r$design,r$family,r$surface,6101,sep="_")
        path <- file.path(study,"results",paste0(id,".rds")); a <- readRDS(path)
        stopifnot(identical(a$id,id))
        folds <- cbind(a$fold,sapply(c(300000L,400000L),function(k) {
            set.seed(6101L+k); sample(rep(1:3,length.out=nrow(a$X)))
        }))
        p <- list(id=id,X=a$X,y=a$y,truth=a$truth,link.truth=a$link.truth,
            family=r$family,design=r$design,surface=r$surface,dimension=2L,seed=6101L,
            folds=folds,source=path,source.hash=btf.hash(path),archive="original")
        btf.atomic(p,file.path(out,"inputs",paste0(id,".rds"))); rows[[length(rows)+1L]] <- p
    }
    scenarios <- read.csv(file.path(later,"planning/proposed_scenarios.csv"))
    for (i in seq_len(nrow(scenarios))) {
        r <- scenarios[i,]; id <- paste0("fresh",r$dimension,"d_",r$design,"_",r$surface,"_",r$first.seed)
        path <- file.path(later,"results/problems",paste0(id,".rds")); a <- readRDS(path)
        p <- list(id=id,X=a$X,y=a$y,truth=a$truth,link.truth=a$link.truth,family="gaussian",
            design=r$design,surface=r$surface,dimension=r$dimension,seed=r$first.seed,
            folds=do.call(cbind,a$folds),source=path,source.hash=btf.hash(path),archive="later")
        btf.atomic(p,file.path(out,"inputs",paste0(id,".rds"))); rows[[length(rows)+1L]] <- p
    }
    stopifnot(length(rows)==18L,sum(vapply(rows,function(p)p$family=="binomial",logical(1)))==4L)
    manifest <- do.call(rbind,lapply(rows,function(p) data.frame(id=p$id,family=p$family,
        design=p$design,surface=p$surface,dimension=p$dimension,seed=p$seed,n=nrow(p$X),
        source=p$source,source.hash=p$source.hash,archive=p$archive)))
    write.csv(manifest,file.path(out,"datasets.csv"),row.names=FALSE)
    for (p in rows) {
        start <- proc.time()[3]; q <- (ncol(p$X)+1)*(ncol(p$X)+2)/2
        base <- legacy$quadratic.residual.operator(p$X,support.size=2*q,max.support=6*q,tie.rule="whole")
        complete <- legacy$quadratic.projector.operator(p$X,supports=base$supports,
            anchors=seq_len(nrow(p$X)),weighting="unit",residual="complete",kernel="uniform")
        central <- legacy$quadratic.projector.operator(p$X,supports=base$supports,
            anchors=seq_len(nrow(p$X)),weighting="unit",residual="central",kernel="uniform")
        D <- as.matrix(stats::dist(p$X)); diag(D) <- Inf; edges <- matrix(FALSE,nrow(D),nrow(D))
        for (i in seq_len(nrow(D))) edges[i,order(D[i,],seq_len(nrow(D)))[seq_len(2*ncol(p$X))]] <- TRUE
        edges <- edges|t(edges); adj <- lapply(seq_len(nrow(D)),function(i)which(edges[i,]))
        G <- geosmooth::graph.trend.filtering.operator(adj,order=2L,weight.rule="unit")
        B <- G$penalty$matrix; B <- as(Matrix::Diagonal(x=1/sqrt(Matrix::rowSums(B*B)))%*%B,"dgCMatrix")
        graph <- list(B=B,polynomial=matrix(1,nrow(p$X),1),X=p$X)
        ops <- list(complete=complete,central_matched=central,graph=graph)
        for (op in ops) stopifnot(max(abs(op$B%*%op$polynomial))<1e-8)
        btf.atomic(list(operators=ops,elapsed=unname(proc.time()[3]-start)),
            file.path(out,"operators",paste0(p$id,".rds")))
    }
    capture.output(sessionInfo(),file=file.path(out,"preparation_session.txt"))
    invisible(manifest)
}

btf.score <- function(y,eta,family) {
    if (family=="gaussian") return((y-eta)^2)
    p <- pmin(1-1e-8,pmax(1e-8,plogis(eta)))
    -y*log(p)-(1-y)*log1p(-p)
}
btf.seed <- function(p,rep,fold) as.integer(p$seed+rep*10000L+fold*100L)
btf.anchor <- function(X,y,family,rho,seed,control) {
    started <- proc.time()[3]
    prob <- geosmooth:::.ptf.problem(X,y,NULL,NULL,family,"isotropic",0,rho,
        geosmooth:::.ptf.control(control),"banded")
    bank <- geosmooth:::.ptf.with.seed(seed,geosmooth:::.ptf.bank(prob,NULL))
    values <- numeric(); records <- list()
    fitter <- if (family=="gaussian") geosmooth::fit.gaussian.trend.filtering else
        geosmooth::fit.logistic.trend.filtering
    for (j in seq_len(nrow(bank))) {
        attempt <- tryCatch({
            x <- geosmooth:::.ptf.projection(prob,bank[j,])
            null <- fitter(x,y,Inf,curve.ridge=length(y)*rho,backend="banded",warn=FALSE)
            stopifnot(null$diagnostics$converged)
            eta <- as.numeric(predict(null,type="link")); h <- eta-mean(eta)
            grad <- ((if(family=="gaussian")eta-y else plogis(eta)-y)+rho*h)/length(y)
            d <- null$design
            H <- geosmooth:::.logistic.tf.basis((x-d$lo)/d$span,d$knots)
            g <- as.vector(crossprod(sweep(H,2,d$center),grad))
            reference <- max(1e-10,max(abs(g[-c(1,2)]))*1.01)
            ok <- FALSE
            for (extension in 0:2) {
                fit <- fitter(x,y,length(y)*reference,curve.ridge=length(y)*rho,backend="banded",warn=FALSE)
                ok <- fit$diagnostics$converged && max(abs(as.numeric(predict(fit,type="link"))-eta))<1e-6
                if (ok) break
                reference <- reference*10
            }
            if (!ok) stop("finite quadratic anchor did not certify")
            list(value=reference,status="certified")
        },error=function(e)list(value=NA_real_,status=conditionMessage(e)))
        values[j] <- attempt$value
        records[[j]] <- data.frame(direction=j,reference=attempt$value,status=attempt$status)
    }
    if (!any(is.finite(values))) stop("No certified training-only projection penalty anchor")
    list(value=max(values,na.rm=TRUE),records=do.call(rbind,records),elapsed=unname(proc.time()[3]-started))
}

btf.grid <- function(method,p,cfg) {
    if (method %in% c("coordinate_tf2","fixed_bank_tf2","learned_tf2")) {
        terms <- if(method=="coordinate_tf2")c(0,ncol(p$X)) else cfg$nterms
        g <- expand.grid(nterms=terms,ratio=c(Inf,cfg$tf.ratios))
        g <- g[g$nterms>0 | is.infinite(g$ratio),,drop=FALSE]
    } else if (method %in% c("complete","central_matched","graph")) g <- data.frame(lambda=cfg$legacy.lambda)
    else if (method=="constant") g <- data.frame(constant=1)
    else if (method=="knn") g <- data.frame(k=cfg$knn)
    else if (method=="quadratic") g <- data.frame(ridge=cfg$quadratic.ridge)
    else if (method=="elastic_net") g <- expand.grid(alpha=c(0,.5,1),ratio=cfg$glmnet.ratios)
    else if (method=="classical_ppr") g <- expand.grid(nterms=cfg$ppr.terms,sm.method=c("supsmu","spline"),stringsAsFactors=FALSE)
    else stop("Unknown method")
    g$candidate <- seq_len(nrow(g)); rownames(g) <- NULL; g
}
btf.poly <- function(X) {
    Z <- X
    for (j in seq_len(ncol(X))) for (k in j:ncol(X)) Z <- cbind(Z,X[,j]*X[,k])
    Z
}

btf.fit <- function(method,p,train,query,grid,cfg,seed,legacy,operator=NULL,anchor=NULL) {
    x <- p$X[train,,drop=FALSE]; y <- p$y[train]; Q <- p$X[query,,drop=FALSE]
    n <- length(y); gaussian <- p$family=="gaussian"; fits <- vector("list",nrow(grid))
    if (method %in% c("complete","central_matched","graph")) {
        weights <- as.numeric(seq_along(p$y) %in% train)
        path <- tryCatch(legacy$fit.quadratic.residual.tf(operator,p$y,
            grid$lambda*length(train)/length(p$y),p$family,weights=weights,
            tolerance=1e-6,max.iterations=cfg$legacy.iterations,polish="active_set"),error=identity)
        for (j in seq_len(nrow(grid))) {
            if (inherits(path,"error")) { fits[[j]] <- list(ok=FALSE,status=conditionMessage(path)); next }
            f <- path$fits[[j]]; check <- tryCatch(legacy$check.saved.solution(operator$B,f$f,p$y,weights,
                grid$lambda[j]*length(train)/length(p$y),p$family,f$dual,operator$polynomial,1e-6),error=identity)
            ok <- isTRUE(f$converged) && !inherits(check,"error") && isTRUE(check$passed)
            fits[[j]] <- list(ok=ok,status=f$status,eta=if(ok)f$f[query] else rep(NA_real_,length(query)),
                diagnostic=list(check=check,iterations=f$iterations,lambda=f$lambda),fit=f)
        }
        return(fits)
    }
    for (j in seq_len(nrow(grid))) {
        spec <- grid[j,]; warnings <- character()
        fits[[j]] <- tryCatch(withCallingHandlers({
            diagnostic <- list(); model <- NULL
            if (method %in% c("coordinate_tf2","fixed_bank_tf2","learned_tf2")) {
                control <- cfg$control
                if(method=="fixed_bank_tf2")control$refinement.passes <- 0L
                model <- geosmooth::fit.projection.trend.filtering(x,y,lambda=spec$ratio*anchor$value,
                    family=p$family,nterms=spec$nterms,direction.search=if(method=="coordinate_tf2")"fixed" else "learned",
                    curve.ridge=cfg$rho,preprocessing="isotropic",seed=seed,control=control,backend="banded",warn=FALSE)
                eta <- as.numeric(predict(model,Q,type="link"))
                ok <- model$converged
                diagnostic <- list(checks=model$checks,search.status=model$search.status,
                    solver.calls=model$solver.calls,failed.proposals=if(nrow(model$search.history))
                        sum(model$search.history$status!="evaluated") else 0,
                    outside.range=sum(attr(predict(model,Q,type="link"),"outside.range")),
                    nterms=model$nterms,lambda=model$lambda)
                status <- model$status
            } else if (method=="constant") {
                value <- mean(y); eta <- rep(if(gaussian)value else qlogis(value),length(query))
                ok <- all(is.finite(eta)); status <- if(ok)"complete" else "nonfinite_intercept"
            } else if (method=="knn") {
                if (spec$k>n) stop("insufficient training neighbors")
                value <- vapply(seq_len(nrow(Q)),function(i) {
                    dist <- rowSums(sweep(x,2,Q[i,])^2)
                    mean(y[order(dist,seq_len(n))[seq_len(spec$k)]])
                },numeric(1))
                eta <- if(gaussian)value else qlogis(pmin(1-1e-8,pmax(1e-8,value)))
                diagnostic$clipped <- if(gaussian)0L else sum(value<1e-8|value>1-1e-8)
                ok <- all(is.finite(eta)); status <- "complete"
            } else if (method=="quadratic") {
                Z <- btf.poly(x); Zq <- btf.poly(Q)
                center <- colMeans(Z); scale <- sqrt(colMeans(sweep(Z,2,center)^2))
                stopifnot(all(scale>0)); Z <- cbind(1,sweep(sweep(Z,2,center),2,scale,"/"))
                Zq <- cbind(1,sweep(sweep(Zq,2,center),2,scale,"/"))
                penalty <- c(0,rep(spec$ridge,ncol(Z)-1))
                loss <- function(b) {
                    v <- as.vector(Z%*%b)
                    mean(if(gaussian)(y-v)^2/2 else pmax(v,0)-y*v+log1p(exp(-abs(v))))+sum(penalty*b^2)/2
                }
                grad <- function(b) {
                    v <- as.vector(Z%*%b)
                    as.vector(crossprod(Z,if(gaussian)v-y else plogis(v)-y))/n+penalty*b
                }
                if (gaussian) {
                    b <- solve(crossprod(Z)/n+diag(penalty),crossprod(Z,y)/n)
                    ok <- max(abs(grad(b)))<1e-6
                } else if (spec$ridge==0) {
                    model <- suppressWarnings(glm.fit(Z,y,family=binomial(),control=glm.control(epsilon=1e-10,maxit=200)))
                    b <- model$coefficients; ok <- isTRUE(model$converged)&&!isTRUE(model$boundary)&&all(is.finite(b))&&max(abs(grad(b)))<1e-6
                } else {
                    model <- optim(numeric(ncol(Z)),loss,grad,method="BFGS",control=list(reltol=1e-12,maxit=3000))
                    b <- model$par; ok <- model$convergence==0&&max(abs(grad(b)))<1e-6
                }
                eta <- as.vector(Zq%*%b); status <- if(ok)"certified" else "quadratic_solver_failed"
                diagnostic$stationarity <- max(abs(grad(b)))
            } else if (method=="elastic_net") {
                initial <- glmnet::glmnet(x,y,family=p$family,alpha=spec$alpha,nlambda=10,thresh=1e-10)
                lambda <- initial$lambda[1]*spec$ratio
                model <- glmnet::glmnet(x,y,family=p$family,alpha=spec$alpha,lambda=lambda,thresh=1e-10,maxit=100000)
                ok <- model$jerr==0 && length(model$lambda)==1L
                eta <- as.numeric(predict(model,Q,s=lambda,type="link"))
                diagnostic$lambda <- lambda; status <- if(ok)"complete" else "glmnet_solver_failed"
            } else if (method=="classical_ppr") {
                model <- stats::ppr(x,y,nterms=spec$nterms,max.terms=max(cfg$ppr.terms),
                    sm.method=spec$sm.method,optlevel=2)
                eta <- as.numeric(predict(model,Q)); ok <- all(is.finite(eta)); status <- "finite_prediction"
            }
            ok <- isTRUE(ok)&&length(eta)==length(query)&&all(is.finite(eta))
            list(ok=ok,status=status,eta=eta,diagnostic=diagnostic,fit=model)
        },warning=function(w) { warnings <<- c(warnings,conditionMessage(w)); invokeRestart("muffleWarning") }),
            error=function(e)list(ok=FALSE,status=conditionMessage(e),eta=rep(NA_real_,length(query))))
        fits[[j]]$warnings <- warnings
    }
    fits
}

btf.task <- function(task,out,run,cfg,legacy) {
    p <- readRDS(file.path(out,"inputs",paste0(task$dataset,".rds")))
    stopifnot(identical(btf.hash(p$source),p$source.hash))
    grid <- btf.grid(task$method,p,cfg); records <- list(); predictions <- list(); timing <- proc.time()[3]
    op <- if(task$method %in% c("complete","central_matched","graph"))
        readRDS(file.path(out,"operators",paste0(p$id,".rds")))$operators[[task$method]] else NULL
    checkpoint <- file.path(run,"checkpoints",task$id); dir.create(checkpoint,recursive=TRUE,showWarnings=FALSE)
    for (r in seq_len(cfg$repeats)) for (k in 1:3) {
        test <- which(p$folds[,r]==k); train <- setdiff(seq_len(nrow(p$X)),test)
        path <- file.path(checkpoint,paste0("repeat",r,"_fold",k,".rds"))
        saved <- if(file.exists(path))readRDS(path) else {
            started <- proc.time()[3]
            anchor <- if(grepl("tf2$",task$method))readRDS(file.path(run,"anchors",paste0(p$id,"_",r,"_",k,".rds"))) else NULL
            fits <- btf.fit(task$method,p,train,test,grid,cfg,btf.seed(p,r,k),legacy,op,anchor)
            diag <- do.call(rbind,lapply(seq_along(fits),function(j) data.frame(candidate=j,repeat.id=r,fold=k,
                n.train=length(train),n.test=length(test),converged=fits[[j]]$ok,status=fits[[j]]$status,
                loss.sum=if(fits[[j]]$ok)sum(btf.score(p$y[test],fits[[j]]$eta,p$family)) else NA_real_)))
            value <- list(config.hash=cfg$hash,records=diag,predictions=lapply(fits,`[[`,"eta"),
                diagnostics=lapply(fits,`[[`,"diagnostic"),warnings=lapply(fits,`[[`,"warnings"),elapsed=unname(proc.time()[3]-started))
            btf.atomic(value,path); value
        }
        stopifnot(identical(saved$config.hash,cfg$hash))
        records[[length(records)+1L]] <- saved$records; predictions[[length(predictions)+1L]] <- saved$predictions
    }
    ledger <- do.call(rbind,records)
    grid$cv.loss <- vapply(grid$candidate,function(j) {
        z <- ledger[ledger$candidate==j,]
        if(!all(z$converged))return(NA_real_)
        sum(z$loss.sum)/(nrow(p$X)*cfg$repeats)
    },numeric(1)); grid$eligible <- is.finite(grid$cv.loss)
    selected <- if(any(grid$eligible))which.min(ifelse(grid$eligible,grid$cv.loss,Inf)) else NA_integer_
    fit <- NULL; status <- "no_eligible_candidate"; rmse <- expected.logloss <- NA_real_; prediction <- rep(NA_real_,nrow(p$X))
    if (!is.na(selected)) {
        anchor <- if(grepl("tf2$",task$method))readRDS(file.path(run,"anchors",paste0(p$id,"_0_0.rds"))) else NULL
        fit <- btf.fit(task$method,p,seq_len(nrow(p$X)),seq_len(nrow(p$X)),grid[selected,,drop=FALSE],cfg,
            btf.seed(p,0,0),legacy,op,anchor)[[1]]
        if(fit$ok) {
            status <- "complete"; prediction <- if(p$family=="gaussian")fit$eta else plogis(fit$eta)
            rmse <- sqrt(mean((prediction-p$truth)^2))
            if(p$family=="binomial") expected.logloss <- mean(btf.score(p$truth,fit$eta,p$family))
        } else status <- paste0("full_refit_failed: ",fit$status)
    }
    boundary <- apply(abs(p$X),1,max)>.75
    list(task=task,config.hash=cfg$hash,grid=grid,selected=selected,cv=ledger,
        heldout.predictions=predictions,fit=fit,prediction=prediction,
        summary=data.frame(dataset=p$id,method=task$method,family=p$family,design=p$design,surface=p$surface,
            dimension=p$dimension,n=nrow(p$X),status=status,rmse=rmse,
            boundary.rmse=if(status=="complete")sqrt(mean((prediction[boundary]-p$truth[boundary])^2)) else NA_real_,
            expected.logloss=expected.logloss,excess.brier=if(p$family=="binomial")rmse^2 else NA_real_,
            cv.loss=if(is.na(selected))NA_real_ else grid$cv.loss[selected],failed.cv=sum(!ledger$converged),
            candidate.fits=nrow(ledger),elapsed=unname(proc.time()[3]-timing)))
}

btf.run <- function(out,cfg.path) {
    cfg <- readRDS(cfg.path); stopifnot(cfg$workers>=1,cfg$workers<=4,cfg$repeats %in% 1:3)
    cfg$hash <- digest::digest(cfg,algo="sha256"); run <- file.path(out,"runs",cfg$name)
    stopifnot(!dir.exists(run)); dir.create(run,recursive=TRUE)
    for(d in c("anchors","results","checkpoints","logs"))dir.create(file.path(run,d))
    btf.atomic(cfg,file.path(run,"config.rds")); legacy <- btf.legacy(out)
    btf.atomic(btf.provenance(),file.path(run,"provenance.rds"))
    datasets <- read.csv(file.path(out,"datasets.csv"),stringsAsFactors=FALSE)
    if(!is.null(cfg$datasets))datasets <- datasets[datasets$id %in% cfg$datasets,]
    stopifnot(nrow(datasets)>0)
    write.csv(datasets,file.path(run,"datasets.csv"),row.names=FALSE)
    # Prepare each response-dependent scale from its training split only.
    for (id in datasets$id) {
        p <- readRDS(file.path(out,"inputs",paste0(id,".rds")))
        indices <- rbind(c(0L,0L),as.matrix(expand.grid(repeat.id=seq_len(cfg$repeats),fold=1:3)))
        for (i in seq_len(nrow(indices))) {
            r <- indices[i,1]; k <- indices[i,2]
            train <- if(r==0L)seq_len(nrow(p$X)) else which(p$folds[,r]!=k)
            a <- btf.anchor(p$X[train,,drop=FALSE],p$y[train],p$family,cfg$rho,btf.seed(p,r,k),cfg$control)
            btf.atomic(a,file.path(run,"anchors",paste0(id,"_",r,"_",k,".rds")))
        }
        cat("Prepared training-only scales:",id,"\n");flush.console()
    }
    tasks <- expand.grid(dataset=datasets$id,method=cfg$methods,stringsAsFactors=FALSE)
    family <- datasets$family[match(tasks$dataset,datasets$id)]
    tasks <- tasks[!(tasks$method=="classical_ppr" & family=="binomial"),]
    tasks$id <- paste(tasks$dataset,tasks$method,sep="__")
    tasks$status <- "queued"; tasks$pid <- NA_integer_; tasks$elapsed <- NA_real_
    write.csv(tasks,file.path(run,"tasks.csv"),row.names=FALSE)
    capture.output(sessionInfo(),file=file.path(run,"session.txt"))
    active <- list(); start.times <- list(); queued <- seq_len(nrow(tasks)); peak <- 0
    while(length(queued)||length(active)) {
        # Admission uses this run's parent and child RSS, not system-wide sums.
        pids <- c(Sys.getpid(),as.integer(names(active)))
        usage <- suppressWarnings(as.numeric(system(paste("ps -o rss= -p",paste(pids,collapse=",")),intern=TRUE)))
        memory <- sum(usage,na.rm=TRUE)/1024^2; peak <- max(peak,memory)
        if (!length(active)&&memory>=cfg$memory.gib)
            stop("Coordinator exceeds the memory admission limit; no new workers started")
        while(length(queued)&&length(active)<cfg$workers&&memory<cfg$memory.gib) {
            i <- queued[1];queued <- queued[-1]; task <- tasks[i,]
            job <- parallel::mcparallel((function() {
                con <- file(file.path(run,"logs",paste0(task$id,".log")),"wt")
                sink(con);sink(con,type="message")
                on.exit({sink(type="message");sink();close(con)},add=TRUE)
                result <- tryCatch(btf.task(task,out,run,cfg,legacy),error=function(e)
                    list(task=task,error=conditionMessage(e),config.hash=cfg$hash))
                btf.atomic(result,file.path(run,"results",paste0(task$id,".rds")))
                list(index=i,status=if(is.null(result$error))result$summary$status else paste0("error: ",result$error))
            })(),mc.set.seed=FALSE,silent=TRUE)
            key <- as.character(job$pid); active[[key]] <- job; start.times[[key]] <- Sys.time()
            tasks$status[i] <- "running"; tasks$pid[i] <- job$pid
        }
        if(length(active)) {
            finished <- parallel::mccollect(active,wait=FALSE,timeout=0)
            for(key in names(finished)) {
                i <- which(tasks$pid==as.integer(key)); value <- finished[[key]]
                tasks$status[i] <- if(is.list(value)&&!is.null(value$status))value$status else "worker_failed"
                tasks$elapsed[i] <- as.numeric(difftime(Sys.time(),start.times[[key]],units="secs"))
                active[[key]] <- NULL; start.times[[key]] <- NULL
            }
            for(key in names(active)) if(as.numeric(difftime(Sys.time(),start.times[[key]],units="secs"))>cfg$task.seconds) {
                tools::pskill(as.integer(key),signal=15L)
                parallel::mccollect(active[key],wait=TRUE)
                i <- which(tasks$pid==as.integer(key)); tasks$status[i] <- "resource_limit"
                tasks$elapsed[i] <- cfg$task.seconds; active[[key]] <- NULL; start.times[[key]] <- NULL
            }
        }
        tmp <- file.path(run,"tasks.csv.tmp");write.csv(tasks,tmp,row.names=FALSE);file.rename(tmp,file.path(run,"tasks.csv"))
        jsonlite::write_json(list(completed=sum(!tasks$status %in% c("queued","running")),total=nrow(tasks),
            running=sum(tasks$status=="running"),peak.rss.gib=peak,updated=as.character(Sys.time())),
            file.path(run,"status.json"),auto_unbox=TRUE,pretty=TRUE)
        if(length(active)) Sys.sleep(1)
    }
    btf.summarize(out,cfg$name)
}

btf.summarize <- function(out,name) {
    run <- file.path(out,"runs",name); tasks <- read.csv(file.path(run,"tasks.csv"),stringsAsFactors=FALSE)
    datasets <- read.csv(file.path(run,"datasets.csv"),stringsAsFactors=FALSE)
    rows <- list()
    for(i in seq_len(nrow(tasks))) {
        path <- file.path(run,"results",paste0(tasks$id[i],".rds"))
        if(file.exists(path)) {
            a <- readRDS(path)
            if(!is.null(a$summary)) {rows[[length(rows)+1L]]<-a$summary;next}
        }
        p <- datasets[match(tasks$dataset[i],datasets$id),]
        rows[[length(rows)+1L]] <- data.frame(dataset=tasks$dataset[i],method=tasks$method[i],
            family=p$family,design=p$design,surface=p$surface,dimension=p$dimension,n=p$n,
            status=tasks$status[i],rmse=NA_real_,boundary.rmse=NA_real_,expected.logloss=NA_real_,excess.brier=NA_real_,
            cv.loss=NA_real_,failed.cv=NA_integer_,candidate.fits=NA_integer_,elapsed=tasks$elapsed[i])
    }
    scores <- do.call(rbind,rows);write.csv(scores,file.path(run,"scores.csv"),row.names=FALSE)
    cat("Saved",nrow(scores),"method/dataset results to",file.path(run,"scores.csv"),"\n")
    invisible(scores)
}

if(sys.nframe()==0L) {
    Sys.setenv(OMP_NUM_THREADS=1,OMP_THREAD_LIMIT=1,OPENBLAS_NUM_THREADS=1,VECLIB_MAXIMUM_THREADS=1,MKL_NUM_THREADS=1)
    args <- commandArgs(trailingOnly=TRUE);stopifnot(length(args)==3L)
    btf.load()
    if(args[1]=="prepare") btf.prepare(args[2],args[3]) else
    if(args[1]=="run") btf.run(normalizePath(args[2]),normalizePath(args[3])) else
    if(args[1]=="summarize") btf.summarize(normalizePath(args[2]),args[3]) else stop("Unknown action")
}
