test_that("actiread data can run through raw sleep preprocessing", {
  raw <- actiread::acti_read_gt3x(actiread::acti_example_gt3x(), verbose = FALSE)
  raw <- raw[seq_len(min(nrow(raw), 7200L)), ]
  out <- acti_sleep_sib(raw, epoch = "5 seconds")
  expect_true(nrow(out) > 0L)
  expect_named(out, c("time", "angle", "invalid", "sib"))
})
