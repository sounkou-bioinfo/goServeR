
# goServeR

[![goserveR status
badge](https://sounkou-bioinfo.r-universe.dev/goserveR/badges/version)](https://sounkou-bioinfo.r-universe.dev/goserveR)

This package provides an interface to a simple HTTP file server written
in go (go part mostly written in the begining with a fair amount of
hallucination by a LLM).

The server supports range requests and unbounded CORS. It uses the cgo
package to call Go functions from R using the R C extension mechanisms.
This is an experimentation with the R C extension mechanism without the
very convenient Rcpp.

The server was very insecure but useful for my use case of serving local
BCF/BAM files to an [ambiorix](https://ambiorix.dev/) app using
[igv.js](https://github.com/igvteam/igv.js) (because {httpuv} does not
support range requests [as of
now](https://github.com/rstudio/httpuv/issues/259)). This can be
installed from
[r-universe](https://sounkou-bioinfo.r-universe.dev/goserveR) and
requires a go installation. We’ve added TLS support and other
improvements since the initial version and we will add allowlisting and
other security features in the future.

## INSTALL

``` bash

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

From the command line, you can start a server in the background and test
it with curl

``` bash
# Start the server in the background
Rscript -e "goserveR::runServer(addr = '0.0.0.0:8080')" &
pid=$!
curl -L http://0.0.0.0:8080/${PWD}
kill -9 $pid

# Or run it interactively and use Ctrl+C to stop
Rscript -e "goserveR::runServer(addr = '0.0.0.0:8080', blocking = TRUE)"
```

R starts a blocking server (blocks R session) with

``` r
library(goserveR)
# set timeout to 5 seconds for demo purpose
setTimeLimit(elapsed = 5, transient = TRUE)
runServer(dir = ".", addr = "0.0.0.0:8080")
#> Server started in blocking mode. Press Ctrl+C to interrupt.
setTimeLimit()
```

To start a background server and get a handle

``` r
h <- runServer(dir = ".", addr = "0.0.0.0:8080", blocking = FALSE)
listServers()
#> [[1]]
#> [1] "."            "0.0.0.0:8080" ""
currentDir <- normalizePath(".")
readLines(paste0("http://0.0.0.0:8080/", currentDir))
#>  [1] "<pre>"                                                                      
#>  [2] "<a href=\".Rbuildignore\">.Rbuildignore</a>"                                
#>  [3] "<a href=\".Rinstignore\">.Rinstignore</a>"                                  
#>  [4] "<a href=\".git/\">.git/</a>"                                                
#>  [5] "<a href=\".github/\">.github/</a>"                                          
#>  [6] "<a href=\".gitignore\">.gitignore</a>"                                      
#>  [7] "<a href=\".lintr\">.lintr</a>"                                              
#>  [8] "<a href=\".pre-commit-config.yaml\">.pre-commit-config.yaml</a>"            
#>  [9] "<a href=\".vscode/\">.vscode/</a>"                                          
#> [10] "<a href=\"DESCRIPTION\">DESCRIPTION</a>"                                    
#> [11] "<a href=\"NAMESPACE\">NAMESPACE</a>"                                        
#> [12] "<a href=\"NEWS.md\">NEWS.md</a>"                                            
#> [13] "<a href=\"R/\">R/</a>"                                                      
#> [14] "<a href=\"README.Rmd\">README.Rmd</a>"                                      
#> [15] "<a href=\"README.html\">README.html</a>"                                    
#> [16] "<a href=\"README.md\">README.md</a>"                                        
#> [17] "<a href=\"Rserve.c\">Rserve.c</a>"                                          
#> [18] "<a href=\"goserveR_0.1.2-0.90000.tar.gz\">goserveR_0.1.2-0.90000.tar.gz</a>"
#> [19] "<a href=\"inst/\">inst/</a>"                                                
#> [20] "<a href=\"man/\">man/</a>"                                                  
#> [21] "<a href=\"precommit.sh\">precommit.sh</a>"                                  
#> [22] "<a href=\"src/\">src/</a>"                                                  
#> [23] "<a href=\"tools/\">tools/</a>"                                              
#> [24] "</pre>"
shutdownServer(h)
```

### Multiple Servers

You can run multiple servers simultaneously on different ports:

``` r
# Start multiple servers
h1 <- runServer(dir = ".", addr = "127.0.0.1:8081", blocking = FALSE, silent = TRUE)
h2 <- runServer(dir = ".", addr = "127.0.0.1:8082", blocking = FALSE, silent = TRUE)
h3 <- runServer(dir = ".", addr = "127.0.0.1:8083", blocking = FALSE, silent = TRUE)

# List all running servers
servers <- listServers()

for(i in seq_along(servers)) {
  sprintf("  Server %d: %s on %s\n", i, servers[[i]][1], servers[[i]][2]) |> cat()
}
#>   Server 1: . on 127.0.0.1:8081
#>   Server 2: . on 127.0.0.1:8082
#>   Server 3: . on 127.0.0.1:8083

# Access different servers

#Server 1 (port 8081) 
length(readLines(paste0("http://127.0.0.1:8081/", normalizePath("."))))
#> [1] 24
#Server 2 (port 8082)
length(readLines(paste0("http://127.0.0.1:8082/", normalizePath("."))))
#> [1] 24
#Server 3 (port 8083)
length(readLines(paste0("http://127.0.0.1:8083/", normalizePath("."))))
#> [1] 24

# Shutdown all servers
shutdownServer(h1)
shutdownServer(h2)
shutdownServer(h3)

# Verify cleanup
length(listServers())
#> [1] 0
```

### TLS/HTTPS Support

The package includes support for TLS/HTTPS connections using certificate
and key files. Example certificate and key files are provided in the
package for testing purposes:

``` r
# Get paths to example certificate and key files
certfile <- system.file("extdata", "cert.pem", package = "goserveR")
keyfile <- system.file("extdata", "key.pem", package = "goserveR")

# Start an HTTPS server
h_tls <- runServer(
  dir = ".", 
  addr = "127.0.0.1:8443", 
  tls = TRUE,
  certfile = certfile,
  keyfile = keyfile,
  blocking = FALSE,
  silent = TRUE
)

# List servers to confirm it's running
servers <- listServers()
for(i in seq_along(servers)) {
  sprintf("  Server %d: %s on %s\n", i, servers[[i]][1], servers[[i]][2]) |> cat()
}
#>   Server 1: . on 127.0.0.1:8443

# Test the HTTPS server - we'll use system2 with curl since readLines
# doesn't handle self-signed certificates well
if (Sys.which("curl") != "") {
  # Use curl with -k flag to accept self-signed certificate and -L to follow redirects
  result <- system2("curl", 
                   args = c("-k", "-s", "-L", paste0("https://127.0.0.1:8443/", normalizePath("."))),
                   stdout = TRUE, stderr = TRUE)
  cat("HTTPS server response (first 5 lines):\n")
  cat(paste(head(result, 5), collapse = "\n"), "\n")
} else {
  cat("curl not available - HTTPS server is running but cannot test from R\n")
}
#> HTTPS server response (first 5 lines):
#> <pre>
#> <a href=".Rbuildignore">.Rbuildignore</a>
#> <a href=".Rinstignore">.Rinstignore</a>
#> <a href=".git/">.git/</a>
#> <a href=".github/">.github/</a>

# Shutdown the TLS server
shutdownServer(h_tls)

# Verify cleanup
length(listServers())
#> [1] 0
```

**Note**: The included certificate files are for testing purposes only
and should not be used in production. For development with
browser-trusted certificates, use `mkcert` to generate locally-trusted
certificates:

``` bash
# Install mkcert (creates locally-trusted development certificates)
# On macOS: brew install mkcert
# On Linux: see https://github.com/FiloSottile/mkcert#installation

# Install the local CA in the system trust store
mkcert -install

# Generate certificate for localhost and local IP
mkcert localhost 127.0.0.1 ::1

# This creates localhost+2.pem (certificate) and localhost+2-key.pem (private key)
# Use these files with the certfile and keyfile parameters
```

For production use, get proper certificates from a Certificate Authority
like Let’s Encrypt:

``` bash
# Using certbot for Let's Encrypt (example for Apache/nginx)
sudo certbot --nginx -d yourdomain.com

# Or generate self-signed certificates (browsers will show warnings)
openssl genpkey -algorithm RSA -out server.key -pkcs8
openssl req -new -x509 -key server.key -out server.crt -days 365
```

## How it works ?

We wrote a standard Go HTTP file server, created a static library from
it, and then wrote the usual R C API wrappers for the cgo (static)
library. Interrupts are now handled entirely at the C level: the Go
server runs in a background thread, and the main C thread periodically
checks for user interrupts using the R API. If an interrupt is detected,
the C code signals the Go server to shut down. This approach is robust,
portable, and keeps all R session control in C, not Go.

## TODO

- [ ] Try to implement a basic
  [Rook](https://github.com/jeffreyhorner/Rook) Rook specs interface
  using ?
  - [ ] issue here is since we elect to not call R from go routines, we
    have to go through pipes or similar to get the request to the main R
    thread. we may use ideas from
    [background](https://github.com/s-u/background)
- [ ] Support windows ?

## REFERENCES

- <https://purrple.cat/blog/2017/05/14/calling-go-from-r/>
- <https://mahowald.github.io/go-ffi/>
- <https://cran.r-project.org/doc/manuals/r-devel/R-exts.pdf>
- <https://github.com/eliben/static-server>
