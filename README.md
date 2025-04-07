# goServeR

[![goserveR status badge](https://sounkou-bioinfo.r-universe.dev/goserveR/badges/version)](https://sounkou-bioinfo.r-universe.dev/goserveR)

This package provides an interface to a simple HTTP file server written in go using Copilot.

The server supports range requests and unbounded CORS. It uses the cgo package to call Go functions from R using the R C extension mechanisms. This is an experimentation with the R C extension mechanism without the very convenient Rcpp.

The server is obviously very insecure but useful for my use case of serving local BCF/BAM files to an [ambiorix](https://ambiorix.dev/) app using [igv.js](https://github.com/igvteam/igv.js). This package works on my ubuntu laptop and github runners (see .github/r.yaml ) and a go install is required.

## INSTALL

```bash

## install golang via apt or binary and put it in the path

go || sudo apt-get install --yes golang
## clone the repo and install
git clone https://github.com/sounkou-bioinfo/goServeR.git
cd goServeR/
R CMD INSTALL  .
# or
Rscript -e 'remotes::install_github("sounkou-bioinfo/goServeR")'
# or 
Rscript -e "install.packages('goserveR', repos = c('https://sounkou-bioinfo.r-universe.dev'))"

```

## Example

```bash
# Start the server in the background
Rscript -e "goserveR::runServer(addr = '0.0.0.0:8080')" &
pid=$!
curl -L http://0.0.0.0:8080/${PWD}
kill -9 $pid

# Or run it interactively and use Ctrl+C to stop
Rscript -e "goserveR::runServer(addr = '0.0.0.0:8080')"
```

## Features

- HTTP file server with range requests support
- Unbounded CORS for API access
- Parameter validation for robust operation
- Graceful shutdown with R interrupt handling (Ctrl+C)
- Comprehensive test suite for parameter validation

## Testing

The package includes a test suite that validates parameter handling and server functionality:

```r
# Run tests (skipping actual server tests by default)
devtools::test()

# To run integration tests that start a real server (manual testing)
devtools::test(filter = "integration")
```

Note: Integration tests require the `httr` and `sys` packages and are skipped by default.

## TODO

- [x] Add assertions to the code
  - [x] Basic path validation
  - [x] Type checking for parameters
  - [x] Validation for address format
  - [x] Better error messages

- [x] Incorporate R interrupt detection to kill the server
  - [x] Implement interrupt checking in Go code
  - [x] Add graceful shutdown mechanism
  - [x] Support for Ctrl+C during server operation

- [x] Add comprehensive tests
  - [x] Unit tests for parameter validation
  - [x] Integration tests for server functionality

## REFERENCES

-   https://purrple.cat/blog/2017/05/14/calling-go-from-r/
-   https://mahowald.github.io/go-ffi/
-   https://cran.r-project.org/doc/manuals/r-devel/R-exts.pdf
