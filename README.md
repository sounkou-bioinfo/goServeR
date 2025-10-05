
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
# this will stop the server after 5 seconds
setTimeLimit(elapsed = 5, transient = TRUE)
runServer(dir = ".", addr = "0.0.0.0:8080", silent = TRUE)
#> Server started in blocking mode. Press Ctrl+C to interrupt.
#> Server address: 0.0.0.0:8080
#> Static files directory: /home/sounkoutoure/Projects/goServeR
#> URL prefix:
setTimeLimit()
```

To start a background server and get a handle

``` r
h <- runServer(dir = ".", addr = "0.0.0.0:8080", blocking = FALSE, silent = TRUE)
listServers() |> str()
#> List of 1
#>  $ :List of 10
#>   ..$ directory      : chr "/home/sounkoutoure/Projects/goServeR"
#>   ..$ address        : chr "0.0.0.0:8080"
#>   ..$ prefix         : chr ""
#>   ..$ protocol       : chr "HTTP"
#>   ..$ logging        : chr "silent"
#>   ..$ log_handler    : chr "none"
#>   ..$ log_destination: chr "none"
#>   ..$ log_function   : chr "none"
#>   ..$ authentication : chr "disabled"
#>   ..$ auth_keys      : chr "none"
#>   ..- attr(*, "class")= chr "server_info"
#>  - attr(*, "class")= chr "server_list"
currentDir <- normalizePath(".")
readLines(paste0("http://0.0.0.0:8080/", currentDir)) |>
  head(10)
#>  [1] "<pre>"                                                          
#>  [2] "<a href=\"..Rcheck/\">..Rcheck/</a>"                            
#>  [3] "<a href=\".Rbuildignore\">.Rbuildignore</a>"                    
#>  [4] "<a href=\".Rinstignore\">.Rinstignore</a>"                      
#>  [5] "<a href=\".git/\">.git/</a>"                                    
#>  [6] "<a href=\".github/\">.github/</a>"                              
#>  [7] "<a href=\".gitignore\">.gitignore</a>"                          
#>  [8] "<a href=\".lintr\">.lintr</a>"                                  
#>  [9] "<a href=\".pre-commit-config.yaml\">.pre-commit-config.yaml</a>"
#> [10] "<a href=\".vscode/\">.vscode/</a>"
shutdownServer(h)
```

### Authentication and TLS/HTTPS Support

The package supports both API key authentication and TLS/HTTPS
connections. You can use them separately or together for secure
authenticated file serving:

``` r

# Get paths to example certificate and key files
certfile <- system.file("extdata", "cert.pem", package = "goserveR")
keyfile <- system.file("extdata", "key.pem", package = "goserveR")
# write test file
writeLines("Hello from goServeR!", "test.txt")

# HTTP server with authentication
h_http_auth <- runServer(dir = ".", addr = "127.0.0.1:8080", prefix = "/", blocking = FALSE, 
                         auth_keys = c("secret123", "token456"), silent = TRUE)

# Test authentication - wrong key should fail
tryCatch({
  download.file("http://127.0.0.1:8080/test.txt", 
                destfile = tempfile(),
                headers = c("X-API-Key" = "wrongkey"),
                quiet = TRUE)
}, error = function(e) {
  cat("Authentication failed as expected\n")
})
#> Warning in download.file("http://127.0.0.1:8080/test.txt", destfile =
#> tempfile(), : downloaded length 0 != reported length 13
#> Warning in download.file("http://127.0.0.1:8080/test.txt", destfile =
#> tempfile(), : cannot open URL 'http://127.0.0.1:8080/test.txt': HTTP status was
#> '401 Unauthorized'
#> Authentication failed as expected

# Test authentication - correct key should succeed
temp_file <- tempfile()
download.file("http://127.0.0.1:8080/test.txt", 
              destfile = temp_file,
              headers = c("X-API-Key" = "secret123"),
              quiet = TRUE)

readLines(temp_file)
#> [1] "Hello from goServeR!"

