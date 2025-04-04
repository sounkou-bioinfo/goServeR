# Unit tests for goServeR package
library(testthat)
library(goserveR)

context("Parameter validation")

test_that("runServer validates directory parameter", {
    # Test non-existent directory
    expect_error(
        runServer(dir = "/path/that/does/not/exist", addr = "0.0.0.0:8181"),
        "dir.exists\\(dir\\) is not TRUE"
    )

    # Test invalid directory type - use a more general pattern to be resilient to message changes
    expect_error(
        runServer(dir = 123, addr = "0.0.0.0:8181"),
        "is.character\\(dir\\)"
    )
})

test_that("runServer validates address parameter", {
    # Test for valid address format
    expect_error(
        runServer(dir = getwd(), addr = "invalid_address"),
        "grepl\\(\"\\^\\[\\^:\\]\\+:\\[0-9\\]\\+\\$\", addr\\) is not TRUE"
    )

    # Test for invalid address type - simplify pattern
    expect_error(
        runServer(dir = getwd(), addr = c("0.0.0.0:8181", "localhost:8080")),
        "is.character\\(addr\\)"
    )
})

test_that("runServer validates prefix parameter", {
    # Test for invalid prefix type - simplify pattern
    expect_error(
        runServer(dir = getwd(), addr = "0.0.0.0:8181", prefix = c("/api", "/data")),
        "is.character\\(prefix\\)"
    )
})

# Skip actual server tests in automated testing
context("Server functionality")

test_that("Server starts and responds", {
    skip_on_cran()
    skip_on_ci()
    skip("Skip server test by default")

    # This test would actually start the server and make requests
    # Not suitable for automated testing, but useful for manual testing
})
