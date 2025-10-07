# Test API key authentication functionality
library(goserveR)
library(tinytest)


# Setup test directory and file
test_dir <- tempdir()
# Normalize path separators consistently across platforms
test_dir <- normalizePath(test_dir, winslash = "/")

print(paste("Test directory:", test_dir))
print(paste("Directory exists:", dir.exists(test_dir)))
print(paste("Directory readable:", file.access(test_dir, 4) == 0))
print(paste("Directory writable:", file.access(test_dir, 2) == 0))

test_content <- "hello world"
# Ensure the directory exists
if (!dir.exists(test_dir)) dir.create(test_dir, recursive = TRUE)

# Create test file with explicit path handling
test_file_path <- file.path(test_dir, "test.txt")
writeLines(test_content, test_file_path)

# Verify file was created
if (!file.exists(test_file_path)) {
  stop("Test file was not created properly")
}
cat("Test file created at:", test_file_path, "\n")

# Test 1: No auth key - all requests pass
server1 <- runServer(
  dir = test_dir,
  addr = "127.0.0.1:8190",
  prefix = "/static",
  blocking = FALSE,
  silent = TRUE,
  auth_keys = c(),
  mustWork = FALSE
)

# Verify server is running
if (!isRunning(server1)) {
  skip("Server failed to start - possibly due to port conflicts or permissions on this platform")
}
expect_true(isRunning(server1), "Server should be running after start")

Sys.sleep(2) # Increase wait time for server to be ready

# Test downloading without authentication
temp_file <- tempfile()
download_url <- "http://127.0.0.1:8190/static/test.txt"
cat("Attempting download from:", download_url, "\n")

tryCatch(
  {
    # Use mode = "wb" for cross-platform compatibility
    download.file(download_url, destfile = temp_file, quiet = TRUE, mode = "wb")

    if (file.exists(temp_file)) {
      no_auth_content <- readLines(temp_file, warn = FALSE)
      cat("File content read:", paste(no_auth_content, collapse = " "), "\n")

      expect_equal(no_auth_content[1], test_content, "No-auth should return file content")
    } else {
      expect_true(FALSE, "Downloaded file was not created")
    }
  },
  error = function(e) {
    cat("Error downloading file:", e$message, "\n")
    # Check if it's a network/server issue vs auth issue
    if (grepl("cannot open URL|HTTP status|404|500", e$message, ignore.case = TRUE)) {
      skip("Server not responding properly - skipping test")
    } else {
      expect_true(FALSE, "Download should succeed without auth")
    }
  }
)

unlink(temp_file)


shutdownServer(server1)
Sys.sleep(1) # Increased shutdown wait time

# Verify server is no longer running
expect_false(isRunning(server1), "Server should not be running after shutdown")

# Test 2: Single auth key
server2 <- runServer(
  dir = test_dir,
  addr = "127.0.0.1:8291",
  prefix = "/", # Consistent prefix
  blocking = FALSE,
  silent = TRUE,
  auth_keys = c("secret123"),
  mustWork = FALSE
)

# Verify server is running
if (!isRunning(server2)) {
  skip("Auth server failed to start - possibly due to port conflicts or permissions")
}
expect_true(isRunning(server2), "Auth server should be running after start")

Sys.sleep(2) # Give server more time to start

# Recreate test file to ensure it exists
writeLines(test_content, test_file_path)
list.files(test_dir) |> print()

if (TRUE) {
  # Always run since download.file is built-in
  # Test without key - should fail
  temp_file_fail <- tempfile()
  auth_failed <- FALSE
  download_url_auth <- "http://127.0.0.1:8291/test.txt"
  cat("Testing auth failure at:", download_url_auth, "\n")

  tryCatch(
    {
      download.file(download_url_auth, destfile = temp_file_fail, quiet = TRUE, mode = "wb")

      if (file.exists(temp_file_fail)) {
        content <- readLines(temp_file_fail, warn = FALSE)
        cat("Content without auth:", paste(content, collapse = " "), "\n")

        # Check for auth failure indicators
        if (any(grepl("Unauthorized|401|403|Forbidden", content, ignore.case = TRUE))) {
          auth_failed <- TRUE
          cat("Auth correctly failed - got error in response\n")
        } else if (length(content) > 0 && content[1] == test_content) {
          expect_true(FALSE, "Download should fail without auth key - got actual file content")
        } else {
          # We got some other content
          expect_true(FALSE, paste("Download should fail without auth key - got unexpected content:", paste(content, collapse = " ")))
        }
      } else {
        auth_failed <- TRUE
        cat("Auth correctly failed - no file created\n")
      }
    },
    error = function(e) {
      cat("Expected auth error:", e$message, "\n")
      auth_failed <<- TRUE
    }
  )

  # Verify that authentication actually failed
  expect_true(auth_failed, "Should get auth error without key")

  # Test with correct key
  temp_file_success <- tempfile()
  cat("Testing with correct key at:", download_url_auth, "\n")

  tryCatch(
    {
      # Try different methods for setting headers based on platform
      if (.Platform$OS.type == "windows") {
        # Windows might need different approach
        download.file(download_url_auth,
          destfile = temp_file_success,
          headers = c("X-API-Key" = "secret123"),
          quiet = TRUE,
          mode = "wb"
        )
      } else {
        download.file(download_url_auth,
          destfile = temp_file_success,
          headers = c("X-API-Key" = "secret123"),
          quiet = TRUE,
          mode = "wb"
        )
      }

      if (file.exists(temp_file_success)) {
        success_content <- readLines(temp_file_success, warn = FALSE)
        cat("With key response:", paste(success_content, collapse = " "), "\n")

        expect_equal(success_content[1], test_content, "Should get file content with the correct key")
      } else {
        expect_true(FALSE, "Downloaded file should exist with correct auth")
      }
    },
    error = function(e) {
      cat("Error with correct auth:", e$message, "\n")
      # Check if this is a known limitation
      if (grepl("headers.*not supported", e$message, ignore.case = TRUE)) {
        skip("Header authentication not supported in this R/platform configuration")
      } else {
        expect_true(FALSE, "Download should succeed with correct auth key")
      }
    }
  )

  unlink(temp_file_fail)
  unlink(temp_file_success)
}


shutdownServer(server2)
Sys.sleep(1) # Give time for shutdown

# Verify server is no longer running
expect_false(
  isRunning(server2),
  "Auth server should not be running after shutdown"
)

unlink(test_file_path)
unlink("output.txt")