unlink(temp_file)

# HTTPS server with authentication
h_https_auth <- runServer(
  dir = ".", 
  addr = "127.0.0.1:8443", 
  tls = TRUE,
  prefix = "/",
  certfile = certfile,
  keyfile = keyfile,
  auth_keys = c("secure_key_123"),
  blocking = FALSE,
  silent = TRUE
)

# Test HTTPS with authentication using download.file
temp_file_https <- tempfile()
download.file("https://127.0.0.1:8443/test.txt", 
                destfile = temp_file_https,
                headers = c("X-API-Key" = "secure_key_123"),
                quiet = TRUE)

readLines(temp_file_https)  
#> [1] "Hello from goServeR!"

listServers() |> str()
#> List of 2
#>  $ :List of 10
#>   ..$ directory      : chr "/home/sounkoutoure/Projects/goServeR"
#>   ..$ address        : chr "127.0.0.1:8080"
#>   ..$ prefix         : chr "/"
#>   ..$ protocol       : chr "HTTP"
#>   ..$ logging        : chr "silent"
#>   ..$ log_handler    : chr "none"
#>   ..$ log_destination: chr "none"
#>   ..$ log_function   : chr "none"
#>   ..$ authentication : chr "enabled"
#>   ..$ auth_keys      : chr "secret123,token456"
#>   ..- attr(*, "class")= chr "server_info"
#>  $ :List of 10
#>   ..$ directory      : chr "/home/sounkoutoure/Projects/goServeR"
#>   ..$ address        : chr "127.0.0.1:8443"
#>   ..$ prefix         : chr "/"
#>   ..$ protocol       : chr "HTTPS"
#>   ..$ logging        : chr "silent"
#>   ..$ log_handler    : chr "none"
#>   ..$ log_destination: chr "none"
#>   ..$ log_function   : chr "none"
#>   ..$ authentication : chr "enabled"
#>   ..$ auth_keys      : chr "secure_key_123"
#>   ..- attr(*, "class")= chr "server_info"
#>  - attr(*, "class")= chr "server_list"

# Cleanup
shutdownServer(h_http_auth)
shutdownServer(h_https_auth)
unlink("test.txt")
```

### Multiple Servers

You can run multiple servers simultaneously on different ports:

``` r
# Start multiple servers
h1 <- runServer(dir = ".", addr = "127.0.0.1:8081", blocking = FALSE, silent = TRUE)
h2 <- runServer(dir = ".", addr = "127.0.0.1:8082", blocking = FALSE, silent = TRUE)
h3 <- runServer(dir = ".", addr = "127.0.0.1:8083", blocking = FALSE, silent = TRUE)

# List all running servers
listServers() |> str()
#> List of 3
#>  $ :List of 10
#>   ..$ directory      : chr "/home/sounkoutoure/Projects/goServeR"
#>   ..$ address        : chr "127.0.0.1:8081"
#>   ..$ prefix         : chr ""
#>   ..$ protocol       : chr "HTTP"
#>   ..$ logging        : chr "silent"
#>   ..$ log_handler    : chr "none"
#>   ..$ log_destination: chr "none"
#>   ..$ log_function   : chr "none"
#>   ..$ authentication : chr "disabled"
#>   ..$ auth_keys      : chr "none"
#>   ..- attr(*, "class")= chr "server_info"
#>  $ :List of 10
#>   ..$ directory      : chr "/home/sounkoutoure/Projects/goServeR"
#>   ..$ address        : chr "127.0.0.1:8082"
#>   ..$ prefix         : chr ""
#>   ..$ protocol       : chr "HTTP"
#>   ..$ logging        : chr "silent"
#>   ..$ log_handler    : chr "none"
#>   ..$ log_destination: chr "none"
#>   ..$ log_function   : chr "none"
#>   ..$ authentication : chr "disabled"
#>   ..$ auth_keys      : chr "none"
#>   ..- attr(*, "class")= chr "server_info"
#>  $ :List of 10
#>   ..$ directory      : chr "/home/sounkoutoure/Projects/goServeR"
#>   ..$ address        : chr "127.0.0.1:8083"
#>   ..$ prefix         : chr ""
#>   ..$ protocol       : chr "HTTP"
#>   ..$ logging        : chr "silent"
#>   ..$ log_handler    : chr "none"
#>   ..$ log_destination: chr "none"
#>   ..$ log_function   : chr "none"
#>   ..$ authentication : chr "disabled"
#>   ..$ auth_keys      : chr "none"
#>   ..- attr(*, "class")= chr "server_info"
#>  - attr(*, "class")= chr "server_list"

