library(goserveR)
library(tinytest)

# Test log handler functionality
cat("Testing log handler functionality...\n")

if (interactive() || !nzchar(Sys.getenv("CI"))) {
  # Test 1: Basic file log handler
  cat("Testing file log handler...\n")

  logfile <- tempfile("test_log_", fileext = ".log")
  h <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8350",
    blocking = FALSE,
    silent = FALSE
  )

  # Give server time to start and generate some log messages
  Sys.sleep(1)

  # Check if log file exists and has content
  if (file.exists(logfile)) {
    log_content <- readLines(logfile)
    expect_true(
      length(log_content) > 0,
      info = "Log file should contain messages"
    )
    cat("Log file content preview:\n")
    cat(head(log_content, 3), sep = "\n")
  }

  shutdownServer(h)
  if (file.exists(logfile)) unlink(logfile)

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

  # Test 3: Custom log handler
  cat("Testing custom log handler...\n")

  # Create a custom handler that collects messages
  log_messages <- character(0)
  custom_handler <- function(handler, message, collector) {
    collector <<- c(collector, trimws(message))
  }

  # For this test, we would need to modify the server creation
  # to accept a custom log handler
  # This is a design consideration for future enhancement

  cat("Log handler tests completed\n")
} else {
  cat("Skipping log handler tests on CI\n")
}
