test_that("acti_asleep validates input and harmonizes predictions", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 0:2,
    X = c(0, 0.1, 0.2), Y = c(0, 0.1, 0.2), Z = c(1, 1, 1)
  )
  testthat::local_mocked_bindings(
    asleep = function(file, ...) {
      expect_named(file, c("time", "X", "Y", "Z"))
      list(predictions = data.frame(
        time = c("2020-01-01 00:00:00", "2020-01-01 00:00:30"),
        sleep_wake = c("wake", "sleep"), sleep_stage = c("wake", "N2")
      ))
    },
    .package = "asleep"
  )

  out <- acti_asleep(data, verbose = FALSE)
  expect_s3_class(out, "acti_sleep_estimate")
  expect_named(out, c("time", "sleep", "sleep_probability", "sleep_stage", "nonwear", "method"))
  expect_equal(out$sleep, c(FALSE, TRUE))
  expect_true(all(is.na(out$sleep_probability)))
  expect_equal(out$method, rep("asleep", 2))
})

test_that("acti_asleep passes a readable file path through unchanged", {
  path <- tempfile(fileext = ".bin")
  file.create(path)
  testthat::local_mocked_bindings(
    asleep = function(file, ...) {
      expect_equal(file, path)
      list(predictions = data.frame(time = "2020-01-01 00:00:00", sleep_wake = "sleep"))
    },
    .package = "asleep"
  )
  out <- acti_asleep(path, verbose = FALSE)
  expect_s3_class(out, "acti_sleep_estimate")
  expect_true(out$sleep)
})

test_that("acti_asleep returns times in the input time zone", {
  data <- data.frame(
    time = as.POSIXct("2013-06-10 19:30:00", tz = "Europe/London") + 0:2,
    X = c(0, 0.1, 0.2), Y = c(0, 0.1, 0.2), Z = c(1, 1, 1)
  )
  testthat::local_mocked_bindings(
    # asleep reports naive local clock times
    asleep = function(file, ...) {
      list(predictions = data.frame(
        time = c("2013-06-10 19:30:00", "2013-06-10 19:30:30"),
        sleep_wake = c("wake", "sleep")
      ))
    },
    .package = "asleep"
  )

  out <- acti_asleep(data, verbose = FALSE)
  expect_equal(attr(out$time, "tzone"), "Europe/London")
  expect_equal(out$time[1], data$time[1])

  out <- acti_asleep(data, verbose = FALSE, tz = "UTC")
  expect_equal(attr(out$time, "tzone"), "UTC")
  expect_equal(format(out$time[1]), "2013-06-10 19:30:00")
})

test_that("acti_asleep uses tz for file input", {
  path <- tempfile(fileext = ".bin")
  file.create(path)
  testthat::local_mocked_bindings(
    asleep = function(file, ...) {
      list(predictions = data.frame(time = "2013-06-10 19:30:00",
                                    sleep_wake = "sleep"))
    },
    .package = "asleep"
  )
  expect_equal(attr(acti_asleep(path, verbose = FALSE)$time, "tzone"), "UTC")
  out <- acti_asleep(path, verbose = FALSE, tz = "Europe/London")
  expect_equal(out$time,
               as.POSIXct("2013-06-10 19:30:00", tz = "Europe/London"))
})

test_that("acti_sleeper supplies required input and harmonizes predictions", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 0:2,
    X = c(0, 0.1, 0.2), Y = c(0, 0.1, 0.2), Z = c(1, 1, 1)
  )
  model_dir <- tempfile()
  dir.create(model_dir)
  testthat::local_mocked_bindings(
    sl_have_models = function(model_dir) TRUE,
    estimate_sleep = function(data, epoch, model_dir) {
      expect_named(data, c("timestamp", "x", "y", "z"))
      expect_type(data$timestamp, "double")
      expect_equal(epoch, 30L)
      data.frame(
        time = c(1577836800, 1577836830, 1577836860),
        classification = c("Wake", "Sleep", "Nonwear")
      )
    },
    .package = "sleeper"
  )

  out <- acti_sleeper(data, model_dir = model_dir)
  expect_s3_class(out, "acti_sleep_estimate")
  expect_equal(out$sleep, c(FALSE, TRUE, FALSE))
  expect_equal(out$nonwear, c(FALSE, FALSE, TRUE))
  expect_true(all(is.na(out$sleep_stage)))
  expect_equal(out$method, rep("sleeper", 3))
})

test_that("acti_sleeper requires a complete model directory", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 0:2,
    X = c(0, 0.1, 0.2), Y = c(0, 0.1, 0.2), Z = c(1, 1, 1)
  )
  model_dir <- tempfile()
  dir.create(model_dir)
  testthat::local_mocked_bindings(
    sl_have_models = function(model_dir) FALSE,
    .package = "sleeper"
  )
  expect_error(acti_sleeper(data, model_dir = model_dir), "valid sleeper model")
})

test_that("py_acti_asleep calls the isolated asleep backend", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 0:2,
    X = c(0, 0.1, 0.2), Y = c(0, 0.1, 0.2), Z = c(1, 1, 1)
  )
  testthat::local_mocked_bindings(
    py_asleep = function(file, ...) {
      expect_named(file, c("time", "X", "Y", "Z"))
      list(predictions = data.frame(time = "2020-01-01 00:00:00", sleep_wake = "sleep"))
    },
    .package = "asleep"
  )
  out <- py_acti_asleep(data, verbose = FALSE)
  expect_s3_class(out, "acti_sleep_estimate")
  expect_true(out$sleep)
})

test_that("py_acti_sleeper calls the isolated sleeper backend", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + 0:2,
    X = c(0, 0.1, 0.2), Y = c(0, 0.1, 0.2), Z = c(1, 1, 1)
  )
  model_dir <- tempfile()
  dir.create(model_dir)
  testthat::local_mocked_bindings(
    sl_have_models = function(model_dir) TRUE,
    py_estimate_sleep = function(data, ...) {
      expect_named(data, c("timestamp", "x", "y", "z"))
      data.frame(time = 1577836800, classification = "Sleep")
    },
    .package = "sleeper"
  )
  out <- py_acti_sleeper(data, model_dir = model_dir)
  expect_s3_class(out, "acti_sleep_estimate")
  expect_true(out$sleep)
})

test_that("model wrappers reject incomplete or unordered acceleration data", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + c(1, 0),
    X = c(0, NA_real_), Y = c(0, 0), Z = c(1, 1)
  )
  expect_error(acti_asleep(data, verbose = FALSE), "complete")
  expect_error(acti_sleeper(data, model_dir = tempdir()), "complete")
})
