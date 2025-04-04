# Integration tests for goServeR package
library(testthat)
library(goserveR)

context("Integration tests")

test_that("Server can serve files", {
    skip_on_cran()
    skip_on_ci()
    skip("Skip integration test by default")

    # Create a temporary directory with a test file
    tmp_dir <- tempfile("goserver-test-")
    dir.create(tmp_dir)
    test_file <- file.path(tmp_dir, "test.txt")
    cat("Test content", file = test_file)

    # Start a test server
    server <- start_test_server(dir = tmp_dir, addr = "127.0.0.1:9090")
    on.exit(server$kill(), add = TRUE)

    # Make a request to the server
    response <- make_test_request(server, "/test.txt")
    expect_false(is.null(response))

    if (!is.null(response)) {
        expect_equal(httr::status_code(response), 200)
        expect_equal(httr::content(response, as = "text"), "Test content")

        # Check CORS headers
        headers <- httr::headers(response)
        expect_equal(headers$`access-control-allow-origin`, "*")
    }

    # Clean up
    unlink(tmp_dir, recursive = TRUE)
})

test_that("Server handles prefixes correctly", {
    skip_on_cran()
    skip_on_ci()
    skip("Skip integration test by default")

    # Create a temporary directory with a test file
    tmp_dir <- tempfile("goserver-test-")
    dir.create(tmp_dir)
    test_file <- file.path(tmp_dir, "test.txt")
    cat("Test content with prefix", file = test_file)

    # Start a test server with a prefix
    server <- start_test_server(dir = tmp_dir, addr = "127.0.0.1:9091", prefix = "/api")
    on.exit(server$kill(), add = TRUE)

    # Make a request to the server with the prefix
    response <- make_test_request(server, "/api/test.txt")
    expect_false(is.null(response))

    if (!is.null(response)) {
        expect_equal(httr::status_code(response), 200)
        expect_equal(httr::content(response, as = "text"), "Test content with prefix")
    }

    # Clean up
    unlink(tmp_dir, recursive = TRUE)
})
