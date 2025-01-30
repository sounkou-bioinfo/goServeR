# goServeR

This package provides an interface to a simple HTTP file server written in go using Copilot.\
The server supports range requests and unbounded CORS. It uses the cgo package to call Go functions from R using the R C extension mechanisms. This is an experimentation with the R C extension mechanism without the very convenient Rcpp.

The server is obviously very insecure but useful for my use case of serving local BCF/BAM files to an [ambiorix](https://ambiorix.dev/) app using [igv.js](https://github.com/igvteam/igv.js). This package works on my ubuntu laptop and you need go to be installed. \
\
TODO

-   Add some assertions to the code

-   Incorporate the R interrupt detection to kill the server : this may be done at the C or R binding level

## REFERENCES

-   https://purrple.cat/blog/2017/05/14/calling-go-from-r/
-   https://mahowald.github.io/go-ffi/
-   https://cran.r-project.org/doc/manuals/r-devel/R-exts.pdf