library(goserveR)
if (requireNamespace("tinytest", quietly = TRUE)) {
  # Sys.setenv("CI" = "CI")
  library(tinytest)
  test_package("goserveR", at_home = FALSE, ncpu = NULL)
}
