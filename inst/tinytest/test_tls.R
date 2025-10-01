library(goserveR)
library(tinytest)

# Test TLS/HTTPS server startup
if (interactive() || !nzchar(Sys.getenv("CI"))) {
    certfile <- system.file("extdata", "cert.pem", package = "goserveR")
    keyfile <- system.file("extdata", "key.pem", package = "goserveR")
    h <- runServer(
        dir = getwd(),
        addr = "127.0.0.1:8443",
        tls = TRUE,
        certfile = certfile,
        keyfile = keyfile,
        blocking = FALSE,
        prefix = "/test",
    )
    expect_true(inherits(h, "externalptr"))
    expect_true(length(listServers()) >= 1)
    while (1) {
        Sys.sleep(1)
    }
    shutdownServer(h)
}
