library(goserveR)
library(tinytest)

if (!requireNamespace("nanonext", quietly = TRUE)) {
  exit_file("Package 'nanonext' is not installed")
}

credentials <- createTLSCertificate(cn = "127.0.0.1")

expect_true(grepl("BEGIN CERTIFICATE", credentials$server[[1L]], fixed = TRUE))
expect_true(grepl("BEGIN RSA PRIVATE KEY", credentials$server[[2L]], fixed = TRUE))
expect_true(file.exists(credentials$certfile))
expect_true(file.exists(credentials$keyfile))

# Test TLS/HTTPS server startup using nanonext-generated PEM credentials.
h <- runServer(
  dir = getwd(),
  addr = "127.0.0.1:8443",
  tls = credentials,
  blocking = FALSE,
  silent = TRUE
)
expect_true(inherits(h, "externalptr"))
Sys.sleep(1)
expect_true(isRunning(h))
shutdownServer(h)
Sys.sleep(0.5)

expect_true(removeTLSCertificate(credentials))
expect_false(file.exists(credentials$certfile))
expect_false(file.exists(credentials$keyfile))
