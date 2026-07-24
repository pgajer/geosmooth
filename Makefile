.PHONY: clean build check check-fast install document attrs test test-all test-lps test-ps-lps test-od test-graph test-ssrhe test-validation test-migration

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
	Rscript scripts/run_test_group.R smoke

test-all:
	Rscript scripts/run_test_group.R all

test-lps:
	Rscript scripts/run_test_group.R lps

test-ps-lps:
	Rscript scripts/run_test_group.R ps-lps

test-od:
	Rscript scripts/run_test_group.R od

test-graph:
	Rscript scripts/run_test_group.R graph

test-ssrhe:
	Rscript scripts/run_test_group.R ssrhe

test-validation:
	Rscript scripts/run_test_group.R validation

test-migration:
	Rscript -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_dir("tests/migration")'

build: clean
	$(MAKE) document
	R CMD build .

check: build
	PATH="$(GCC_BIN):$(HOMEBREW_BIN):$$PATH" R_TIDYCMD="$(TIDY_BIN)" R CMD check $(TARBALL) --as-cran

check-fast: build
	PATH="$(GCC_BIN):$(HOMEBREW_BIN):$$PATH" R_TIDYCMD="$(TIDY_BIN)" R CMD check $(TARBALL) --as-cran --no-examples --no-tests --no-manual

install: build
	R CMD INSTALL $(TARBALL)
