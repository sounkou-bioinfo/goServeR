library(goserveR)
library(tinytest)

# Integration test for runServer
if (interactive() || !nzchar(Sys.getenv("CI"))) {
  tmp_dir <- tempdir()
  h <- runServer(dir = tmp_dir, addr = "127.0.0.1:9092", blocking = FALSE)
  expect_true(inherits(h, "externalptr"))
  shutdownServer(h)
}