# Access different servers

#Server 1 (port 8081) 
length(readLines(paste0("http://127.0.0.1:8081/", normalizePath("."))))
#> [1] 28
#Server 2 (port 8082)
length(readLines(paste0("http://127.0.0.1:8082/", normalizePath("."))))
#> [1] 28
#Server 3 (port 8083)
length(readLines(paste0("http://127.0.0.1:8083/", normalizePath("."))))
#> [1] 28

# Shutdown all servers
shutdownServer(h1)
shutdownServer(h2)
shutdownServer(h3)

# Verify cleanup
length(listServers())
#> [1] 0
```

### Background Log Handling

The package implements asynchronous log handling using R’s async
handling capabilities that was adapted from Simon Urbanek’s [async
callback pattern](https://github.com/s-u/background). Each server can
have a custom log handler:

``` r
# Default console logging
h1 <- runServer(dir = ".", addr = "127.0.0.1:8350", blocking = FALSE, silent = FALSE)

# Custom file logger
logfile <- tempfile("custom_", fileext = ".log")
file_logger <- function(handler, message, user) {
  cat(format(Sys.time(), "[%Y-%m-%d %H:%M:%S]"), message, "\n", file = logfile, append = TRUE)
}
h2 <- runServer(dir = ".", addr = "127.0.0.1:8351", blocking = FALSE, 
                silent = FALSE, log_handler = file_logger)
# read some lines to generate logs
bunk <- readLines(paste0("http://127.0.0.1:8351/", normalizePath(".")))
# Custom console logger with prefix
console_logger <- function(handler, message, user) {
  cat("\n*** [CUSTOM-SERVER] ***", message, "*** END ***\n")
  flush.console()
}
h3 <- runServer(dir = ".", addr = "127.0.0.1:8352", blocking = FALSE, 
                silent = FALSE, log_handler = console_logger)
bunk <- readLines(paste0("http://127.0.0.1:8352/", normalizePath(".")))
# Silent mode (no logs)
h4 <- runServer(dir = ".", addr = "127.0.0.1:8353", blocking = FALSE, silent = TRUE)

