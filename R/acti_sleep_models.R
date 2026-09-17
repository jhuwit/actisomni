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

.acti_sleep_model_time <- function(x) {
  if (inherits(x, "POSIXct")) return(x)
  if (!inherits(x, "POSIXt")) return(as.POSIXct(x, tz = "UTC"))
  if (is.numeric(x)) return(as.POSIXct(x, origin = "1970-01-01", tz = "UTC"))
  lubridate::ymd_hms(as.character(x), tz = "UTC", quiet = TRUE)
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

.acti_sleep_asleep_result <- function(result) {
  assertthat::assert_that(
    !is.null(result), is.data.frame(result$predictions),
    all(c("time", "sleep_wake") %in% names(result$predictions)),
    msg = "`asleep` did not return a predictions data frame with `time` and `sleep_wake`."
  )
  predictions <- result$predictions
  sleep_wake <- tolower(trimws(as.character(predictions$sleep_wake)))
  .acti_sleep_model_result(
    time = predictions$time,
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
#' @return An `acti_sleep_estimate` tibble with `time`, `sleep`,
#'   `sleep_probability`, `sleep_stage`, `nonwear`, and `method`. The asleep
#'   backend currently does not return probabilities, so `sleep_probability` is
#'   `NA`.
#' @export
acti_asleep <- function(data, min_wear_hours = 22L, time_shift = "0",
                              report_light_and_temp = FALSE,
                              pytorch_device = c("cpu", "cuda:0"),
                              sample_rate = NULL, verbose = TRUE,
                              force_download = FALSE) {
  data <- .acti_sleep_asleep_input(data)
  result <- asleep::asleep(
    file = data, min_wear_hours = min_wear_hours, time_shift = time_shift,
    report_light_and_temp = report_light_and_temp,
    pytorch_device = match.arg(pytorch_device), sample_rate = sample_rate,
    verbose = verbose, force_download = force_download
  )
  on.exit(cleanup_uv_lock_files(), add = TRUE)
  .acti_sleep_asleep_result(result)
}

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
                           show = FALSE) {
  data <- .acti_sleep_asleep_input(data)
  result <- asleep::py_asleep(
    file = data, min_wear_hours = min_wear_hours, time_shift = time_shift,
    report_light_and_temp = report_light_and_temp,
    pytorch_device = match.arg(pytorch_device), sample_rate = sample_rate,
    verbose = verbose, force_download = force_download,
    pyenv_function = pyenv_function, show = show
  )
  on.exit(cleanup_uv_lock_files(), add = TRUE)
  .acti_sleep_asleep_result(result)
}

#' Estimate sleep with the sleeper model
#'
#' Runs [sleeper::estimate_sleep()] on complete, time-ordered raw triaxial
#' acceleration. Input is converted to the timestamp-in-seconds format required
#' by `sleeper` before the model is called.
#'
#' @param data A data frame containing timestamps and triaxial acceleration.
#' @param epoch Output epoch in seconds.
#' @param model_dir Directory containing the sleeper model files.
#' @return An `acti_sleep_estimate` tibble with `time`, `sleep`,
#'   `sleep_probability`, `sleep_stage`, `nonwear`, and `method`. The sleeper
#'   backend does not return probabilities or sleep stages, so those columns are
#'   `NA`.
#' @export
acti_sleeper <- function(data, epoch = 30L, model_dir) {
  data <- .acti_sleep_model_input(data)
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
  on.exit(cleanup_uv_lock_files(), add = TRUE)
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
  on.exit(cleanup_uv_lock_files(), add = TRUE)
  .acti_sleep_sleeper_result(predictions)
}
