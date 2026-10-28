# Sleep classification model wrappers ----------------------------------------

.acti_sleep_model_input <- function(data) {
  data <- actibase::acti_standardize_data(
    data, subset_xyz = FALSE, check_xyz = TRUE
  )
  assertthat::assert_that(
    all(c("time", "X", "Y", "Z") %in% names(data)),
    msg = paste0("`data` must contain timestamped triaxial acceleration ",
                 "that actibase can standardize to `time`, `X`, `Y`, and `Z`.")
  )

  data <- dplyr::transmute(
    data,
    time = .data$time,
    X = as.numeric(.data$X),
    Y = as.numeric(.data$Y),
    Z = as.numeric(.data$Z)
  )
  assertthat::assert_that(
    nrow(data) >= 2L,
    inherits(data$time, "POSIXt"),
    all(is.finite(as.numeric(data$time))),
    all(is.finite(data$X) & is.finite(data$Y) & is.finite(data$Z)),
    all(diff(as.numeric(data$time)) > 0),
    msg = paste0("`data` must have at least two complete, uniquely timestamped ",
                 "observations in increasing time order.")
  )
  data
}

.acti_sleep_asleep_input <- function(data) {
  if (!is.character(data)) return(.acti_sleep_model_input(data))
  assertthat::assert_that(
    assertthat::is.string(data), assertthat::is.readable(data),
    msg = "A file input must be one readable accelerometry file path."
  )
  data
}

# asleep reports local clock times without a time zone. For data-frame input
# these are the clock times of `data$time`; for a file path they are the
# device clock, so the time zone must be supplied.
.acti_sleep_input_tz <- function(data, tz = NULL) {
  if (!is.null(tz)) {
    assertthat::assert_that(assertthat::is.string(tz),
                            msg = "`tz` must be one time zone name.")
    return(tz)
  }
  if (is.data.frame(data) && inherits(data$time, "POSIXt")) {
    tzone <- attr(data$time, "tzone")
    return(if (is.null(tzone)) "" else tzone[1L])
  }
  "UTC"
}

.acti_sleep_model_time <- function(x) {
  if (inherits(x, "POSIXct")) return(x)
  if (!inherits(x, "POSIXt")) return(as.POSIXct(x, tz = "UTC"))
  if (is.numeric(x)) return(as.POSIXct(x, origin = "1970-01-01", tz = "UTC"))
  lubridate::ymd_hms(as.character(x), tz = "UTC", quiet = TRUE)
}

# Seconds that clock time in `tz` is ahead of UTC at `time`.
.acti_sleep_clock_offset <- function(time, tz) {
  as.numeric(lubridate::force_tz(lubridate::with_tz(time, tz), "UTC")) -
    as.numeric(time)
}

# asleep works on naive local clock times. For data-frame input, hold the clock
# at the UTC offset at the start of the recording, as a device clock is, so it
# never repeats or skips an hour at a daylight-saving transition.
.acti_sleep_fixed_clock <- function(data, tz) {
  offset <- .acti_sleep_clock_offset(data$time[1L], tz)
  data$time <- lubridate::with_tz(data$time, "UTC") + offset
  attr(data$time, "tzone") <- "UTC"
  list(data = data, offset = offset)
}

.acti_sleep_model_result <- function(time, sleep, method,
                                     sleep_probability = NA_real_,
                                     sleep_stage = NA_character_,
                                     nonwear = FALSE) {
  time <- .acti_sleep_model_time(time)
  n <- length(time)
  if (length(sleep_probability) == 1L) sleep_probability <- rep(sleep_probability, n)
  if (length(sleep_stage) == 1L) sleep_stage <- rep(sleep_stage, n)
  if (length(nonwear) == 1L) nonwear <- rep(nonwear, n)
  assertthat::assert_that(
    !anyNA(time),
    assertthat::are_equal(length(sleep), n),
    assertthat::are_equal(length(sleep_probability), n),
    assertthat::are_equal(length(sleep_stage), n),
    assertthat::are_equal(length(nonwear), n),
    msg = "The model returned incomplete or inconsistent predictions."
  )
  structure(
    tibble::tibble(
      time = time,
      sleep = as.logical(sleep),
      sleep_probability = as.numeric(sleep_probability),
      sleep_stage = as.character(sleep_stage),
      nonwear = as.logical(nonwear),
      method = rep(method, n)
    ),
    class = c("acti_sleep_estimate", "tbl_df", "tbl", "data.frame")
  )
}

