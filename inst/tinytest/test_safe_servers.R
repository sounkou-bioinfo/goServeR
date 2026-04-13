library(goserveR)
library(tinytest)

cat("Testing basic server operations safely...\n")

# Test 1: Single server start/stop
h1 <- runServer(
  dir = getwd(),
  addr = "127.0.0.1:8401",
  blocking = FALSE,
  silent = TRUE
)
Sys.sleep(0.5)

expect_true(inherits(h1, "externalptr"))

servers <- listServers()
expect_true(is.list(servers))
expect_true(length(servers) >= 1)

shutdownServer(h1)
Sys.sleep(0.5)

# Test 2: Sequential server operations (not concurrent)
cat("Testing sequential servers...\n")

for (port in 8410:8412) {
  h <- runServer(
    dir = getwd(),
    addr = paste0("127.0.0.1:", port),
    blocking = FALSE,
    silent = TRUE
  )
  Sys.sleep(0.3)

  shutdownServer(h)
  Sys.sleep(0.3)
}

# Test 3: Error scenarios (R-level validation)
cat("Testing input validation...\n")

expect_error(runServer(dir = "", blocking = FALSE))
expect_error(runServer(dir = getwd(), addr = "", blocking = FALSE))
expect_error(runServer(dir = getwd(), addr = "invalid", blocking = FALSE))

cat("Safe server tests completed\n")
