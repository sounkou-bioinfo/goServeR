library(goserveR)
library(tinytest)

# Multiple directory serving functionality
if (interactive() || !nzchar(Sys.getenv("CI"))) {
  cat("=== Multiple Directory Serving Tests ===\n")

  # Create test directories and files
  test_dirs <- c(
    "test_multidir_data",
    "test_multidir_docs",
    "test_multidir_files"
  )
  test_files <- list(
    "test_multidir_data/data.txt",
    "test_multidir_docs/readme.txt",
    "test_multidir_files/config.txt"
  )
  test_contents <- list(
    "This is test data content",
    "This is documentation content",
    "This is configuration content"
  )

  # Setup test environment
  tryCatch(
    {
      for (dir in test_dirs) {
        dir.create(dir, showWarnings = FALSE, recursive = TRUE)
      }
      for (i in seq_along(test_files)) {
        writeLines(test_contents[[i]], test_files[[i]])
      }
    },
    error = function(e) {
      cat("Setup error:", e$message, "\n")
    }
  )

  # Test 1: Backward compatibility - single directory
  cat("1. Testing backward compatibility (single directory)...\n")

  h1 <- runServer(
    dir = ".",
    prefix = "/root",
    addr = "127.0.0.1:8701",
    blocking = FALSE,
    silent = TRUE
  )
  expect_true(
    inherits(h1, "externalptr"),
    info = "Single dir server handle should be external pointer"
  )
  Sys.sleep(0.5)

  servers <- tryCatch(listServers(), error = function(e) list())
  expect_true(
    length(servers) >= 1,
    info = "Single dir server should be running"
  )

  shutdownServer(h1)
  Sys.sleep(0.5)
  cat("   ✓ Backward compatibility test completed\n")

  # Test 2: Multiple directories serving
  cat("2. Testing multiple directories serving...\n")

  h2 <- runServer(
    dir = test_dirs,
    prefix = c("/api/data", "/docs", "/files"),
    addr = "127.0.0.1:8702",
    blocking = FALSE,
    silent = TRUE
  )
  expect_true(
    inherits(h2, "externalptr"),
    info = "Multi dir server handle should be external pointer"
  )
  Sys.sleep(0.5)

  servers <- tryCatch(listServers(), error = function(e) list())
  expect_true(length(servers) >= 1, info = "Multi dir server should be running")

  # Test that server info shows multiple directories
  if (length(servers) > 0) {
    server_info <- servers[[length(servers)]] # Get the last (most recent) server
    expect_true(
      grepl(",", server_info$directory),
      info = "Server info should show multiple directories"
    )
    expect_true(
      grepl(",", server_info$prefix),
      info = "Server info should show multiple prefixes"
    )
  }

  shutdownServer(h2)
  Sys.sleep(0.5)
  cat("   ✓ Multiple directories test completed\n")

  # Test 3: Mixed directory types (relative and absolute paths)
  cat("3. Testing mixed directory types...\n")

  # Get absolute path for one directory
  abs_dir <- normalizePath(test_dirs[1])

  h3 <- runServer(
    dir = c(abs_dir, test_dirs[2]), # Mix absolute and relative
    prefix = c("/abs", "/rel"),
    addr = "127.0.0.1:8703",
    blocking = FALSE,
    silent = TRUE
  )
  expect_true(
    inherits(h3, "externalptr"),
    info = "Mixed paths server handle should be external pointer"
  )
  Sys.sleep(0.5)

  shutdownServer(h3)
  Sys.sleep(0.5)
  cat("   ✓ Mixed directory types test completed\n")

  # Test 4: Validation errors for multiple directories
  cat("4. Testing validation errors...\n")

  # Mismatched lengths
  expect_error(
    runServer(
      dir = c(".", test_dirs[1]),
      prefix = c("/root"), # Only one prefix for two directories
      addr = "127.0.0.1:8704",
      blocking = FALSE
    ),
    info = "Should error when dir and prefix have different lengths"
  )

  # Non-existent directory in vector
  expect_error(
    runServer(
      dir = c(".", "/nonexistent/directory"),
      prefix = c("/root", "/fake"),
      addr = "127.0.0.1:8705",
      blocking = FALSE
    ),
    info = "Should error when one directory doesn't exist"
  )

  cat("   ✓ Validation errors test completed\n")

  # Test 5: Edge cases
  cat("5. Testing edge cases...\n")

  # Single directory with vector input (length 1)
  h5 <- runServer(
    dir = c("."), # Vector of length 1
    prefix = c("/single"),
    addr = "127.0.0.1:8706",
    blocking = FALSE,
    silent = TRUE
  )
  expect_true(
    inherits(h5, "externalptr"),
    info = "Single element vector should work"
  )
  Sys.sleep(0.5)
  shutdownServer(h5)
  Sys.sleep(0.5)

  # Root prefix handling
  h6 <- runServer(
    dir = c(test_dirs[1], test_dirs[2]),
    prefix = c("/", "/docs"), # One root prefix
    addr = "127.0.0.1:8707",
    blocking = FALSE,
    silent = TRUE
  )
  expect_true(
    inherits(h6, "externalptr"),
    info = "Root prefix should work in multi-dir setup"
  )
  Sys.sleep(0.5)
  shutdownServer(h6)
  Sys.sleep(0.5)

  cat("   ✓ Edge cases test completed\n")

  # Test 6: Multiple directories with different configurations
  cat("6. Testing multiple directories with configurations...\n")

  # Test with CORS and COOP enabled
  h7 <- runServer(
    dir = test_dirs,
    prefix = c("/data", "/docs", "/files"),
    addr = "127.0.0.1:8708",
    blocking = FALSE,
    cors = TRUE,
    coop = TRUE,
    silent = TRUE
  )
  expect_true(
    inherits(h7, "externalptr"),
    info = "Multi dir with CORS/COOP should work"
  )
  Sys.sleep(0.5)
  shutdownServer(h7)
  Sys.sleep(0.5)

  cat("   ✓ Configuration test completed\n")

  # Test 7: Concurrent multiple directory servers
  cat("7. Testing concurrent multiple directory servers...\n")

  # Start two servers serving different directory sets
  h8a <- runServer(
    dir = test_dirs[1:2],
    prefix = c("/set1/data", "/set1/docs"),
    addr = "127.0.0.1:8709",
    blocking = FALSE,
    silent = TRUE
  )
  Sys.sleep(0.3)

  h8b <- runServer(
    dir = test_dirs[2:3],
    prefix = c("/set2/docs", "/set2/files"),
    addr = "127.0.0.1:8710",
    blocking = FALSE,
    silent = TRUE
  )
  Sys.sleep(0.5)

  servers <- tryCatch(listServers(), error = function(e) list())
  expect_true(
    length(servers) >= 2,
    info = "Should have multiple concurrent servers"
  )

  shutdownServer(h8a)
  shutdownServer(h8b)
  Sys.sleep(0.5)

  cat("   ✓ Concurrent servers test completed\n")

  # Cleanup test environment
  cat("8. Cleaning up test environment...\n")

  tryCatch(
    {
      for (file in test_files) {
        if (file.exists(file)) unlink(file)
      }
      for (dir in test_dirs) {
        if (dir.exists(dir)) unlink(dir, recursive = TRUE)
      }
    },
    error = function(e) {
      cat("Cleanup error:", e$message, "\n")
    }
  )

  # Final server check
  final_servers <- tryCatch(listServers(), error = function(e) list())
  cat("   Final server count:", length(final_servers), "\n")

  cat("=== Multiple Directory Tests Completed Successfully! ===\n")
} else {
  cat("Skipping multiple directory tests on CI environment\n")
}
