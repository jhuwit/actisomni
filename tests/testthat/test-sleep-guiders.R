test_that("HDCZA identifies a prolonged low-angle-change block", {
  angle <- c(seq(0, 40, length.out = 60), rep(40, 480),
             seq(40, 80, length.out = 60))
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + seq_along(angle) * 60,
    X = 1, Y = 0, Z = tan(angle * pi / 180)
  )
  out <- acti_sleep_hdcza(data, epoch = "1 minute")

  expect_s3_class(out, "acti_sleep_guider")
  expect_equal(out$method, "HDCZA")
  expect_true(sum(out$window) >= 450)
  expect_true(out$start_index > 1)
  expect_true(out$end_index < length(angle))
})

test_that("HDCZA derives its default threshold from the recording", {
  set.seed(1)
  angle <- c(cumsum(rnorm(720, sd = 3)), 40 + rnorm(2880, sd = 0.05),
             cumsum(rnorm(720, sd = 3)))
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + seq_along(angle) * 5,
    X = 1, Y = 0, Z = tan(angle * pi / 180)
  )
  default <- acti_sleep_hdcza(data, epoch = "5 seconds")
  expect_true(default$threshold >= 0.13 && default$threshold <= 0.5)
  expected <- min(max(stats::quantile(default$angle_change, 0.1,
                                      names = FALSE) * 15, 0.13), 0.5)
  expect_equal(default$threshold, expected)

  fixed <- acti_sleep_hdcza(data, epoch = "5 seconds", threshold = 0.2)
  expect_equal(fixed$threshold, 0.2)
  expect_error(acti_sleep_hdcza(data, threshold = c(10, 15)), "threshold")

  custom <- acti_sleep_hdcza(data, epoch = "5 seconds",
                             threshold_percentile = 20,
                             threshold_multiplier = 5)
  expected <- min(max(stats::quantile(custom$angle_change, 0.2,
                                      names = FALSE) * 5, 0.13), 0.5)
  expect_equal(custom$threshold, expected)

  # Proportions and fixed cutoffs passed as a percentile are rejected
  expect_error(acti_sleep_hdcza(data, threshold_percentile = 0.1),
               "threshold_percentile")
  expect_error(acti_sleep_hdcza(data, threshold_percentile = 150),
               "threshold_percentile")
  expect_error(acti_sleep_hdcza(data, threshold_multiplier = 0),
               "threshold_multiplier")
  expect_warning(
    acti_sleep_hdcza(data, epoch = "5 seconds", threshold = 0.2,
                     threshold_percentile = 20),
    "ignored"
  )
})

test_that("HDCZA rejects epochs too coarse for a five-minute window", {
  angle <- rep(40, 288)
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + seq_along(angle) * 300,
    X = 1, Y = 0, Z = tan(angle * pi / 180)
  )
  expect_error(acti_sleep_hdcza(data, epoch = "5 minutes"),
               "at least two angles")
  expect_error(acti_sleep_hdcza(data, epoch = "5 minutes", threshold = 0.2),
               "at least two angles")
})

test_that("HDCZA default matches GGIR's HASPT default", {
  skip_if_not_installed("GGIR")
  set.seed(2)
  angle <- c(cumsum(rnorm(1440, sd = 2)), 20 + cumsum(rnorm(4320, sd = 0.05)),
             cumsum(rnorm(1440, sd = 2)))
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + seq_along(angle) * 5,
    X = 1, Y = 0, Z = tan(angle * pi / 180)
  )
  out <- acti_sleep_hdcza(data, epoch = "5 seconds")
  params_sleep <- GGIR::load_params()$params_sleep
  ggir <- GGIR::HASPT(angle = out$epoch_data$angle, ws3 = 5,
                      HASPT.algo = "HDCZA",
                      invalid = rep(0, length(out$epoch_data$angle)),
                      params_sleep = params_sleep)
  expect_equal(out$start_index, ggir$SPTE_start)
  # GGIR pads the low-movement series before run-length encoding, so its
  # SPTE_end is the epoch after the last low-movement epoch of the block.
  expect_equal(out$end_index + 1, ggir$SPTE_end)
})

test_that("L5, fixed-window, and diary guiders identify expected windows", {
  activity <- c(rep(10, 120), rep(0, 300), rep(10, 1020))
  time <- as.POSIXct("2020-01-01 18:00:00", tz = "UTC") + 0:1439 * 60
  data <- data.frame(time = time, activity = activity)
  l5 <- acti_sleep_l5(data)
  expect_equal(l5$l5_start_index, 121)
  expect_equal(sum(l5$window), 720)

  fixed <- acti_sleep_setwindow(data, 22, 8)
  expect_equal(sum(fixed$window), 600)
  diary <- acti_sleep_diary(data, time[300], time[800])
  expect_equal(sum(diary$window), 501)
})

