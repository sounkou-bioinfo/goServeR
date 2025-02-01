#!/usr/bin/env bash

cd $(dirname ${0}) || exit

Rscript -e 'roxygen2::roxygenise()'
echo "------------R CMD Check"
R CMD check --no-manual .