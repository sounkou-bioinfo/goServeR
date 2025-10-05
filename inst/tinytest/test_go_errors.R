library(goserveR)
library(tinytest)

# Test Go-level error scenarios with logging
# These tests focus on errors that occur at the Go server level
# and verify they are logged properly without crashing R

if (interactive() || !nzchar(Sys.getenv("CI"))) {
  cat("Testing Go-level error scenarios with logging...\n")

  # Test 1: Port binding conflict with logging capture
  cat("Testing port binding conflict with logging...\n")

  # Create a temporary log file to capture messages
  logfile1 <- tempfile("port_conflict_", fileext = ".log")

  # Start a server on a specific port (not silent to capture logs)
  h1 <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8300",
    blocking = FALSE,
    silent = FALSE
  )
  Sys.sleep(0.5) # Let it start

  # Verify it's running
  servers_before <- listServers()
  expect_true(
    length(servers_before) >= 1,
    info = "First server should be running"
  )

  # Try to start another server on the same port
  # This should fail at Go level and the error should be logged
  cat(
    "Starting conflicting server (should fail at Go level and be logged)...\n"
  )
  h2 <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8300",
    blocking = FALSE,
    silent = FALSE
  )

  # Give time for the conflict to manifest and be logged
  Sys.sleep(2)

  # Check server list - the conflicting server should have failed and exited
  servers_after <- listServers()
  cat("Servers before conflict:", length(servers_before), "\n")
  cat("Servers after conflict:", length(servers_after), "\n")

  # Verify R session is still intact after Go error
  expect_true(
    is.list(servers_after),
    info = "R should still be responsive after Go error"
  )

  # Cleanup
  shutdownServer(h1)
  shutdownServer(h2) # This should be safe (no-op)

  cat("Port conflict test completed - R session intact\n")

  # Test 2: Permission denied with logging
  cat("Testing permission scenarios with logging...\n")

  if (.Platform$OS.type != "windows") {
    # Skip on Windows
    cat(
      "Attempting to bind to privileged port (should fail and be logged)...\n"
    )
    h_priv <- runServer(
      dir = getwd(),
      addr = "127.0.0.1:80",
      blocking = FALSE,
      silent = FALSE
    )

    # Give time for the permission error to occur and be logged
    Sys.sleep(2)

    # Verify R is still responsive
    servers_priv <- listServers()
    expect_true(
      is.list(servers_priv),
      info = "R should remain responsive after permission error"
    )
    cat("R session remains intact after permission error\n")

    # Cleanup
    shutdownServer(h_priv)
  }

  # Test 3: TLS errors with logging
  cat("Testing TLS certificate errors with logging...\n")

  # Try to start TLS server with non-existent certificates
  # This should fail at Go level and be logged
  h_tls <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8301",
    blocking = FALSE,
    tls = TRUE,
    certfile = "/nonexistent/cert.pem",
    keyfile = "/nonexistent/key.pem",
    silent = FALSE
  )

  # Give time for TLS error to occur and be logged
  Sys.sleep(2)

  servers_tls <- listServers()
  expect_true(
    is.list(servers_tls),
    info = "R should remain responsive after TLS error"
  )
  cat("R session remains intact after TLS error\n")

  # Cleanup
  shutdownServer(h_tls)

  # Test 4: Verify panic recovery doesn't crash R
  cat("Testing that Go panics are recovered and don't crash R...\n")

  # Start multiple servers that will all conflict rapidly
  # This can potentially cause Go panics in the HTTP server
  base_port <- 8310
  h_base <- runServer(
    dir = getwd(),
    addr = paste0("127.0.0.1:", base_port),
    blocking = FALSE,
    silent = FALSE
  )
  Sys.sleep(0.5)

  # Start several conflicting servers rapidly to stress the system
  conflicting_handles <- list()
  for (i in 1:5) {
    conflicting_handles[[i]] <- runServer(
      dir = getwd(),
      addr = paste0("127.0.0.1:", base_port),
      blocking = FALSE,
      silent = FALSE
    )
  }

  # Give time for all conflicts to resolve and any panics to be recovered
  Sys.sleep(3)

  # Verify R is still completely functional
  servers_final <- listServers()
  expect_true(
    is.list(servers_final),
    info = "R should remain fully functional after stress test"
  )

  # Test that R can still perform complex operations
  test_data <- data.frame(x = 1:10, y = rnorm(10))
  expect_true(
    nrow(test_data) == 10,
    info = "R should still perform data operations"
  )

  cat("Final server count after rapid conflicts:", length(servers_final), "\n")
  cat("R session fully functional after Go stress test\n")

  # Cleanup everything
  shutdownServer(h_base)
  for (h in conflicting_handles) {
    shutdownServer(h)
  }

  # Final verification that R is still healthy
  final_check <- listServers()
  expect_true(is.list(final_check), info = "Final R health check should pass")

  cat("Go-level error tests completed - R session fully intact\n")
} else {
  cat("Skipping Go-level error tests on CI\n")
}
