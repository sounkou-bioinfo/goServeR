library(goserveR)
library(tinytest)

# Integration test for runServer
tmp_dir <- tempdir()
h <- runServer(dir = tmp_dir, addr = "127.0.0.1:9092", blocking = FALSE, silent = TRUE)
expect_true(inherits(h, "externalptr"))
Sys.sleep(0.5)
shutdownServer(h)
Sys.sleep(0.5)
