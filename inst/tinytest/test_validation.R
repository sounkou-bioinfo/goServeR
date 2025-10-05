library(goserveR)
library(tinytest)

# Parameter validation
expect_error(runServer(
  dir = "/path/that/does/not/exist",
  addr = "0.0.0.0:8181"
))
expect_error(runServer(dir = 123, addr = "0.0.0.0:8181"))
expect_error(runServer(dir = getwd(), addr = "invalid_address"))
expect_error(runServer(
  dir = getwd(),
  addr = c("0.0.0.0:8181", "localhost:8080")
))
expect_error(runServer(
  dir = getwd(),
  addr = "0.0.0.0:8181",
  prefix = c("/api", "/data")
))
