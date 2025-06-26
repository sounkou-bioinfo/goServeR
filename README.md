# goServeR

[![goserveR status badge](https://sounkou-bioinfo.r-universe.dev/goserveR/badges/version)](https://sounkou-bioinfo.r-universe.dev/goserveR)

This package provides an interface to a simple HTTP file server written in go (go part mostly written in the begining with a fair amount of hallucination by a LLM).

The server supports range requests and unbounded CORS. It uses the cgo package to call Go functions from R using the R C extension mechanisms. This is an experimentation with the R C extension mechanism without the very convenient Rcpp.

The server is obviously very insecure but useful for my use case of serving local BCF/BAM files to an [ambiorix](https://ambiorix.dev/) app using [igv.js](https://github.com/igvteam/igv.js) (because {httpuv} does not support range requests [as of now](https://github.com/rstudio/httpuv/issues/259)). This can be installed from [r-universe](https://sounkou-bioinfo.r-universe.dev/goserveR) and requires a go installation

## INSTALL

```bash

## install golang via apt/yum/brew or binary and put it in the path
## to build from source

go || sudo apt-get install --yes golang
## clone the repo and install
git clone https://github.com/sounkou-bioinfo/goServeR.git
cd goServeR/
R CMD INSTALL  .
# or github via remotes
Rscript -e 'remotes::install_github("sounkou-bioinfo/goServeR")'
# or via r-universe 
Rscript -e "install.packages('goserveR', repos = c('https://sounkou-bioinfo.r-universe.dev'))"

```

## Usage Example

```bash
# Start the server in the background
Rscript -e "goserveR::runServer(addr = '0.0.0.0:8080')" &
pid=$!
curl -L http://0.0.0.0:8080/${PWD}
kill -9 $pid

# Or run it interactively and use Ctrl+C to stop
Rscript -e "goserveR::runServer(addr = '0.0.0.0:8080')"
```
## How it works ?
We wrote first a standard go http file server, created a static library out of it and then write the usual R C API wrappers for the cgo (static) library. To incorporate the user interrupt mechanism, we adapted this method form [{curl}](https://stackoverflow.com/questions/40563522/r-how-to-write-interruptible-c-function-and-recover-partial-results) to stop C codes (but we called it from go). We had to link the R shared library to go [see](src/go/serve.go) [and](src/Makevars).

## TODO

- [ ] Try to implement a basic [Rook](https://github.com/jeffreyhorner/Rook) Rook specs interface using
  - [ ] Avoid R C stac overflown when passing C functions to the Go runtime
  - [ ] Use Rprotobuf instead ???
- [ ] Windows compilation issue, because why not ?
- [ ] Add SSL because the go standard lib is great !

## REFERENCES

-   https://purrple.cat/blog/2017/05/14/calling-go-from-r/
-   https://mahowald.github.io/go-ffi/
-   https://cran.r-project.org/doc/manuals/r-devel/R-exts.pdf
