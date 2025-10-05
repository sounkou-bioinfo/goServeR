library(goserveR)
library(tinytest)

# Test rapid server operations with proper synchronization
if (interactive() || !nzchar(Sys.getenv("CI"))) {
  cat("Testing rapid server operations (no artificial delays)...\n")

  # Test 1: Rapid server creation and shutdown
  handles <- list()
  ports <- 8600:8605

  cat("Starting", length(ports), "servers rapidly...\n")
  start_time <- Sys.time()

  # Start servers without delays - rely on proper synchronization
  for (i in seq_along(ports)) {
    handles[[i]] <- runServer(
      dir = getwd(),
      addr = paste0("127.0.0.1:", ports[i]),
      blocking = FALSE,
      silent = TRUE
    )
  }

  end_time <- Sys.time()
  cat(
    "Server creation took:",
    as.numeric(end_time - start_time, units = "secs"),
    "seconds\n"
  )

  # Check servers immediately - should work with proper synchronization
  servers <- listServers()
  expect_true(
    length(servers) >= length(ports),
    info = paste(
      "Should have at least",
      length(ports),
      "servers, got",
      length(servers)
    )
  )

  cat("Found", length(servers), "active servers\n")

  # Test rapid shutdown
  cat("Shutting down servers rapidly...\n")
  start_time <- Sys.time()

  for (h in handles) {
    shutdownServer(h)
  }

  end_time <- Sys.time()
  cat(
    "Server shutdown took:",
    as.numeric(end_time - start_time, units = "secs"),
    "seconds\n"
  )

  # Brief pause to let cleanup complete
  Sys.sleep(0.5)

  final_servers <- listServers()
  cat("Servers remaining after cleanup:", length(final_servers), "\n")

  # Test 2: Stress test with many servers
  cat("\nStress testing with many servers...\n")

  stress_handles <- list()
  stress_ports <- 8610:8620 # 11 servers

  # Rapid creation
  for (i in seq_along(stress_ports)) {
    stress_handles[[i]] <- runServer(
      dir = getwd(),
      addr = paste0("127.0.0.1:", stress_ports[i]),
      blocking = FALSE,
      silent = TRUE
    )
  }

  # Multiple rapid listServers() calls (this used to cause segfaults)
  for (i in 1:5) {
    servers <- listServers()
    cat("Iteration", i, "- found", length(servers), "servers\n")
  }

  # Rapid cleanup
  for (h in stress_handles) {
    shutdownServer(h)
  }

  cat("Stress test completed\n")

  # Test 3: Concurrent operations simulation
  cat("\nTesting concurrent-like operations...\n")

  # Start some servers
  concurrent_handles <- list()
  concurrent_ports <- 8630:8632

  for (i in seq_along(concurrent_ports)) {
    concurrent_handles[[i]] <- runServer(
      dir = getwd(),
      addr = paste0("127.0.0.1:", concurrent_ports[i]),
      blocking = FALSE,
      silent = TRUE
    )
  }

  # Interleave listServers() calls with shutdowns
  servers1 <- listServers()
  shutdownServer(concurrent_handles[[1]])

  servers2 <- listServers()
  shutdownServer(concurrent_handles[[2]])

  servers3 <- listServers()
  shutdownServer(concurrent_handles[[3]])

  servers4 <- listServers()

  cat(
    "Server counts during shutdown:",
    length(servers1),
    "->",
    length(servers2),
    "->",
    length(servers3),
    "->",
    length(servers4),
    "\n"
  )

  cat("All rapid operation tests completed successfully!\n")
} else {
  cat("Skipping rapid operation tests on CI\n")
}
