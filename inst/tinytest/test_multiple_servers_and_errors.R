library(goserveR)
library(tinytest)

# DISABLED: This test causes segfaults due to race conditions in C code
# The issue is in listServers() when called during rapid server operations
# See test_comprehensive_safe.R for safe alternatives

if (FALSE) {
  # Disabled to prevent segfaults
  # Test 1: Multiple servers can run simultaneously
  cat("Testing multiple servers...\n")

  # Start multiple servers on different ports
  h1 <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8201",
    blocking = FALSE,
    silent = TRUE
  )
  h2 <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8202",
    blocking = FALSE,
    silent = TRUE
  )
  h3 <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8203",
    blocking = FALSE,
    silent = TRUE
  )

  # Give servers time to start
  Sys.sleep(0.5)

  # Check all servers are running
  servers <- listServers()
  expect_true(
    length(servers) >= 3,
    info = "Should have at least 3 servers running"
  )

  # Verify each server handle is valid
  expect_true(inherits(h1, "externalptr"))
  expect_true(inherits(h2, "externalptr"))
  expect_true(inherits(h3, "externalptr"))

  # Test that we can shutdown individual servers
  shutdownServer(h2)
  Sys.sleep(0.2)
  servers_after_shutdown <- listServers()
  expect_true(
    length(servers_after_shutdown) == length(servers) - 1,
    info = "Should have one less server after shutdown"
  )

  # Cleanup remaining servers
  shutdownServer(h1)
  shutdownServer(h3)
  Sys.sleep(0.2)

  cat("Multiple servers test completed\n")

  # Test 2: Port already in use error
  cat("Testing port conflict error...\n")

  # Start a server
  h_main <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8210",
    blocking = FALSE,
    silent = TRUE
  )
  Sys.sleep(0.5)

  # Try to start another server on the same port (should fail)
  # Note: The Go server will log an error and the thread will exit
  # but R won't get an immediate error - it's a background failure
  h_conflict <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8210",
    blocking = FALSE,
    silent = TRUE
  )

  # Give time for the conflict to be detected
  Sys.sleep(1)

  # The conflicting server should not appear in the list (it failed to start)
  servers <- listServers()

  # We should only have one server running (the first one)
  # The second one failed and its thread exited
  expect_true(
    length(servers) >= 1,
    info = "Original server should still be running"
  )

  # Cleanup
  shutdownServer(h_main)
  Sys.sleep(0.2)

  cat("Port conflict test completed\n")

  # Test 3: Invalid directory error
  cat("Testing invalid directory error...\n")

  # Try to serve a non-existent directory
  # Note: The validation happens in R before calling Go, so this should error immediately
  expect_error(
    runServer(
      dir = "/nonexistent/directory",
      addr = "127.0.0.1:8211",
      blocking = FALSE
    ),
    info = "Should error when directory doesn't exist"
  )

  cat("Invalid directory test completed\n")

  # Test 4: Invalid address format error
  cat("Testing invalid address format...\n")

  # Try invalid address formats
  expect_error(
    runServer(dir = getwd(), addr = "invalid-address", blocking = FALSE),
    info = "Should error with invalid address format"
  )

  expect_error(
    runServer(dir = getwd(), addr = "127.0.0.1", blocking = FALSE),
    info = "Should error with address missing port"
  )

  expect_error(
    runServer(dir = getwd(), addr = ":8080", blocking = FALSE),
    info = "Should error with missing host"
  )

  cat("Invalid address format test completed\n")

  # Test 5: Server cleanup and finalizer behavior
  cat("Testing server cleanup...\n")

  # Start servers and let them go out of scope
  local({
    h_temp1 <- runServer(
      dir = getwd(),
      addr = "127.0.0.1:8220",
      blocking = FALSE,
      silent = TRUE
    )
    h_temp2 <- runServer(
      dir = getwd(),
      addr = "127.0.0.1:8221",
      blocking = FALSE,
      silent = TRUE
    )
    Sys.sleep(0.5)

    servers_before <- listServers()
    expect_true(length(servers_before) >= 2)

    # Explicit shutdown of one
    shutdownServer(h_temp1)
    # h_temp2 will be cleaned up by finalizer when this scope ends
  })

  # Force garbage collection to trigger finalizers
  gc()
  Sys.sleep(0.5)

  # Check that servers are cleaned up
  servers_after_gc <- listServers()
  # The server should be cleaned up by the finalizer

  cat("Server cleanup test completed\n")

  # Test 6: Conservative start/stop cycle (avoid rapid operations)
  cat("Testing controlled start/stop cycle...\n")

  handles <- list()
  ports <- 8230:8232 # Reduced number to avoid race conditions

  # Start servers with small delays
  for (i in seq_along(ports)) {
    handles[[i]] <- runServer(
      dir = getwd(),
      addr = paste0("127.0.0.1:", ports[i]),
      blocking = FALSE,
      silent = TRUE
    )
    Sys.sleep(0.1) # Small delay between starts
  }

  Sys.sleep(1) # Longer wait for all to start properly

  # Check servers (with error handling)
  tryCatch(
    {
      servers_controlled <- listServers()
      expect_true(
        length(servers_controlled) >= length(ports),
        info = "All controlled servers should be running"
      )
    },
    error = function(e) {
      cat("Error in listServers():", e$message, "\n")
    }
  )

  # Stop them with delays
  for (h in handles) {
    shutdownServer(h)
    Sys.sleep(0.1) # Small delay between stops
  }

  Sys.sleep(1) # Wait for cleanup

  cat("Controlled start/stop test completed\n")

  # Test 7: Server with different configurations
  cat("Testing different server configurations...\n")

  # Test CORS enabled
  h_cors <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8240",
    blocking = FALSE,
    cors = TRUE,
    silent = TRUE
  )

  # Test COOP enabled
  h_coop <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8241",
    blocking = FALSE,
    coop = TRUE,
    silent = TRUE
  )

  # Test both CORS and COOP
  h_both <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:8242",
    blocking = FALSE,
    cors = TRUE,
    coop = TRUE,
    silent = TRUE
  )

  Sys.sleep(0.5)

  servers_config <- listServers()
  expect_true(
    length(servers_config) >= 3,
    info = "All configuration test servers should be running"
  )

  # Cleanup
  shutdownServer(h_cors)
  shutdownServer(h_coop)
  shutdownServer(h_both)

  cat("Configuration test completed\n")

  cat("All tests completed successfully!\n")
} # End of disabled test block