.acti_sleep_asleep_result <- function(result, tz = "UTC", offset = NULL) {
  assertthat::assert_that(
    !is.null(result), is.data.frame(result$predictions),
    all(c("time", "sleep_wake") %in% names(result$predictions)),
    msg = "`asleep` did not return a predictions data frame with `time` and `sleep_wake`."
  )
  predictions <- result$predictions
  clock <- lubridate::force_tz(.acti_sleep_model_time(predictions$time), "UTC")
  time <- if (is.null(offset)) {
    # File input: relabel (not convert) the device clock times to `tz`
    lubridate::force_tz(clock, tz)
  } else {
    # Data-frame input: undo the fixed offset applied to the input clock
    lubridate::with_tz(clock - offset, tz)
  }
  sleep_wake <- tolower(trimws(as.character(predictions$sleep_wake)))
  .acti_sleep_model_result(
    time = time,
    sleep = sleep_wake == "sleep",
    sleep_stage = if ("sleep_stage" %in% names(predictions)) {
      predictions$sleep_stage
    } else {
      rep(NA_character_, nrow(predictions))
    },
    method = "asleep"
  )
}

.acti_sleep_sleeper_result <- function(predictions) {
  assertthat::assert_that(
    is.data.frame(predictions), all(c("time", "classification") %in% names(predictions)),
    msg = "`sleeper` did not return a predictions data frame with `time` and `classification`."
  )
  classification <- tolower(trimws(as.character(predictions$classification)))
  .acti_sleep_model_result(
    time = predictions$time,
    sleep = classification == "sleep",
    nonwear = classification == "nonwear",
    method = "sleeper"
  )
}

#' Estimate sleep with the asleep model
#'
#' Runs [asleep::asleep()] on complete, time-ordered raw triaxial acceleration
#' and converts its predictions to the common `acti_sleep_estimate` format.
#'
#' @param data A data frame containing timestamps and triaxial acceleration, or
#'   a readable accelerometry file path. File paths are passed unchanged to
#'   [asleep::asleep()].
#' @param min_wear_hours Minimum daily wear time used by `asleep` summaries.
#' @param time_shift Clock-time correction passed to [asleep::asleep()].
#' @param report_light_and_temp Whether to request light and temperature output.
#' @param pytorch_device Device used for prediction.
#' @param sample_rate Optional input sample rate.
#' @param verbose Whether `asleep` prints progress messages.
#' @param force_download Whether to re-download `asleep` model files.
#' @param tz Time zone of the recording and the returned times. By default
#'   the time zone of `data$time`, or `"UTC"` when `data` is a file path; set
#'   it to the recording's time zone for file input. `asleep` works on local
#'   clock times without a time zone and splits the recording into
#'   noon-to-noon days on that clock.
#'
#'   For data-frame input, the clock passed to `asleep` is held at the UTC
#'   offset in effect at the start of the recording, as a device clock is, so
#'   it never repeats or skips an hour at a daylight-saving transition. The
#'   returned times are the exact instants of the input, shown in `tz`.
#'
#'   For file input, the device clock times that `asleep` reports are taken as
#'   clock times in `tz`. File and data-frame input of the same recording can
#'   therefore differ after a daylight-saving transition: a device clock that
#'   does not change for daylight saving is an hour off from `tz` until the
#'   clocks change back. This difference is known. To match such a device
#'   clock, use a fixed-offset time zone, e.g. `tz = "Etc/GMT-1"` for UTC+1.
#' @return An `acti_sleep_estimate` tibble with `time`, `sleep`,
#'   `sleep_probability`, `sleep_stage`, `nonwear`, and `method`. The asleep
#'   backend currently does not return probabilities, so `sleep_probability` is
#'   `NA`.
#' @export
acti_asleep <- function(data, min_wear_hours = 22L, time_shift = "0",
                              report_light_and_temp = FALSE,
                              pytorch_device = c("cpu", "cuda:0"),
                              sample_rate = NULL, verbose = TRUE,
                              force_download = FALSE, tz = NULL) {
  data <- .acti_sleep_asleep_input(data)
  tz <- .acti_sleep_input_tz(data, tz)
  offset <- NULL
  if (is.data.frame(data)) {
    clock <- .acti_sleep_fixed_clock(data, tz)
    data <- clock$data
    offset <- clock$offset
  }
  result <- asleep::asleep(
    file = data, min_wear_hours = min_wear_hours, time_shift = time_shift,
    report_light_and_temp = report_light_and_temp,
    pytorch_device = match.arg(pytorch_device), sample_rate = sample_rate,
    verbose = verbose, force_download = force_download
  )
  if (Sys.getenv("NOT_CRAN") != "true") {
    on.exit(cleanup_uv_lock_files(), add = TRUE)
  }
  .acti_sleep_asleep_result(result, tz = tz, offset = offset)
}

