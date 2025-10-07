library(goserveR)
if (requireNamespace("tinytest", quietly = TRUE)) {
  library(tinytest)
  Sys.setenv("CI" = "CI")
  tinytest::test_package("goserveR", at_home = FALSE, ncpu = 1)
}
