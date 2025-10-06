library(goserveR)
if (requireNamespace("tinytest", quietly = TRUE)) {
  Sys.setenv("CI" = "CI")
  tinytest::test_package("goserveR", at_home = FALSE)
}