#' @export
#' @rdname acti_asleep
acti_calculate_asleep = acti_asleep

#' Estimate sleep with asleep in an isolated Python process
#'
#' Uses [asleep::py_asleep()] to run the same asleep model as
#' [acti_asleep()] in a `callr` subprocess. This keeps Python package
#' requirements separate from the current R session.
#'
#' @inheritParams acti_asleep
#' @param pyenv_function Function that configures Python in the subprocess.
#' @param show Whether to stream subprocess output.
#' @return An `acti_sleep_estimate` tibble; see [acti_asleep()].
#' @export
py_acti_asleep <- function(data, min_wear_hours = 22L, time_shift = "0",
                           report_light_and_temp = FALSE,
                           pytorch_device = c("cpu", "cuda:0"),
                           sample_rate = NULL, verbose = TRUE,
                           force_download = FALSE,
                           pyenv_function = function() asleep::py_require_asleep(),
                           show = FALSE, tz = NULL) {
  data <- .acti_sleep_asleep_input(data)
  tz <- .acti_sleep_input_tz(data, tz)
  offset <- NULL
  if (is.data.frame(data)) {
    clock <- .acti_sleep_fixed_clock(data, tz)
    data <- clock$data
    offset <- clock$offset
  }
  result <- asleep::py_asleep(
    file = data, min_wear_hours = min_wear_hours, time_shift = time_shift,
    report_light_and_temp = report_light_and_temp,
    pytorch_device = match.arg(pytorch_device), sample_rate = sample_rate,
    verbose = verbose, force_download = force_download,
    pyenv_function = pyenv_function, show = show
  )
  if (Sys.getenv("NOT_CRAN") != "true") {
    on.exit(cleanup_uv_lock_files(), add = TRUE)
  }
  .acti_sleep_asleep_result(result, tz = tz, offset = offset)
}

#' Estimate sleep with the sleeper model
#'
#' Runs [sleeper::estimate_sleep()] on complete, time-ordered raw triaxial
#' acceleration. Input is converted to the timestamp-in-seconds format required
#' by `sleeper` before the model is called.
#'
#' @param data A data frame containing timestamps and triaxial acceleration.
#' @param epoch Output epoch, in whole seconds or a string such as
#'   `"30 seconds"`; see [actibase::acti_standardize_epoch()].
#' @param model_dir Directory containing the sleeper model files.
#' @return An `acti_sleep_estimate` tibble with `time`, `sleep`,
#'   `sleep_probability`, `sleep_stage`, `nonwear`, and `method`. The sleeper
#'   backend does not return probabilities or sleep stages, so those columns are
#'   `NA`.
#' @export
acti_sleeper <- function(data, epoch = 30L, model_dir) {
  data <- .acti_sleep_model_input(data)
  epoch <- actibase::acti_standardize_epoch(epoch)
  assertthat::assert_that(
    assertthat::is.count(epoch), epoch > 0,
    assertthat::is.string(model_dir), dir.exists(path.expand(model_dir)),
    msg = "`epoch` must be one positive integer and `model_dir` must exist."
  )
  assertthat::assert_that(
    sleeper::sl_have_models(model_dir),
    msg = paste0("`model_dir` does not contain valid sleeper model files. ",
                 "Download them with `sleeper::sl_download_models()`. ")
  )
  sleeper_data <- data.frame(
    timestamp = as.numeric(data$time), x = data$X, y = data$Y, z = data$Z
  )
  predictions <- sleeper::estimate_sleep(
    data = sleeper_data, epoch = as.integer(epoch), model_dir = model_dir
  )
  if (Sys.getenv("NOT_CRAN") != "true") {
    on.exit(cleanup_uv_lock_files(), add = TRUE)
  }
  .acti_sleep_sleeper_result(predictions)
}

