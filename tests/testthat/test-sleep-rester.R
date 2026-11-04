# Mock rester output: one 30-second epoch per input row (or `n` epochs),
# starting at the first time it is given, as rester formats predictions
rester_predictions <- function(start, stages, model = "lstm_sleepstages") {
  labels <- c("deep", "light", "rem", "wake")
  probs <- t(vapply(stages, function(stage) {
    if (is.na(stage)) return(rep(NA_real_, 4))
    p <- rep(0.1, 4)
    p[labels == stage] <- 0.7
    p
  }, numeric(4)))
  colnames(probs) <- paste0("prob_", labels)
  pred <- dplyr::bind_cols(
    tibble::tibble(epoch = seq_along(stages),
                   time = start + (seq_along(stages) - 1) * 30),
    tibble::as_tibble(probs),
    tibble::tibble(prediction = factor(stages, levels = labels))
  )
  out <- stats::setNames(list(pred), model)
  attr(out, "info") <- list(ResampleRate = 30)
  out
}

rester_data <- function(start = "2020-01-01", tz = "UTC", n = 4) {
  data <- data.frame(
    time = as.POSIXct(start, tz = tz) + (seq_len(n) - 1) * 30,
    X = 0, Y = 0, Z = 1
  )
  attr(data, "sample_rate") <- 1 / 30
  data
}

test_that("acti_rester harmonizes sleep-stage predictions", {
  data <- rester_data()
  seen <- NULL
  testthat::local_mocked_bindings(
    estimate_rest = function(file, model, ...) {
      seen <<- list(file = file, model = model, dots = list(...))
      rester_predictions(file$time[1], c("wake", "light", "deep", NA, "rem"))
    },
    .package = "rester"
  )

  out <- acti_rester(data, cache_dir = tempdir())
  expect_s3_class(out, "acti_sleep_estimate")
  expect_named(out, c("time", "sleep", "sleep_probability", "sleep_stage",
                      "nonwear", "method"))
  expect_equal(seen$model, "lstm_sleepstages")
  expect_named(seen$file, c("time", "X", "Y", "Z"))
  expect_equal(attr(seen$file, "sample_rate"), 1 / 30)
  expect_equal(out$sleep, c(FALSE, TRUE, TRUE, NA, TRUE))
  expect_equal(out$sleep_stage, c("wake", "light", "deep", NA, "rem"))
  expect_equal(out$sleep_probability, c(0.3, 0.9, 0.9, NA, 0.9))
  expect_equal(out$nonwear, c(FALSE, FALSE, FALSE, NA, FALSE))
  expect_equal(out$method, rep("rester_lstm_sleepstages", 5))
  expect_equal(out$time, data$time[1] + 0:4 * 30)
  expect_equal(attr(out, "info"), list(ResampleRate = 30))
})

test_that("acti_rester selects the linear head and passes arguments", {
  data <- rester_data()
  seen <- NULL
  testthat::local_mocked_bindings(
    estimate_rest = function(file, model, ...) {
      seen <<- list(model = model, dots = list(...))
      rester_predictions(file$time[1], "light", model = model)
    },
    .package = "rester"
  )
  out <- acti_rester(data, model = "linear_sleepstages",
                     cache_dir = tempdir(), context_window_shift = 32L,
                     fill_zeros = FALSE)
  expect_equal(seen$model, "linear_sleepstages")
  expect_equal(seen$dots$context_window_shift, 32L)
  expect_false(seen$dots$fill_zeros)
  expect_equal(out$method, "rester_linear_sleepstages")
  expect_error(acti_rester(data, model = "linear_respevents",
                           cache_dir = tempdir()))
})

test_that("acti_rester returns exact instants across DST transitions", {
  for (start in c("2023-10-29 00:00:00", "2023-03-26 00:00:00")) {
    data <- rester_data(start, tz = "Europe/London", n = 8)
    data$time <- as.POSIXct(start, tz = "Europe/London") + 0:7 * 1800
    seen <- NULL
    testthat::local_mocked_bindings(
      estimate_rest = function(file, ...) {
        seen <<- file$time
        out <- rester_predictions(file$time[1], rep("light", 8 * 60))
        out
      },
      .package = "rester"
    )
    out <- acti_rester(data, cache_dir = tempdir())
    # The clock rester sees starts at local time and never repeats or skips
    expect_equal(format(seen[1]), format(data$time[1]))
    expect_equal(diff(as.numeric(seen)), rep(1800, 7))
    expect_equal(attr(out$time, "tzone"), "Europe/London")
    expect_equal(out$time, data$time[1] + (seq_len(8 * 60) - 1) * 30)

    out <- acti_rester(data, cache_dir = tempdir(), tz = "UTC")
    expect_equal(attr(out$time, "tzone"), "UTC")
    expect_equal(as.numeric(out$time[1]), as.numeric(data$time[1]))
  }
})

test_that("acti_rester passes file paths through and keeps their times", {
  path <- tempfile(fileext = ".cwa")
  file.create(path)
  start <- as.POSIXct("2020-01-01", tz = "America/New_York")
  testthat::local_mocked_bindings(
    estimate_rest = function(file, ...) {
      expect_equal(file, path)
      rester_predictions(start, c("wake", "deep"))
    },
    .package = "rester"
  )
  out <- acti_rester(path, cache_dir = tempdir())
  expect_equal(out$time, start + c(0, 30))
  expect_equal(attr(out$time, "tzone"), "America/New_York")
  out <- acti_rester(path, cache_dir = tempdir(), tz = "UTC")
  expect_equal(attr(out$time, "tzone"), "UTC")

  h5 <- tempfile(fileext = ".h5")
  file.create(h5)
  expect_error(acti_rester(h5, cache_dir = tempdir()), "h5")
})

test_that("py_acti_rester calls the isolated rester backend", {
  data <- rester_data()
  testthat::local_mocked_bindings(
    py_estimate_rest = function(file, model, ..., pyenv_function, show) {
      expect_named(file, c("time", "X", "Y", "Z"))
      expect_type(pyenv_function, "closure")
      expect_false(show)
      rester_predictions(file$time[1], "rem", model = model)
    },
    .package = "rester"
  )
  out <- py_acti_rester(data, cache_dir = tempdir())
  expect_s3_class(out, "acti_sleep_estimate")
  expect_true(out$sleep)
  expect_equal(out$sleep_stage, "rem")
})

test_that("acti_rester rejects incomplete or unordered acceleration data", {
  data <- data.frame(
    time = as.POSIXct("2020-01-01", tz = "UTC") + c(1, 0),
    X = c(0, NA_real_), Y = c(0, 0), Z = c(1, 1)
  )
  expect_error(acti_rester(data, cache_dir = tempdir()), "complete")
})
