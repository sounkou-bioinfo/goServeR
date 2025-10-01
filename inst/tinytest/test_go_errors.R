library(goserveR)
library(tinytest)

# Test Go-level error scenarios
# These tests focus on errors that occur at the Go server level

if (interactive() || !nzchar(Sys.getenv("CI"))) {
    cat("Testing Go-level error scenarios...\n")

    # Test 1: Port binding conflict (Go-level error)
    cat("Testing port binding conflict...\n")

    # Start a server on a specific port
    h1 <- runServer(dir = getwd(), addr = "127.0.0.1:8300", blocking = FALSE, silent = FALSE)
    Sys.sleep(0.5) # Let it start

    # Verify it's running
    servers_before <- listServers()
    expect_true(length(servers_before) >= 1, info = "First server should be running")

    # Try to start another server on the same port
    # This should succeed in R but fail at Go level
    cat("Starting conflicting server (should fail at Go level)...\n")
    h2 <- runServer(dir = getwd(), addr = "127.0.0.1:8300", blocking = FALSE, silent = FALSE)

    # Give time for the conflict to manifest
    Sys.sleep(2)

    # Check server list - the conflicting server should have failed and exited
    servers_after <- listServers()
    cat("Servers before conflict:", length(servers_before), "\n")
    cat("Servers after conflict:", length(servers_after), "\n")

    # The second server should have failed to start (Go error) and its thread should have exited
    # So we should still have approximately the same number of servers
    # (The failed server won't appear in the list anymore)

    # Cleanup
    shutdownServer(h1)
    # h2 should already be dead from the Go error
    shutdownServer(h2) # This should be safe (no-op)

    cat("Port conflict test completed\n")

    # Test 2: Permission denied error (if we can simulate it)
    cat("Testing permission scenarios...\n")

    # Try to bind to a privileged port (will fail with permission denied on most systems)
    # This is a Go-level error that should cause the server thread to exit
    if (.Platform$OS.type != "windows") { # Skip on Windows
        cat("Attempting to bind to privileged port (should fail)...\n")
        h_priv <- runServer(dir = getwd(), addr = "127.0.0.1:80", blocking = FALSE, silent = FALSE)

        # Give time for the permission error to occur
        Sys.sleep(2)

        # The server should have failed at Go level
        # The thread should have exited
        servers_priv <- listServers()
        cat("Servers after privilege test:", length(servers_priv), "\n")

        # Cleanup (should be no-op since server failed)
        shutdownServer(h_priv)
    }

    # Test 3: Test TLS errors (if certificates don't exist)
    cat("Testing TLS certificate errors...\n")

    # Try to start TLS server with non-existent certificates
    # This should fail at Go level when trying to load certificates
    h_tls <- runServer(
        dir = getwd(), addr = "127.0.0.1:8301",
        blocking = FALSE, tls = TRUE,
        certfile = "/nonexistent/cert.pem",
        keyfile = "/nonexistent/key.pem",
        silent = FALSE
    )

    # Give time for TLS error to occur
    Sys.sleep(2)

    servers_tls <- listServers()
    cat("Servers after TLS test:", length(servers_tls), "\n")

    # Cleanup
    shutdownServer(h_tls)

    # Test 4: Rapid error scenarios
    cat("Testing rapid error scenarios...\n")

    # Start multiple servers that will all conflict with the first one
    base_port <- 8310
    h_base <- runServer(
        dir = getwd(), addr = paste0("127.0.0.1:", base_port),
        blocking = FALSE, silent = TRUE
    )
    Sys.sleep(0.5)

    # Start several conflicting servers rapidly
    conflicting_handles <- list()
    for (i in 1:3) {
        conflicting_handles[[i]] <- runServer(
            dir = getwd(),
            addr = paste0("127.0.0.1:", base_port),
            blocking = FALSE, silent = TRUE
        )
    }

    # Give time for all conflicts to resolve
    Sys.sleep(3)

    servers_final <- listServers()
    cat("Final server count after rapid conflicts:", length(servers_final), "\n")

    # Cleanup everything
    shutdownServer(h_base)
    for (h in conflicting_handles) {
        shutdownServer(h)
    }

    cat("Go-level error tests completed\n")
} else {
    cat("Skipping Go-level error tests on CI\n")
}