test_that("HLRB and NotWorn return a longest candidate window", {
  sib <- c(rep(FALSE, 120), rep(TRUE, 300), rep(FALSE, 120), rep(TRUE, 180))
  time <- as.POSIXct("2020-01-01", tz = "UTC") + seq_along(sib) * 60
  data <- data.frame(time = time, sib = sib)
  hlrb <- acti_sleep_hlrb(data)
  expect_true(sum(hlrb$window) > 0)

  activity <- c(rep(4, 120), rep(0, 300), rep(4, 120), rep(0, 180))
  notworn <- acti_sleep_notworn(data.frame(time = time, activity = activity))
  expect_equal(notworn$method, "NotWorn")
  expect_true(sum(notworn$window) > 0)
})

test_that("guiders return an empty window when no block is eligible", {
  angle <- rep(c(0, 10), length.out = 24 * 60)
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + seq_along(angle) * 60,
    X = 1, Y = 0, Z = tan(angle * pi / 180)
  )
  out <- acti_sleep_hdcza(data, epoch = "1 minute", threshold = 0.2)
  expect_false(any(out$window))
  expect_true(is.na(out$start_index))
})

test_that("the data-frame interface selects method-specific inputs", {
  time <- as.POSIXct("2020-01-01 00:00:00", tz = "UTC") + 0:599 * 60
  data <- data.frame(time = time, x = 1, y = 0,
                     z = tan(c(rep(0, 500), rep(10, 100)) * pi / 180),
                     activity = rep(0, 600), sib = rep(TRUE, 600))
  out <- acti_sleep_guider(data, "HDCZA", epoch = "1 minute", threshold = 0.2)

  expect_s3_class(out, "acti_sleep_guider")
  expect_equal(out$method, "HDCZA")
  requirements <- acti_sleep_guider_requirements()
  expect_true(requirements$raw_acceleration[requirements$method == "HDCZA"])
  expect_false(requirements$raw_acceleration[requirements$method == "L5"])
})

test_that("guiders convert SIBs to sleep labels under both overlap rules", {
  guider <- structure(list(window = c(FALSE, TRUE, TRUE, FALSE, FALSE)),
                      class = "acti_sleep_guider")
  sib <- c(FALSE, TRUE, TRUE, TRUE, FALSE)
  expect_equal(acti_sleep_label(sib, guider, "SPT"), sib)
  expect_equal(acti_sleep_label(sib, guider, "TimeInBed"), rep(FALSE, 5))
})

test_that("multiple guider labels can be fused with STAPLE", {
  guider1 <- structure(list(method = "one", window = c(FALSE, TRUE, TRUE, FALSE)),
                       class = "acti_sleep_guider")
  guider2 <- structure(list(method = "two", window = c(FALSE, TRUE, FALSE, FALSE)),
                       class = "acti_sleep_guider")
  labels <- acti_sleep_labels(c(FALSE, TRUE, TRUE, FALSE),
                              list(one = guider1, two = guider2))
  fused <- acti_sleep_fuse_labels(labels)
  expect_named(labels, c("sleep_one", "sleep_two"))
  expect_s3_class(fused, "tbl_df")
  expect_true(all(fused$sleep_probability >= 0 & fused$sleep_probability <= 1))
  expect_true(!is.null(attr(fused, "staple")))
})

test_that("SIB and ensemble workflows operate on raw data", {
  angle <- rep(c(20, 30), length.out = 24 * 60 * 60 / 5)
  raw <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + seq_along(angle) * 5,
    X = 1, Y = 0, Z = tan(angle * pi / 180)
  )
  sib <- acti_sleep_sib(raw, epoch = "5 seconds")
  expect_named(sib, c("time", "angle", "invalid", "sib"))
  ensemble <- acti_sleep_ensemble(raw, epoch = "5 seconds",
                                  guiders = c("HDCZA", "HorAngle", "L5"))
  expect_s3_class(ensemble$labels, "tbl_df")
  expect_true(all(c("sleep_probability", "sleep") %in% names(ensemble$fused)))
  expect_true(all(c("time", "sleep_HDCZA", "sleep_HorAngle", "sleep_L5") %in%
    names(ensemble$labels)))
  expect_true("time" %in% names(ensemble$fused))
  expect_true("time" %in% names(ensemble$guiders$HDCZA$label_data))
  expect_true(all(c("time", "sib", "sleep_HDCZA", "sleep_HorAngle",
                    "sleep_L5", "sleep_probability", "sleep") %in%
    names(ensemble$label_data)))
})

test_that("ensemble defaults omit L5 for recordings shorter than five hours", {
  raw <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + seq(0, 40 * 60, by = 5),
    X = 1, Y = 0, Z = 0
  )
  ensemble <- acti_sleep_ensemble(raw, epoch = "5 seconds")
  expect_setequal(names(ensemble$guiders), c("HDCZA", "HorAngle", "setwindow"))
})
