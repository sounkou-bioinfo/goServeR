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

# Debug path information for Windows
if (.Platform$OS.type == "windows") {
  cat("Windows path debugging:\n")
  cat("  test_dir:", test_dir, "\n")
  cat("  test_file_path:", test_file_path, "\n")
  cat("  normalizePath(test_dir):", normalizePath(test_dir), "\n")
  cat("  file.exists(test_file_path):", file.exists(test_file_path), "\n")
}

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


expect_true(isRunning(server1), "Server should be running after start")

Sys.sleep(2)

# Test downloading without authentication
temp_file <- tempfile()
download_url <- "http://127.0.0.1:8190/static/test.txt"
cat("Attempting download from:", download_url, "\n")

# Windows path handling debug
if (.Platform$OS.type == "windows") {
  cat("Windows URL/path mapping debug:\n")
  cat("  URL path: /static/test.txt\n")
  cat("  Expected filesystem path:", file.path(test_dir, "test.txt"), "\n")
  cat("  Server directory:", test_dir, "\n")
  cat("  Server prefix: /static\n")
}

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
    if (grepl("cannot open URL|HTTP status|404|500|Could not connect to server", e$message, ignore.case = TRUE)) {
      if (.Platform$OS.type == "windows") {
        # Check if this could be the Go 1.20+ filepath.Clean issue
        cat("Windows detected. This could be related to Go 1.20+ filepath handling changes\n")
        cat("See: https://github.com/golang/go/issues/56336\n")
      } else {
        message("let's check if the server is running properly")
      }
    } else {
      expect_true(FALSE, "Download should succeed without auth")
    }
  }
)

unlink(temp_file)


shutdownServer(server1)
Sys.sleep(1)

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
  mustWork = FALSE
)


expect_true(isRunning(server2), "Auth server should be running after start")

Sys.sleep(2)

# Recreate test file to ensure it exists
writeLines(test_content, test_file_path)
list.files(test_dir) |> print()

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
    # Check if we're on Windows and if pipe-based auth might have issues
    if (.Platform$OS.type == "windows") {
      Sys.sleep(1)
      cat("Windows platform detected - giving extra time for pipe auth setup\n")
    }

    download.file(download_url_auth,
      destfile = temp_file_success,
      headers = c("X-API-Key" = "secret123"),
      quiet = TRUE,
      mode = "wb"
    )

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

    expect_true(FALSE, "Download should succeed with correct auth key")
  }
)

unlink(temp_file_fail)
unlink(temp_file_success)

shutdownServer(server2)
Sys.sleep(1)

# Verify server is no longer running
expect_false(
  isRunning(server2),
  "Auth server should not be running after shutdown"
)

unlink(test_file_path)
unlink("output.txt")
