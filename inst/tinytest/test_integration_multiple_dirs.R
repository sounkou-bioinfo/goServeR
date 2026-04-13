library(goserveR)
library(tinytest)

if (!requireNamespace("curl", quietly = TRUE)) {
  exit_file("curl package not available")
}

# Helper: fetch URL content with curl and timeout
curl_get <- function(url, timeout = 5) {
  h <- curl::new_handle()
  curl::handle_setopt(h, timeout = timeout, connecttimeout = timeout)
  tryCatch(
    {
      resp <- curl::curl_fetch_memory(url, handle = h)
      list(status = resp$status_code, content = rawToChar(resp$content), error = NULL)
    },
    error = function(e) {
      list(status = NULL, content = NULL, error = e$message)
    }
  )
}

cat("=== Simple Multiple Directory Integration Test ===\n")

# Create test structure
dirs <- c("test_simple_data", "test_simple_docs")
for (d in dirs) dir.create(d, showWarnings = FALSE)

writeLines("data content", "test_simple_data/test.txt")
writeLines("docs content", "test_simple_docs/info.txt")

# Test multiple directories
cat("Starting server with multiple directories...\n")
h <- runServer(
  dir = dirs,
  prefix = c("/data", "/docs"),
  addr = "127.0.0.1:8801",
  blocking = FALSE,
  silent = TRUE
)

# Give server time to start
Sys.sleep(1)

# Test endpoints
cat("Testing endpoints...\n")

# Test data endpoint
resp_data <- curl_get("http://127.0.0.1:8801/data/test.txt")
if (is.null(resp_data$error)) {
  expect_equal(
    trimws(resp_data$content),
    "data content",
    info = "Data endpoint should return correct content"
  )
} else {
  cat("HTTP error (data):", resp_data$error, "\n")
}

# Test docs endpoint
resp_docs <- curl_get("http://127.0.0.1:8801/docs/info.txt")
if (is.null(resp_docs$error)) {
  expect_equal(
    trimws(resp_docs$content),
    "docs content",
    info = "Docs endpoint should return correct content"
  )
} else {
  cat("HTTP error (docs):", resp_docs$error, "\n")
}

# Show server info
servers <- listServers()
cat("Server information:\n")
if (length(servers) > 0) {
  srv <- servers[[1]]
  cat("  Directories:", srv$directory, "\n")
  cat("  Prefixes:", srv$prefix, "\n")
  cat("  Address:", srv$address, "\n")
}

# Cleanup
cat("Shutting down server...\n")
shutdownServer(h)
Sys.sleep(0.5)

# Cleanup files
unlink(dirs, recursive = TRUE)

cat("=== Integration Test Completed ===\n")
