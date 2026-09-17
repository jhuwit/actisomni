if (rlang::is_installed("asleep") && rlang::is_installed("reticulate")) {
  try({
    asleep::py_require_asleep()
    reticulate::import("asleep")
  })
}
library(testthat)
library(actisomni)


test_check("actisomni")
