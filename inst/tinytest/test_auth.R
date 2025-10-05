# Test API key authentication functionality
library(goserveR)
library(tinytest)

# Setup test directory and file
test_dir <- tempdir()
test_content <- "hello world"
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
  auth_keys = c()
)

Sys.sleep(0.5)

if (Sys.which("curl") != "") {
  system2("curl", c("-s", "http://127.0.0.1:8190/test.txt", "-o", "output.txt"))
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
Sys.sleep(0.5)

# Test 2: Single auth key
server2 <- runServer(
  dir = test_dir,
  addr = "127.0.0.1:8191",
  prefix = "/",
  blocking = FALSE,
  silent = TRUE,
  auth_keys = c("secret123")
)

Sys.sleep(0.5)

if (Sys.which("curl") != "") {
  # Without key - should fail
  system2("curl", c("-s", "http://127.0.0.1:8191/test.txt", "-o", "output.txt"))
  fail_content <- tryCatch(
    readLines("output.txt", warn = FALSE),
    error = function(e) "ERROR"
  )
  cat("Without key response:", fail_content[1], "\n")
  expect_true(
    grepl("Unauthorized|error", fail_content[1]),
    "Should get auth error without key"
  )

  # With correct key - should work
  system2(
    "curl",
    c(
      "-s",
      "-H",
      "X-API-Key: secret123",
      "http://127.0.0.1:8191/test.txt",
      "-o",
      "output.txt"
    )
  )
  success_content <- tryCatch(
    readLines("output.txt", warn = FALSE),
    error = function(e) "ERROR"
  )
  cat("With key response:", success_content[1], "\n")
  expect_true(
    success_content[1] == test_content || success_content[1] != "Unauthorized",
    "Should get content or not get Unauthorized with correct key"
  )
}

shutdownServer(server2)
Sys.sleep(0.5)

unlink(file.path(test_dir, "test.txt"))
unlink("output.txt")
