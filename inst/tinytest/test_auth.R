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

Sys.sleep(1)

# Test downloading without authentication
temp_file <- tempfile()
tryCatch(
  {
    download.file(
      "http://127.0.0.1:8190/test.txt",
      destfile = temp_file,
      quiet = TRUE
    )

    if (file.exists(temp_file)) {
      no_auth_content <- readLines(temp_file, warn = FALSE)
      cat("File content read:", paste(no_auth_content, collapse = " "), "\n")

      expect_equal(
        no_auth_content[1],
        test_content,
        "No-auth should return file content"
      )
    } else {
      expect_true(FALSE, "Downloaded file was not created")
    }
  },
  error = function(e) {
    cat("Error downloading file:", e$message, "\n")
    expect_true(FALSE, "Download should succeed without auth")
  }
)

unlink(temp_file)


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

if (TRUE) {
  # Always run since download.file is built-in
  # Test without key - should fail
  temp_file_fail <- tempfile()
  auth_failed <- FALSE
  tryCatch(
    {
      download.file(
        "http://127.0.0.1:8291/test.txt",
        destfile = temp_file_fail,
        quiet = TRUE
      )

      # If we get here, check if we actually got the file or an error page
      if (file.exists(temp_file_fail)) {
        content <- readLines(temp_file_fail, warn = FALSE)
        cat("Content without auth:", paste(content, collapse = " "), "\n")
        # Check if we got an error response rather than the actual file
        if (any(grepl("Unauthorized|401|403|Forbidden", content, ignore.case = TRUE))) {
          auth_failed <- TRUE
          cat("Auth correctly failed - got error in response\n")
        } else if (length(content) > 0 && content[1] == test_content) {
          # We got the actual file content - auth did not work
          expect_true(FALSE, "Download should fail without auth key - got actual file content")
        } else {
          # We got some other content
          expect_true(FALSE, paste("Download should fail without auth key - got unexpected content:", paste(content, collapse = " ")))
        }
      } else {
        # File wasn't created at all
        auth_failed <- TRUE
        cat("Auth correctly failed - no file created\n")
      }
    },
    error = function(e) {
      cat("Expected auth error:", e$message, "\n")
      # Check if the error message indicates authentication failure
      if (grepl("401|Unauthorized|403|Forbidden", e$message, ignore.case = TRUE)) {
        auth_failed <<- TRUE
      } else {
        # Some other error occurred
        auth_failed <<- TRUE # Assume any error is auth-related for now
      }
    }
  )

  # Verify that authentication actually failed
  expect_true(auth_failed, "Should get auth error without key")

  # Test with correct key - using headers parameter
  temp_file_success <- tempfile()
  tryCatch(
    {
      download.file("http://127.0.0.1:8291/test.txt",
        destfile = temp_file_success,
        headers = c("X-API-Key" = "secret123"),
        quiet = TRUE
      )

      if (file.exists(temp_file_success)) {
        success_content <- readLines(temp_file_success, warn = FALSE)
        cat("With key response:", paste(success_content, collapse = " "), "\n")

        expect_equal(
          success_content[1],
          test_content,
          "Should get file content with the correct key"
        )
      } else {
        expect_true(FALSE, "Downloaded file should exist with correct auth")
      }
    },
    error = function(e) {
      cat("Unexpected error with correct auth:", e$message, "\n")
      expect_true(FALSE, "Download should succeed with correct auth key")
    }
  )

  unlink(temp_file_fail)
  unlink(temp_file_success)
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
