library(goserveR)
library(tinytest)

# Test TLS/HTTPS server startup
certfile <- system.file("extdata", "cert.pem", package = "goserveR")
keyfile <- system.file("extdata", "key.pem", package = "goserveR")
h <- runServer(
  dir = getwd(),
  addr = "127.0.0.1:8443",
  tls = TRUE,
  certfile = certfile,
  keyfile = keyfile,
  blocking = FALSE,
  silent = TRUE
)
expect_true(inherits(h, "externalptr"))
Sys.sleep(1)
expect_true(length(listServers()) >= 1)
shutdownServer(h)
Sys.sleep(0.5)
