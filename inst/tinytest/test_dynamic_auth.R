# Test dynamic auth management functionality
library(tinytest)
library(goserveR)

# Create temp directories and files for testing
temp_dir <- tempdir()
test_file <- file.path(temp_dir, "test_auth.txt")
writeLines("Test content for auth", test_file)

# Test 1: Create server with auth system
server <- runServer(
    dir = temp_dir,
    addr = "127.0.0.1:8193",
    blocking = FALSE,
    auth = TRUE,
    initial_keys = c("test_key_1", "test_key_2", "secret_123")
)
expect_true(inherits(server, "externalptr"))

# Test 2: List initial auth keys
keys <- listAuthKeys(server)
expect_true(is.character(keys))
expect_equal(length(keys), 3)
expect_true("test_key_1" %in% keys)
expect_true("test_key_2" %in% keys)
expect_true("secret_123" %in% keys)

# Test 3: Remove auth key
expect_silent(removeAuthKey(server, "test_key_1"))
keys <- listAuthKeys(server)
expect_equal(length(keys), 2)
expect_false("test_key_1" %in% keys)
expect_true("test_key_2" %in% keys)
expect_true("secret_123" %in% keys)

# Test 4: Add a new auth key
expect_silent(addAuthKey(server, "new_dynamic_key"))
keys <- listAuthKeys(server)
expect_equal(length(keys), 3)
expect_true("new_dynamic_key" %in% keys)

# Test 5: Clear all keys
expect_silent(clearAuthKeys(server))
keys <- listAuthKeys(server)
expect_equal(length(keys), 0)

# Test 6: Add duplicate keys (should not error)
expect_silent(addAuthKey(server, "dup_key"))
expect_silent(addAuthKey(server, "dup_key")) # Adding same key again
keys <- listAuthKeys(server)
# Should only appear once due to C-level duplicate prevention
expect_equal(length(keys), 1)
expect_true("dup_key" %in% keys)

# Test 7: Remove non-existent key (should not error)
# Ensure server object is still valid before this test
expect_true(inherits(server, "externalptr"))
expect_silent(removeAuthKey(server, "non_existent_key"))

# Test 8: Error handling - invalid server handles
expect_error(addAuthKey("invalid", "key"))
expect_error(removeAuthKey("invalid", "key"))
expect_error(listAuthKeys("invalid"))
expect_error(clearAuthKeys("invalid"))

# Test 9: Error handling - missing parameters
expect_error(addAuthKey())
expect_error(removeAuthKey())
expect_error(listAuthKeys())
expect_error(clearAuthKeys())

# Test 10: Integration test - create server without auth, should error
server_no_auth <- runServer(
    dir = temp_dir,
    addr = "127.0.0.1:8194",
    blocking = FALSE,
    auth = FALSE
)
expect_error(addAuthKey(server_no_auth, "key"))
expect_error(listAuthKeys(server_no_auth))

# Clean up servers
shutdownServer(server)
shutdownServer(server_no_auth)

# Clean up
rm(server, server_no_auth, keys, temp_dir, test_file)