#' Estimate sleep with sleeper in an isolated Python process
#'
#' Uses [sleeper::py_estimate_sleep()] to run the same sleeper model as
#' [acti_sleeper()] in a `callr` subprocess.
#'
#' @inheritParams acti_sleeper
#' @param pyenv_function Function that configures Python in the subprocess.
#' @param show Whether to stream subprocess output.
#' @return An `acti_sleep_estimate` tibble; see [acti_sleeper()].
#' @export
py_acti_sleeper <- function(data, epoch = 30L, model_dir,
                            pyenv_function = function() sleeper::py_require_sleeper(),
                            show = FALSE) {
  data <- .acti_sleep_model_input(data)
  epoch <- actibase::acti_standardize_epoch(epoch)
  assertthat::assert_that(
    assertthat::is.count(epoch), epoch > 0,
    assertthat::is.string(model_dir), dir.exists(path.expand(model_dir)),
    msg = "`epoch` must be one positive integer and `model_dir` must exist."
  )
  assertthat::assert_that(
    sleeper::sl_have_models(model_dir),
    msg = paste0("`model_dir` does not contain valid sleeper model files. ",
                 "Download them with `sleeper::sl_download_models()`. ")
  )
  sleeper_data <- data.frame(
    timestamp = as.numeric(data$time), x = data$X, y = data$Y, z = data$Z
  )
  predictions <- sleeper::py_estimate_sleep(
    data = sleeper_data, epoch = as.integer(epoch), model_dir = model_dir,
    pyenv_function = pyenv_function, show = show
  )
  if (Sys.getenv("NOT_CRAN") != "true") {
    on.exit(cleanup_uv_lock_files(), add = TRUE)
  }
  .acti_sleep_sleeper_result(predictions)
}

.acti_sleep_rester_input <- function(data) {
  if (!is.character(data)) return(.acti_sleep_model_input(data))
  assertthat::assert_that(
    assertthat::is.string(data), assertthat::is.readable(data),
    msg = "A file input must be one readable accelerometry file path."
  )
  assertthat::assert_that(
    !grepl("[.]h5([.](gz|bz2|xz))?$", data, ignore.case = TRUE),
    msg = "`.h5` files have no time stamps, so they cannot be used here."
  )
  data
}

# Prepare the input for rester. Data frames get the same fixed clock as asleep,
# because actipy resamples on naive local clock times. The sample rate is found
# before standardizing, which drops a `sample_rate` attribute.
.acti_sleep_rester_prepare <- function(data, sample_rate = NULL, tz = NULL) {
  input <- data
  data <- .acti_sleep_rester_input(data)
  if (!is.data.frame(data)) {
    return(list(data = data, sample_rate = sample_rate, tz = tz, offset = NULL))
  }
  sample_rate <- actibase::get_sample_rate(input, sample_rate = sample_rate)
  tz <- .acti_sleep_input_tz(data, tz)
  clock <- .acti_sleep_fixed_clock(data, tz)
  list(data = clock$data, sample_rate = sample_rate, tz = tz,
       offset = clock$offset)
}

.acti_sleep_rester_result <- function(result, model, tz = NULL, offset = NULL) {
  predictions <- result[[model]]
  assertthat::assert_that(
    is.data.frame(predictions),
    all(c("time", "prediction", "prob_wake") %in% names(predictions)),
    msg = paste0("`rester` did not return a `", model, "` data frame with ",
                 "`time`, `prediction`, and `prob_wake`.")
  )
  time <- .acti_sleep_model_time(predictions$time)
  if (!is.null(offset)) {
    # Data-frame input: undo the fixed offset applied to the input clock
    time <- lubridate::force_tz(time, "UTC") - offset
  }
  if (!is.null(tz)) time <- lubridate::with_tz(time, tz)
  stage <- tolower(trimws(as.character(predictions$prediction)))
  .acti_sleep_model_result(
    time = time,
    sleep = stage != "wake",
    sleep_probability = 1 - as.numeric(predictions$prob_wake),
    sleep_stage = stage,
    method = "rester"
  )
}

