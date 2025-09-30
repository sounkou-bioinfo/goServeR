library(goserveR)
library(tinytest)

# Test advanced/manual C-level usage as in README
if (interactive() || !nzchar(Sys.getenv("CI"))) {
    h <- goserveR::StartServer(dir = getwd(), addr = "127.0.0.1:8084", prefix = "", blocking = FALSE)
    expect_true(inherits(h, "externalptr"))
    servers <- goserveR:::ListServers()
    expect_true(length(servers) >= 1)
    goserveR:::ShutdownServer(h)
}
