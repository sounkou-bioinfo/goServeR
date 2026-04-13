library(goserveR)
library(tinytest)

cat("Testing rapid server operations...\n")

# Test 1: Rapid server creation and shutdown
handles <- list()
ports <- 8600:8605

cat("Starting", length(ports), "servers rapidly...\n")
start_time <- Sys.time()

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

# Let servers fully initialize
Sys.sleep(1)
servers <- listServers()

expect_true(
  length(servers) >= length(ports) - 1,
  info = paste(
    "Should have at least",
    length(ports) - 1,
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

Sys.sleep(1)

final_servers <- listServers()
cat("Servers remaining after cleanup:", length(final_servers), "\n")

# Test 2: Stress test with many servers
cat("\nStress testing with many servers...\n")

stress_handles <- list()
stress_ports <- 8610:8620 # 11 servers

for (i in seq_along(stress_ports)) {
  stress_handles[[i]] <- runServer(
    dir = getwd(),
    addr = paste0("127.0.0.1:", stress_ports[i]),
    blocking = FALSE,
    silent = TRUE
  )
  Sys.sleep(0.1) # Small delay between starts to avoid race conditions
}

Sys.sleep(1.5)

# Multiple rapid listServers() calls (this used to cause segfaults)
for (i in 1:5) {
  if (i > 1) Sys.sleep(0.05)
  servers <- listServers()
  cat("Iteration", i, "- found", length(servers), "servers\n")
}

# Rapid cleanup
for (h in stress_handles) {
  shutdownServer(h)
  Sys.sleep(0.1)
}

Sys.sleep(1.5)
cat("Stress test completed\n")

# Test 3: Concurrent operations simulation
cat("\nTesting concurrent-like operations...\n")

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

Sys.sleep(0.5)

# Interleave listServers() calls with shutdowns
servers1 <- listServers()
shutdownServer(concurrent_handles[[1]])
Sys.sleep(0.2)

servers2 <- listServers()
shutdownServer(concurrent_handles[[2]])
Sys.sleep(0.2)

servers3 <- listServers()
shutdownServer(concurrent_handles[[3]])
Sys.sleep(0.2)

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
