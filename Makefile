.PHONY: clean build check check-fast install document attrs test

VERSION := $(shell grep "^Version:" DESCRIPTION | sed 's/Version: //')
PKGNAME := geosmooth
TARBALL := $(PKGNAME)_$(VERSION).tar.gz
HOMEBREW_BIN := /opt/homebrew/bin
GCC_BIN := /opt/homebrew/opt/gcc/bin
TIDY_BIN := $(shell if [ -x "$(HOMEBREW_BIN)/tidy" ]; then echo "$(HOMEBREW_BIN)/tidy"; elif command -v tidy >/dev/null 2>&1; then command -v tidy; else echo "$(HOMEBREW_BIN)/tidy"; fi)

clean:
	find src -name "*.o" -delete
	find src -name "*.so" -delete
	rm -f src/*.dll
	rm -rf $(PKGNAME).Rcheck
	rm -f $(TARBALL)
	rm -rf .claude

attrs:
	R -q -e "Rcpp::compileAttributes()"

document: attrs
	PATH="$(GCC_BIN):$(HOMEBREW_BIN):$$PATH" R -q -e "roxygen2::roxygenise(load = 'source')"

test:
	Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_dir("tests/testthat")'

build: clean
	R CMD build .

check: build
	PATH="$(GCC_BIN):$(HOMEBREW_BIN):$$PATH" R_TIDYCMD="$(TIDY_BIN)" R CMD check $(TARBALL) --as-cran

check-fast: build
	PATH="$(GCC_BIN):$(HOMEBREW_BIN):$$PATH" R_TIDYCMD="$(TIDY_BIN)" R CMD check $(TARBALL) --as-cran --no-examples --no-tests --no-manual

install: build
	R CMD INSTALL $(TARBALL)
