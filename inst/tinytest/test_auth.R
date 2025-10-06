# Test API key authentication functionality
library(goserveR)
library(tinytest)


# Setup test directory and file
# Use normalizePath to ensure we have an absolute path, which is more robust.
test_dir <- normalizePath(tempdir())
print(test_dir)
test_content <- "hello world"
# Ensure the directory exists
if (!dir.exists(test_dir)) dir.create(test_dir, recursive = TRUE)
writeLines(test_content, file.path(test_dir, "test.txt"))

# Verify file was created
if (!file.exists(file.path(test_dir, "test.txt"))) {
    stop("Test file was not created properly")
}
cat("Test file created at:", file.path(test_dir, "test.txt"), "\n")

# Test 1: No auth key - all requests pass
server1 <- runServer(
    dir = test_dir,
    addr = "127.0.0.1:8190",
    prefix = "/",
    blocking = FALSE,
    silent = TRUE,
    auth_keys = c(),
    mustWork = TRUE # Ensure server actually starts
)

# Verify server is running
expect_true(isRunning(server1), "Server should be running after start")
# Helper function to wait for a server to be responsive

if (Sys.which("curl") != "") {
    system('curl -s "http://127.0.0.1:8190/test.txt" -o "output.txt"')
    no_auth_content <- tryCatch(
        readLines("output.txt", warn = FALSE),
        error = function(e) "ERROR"
    )
    expect_true(
        length(no_auth_content) > 0 && no_auth_content[1] == test_content,
        "No-auth should return file content"
    )
}

shutdownServer(server1)
Sys.sleep(0.5) # Give time for shutdown

# Verify server is no longer running
expect_false(isRunning(server1), "Server should not be running after shutdown")

# Test 2: Single auth key
server2 <- runServer(
    dir = test_dir,
    addr = "127.0.0.1:8291",
    prefix = "/",
    blocking = FALSE,
    silent = TRUE,
    auth_keys = c("secret123"),
    mustWork = TRUE # Ensure server actually starts
)

# Verify server is running
expect_true(isRunning(server2), "Auth server should be running after start")

Sys.sleep(1) # Give server time to start
# create test file
writeLines(test_content, file.path(test_dir, "test.txt"))
list.files(test_dir) |> print()

if (Sys.which("curl") != "") {
    # Without key - should fail
    system('curl -s "http://127.0.0.1:8291/test.txt" -o "output.txt"')
    fail_content <- tryCatch(
        readLines("output.txt", warn = FALSE),
        error = function(e) "ERROR"
    )
    cat("Without key response:", fail_content[1], "\n")
    expect_true(
        grepl("Unauthorized", fail_content[1]),
        "Should get auth error without key"
    )

    # With correct key - should work
    system('curl -s -H "X-API-Key: secret123" "http://127.0.0.1:8291/test.txt" -o "output.txt"')
    success_content <- tryCatch(
        readLines("output.txt", warn = FALSE),
        error = function(e) "ERROR"
    )
    cat("With key response:", success_content[1], "\n")
    # This is the expectation that was failing.
    # Let's make it more explicit.
    expect_equal(
        success_content[1],
        test_content,
        "Should get file content with the correct key"
    )
}

shutdownServer(server2)
Sys.sleep(0.5) # Give time for shutdown

# Verify server is no longer running
expect_false(isRunning(server2), "Auth server should not be running after shutdown")

unlink(file.path(test_dir, "test.txt"))
unlink("output.txt")
