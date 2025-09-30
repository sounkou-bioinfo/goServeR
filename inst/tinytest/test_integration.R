library(goserveR)
library(tinytest)

# Integration test (manual/skip on CI)
if (interactive() || !nzchar(Sys.getenv("CI"))) {
    tmp_dir <- tempfile("goserver-test-")
    dir.create(tmp_dir)
    test_file <- file.path(tmp_dir, "test.txt")
    cat("Test content", file = test_file)

    h <- runServer(dir = tmp_dir, addr = "127.0.0.1:9092", blocking = FALSE)
    expect_true(inherits(h, "externalptr"))
    Sys.sleep(1)
    shutdownServer(h)
    unlink(tmp_dir, recursive = TRUE)
}