listServers() |> str()
#> List of 4
#>  $ :List of 10
#>   ..$ directory      : chr "/home/sounkoutoure/Projects/goServeR"
#>   ..$ address        : chr "127.0.0.1:8350"
#>   ..$ prefix         : chr ""
#>   ..$ protocol       : chr "HTTP"
#>   ..$ logging        : chr "logging"
#>   ..$ log_handler    : chr "default"
#>   ..$ log_destination: chr "console"
#>   ..$ log_function   : chr ".default_log_callback"
#>   ..$ authentication : chr "disabled"
#>   ..$ auth_keys      : chr "none"
#>   ..- attr(*, "class")= chr "server_info"
#>  $ :List of 10
#>   ..$ directory      : chr "/home/sounkoutoure/Projects/goServeR"
#>   ..$ address        : chr "127.0.0.1:8351"
#>   ..$ prefix         : chr ""
#>   ..$ protocol       : chr "HTTP"
#>   ..$ logging        : chr "logging"
#>   ..$ log_handler    : chr "custom_function"
#>   ..$ log_destination: chr "custom"
#>   ..$ log_function   : chr "function (handler, message, user) "
#>   ..$ authentication : chr "disabled"
#>   ..$ auth_keys      : chr "none"
#>   ..- attr(*, "class")= chr "server_info"
#>  $ :List of 10
#>   ..$ directory      : chr "/home/sounkoutoure/Projects/goServeR"
#>   ..$ address        : chr "127.0.0.1:8352"
#>   ..$ prefix         : chr ""
#>   ..$ protocol       : chr "HTTP"
#>   ..$ logging        : chr "logging"
#>   ..$ log_handler    : chr "custom_function"
#>   ..$ log_destination: chr "custom"
#>   ..$ log_function   : chr "function (handler, message, user) "
#>   ..$ authentication : chr "disabled"
#>   ..$ auth_keys      : chr "none"
#>   ..- attr(*, "class")= chr "server_info"
#>  $ :List of 10
#>   ..$ directory      : chr "/home/sounkoutoure/Projects/goServeR"
#>   ..$ address        : chr "127.0.0.1:8353"
#>   ..$ prefix         : chr ""
#>   ..$ protocol       : chr "HTTP"
#>   ..$ logging        : chr "silent"
#>   ..$ log_handler    : chr "none"
#>   ..$ log_destination: chr "none"
#>   ..$ log_function   : chr "none"
#>   ..$ authentication : chr "disabled"
#>   ..$ auth_keys      : chr "none"
#>   ..- attr(*, "class")= chr "server_info"
#>  - attr(*, "class")= chr "server_list"

# let's get the log by making R idle !
Sys.sleep(5)
#> [goserveR] 2025/10/05 22:00:04.000677 Serving directory "/home/sounkoutoure/Projects/goServeR" on http://127.0.0.1:8350
#> 
#> *** [CUSTOM-SERVER] *** 2025/10/05 22:00:04.008046 Serving directory "/home/sounkoutoure/Projects/goServeR" on http://127.0.0.1:8352
#> 2025/10/05 22:00:04.010492 GET /home/sounkoutoure/Projects/goServeR/ 127.0.0.1:54824 241.801µs
#>  *** END ***
shutdownServer(h1)
shutdownServer(h2)
shutdownServer(h3)
shutdownServer(h4)


# Check custom log file
if (file.exists(logfile)) {
  cat(readLines(logfile, n = 3), sep = "\n")
}
#> [2025-10-05 22:00:04] 2025/10/05 22:00:04.002869 Serving directory "/home/sounkoutoure/Projects/goServeR" on http://127.0.0.1:8351
#> 2025/10/05 22:00:04.004369 GET /home/sounkoutoure/Projects/goServeR/ 127.0.0.1:46548 245.709µs
#> 
```

## On background log handlers

An important note is that the handler may run at unpredictable times,
and are removed when the server is shutdown, so there is no guarantee
that they may run when go write to the log pipe.

## How it works ?

We wrote a standard Go HTTP file server, created a static library from
it, and then wrote the usual R C API wrappers for the cgo (static)
library. Interrupts are now handled entirely at the C level: the Go
server runs in a background thread, and the main C thread periodically
checks for user interrupts using the R API. If an interrupt is detected,
the C code signals the Go server to shut down. This approach is robust,
portable, and keeps all R session control in C, not Go. Morover logging
is now handled asynchronously using asynchronous input handlers as
adapted from Simon Urbanek’s [async callback
pattern](https://github.com/s-u/background).

## On TLS Certificates

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

## TODO

- [ ] Try to implement a basic
  [Rook](https://github.com/jeffreyhorner/Rook) Rook specs interface
  using ?
  - [ ] issue here is since we elect to not call R from go routines, we
    have to go through pipes or similar to get the request to the main R
    thread. we may use ideas from
    [background](https://github.com/s-u/background)

## REFERENCES

- <https://purrple.cat/blog/2017/05/14/calling-go-from-r/>
- <https://mahowald.github.io/go-ffi/>
- <https://cran.r-project.org/doc/manuals/r-devel/R-exts.pdf>
- <https://github.com/eliben/static-server>
