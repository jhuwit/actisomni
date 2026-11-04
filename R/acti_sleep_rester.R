# AcceleRest (rester) sleep-stage wrappers ------------------------------------

.acti_sleep_rester_input <- function(data) {
  if (is.character(data)) {
    data <- .acti_sleep_asleep_input(data)
    assertthat::assert_that(
      !grepl("[.]h5([.](gz|bz2|xz))?$", data, ignore.case = TRUE),
      msg = paste0("`.h5` files have no time stamps, so their predictions ",
                   "cannot be timed. Use `rester::estimate_rest()` directly.")
    )
    return(data)
  }
  .acti_sleep_model_input(data)
}

# Set up the input passed to rester. Data frames get a fixed clock (see
# `.acti_sleep_fixed_clock()`), as `actipy` works on naive clock times. The
# sample rate is found before standardizing, which drops a `sample_rate`
# attribute.
.acti_sleep_rester_prepare <- function(data, sample_rate = NULL, tz = NULL) {
  input <- data
  data <- .acti_sleep_rester_input(data)
  if (!is.data.frame(data)) {
    if (!is.null(tz)) tz <- .acti_sleep_input_tz(data, tz)
    return(list(data = data, sample_rate = sample_rate, tz = tz,
                offset = NULL))
  }
  sample_rate <- actibase::get_sample_rate(input, sample_rate = sample_rate)
  assertthat::assert_that(
    assertthat::is.number(sample_rate), sample_rate > 0,
    msg = "`sample_rate` must be one positive number."
  )
  tz <- .acti_sleep_input_tz(data, tz)
  clock <- .acti_sleep_fixed_clock(data, tz)
  list(data = clock$data, sample_rate = sample_rate, tz = tz,
       offset = clock$offset)
}

.acti_sleep_rester_result <- function(result, model, tz = NULL,
                                      offset = NULL) {
  predictions <- result[[model]]
  assertthat::assert_that(
    is.data.frame(predictions),
    all(c("time", "prob_wake", "prediction") %in% names(predictions)),
    msg = paste0("`rester` did not return ", model, " predictions with ",
                 "`time`, `prob_wake`, and `prediction`.")
  )
  time <- predictions$time
  if (!is.null(offset)) {
    # Data-frame input: undo the fixed offset applied to the input clock
    time <- lubridate::force_tz(time, "UTC") - offset
  }
  if (!is.null(tz)) time <- lubridate::with_tz(time, tz)
  stage <- as.character(predictions$prediction)
  out <- .acti_sleep_model_result(
    time = time,
    sleep = stage != "wake",
    sleep_probability = 1 - predictions$prob_wake,
    sleep_stage = stage,
    # Epochs without valid data (gaps, or non-wear when detected) are unknown
    nonwear = ifelse(is.na(stage), NA, FALSE),
    method = paste0("rester_", model)
  )
  attr(out, "info") <- attr(result, "info")
  out
}

#' Estimate sleep with the AcceleRest model
#'
#' Runs [rester::estimate_rest()], the AcceleRest model of Lorenzen et al.
#' (2026), on raw triaxial acceleration and converts its sleep-stage
#' predictions to the common `acti_sleep_estimate` format. AcceleRest
#' predicts deep, light, REM, and wake stages for 30-second epochs over
#' context windows of about 2.1 hours, so at least that much data is needed.
#'
#' The model code and weights must be downloaded first with
#' [rester::ar_setup()].
#'
#' @param data A data frame containing timestamps and triaxial acceleration,
#'   or a readable accelerometry file path (a device file or CSV; `.h5`
#'   files are not supported because they have no time stamps). File paths
#'   are passed unchanged to [rester::estimate_rest()].
#' @param model The sleep-stage head to use: `"lstm_sleepstages"` (default)
#'   or `"linear_sleepstages"`.
#' @param sample_rate Sample rate (Hz) of the input. If `NULL`, it is found
#'   with [actibase::get_sample_rate()] (from the `sample_rate` attribute,
#'   the header, or the time stamps).
#' @param tz Time zone of the returned times. By default the time zone of
#'   `data$time`, or the time zone of the times read from a file.
#'
#'   For data-frame input, the clock passed to `rester` is held at the UTC
#'   offset in effect at the start of the recording, as `actipy` works on
#'   clock times without a time zone. The returned times are the exact
#'   instants of the input, shown in `tz`.
#' @param cache_dir Directory with the downloaded AcceleRest code and
#'   weights; see [rester::ar_setup()].
#' @param context_window_shift Number of 30-second epochs to shift
#'   consecutive context windows; see [rester::estimate_rest()].
#' @param max_batch_size Number of context windows per forward pass.
#' @param device `torch` device, e.g. `"cpu"`, `"cuda"`, or `"mps"`. If
#'   `NULL`, `rester` chooses.
#' @param ... Additional arguments passed to [rester::ar_read()], such as
#'   `fill_zeros`, `detect_nonwear`, or `verbose`.
#' @return An `acti_sleep_estimate` tibble with `time`, `sleep`,
#'   `sleep_probability`, `sleep_stage`, `nonwear`, and `method`.
#'   `sleep_probability` is one minus the probability of wake, `sleep_stage`
#'   is the most probable of `"deep"`, `"light"`, `"rem"`, and `"wake"`, and
#'   epochs with no valid data have `NA` for `sleep`, `sleep_probability`,
#'   `sleep_stage`, and `nonwear`. The `actipy` information about the data is
#'   in `attr(x, "info")`.
#' @references Lorenzen NR, Brink-Kjaer A, Jennum PJ, Mignot E (2026).
#'   AcceleRest: A Physiology-Aware Masked Autoencoder for Wrist
#'   Accelerometer-based Sleep Staging and Apnea Evaluation. *medRxiv*.
#'   \doi{10.64898/2026.01.28.26345056}
#' @export
#' @examples
#' \donttest{
#'   # Runs only after rester::ar_setup(), so Python is not set up otherwise
#'   if (rester::ar_have_repo() &&
#'       rester::ar_have_weights("lstm_sleepstages") &&
#'       rester::ar_python_modules_installed()) {
#'     data <- rester::ar_example_data(n_hours = 2.5)
#'     out <- acti_rester(data, context_window_shift = 32L)
#'     head(out)
#'   }
#' }
acti_rester <- function(data, model = c("lstm_sleepstages",
                                        "linear_sleepstages"),
                        sample_rate = NULL, tz = NULL,
                        cache_dir = rester::ar_cache_dir(),
                        context_window_shift = 1L, max_batch_size = 16L,
                        device = NULL, ...) {
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
  .acti_sleep_rester_result(result, model, tz = input$tz,
                            offset = input$offset)
}

#' Estimate sleep with AcceleRest in an isolated Python process
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
py_acti_rester <- function(data, model = c("lstm_sleepstages",
                                           "linear_sleepstages"),
                           sample_rate = NULL, tz = NULL,
                        cache_dir = rester::ar_cache_dir(),
                           context_window_shift = 1L, max_batch_size = 16L,
                           device = NULL,
                           pyenv_function = function() rester::py_require_rester(),
                           show = FALSE, ...) {
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
  .acti_sleep_rester_result(result, model, tz = input$tz,
                            offset = input$offset)
}
