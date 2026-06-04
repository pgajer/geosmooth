.PHONY: clean build check check-fast install document attrs test

VERSION := $(shell grep "^Version:" DESCRIPTION | sed 's/Version: //')
PKGNAME := geosmooth
TARBALL := $(PKGNAME)_$(VERSION).tar.gz
LOGDIR := .claude
HOMEBREW_BIN := /opt/homebrew/bin
GCC_BIN := /opt/homebrew/opt/gcc/bin
TIDY_BIN := $(shell if [ -x "$(HOMEBREW_BIN)/tidy" ]; then echo "$(HOMEBREW_BIN)/tidy"; elif command -v tidy >/dev/null 2>&1; then command -v tidy; else echo "$(HOMEBREW_BIN)/tidy"; fi)

clean:
	find src -name "*.o" -delete
	find src -name "*.so" -delete
	rm -f src/*.dll
	rm -rf $(PKGNAME).Rcheck
	rm -f $(TARBALL)
	rm -f $(LOGDIR)/*.log

attrs:
	@mkdir -p $(LOGDIR)
	@echo "Running Rcpp::compileAttributes()..."
	@R -q -e "Rcpp::compileAttributes()" > $(LOGDIR)/$(PKGNAME)_rcppattrs.log 2>&1
	@echo "RcppExports regenerated (log: $(LOGDIR)/$(PKGNAME)_rcppattrs.log)"

document: attrs
	@mkdir -p $(LOGDIR)
	@echo "Running roxygen2::roxygenise(load = 'source')..."
	@PATH="$(GCC_BIN):$(HOMEBREW_BIN):$$PATH" R -q -e "roxygen2::roxygenise(load = 'source')" > $(LOGDIR)/$(PKGNAME)_document.log 2>&1
	@echo "Documentation generated (log: $(LOGDIR)/$(PKGNAME)_document.log)"

test:
	@mkdir -p $(LOGDIR)
	@Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_dir("tests/testthat")' > $(LOGDIR)/$(PKGNAME)_test.log 2>&1
	@echo "Tests completed (log: $(LOGDIR)/$(PKGNAME)_test.log)"

build: clean
	@mkdir -p $(LOGDIR)
	@echo "Building package..."
	@bash -o pipefail -c 'R CMD build . 2>&1 | tee "$(LOGDIR)/$(PKGNAME)_build.log"'
	@echo "Package built successfully (log: $(LOGDIR)/$(PKGNAME)_build.log)"

check: build
	PATH="$(GCC_BIN):$(HOMEBREW_BIN):$$PATH" R_TIDYCMD="$(TIDY_BIN)" R CMD check $(TARBALL) --as-cran

check-fast: build
	PATH="$(GCC_BIN):$(HOMEBREW_BIN):$$PATH" R_TIDYCMD="$(TIDY_BIN)" R CMD check $(TARBALL) --as-cran --no-examples --no-tests --no-manual

install: build
	R CMD INSTALL $(TARBALL)
