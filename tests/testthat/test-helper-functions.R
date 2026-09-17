test_that("Tudor--Locke adapter accepts actisomni-style labelled epochs", {
  time <- as.POSIXct("2020-01-01", tz = "UTC") + 0:299 * 60
  epochs <- data.frame(time = time, activity = 0, sleep = TRUE)

  out <- acti_sleep_tudor_locke(epochs)
  expect_s3_class(out, "tbl_df")
  expect_named(out, c(
    "in_bed_time", "out_bed_time", "onset", "latency", "efficiency",
    "duration", "activity_counts", "nonzero_epochs", "total_sleep_time",
    "wake_after_onset", "nb_awakenings", "ave_awakening", "movement_index",
    "fragmentation_index", "sleep_fragmentation_index"
  ))
  expect_equal(out$duration, 300L)
  expect_equal(out$total_sleep_time, 300L)
  expect_equal(out$efficiency, 100)
})

test_that("Tudor--Locke adapter supports character labels and recordings", {
  time <- as.POSIXct("2020-01-01", tz = "UTC") + 0:179 * 60
  epochs <- data.frame(
    id = rep(c("one", "two"), each = 180),
    time = rep(time, 2), axis1 = 0,
    sleep = rep(c("wake", "sleep"), each = 180)
  )
  out <- acti_sleep_tudor_locke(
    epochs, activity_col = "axis1", id_col = "id", min_sleep_period = 160
  )
  expect_equal(out$id, "two")
  expect_equal(out$duration, 180L)
})

test_that("Tudor--Locke adapter derives multiple nights from a sleep diary", {
  # Eight days of 1-minute data stress the full multi-day delegation path.
  time <- as.POSIXct("2020-01-01", tz = "UTC") + 0:(8 * 24 * 60 - 1) * 60
  epochs <- data.frame(time = time, activity = 0)
  diary <- data.frame(
    onset = as.POSIXct("2020-01-01 22:00:00", tz = "UTC") + 0:6 * 24 * 60 * 60,
    wakeup = as.POSIXct("2020-01-02 06:00:00", tz = "UTC") + 0:6 * 24 * 60 * 60
  )
  labelled <- acti_sleep_tudor_locke_diary(epochs, diary)
  expect_true(all(labelled$sleep[labelled$time == diary$onset[1L]]))
  expect_false(any(labelled$sleep[labelled$time == diary$wakeup[1L]]))
  out <- acti_sleep_tudor_locke(labelled)
  expect_equal(nrow(out), 7L)
  expect_equal(out$total_sleep_time, rep(480L, 7L))
  expect_equal(out$onset, diary$onset)
})

test_that("Tudor--Locke adapter reports actionable input errors", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + c(0, 30),
    activity = c(0, 0), sleep = c(TRUE, TRUE)
  )
  expect_error(acti_sleep_tudor_locke(data), "60-second epochs")
  data$sleep <- c("sleep", "unknown")
  data$time <- as.POSIXct("2020-01-01", tz = "UTC") + c(0, 60)
  expect_error(acti_sleep_tudor_locke(data), "Sleep labels")
  expect_error(acti_sleep_tudor_locke_diary(data, data.frame()), "onset and wakeup")
})

test_that("actiread data can run through raw sleep preprocessing", {
  raw <- actiread::acti_read_gt3x(actiread::acti_example_gt3x(), verbose = FALSE)
  raw <- raw[seq_len(min(nrow(raw), 7200L)), ]
  out <- acti_sleep_sib(raw, epoch = "5 seconds")
  expect_true(nrow(out) > 0L)
  expect_named(out, c("time", "angle", "invalid", "sib"))
})
