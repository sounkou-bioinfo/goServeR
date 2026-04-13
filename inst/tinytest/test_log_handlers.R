library(goserveR)
library(tinytest)

# Test log handler functionality
cat("Testing log handler functionality...\n")

# Test 1: Basic default log handler
cat("Testing default log handler...\n")

h <- runServer(
  dir = getwd(),
  addr = "127.0.0.1:8350",
  blocking = FALSE,
  silent = FALSE
)

# Give server time to start and generate some log messages
Sys.sleep(1)

shutdownServer(h)
Sys.sleep(0.5)

# Test 2: Silent mode (should register no-op handler)
cat("Testing silent mode...\n")

h_silent <- runServer(
  dir = getwd(),
  addr = "127.0.0.1:8351",
  blocking = FALSE,
  silent = TRUE
)

Sys.sleep(0.5)
shutdownServer(h_silent)
Sys.sleep(0.5)

cat("Log handler tests completed\n")
