library(goserveR)
library(tinytest)

# runServer can start and shutdown a background server
h <- runServer(dir = getwd(), addr = "127.0.0.1:8182", blocking = FALSE, silent = TRUE)
expect_true(inherits(h, "externalptr"))
Sys.sleep(0.5)
expect_true(length(listServers()) >= 1)
shutdownServer(h)
Sys.sleep(0.5)

# StartServer/ShutdownServer advanced usage works
h2 <- goserveR:::StartServer(
  dir = getwd(),
  addr = "127.0.0.1:8183",
  prefix = "",
  blocking = FALSE
)
expect_true(inherits(h2, "externalptr"))
Sys.sleep(0.5)
expect_true(length(listServers()) >= 1)
shutdownServer(h2)
Sys.sleep(0.5)