#' Estimate sleep with the rester (AcceleRest) model
#'
#' Runs [rester::estimate_rest()] on complete, time-ordered raw triaxial
#' acceleration and converts the sleep-stage predictions of the AcceleRest
#' model to the common `acti_sleep_estimate` format. AcceleRest predicts 30
#' second epochs over context windows of 256 epochs (about 2.1 hours), so at
#' least that much data is needed.
#'
#' @param data A data frame containing timestamps and triaxial acceleration, or
#'   a readable accelerometry file path (`.cwa`, `.gt3x`, `.bin`, or CSV),
#'   passed unchanged to [rester::estimate_rest()].
#' @param model The sleep-stage prediction head, `"linear_sleepstages"` or
#'   `"lstm_sleepstages"`.
#' @param cache_dir Directory with the downloaded AcceleRest code and weights;
#'   see [rester::ar_setup()].
#' @param context_window_shift Number of 30-second epochs to shift consecutive
#'   context windows. Smaller is slower but averages over more windows.
#' @param max_batch_size Number of context windows per forward pass.
#' @param device `torch` device, e.g. `"cpu"`, `"cuda"`, or `"mps"`. If `NULL`,
#'   `rester` uses `"cuda"` if available, otherwise `"cpu"`.
#' @param sample_rate Optional input sample rate (Hz). If `NULL`, it is found
#'   with [actibase::get_sample_rate()].
#' @param tz Time zone of the returned times. By default the time zone of
#'   `data$time`, or the time zone `rester` reads a file in. For data-frame
#'   input, the clock passed to `rester` is held at the UTC offset in effect at
#'   the start of the recording, as in [acti_asleep()], and the returned times
#'   are exact instants shown in `tz`.
#' @param ... Additional arguments passed to [rester::ar_read()], such as
#'   `fill_zeros` or `detect_nonwear`.
#' @return An `acti_sleep_estimate` tibble with `time`, `sleep`,
#'   `sleep_probability`, `sleep_stage`, `nonwear`, and `method`. `sleep` is
#'   `TRUE` for deep, light, and REM epochs, `sleep_probability` is one minus
#'   the probability of wake, and `sleep_stage` is the most probable of
#'   `"deep"`, `"light"`, `"rem"`, and `"wake"`. Epochs without valid data
#'   (gaps, or non-wear when `detect_nonwear = TRUE`) have `NA` for `sleep`,
#'   `sleep_probability`, and `sleep_stage`; `nonwear` is always `FALSE`.
#' @export
acti_rester <- function(data,
                        model = c("linear_sleepstages", "lstm_sleepstages"),
                        cache_dir = rester::ar_cache_dir(),
                        context_window_shift = 1L, max_batch_size = 16L,
                        device = NULL, sample_rate = NULL, tz = NULL, ...) {
  rlang::check_installed("rester")
  model <- match.arg(model)
  input <- .acti_sleep_rester_prepare(data, sample_rate = sample_rate, tz = tz)
  result <- rester::estimate_rest(
    file = input$data, model = model, cache_dir = cache_dir,
    context_window_shift = context_window_shift,
    max_batch_size = max_batch_size, device = device,
    sample_rate = input$sample_rate, ...
  )
  if (Sys.getenv("NOT_CRAN") != "true") {
    on.exit(cleanup_uv_lock_files(), add = TRUE)
  }
  .acti_sleep_rester_result(result, model, tz = input$tz, offset = input$offset)
}

#' Estimate sleep with rester in an isolated Python process
#'
#' Uses [rester::py_estimate_rest()] to run the same AcceleRest model as
#' [acti_rester()] in a `callr` subprocess. This keeps Python package
#' requirements separate from the current R session.
#'
#' @inheritParams acti_rester
#' @param pyenv_function Function that configures Python in the subprocess.
#' @param show Whether to stream subprocess output.
#' @return An `acti_sleep_estimate` tibble; see [acti_rester()].
#' @export
py_acti_rester <- function(data,
                           model = c("linear_sleepstages", "lstm_sleepstages"),
                           cache_dir = rester::ar_cache_dir(),
                           context_window_shift = 1L, max_batch_size = 16L,
                           device = NULL, sample_rate = NULL, tz = NULL, ...,
                           pyenv_function = function() rester::py_require_rester(),
                           show = FALSE) {
  rlang::check_installed(c("rester", "callr"))
  model <- match.arg(model)
  input <- .acti_sleep_rester_prepare(data, sample_rate = sample_rate, tz = tz)
  result <- rester::py_estimate_rest(
    file = input$data, model = model, cache_dir = cache_dir,
    context_window_shift = context_window_shift,
    max_batch_size = max_batch_size, device = device,
    sample_rate = input$sample_rate, ...,
    pyenv_function = pyenv_function, show = show
  )
  if (Sys.getenv("NOT_CRAN") != "true") {
    on.exit(cleanup_uv_lock_files(), add = TRUE)
  }
  .acti_sleep_rester_result(result, model, tz = input$tz, offset = input$offset)
}
