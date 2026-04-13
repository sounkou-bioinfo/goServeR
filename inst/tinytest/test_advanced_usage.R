library(goserveR)
library(tinytest)

# Test advanced/manual C-level usage as in README
h <- goserveR::StartServer(
  dir = getwd(),
  addr = "127.0.0.1:8084",
  prefix = "",
  blocking = FALSE
)
expect_true(inherits(h, "externalptr"))
Sys.sleep(0.5)
servers <- listServers()
expect_true(length(servers) >= 1)
shutdownServer(h)
Sys.sleep(0.5)
