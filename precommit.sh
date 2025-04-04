#!/usr/bin/env bash
set -x
cd $(dirname ${0}) || exit

#Rscript -e 'roxygen2::roxygenise()'
#echo "------------R CMD Check"
#R CMD check --no-vignettes --no-manuals
#R CMD check --as-cran .
#git commit -am "document"
