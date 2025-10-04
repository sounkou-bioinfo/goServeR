#!/usr/bin/env bash
set -x
cd $(dirname ${0}) || exit
PKGNAME=$(sed -n "s/Package: *\([^ ]*\)/\1/p" DESCRIPTION)
PKGVERS=$(sed -n "s/Version: *\([^ ]*\)/\1/p" DESCRIPTION)
Rscript -e 'roxygen2::roxygenise()'
R CMD build .
R CMD check --as-cran ${PKGNAME}_${PKGVERS}.tar.gz
R CMD INSTALL ${PKGNAME}_${PKGVERS}.tar.gz
#R -e 'tinytest::test_package(testdir="./inst/tinytest")'
#git commit -am "document"
