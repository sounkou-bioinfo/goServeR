library(goserveR)
library(tinytest)

# Test error handling and edge cases
cat("Testing error handling scenarios...\n")

# Test 1: Invalid parameters (these should fail in R validation)
expect_error(runServer(dir = "", blocking = FALSE),
    info = "Empty directory should error"
)

expect_error(runServer(dir = NA, blocking = FALSE),
    info = "NA directory should error"
)

expect_error(runServer(dir = getwd(), addr = "", blocking = FALSE),
    info = "Empty address should error"
)

expect_error(runServer(dir = getwd(), addr = NA, blocking = FALSE),
    info = "NA address should error"
)

# Test 2: Type validation
expect_error(runServer(dir = getwd(), blocking = "yes"),
    info = "Non-logical blocking parameter should error"
)

expect_error(runServer(dir = getwd(), cors = "true"),
    info = "Non-logical cors parameter should error"
)

expect_error(runServer(dir = getwd(), silent = 1),
    info = "Non-logical silent parameter should error"
)

# Test 3: Multiple parameter errors
expect_error(runServer(dir = c(".", ".."), blocking = FALSE),
    info = "Multiple directories should error"
)

expect_error(runServer(dir = getwd(), addr = c("127.0.0.1:8080", "127.0.0.1:8081"), blocking = FALSE),
    info = "Multiple addresses should error"
)

# Test 4: Edge case addresses
# Note: Invalid IPs (like 999.999.999.999) are handled by Go, not R validation
# They create a server that fails at Go level, which is expected behavior

expect_error(runServer(dir = getwd(), addr = "127.0.0.1:99999", blocking = FALSE),
    info = "Invalid port number should error"
)

expect_error(runServer(dir = getwd(), addr = "127.0.0.1:-1", blocking = FALSE),
    info = "Negative port should error"
)

# Test 5: Test shutdown of invalid handle
if (interactive() || !nzchar(Sys.getenv("CI"))) {
    # This should not crash, just be a no-op
    expect_silent(shutdownServer(NULL), info = "Shutting down NULL should be silent")

    # Test double shutdown (should be safe)
    h <- runServer(dir = getwd(), addr = "127.0.0.1:8250", blocking = FALSE, silent = TRUE)
    Sys.sleep(0.2)
    shutdownServer(h)
    expect_silent(shutdownServer(h), info = "Double shutdown should be silent")
}

# Test 6: listServers when no servers running
# Clear any remaining servers first
if (interactive() || !nzchar(Sys.getenv("CI"))) {
    servers <- listServers()
    # This might return empty list, which is fine
    expect_true(is.list(servers), info = "listServers should return a list")
}

cat("Error handling tests completed\n")
