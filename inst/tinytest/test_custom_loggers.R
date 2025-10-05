library(goserveR)
library(tinytest)

# Test custom log handlers
if (interactive() || !nzchar(Sys.getenv("CI"))) {
  cat("Testing custom log handlers...\n")

  # Test 1: Custom file logger
  cat("Testing file logger...\n")
  logfile <- tempfile("test_file_", fileext = ".log")

  file_logger <- function(handler, message, user) {
    cat(
      paste0("[FILE] ", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), " ", message),
      file = logfile,
      append = TRUE
    )
  }

  h1 <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8400",
    blocking = FALSE,
    silent = FALSE,
    log_handler = file_logger
  )

  Sys.sleep(1)

  # Check if log file was created and has content
  expect_true(file.exists(logfile), info = "Log file should exist")
  if (file.exists(logfile)) {
    log_content <- readLines(logfile)
    expect_true(length(log_content) > 0, info = "Log file should have content")
    expect_true(
      any(grepl("\\[FILE\\]", log_content)),
      info = "Log should have custom prefix"
    )
    expect_true(
      any(grepl("Serving.*directories", log_content)),
      info = "Log should contain server startup message"
    )
  }

  shutdownServer(h1)
  if (file.exists(logfile)) unlink(logfile)

  # Test 2: Custom console logger with prefix
  cat("Testing custom console logger...\n")

  # Capture console output
  captured_output <- ""
  console_logger <- function(handler, message, user) {
    captured_output <<- paste0(captured_output, "[CUSTOM] ", message)
  }

  h2 <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8401",
    blocking = FALSE,
    silent = FALSE,
    log_handler = console_logger
  )

  Sys.sleep(1)

  expect_true(
    nchar(captured_output) > 0,
    info = "Custom console logger should capture output"
  )
  expect_true(
    grepl("\\[CUSTOM\\]", captured_output),
    info = "Custom prefix should appear"
  )

  shutdownServer(h2)

  # Test 3: Compare with default logger
  cat("Testing default vs custom behavior...\n")

  # Default logger
  h3 <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8402",
    blocking = FALSE,
    silent = FALSE
  )

  # Custom silent logger
  custom_silent <- function(handler, message, user) {
    # Do nothing - custom silent implementation
  }
  h4 <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8403",
    blocking = FALSE,
    silent = FALSE,
    log_handler = custom_silent
  )

  # Built-in silent mode
  h5 <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8404",
    blocking = FALSE,
    silent = TRUE
  )

  servers <- listServers()
  expect_true(length(servers) == 3, info = "Should have 3 servers running")

  Sys.sleep(1)

  # Cleanup
  shutdownServer(h3)
  shutdownServer(h4)
  shutdownServer(h5)

  # Test 4: Logger with user data
  cat("Testing logger with user data...\n")

  logfile2 <- tempfile("test_user_", fileext = ".log")

  user_data_logger <- function(handler, message, user) {
    if (!is.null(user)) {
      cat(paste0("[", user, "] ", message), file = logfile2, append = TRUE)
    } else {
      cat(message, file = logfile2, append = TRUE)
    }
  }

  # Note: This test demonstrates the interface, but user data passing
  # would need additional C-level implementation
  h6 <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8405",
    blocking = FALSE,
    silent = FALSE,
    log_handler = user_data_logger
  )

  Sys.sleep(1)

  shutdownServer(h6)
  if (file.exists(logfile2)) unlink(logfile2)

  # Final verification
  final_servers <- listServers()
  expect_true(
    length(final_servers) == 0,
    info = "All servers should be cleaned up"
  )

  cat("Custom logger tests completed successfully\n")
} else {
  cat("Skipping custom logger tests on CI\n")
}
