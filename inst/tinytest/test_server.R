library(goserveR)
library(tinytest)

# Server functionality (manual/skip on CI)
if (interactive() || !nzchar(Sys.getenv("CI"))) {
    # runServer can start and shutdown a background server
    h <- runServer(dir = getwd(), addr = "127.0.0.1:8182", blocking = FALSE)
    expect_true(inherits(h, "externalptr"))
    expect_true(length(listServers()) >= 1)
    shutdownServer(h)

    # StartServer/ShutdownServer advanced usage works
    h2 <- goserveR:::StartServer(dir = getwd(), addr = "127.0.0.1:8183", prefix = "", blocking = FALSE)
    expect_true(inherits(h2, "externalptr"))
    expect_true(length(goserveR:::ListServers()) >= 1)
    goserveR:::ShutdownServer(h2)
}
