library(goserveR)
library(tinytest)

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
data_content <- readLines("http://127.0.0.1:8801/data/test.txt")
expect_equal(
  data_content,
  "data content",
  info = "Data endpoint should return correct content"
)

# Test docs endpoint
docs_content <- readLines("http://127.0.0.1:8801/docs/info.txt")
expect_equal(
  docs_content,
  "docs content",
  info = "Docs endpoint should return correct content"
)

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
