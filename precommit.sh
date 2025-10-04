#!/usr/bin/env bash
set -x
cd $(dirname ${0}) || exit

Rscript -e 'roxygen2::roxygenise()'
#echo "------------R CMD Check"
#R CMD check --no-vignettes --no-manuals
R CMD check --as-cran .
R CMD INSTALL .
R -e 'tinytest::test_package(testdir="./inst/tinytest")'
#git commit -am "document"
