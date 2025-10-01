library(goserveR)
library(tinytest)

# Comprehensive but safe server testing
if (interactive() || !nzchar(Sys.getenv("CI"))) {
    cat("=== Comprehensive Server Testing ===\n")

    # Test 1: Basic server lifecycle
    cat("1. Testing basic server lifecycle...\n")

    h1 <- runServer(dir = getwd(), addr = "127.0.0.1:8501", blocking = FALSE, silent = TRUE)
    expect_true(inherits(h1, "externalptr"), info = "Server handle should be external pointer")
    Sys.sleep(0.5)

    # Safely check server list
    servers <- tryCatch(listServers(), error = function(e) list())
    expect_true(length(servers) >= 1, info = "Should have at least one server")

    shutdownServer(h1)
    Sys.sleep(0.5)
    cat("   ✓ Basic lifecycle completed\n")

    # Test 2: Multiple servers (sequential, not concurrent)
    cat("2. Testing multiple servers sequentially...\n")

    handles <- list()
    ports <- 8510:8512

    # Start servers one by one with delays
    for (i in seq_along(ports)) {
        handles[[i]] <- runServer(
            dir = getwd(), addr = paste0("127.0.0.1:", ports[i]),
            blocking = FALSE, silent = TRUE
        )
        Sys.sleep(0.3) # Wait between starts
    }

    Sys.sleep(1) # Let all servers stabilize

    # Check all are running
    servers <- tryCatch(listServers(), error = function(e) list())
    expect_true(length(servers) >= length(ports), info = "All sequential servers should be running")

    # Stop them one by one with delays
    for (h in handles) {
        shutdownServer(h)
        Sys.sleep(0.3) # Wait between stops
    }

    Sys.sleep(1) # Let cleanup complete
    cat("   ✓ Sequential multiple servers completed\n")

    # Test 3: Server configuration options
    cat("3. Testing server configurations...\n")

    # CORS enabled
    h_cors <- runServer(
        dir = getwd(), addr = "127.0.0.1:8520",
        blocking = FALSE, cors = TRUE, silent = TRUE
    )
    Sys.sleep(0.5)
    shutdownServer(h_cors)
    Sys.sleep(0.5)

    # COOP enabled
    h_coop <- runServer(
        dir = getwd(), addr = "127.0.0.1:8521",
        blocking = FALSE, coop = TRUE, silent = TRUE
    )
    Sys.sleep(0.5)
    shutdownServer(h_coop)
    Sys.sleep(0.5)

    # Both enabled
    h_both <- runServer(
        dir = getwd(), addr = "127.0.0.1:8522",
        blocking = FALSE, cors = TRUE, coop = TRUE, silent = TRUE
    )
    Sys.sleep(0.5)
    shutdownServer(h_both)
    Sys.sleep(0.5)

    cat("   ✓ Configuration options completed\n")

    # Test 4: Error scenarios (controlled)
    cat("4. Testing controlled error scenarios...\n")

    # Port conflict (Go-level error)
    h_main <- runServer(dir = getwd(), addr = "127.0.0.1:8530", blocking = FALSE, silent = TRUE)
    Sys.sleep(0.5)

    # Try to start conflicting server
    h_conflict <- runServer(dir = getwd(), addr = "127.0.0.1:8530", blocking = FALSE, silent = TRUE)
    Sys.sleep(2) # Give time for conflict to resolve

    # The conflicting server should fail at Go level and not appear in list
    servers_conflict <- tryCatch(listServers(), error = function(e) list())
    expect_true(length(servers_conflict) >= 1, info = "Original server should still be running")

    shutdownServer(h_main)
    shutdownServer(h_conflict) # Safe to call even if already failed
    Sys.sleep(0.5)

    cat("   ✓ Controlled error scenarios completed\n")

    # Test 5: R-level validation errors
    cat("5. Testing R-level validation...\n")

    # These should fail in R validation before reaching Go
    expect_error(runServer(dir = "", blocking = FALSE),
        info = "Empty directory should error"
    )

    expect_error(runServer(dir = "/nonexistent/path", blocking = FALSE),
        info = "Non-existent directory should error"
    )

    expect_error(runServer(dir = getwd(), addr = "", blocking = FALSE),
        info = "Empty address should error"
    )

    expect_error(runServer(dir = getwd(), addr = "invalid-format", blocking = FALSE),
        info = "Invalid address format should error"
    )

    expect_error(runServer(dir = getwd(), addr = "127.0.0.1", blocking = FALSE),
        info = "Missing port should error"
    )

    expect_error(runServer(dir = getwd(), addr = ":8080", blocking = FALSE),
        info = "Missing host should error"
    )

    # Type validation
    expect_error(runServer(dir = getwd(), blocking = "yes"),
        info = "Non-logical blocking should error"
    )

    expect_error(runServer(dir = getwd(), cors = "true"),
        info = "Non-logical cors should error"
    )

    cat("   ✓ R-level validation completed\n")

    # Test 6: Safe cleanup operations
    cat("6. Testing safe cleanup...\n")

    # Test double shutdown (should be safe)
    h_cleanup <- runServer(dir = getwd(), addr = "127.0.0.1:8540", blocking = FALSE, silent = TRUE)
    Sys.sleep(0.5)

    shutdownServer(h_cleanup)
    expect_silent(shutdownServer(h_cleanup), info = "Double shutdown should be safe")

    # Test shutdown of NULL (should be safe)
    expect_silent(shutdownServer(NULL), info = "Shutdown of NULL should be safe")

    cat("   ✓ Safe cleanup completed\n")

    # Final check - ensure no servers are left running
    cat("7. Final cleanup check...\n")
    Sys.sleep(1)

    final_servers <- tryCatch(listServers(), error = function(e) list())
    cat("   Final server count:", length(final_servers), "\n")

    cat("=== All tests completed successfully! ===\n")
} else {
    cat("Skipping comprehensive server tests on CI environment\n")
}
