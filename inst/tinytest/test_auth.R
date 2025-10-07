# Test API key authentication functionality
library(goserveR)
library(tinytest)


# Setup test directory and file
# Use tempdir() directly to ensure we have a directory that works cross-platform.
test_dir <- tempdir()
# On Windows, normalize path separators to be consistent
if (.Platform$OS.type == "windows") {
  test_dir <- normalizePath(test_dir, winslash = "/")
}
print(paste("Test directory:", test_dir))
print(paste("Directory exists:", dir.exists(test_dir)))
print(paste("Directory readable:", file.access(test_dir, 4) == 0))
print(paste("Directory writable:", file.access(test_dir, 2) == 0))
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
  mustWork = FALSE # Don't force failure, let test handle it
)

# Verify server is running
if (!isRunning(server1)) {
  skip(
    "Server failed to start - possibly due to port conflicts or permissions on this platform"
  )
}
expect_true(isRunning(server1), "Server should be running after start")
# Helper function to wait for a server to be responsive

# Test HTTP requests - use R's built-in capabilities if curl fails
# Skip HTTP tests on Windows CI due to curl/networking issues
if (Sys.which("curl") != "" && !(.Platform$OS.type == "windows" && nzchar(Sys.getenv("CI")))) {
  # Add a small delay to ensure server is fully started
  Sys.sleep(1)

  # Check if curl command succeeds
  curl_result <- system('curl -s "http://127.0.0.1:8190/test.txt" -o "output.txt"',
    intern = FALSE, ignore.stdout = TRUE, ignore.stderr = TRUE
  )
  cat("Curl exit code:", curl_result, "\n")

  if (file.exists("output.txt")) {
    no_auth_content <- tryCatch(
      readLines("output.txt", warn = FALSE),
      error = function(e) {
        cat("Error reading output.txt:", e$message, "\n")
        "ERROR"
      }
    )
    cat("File content read:", paste(no_auth_content, collapse = " "), "\n")
  } else {
    cat("output.txt file was not created\n")
    no_auth_content <- "ERROR"
  }

  expect_true(
    length(no_auth_content) > 0 && no_auth_content[1] == test_content,
    "No-auth should return file content"
  )
} else {
  # Skip HTTP tests if curl is not available or on Windows CI
  cat("Skipping HTTP tests (curl not available or Windows CI)\n")
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
  mustWork = FALSE # Don't force failure
)

# Verify server is running
if (!isRunning(server2)) {
  shutdownServer(server1) # Clean up first server
  skip(
    "Auth server failed to start - possibly due to port conflicts or permissions on this platform"
  )
}
expect_true(isRunning(server2), "Auth server should be running after start")

Sys.sleep(1) # Give server time to start
# create test file
writeLines(test_content, file.path(test_dir, "test.txt"))
list.files(test_dir) |> print()

if (Sys.which("curl") != "" && !(.Platform$OS.type == "windows" && nzchar(Sys.getenv("CI")))) {
  # Without key - should fail
  curl_result1 <- system('curl -s "http://127.0.0.1:8291/test.txt" -o "output.txt"',
    intern = FALSE, ignore.stdout = TRUE, ignore.stderr = TRUE
  )
  cat("Curl exit code (no auth):", curl_result1, "
")

  if (file.exists("output.txt")) {
    fail_content <- tryCatch(
      readLines("output.txt", warn = FALSE),
      error = function(e) {
        cat("Error reading output.txt (no auth):", e$message, "
")
        "ERROR"
      }
    )
  } else {
    cat("output.txt file was not created (no auth)
")
    fail_content <- "ERROR"
  }

  cat("Without key response:", paste(fail_content, collapse = " "), "
")
  expect_true(
    grepl("Unauthorized", fail_content[1]),
    "Should get auth error without key"
  )

  # With correct key - should work
  curl_result2 <- system(
    'curl -s -H "X-API-Key: secret123" "http://127.0.0.1:8291/test.txt" -o "output.txt"',
    intern = FALSE, ignore.stdout = TRUE, ignore.stderr = TRUE
  )
  cat("Curl exit code (with auth):", curl_result2, "
")

  if (file.exists("output.txt")) {
    success_content <- tryCatch(
      readLines("output.txt", warn = FALSE),
      error = function(e) {
        cat("Error reading output.txt (with auth):", e$message, "
")
        "ERROR"
      }
    )
  } else {
    cat("output.txt file was not created (with auth)
")
    success_content <- "ERROR"
  }

  cat("With key response:", paste(success_content, collapse = " "), "
")
  # This is the expectation that was failing.
  # Let's make it more explicit.
  expect_equal(
    success_content[1],
    test_content,
    "Should get file content with the correct key"
  )
} else {
  # Skip HTTP tests if curl is not available or on Windows CI
  cat("Skipping HTTP auth tests (curl not available or Windows CI)
")
}

shutdownServer(server2)
Sys.sleep(0.5) # Give time for shutdown

# Verify server is no longer running
expect_false(
  isRunning(server2),
  "Auth server should not be running after shutdown"
)

unlink(file.path(test_dir, "test.txt"))
unlink("output.txt")
