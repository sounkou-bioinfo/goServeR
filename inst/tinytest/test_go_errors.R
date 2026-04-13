library(goserveR)
library(tinytest)

# Test Go-level error scenarios with logging
cat("Testing Go-level error scenarios with logging...\n")

# Test 1: Port binding conflict with logging capture
cat("Testing port binding conflict with logging...\n")

h1 <- runServer(
  dir = getwd(),
  addr = "127.0.0.1:8300",
  blocking = FALSE,
  silent = TRUE
)
Sys.sleep(0.5)

# Verify it's running
servers_before <- listServers()
expect_true(
  length(servers_before) >= 1,
  info = "First server should be running"
)

# Try to start another server on the same port
cat("Starting conflicting server (should fail at Go level)...\n")
h2 <- runServer(
  dir = getwd(),
  addr = "127.0.0.1:8300",
  blocking = FALSE,
  silent = TRUE
)

# Give time for the conflict to manifest
Sys.sleep(2)

servers_after <- listServers()
cat("Servers before conflict:", length(servers_before), "\n")
cat("Servers after conflict:", length(servers_after), "\n")

expect_true(
  is.list(servers_after),
  info = "R should still be responsive after Go error"
)

# Cleanup
shutdownServer(h1)
shutdownServer(h2)
Sys.sleep(0.5)

cat("Port conflict test completed - R session intact\n")

# Test 2: Permission denied with logging
cat("Testing permission scenarios with logging...\n")

if (.Platform$OS.type != "windows") {
  cat("Attempting to bind to privileged port (should fail)...\n")
  h_priv <- runServer(
    dir = getwd(),
    addr = "127.0.0.1:80",
    blocking = FALSE,
    silent = TRUE
  )

  Sys.sleep(2)

  servers_priv <- listServers()
  expect_true(
    is.list(servers_priv),
    info = "R should remain responsive after permission error"
  )
  cat("R session remains intact after permission error\n")

  shutdownServer(h_priv)
  Sys.sleep(0.5)
}

# Test 3: TLS errors with logging
cat("Testing TLS certificate errors with logging...\n")

h_tls <- runServer(
  dir = getwd(),
  addr = "127.0.0.1:8301",
  blocking = FALSE,
  tls = TRUE,
  certfile = "/nonexistent/cert.pem",
  keyfile = "/nonexistent/key.pem",
  silent = TRUE
)

Sys.sleep(2)

servers_tls <- listServers()
expect_true(
  is.list(servers_tls),
  info = "R should remain responsive after TLS error"
)
cat("R session remains intact after TLS error\n")

shutdownServer(h_tls)
Sys.sleep(0.5)

# Test 4: Verify panic recovery doesn't crash R
cat("Testing that Go panics are recovered and don't crash R...\n")

base_port <- 8310
h_base <- runServer(
  dir = getwd(),
  addr = paste0("127.0.0.1:", base_port),
  blocking = FALSE,
  silent = TRUE
)
Sys.sleep(0.5)

conflicting_handles <- list()
for (i in 1:3) {
  conflicting_handles[[i]] <- runServer(
    dir = getwd(),
    addr = paste0("127.0.0.1:", base_port),
    blocking = FALSE,
    silent = TRUE
  )
}

Sys.sleep(3)

servers_final <- listServers()
expect_true(
  is.list(servers_final),
  info = "R should remain fully functional after stress test"
)

test_data <- data.frame(x = 1:10, y = rnorm(10))
expect_true(
  nrow(test_data) == 10,
  info = "R should still perform data operations"
)

cat("Final server count after rapid conflicts:", length(servers_final), "\n")

# Cleanup everything
shutdownServer(h_base)
for (h in conflicting_handles) {
  shutdownServer(h)
}
Sys.sleep(0.5)

final_check <- listServers()
expect_true(is.list(final_check), info = "Final R health check should pass")

cat("Go-level error tests completed - R session fully intact\n")
