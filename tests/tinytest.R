library(goserveR)
library(tinytest)
if (requireNamespace("tinytest", quietly = TRUE)) {
  Sys.setenv("CI" = "CI")
  tinytest::test_package("goserveR", at_home = FALSE, ncpu = 1)
}
