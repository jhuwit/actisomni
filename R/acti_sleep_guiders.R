# Sleep guider algorithms -----------------------------------------------------
#
# Standalone implementations of the sleep-period-time (SPT) *guiders*
# described in the GGIR sleep fundamentals documentation.  A guider identifies
# the most likely main sleep window; it is not an epoch-by-epoch sleep/wake
# classifier.  The implementations below do not call, import, or require GGIR.

.acti_sleep_epoch_seconds <- function(time = NULL, epoch_seconds = NULL) {
  if (!is.null(epoch_seconds)) {
    assertthat::assert_that(
      assertthat::is.number(epoch_seconds), epoch_seconds > 0,
      msg = "`epoch_seconds` must be one positive number."
    )
    return(as.numeric(epoch_seconds))
  }
  assertthat::assert_that(
    !is.null(time), length(time) >= 2L,
    msg = "Supply `epoch_seconds`, or at least two regularly spaced timestamps."
  )
  time_difference <- diff(time)
  if (inherits(time_difference, "difftime")) {
    time_difference <- as.numeric(time_difference, units = "secs")
  }
  epoch_seconds <- stats::median(as.numeric(time_difference), na.rm = TRUE)
  assertthat::assert_that(
    assertthat::is.number(epoch_seconds), epoch_seconds > 0,
    msg = "Could not infer a positive epoch length from `time`."
  )
  epoch_seconds
}

.acti_sleep_check_vector <- function(x, name, n = NULL) {
  assertthat::assert_that(
    is.numeric(x), assertthat::not_empty(x),
    msg = sprintf("`%s` must be a non-empty numeric vector.", name)
  )
  if (!is.null(n)) {
    assertthat::assert_that(
      assertthat::are_equal(length(x), n),
      msg = sprintf("`%s` must have length %d.", name, n)
    )
  }
  as.numeric(x)
}

.acti_sleep_roll_apply <- function(x, width, fun) {
  # A centred rolling statistic with zero-filled ends, matching the HDCZA
  # convention used for the first and last half-window.
  n <- length(x)
  out <- numeric(n)
  half_left <- floor((width - 1L) / 2L)
  half_right <- width - half_left - 1L
  for (i in seq_len(n)) {
    lo <- i - half_left
    hi <- i + half_right
    if (lo >= 1L && hi <= n) out[i] <- fun(x[lo:hi])
  }
  out
}

.acti_sleep_interior_runs <- function(runs) {
  if (length(runs$values) <= 2L) return(integer())
  seq.int(2L, length(runs$values) - 1L)
}

.acti_sleep_angle <- function(X, Y, Z, longitudinal_axis = "Z") {
  longitudinal_axis <- match.arg(longitudinal_axis, c("X", "Y", "Z"))
  assertthat::assert_that(
    assertthat::are_equal(length(X), length(Y)),
    assertthat::are_equal(length(X), length(Z)),
    msg = "`X`, `Y`, and `Z` must have the same length."
  )
  axis <- switch(longitudinal_axis, X = X, Y = Y, Z = Z)
  other_axes <- switch(longitudinal_axis,
    X = list(Y, Z), Y = list(X, Z), Z = list(X, Y)
  )
  atan(axis / sqrt(other_axes[[1L]]^2 + other_axes[[2L]]^2)) * 180 / pi
}

.acti_sleep_blocks <- function(flag, min_block_epochs, max_gap_epochs) {
  # Remove short inactive blocks, bridge short interruptions, then retain the
  # longest remaining block.  `flag` is the candidate low-movement signal.
  n <- length(flag)
  r <- rle(c(FALSE, flag, FALSE))
  interior <- .acti_sleep_interior_runs(r)
  remove <- interior[r$values[interior] &
                       r$lengths[interior] <= min_block_epochs]
  if (length(remove)) r$values[remove] <- FALSE

  flag <- rep(r$values, r$lengths)[-c(1L, n + 2L)]
  r <- rle(c(FALSE, flag, FALSE))
  interior <- .acti_sleep_interior_runs(r)
  fill <- interior[!r$values[interior] &
                     r$lengths[interior] < max_gap_epochs]
  if (length(fill)) r$values[fill] <- TRUE

  crude <- rep(r$values, r$lengths)[-c(1L, n + 2L)]
  r <- rle(c(FALSE, crude, FALSE))
  interior <- .acti_sleep_interior_runs(r)
  candidates <- interior[r$values[interior]]
  selected <- rep(FALSE, n)
  if (length(candidates)) {
    # `which.max` deliberately selects the first tied window, as GGIR does.
    chosen <- candidates[which.max(r$lengths[candidates])]
    start <- sum(r$lengths[seq_len(chosen - 1L)])
    selected[seq.int(start, start + r$lengths[chosen] - 1L)] <- TRUE
  }
  list(crude = crude, selected = selected)
}

.acti_sleep_result <- function(selected, method, threshold = NA_real_,
                               crude = NULL, details = list()) {
  starts <- which(diff(c(FALSE, selected)) == 1L)
  ends <- which(diff(c(selected, FALSE)) == -1L)
  structure(c(list(
    method = method,
    start_index = if (length(starts)) starts[1L] else NA_integer_,
    end_index = if (length(ends)) ends[1L] else NA_integer_,
    threshold = threshold,
    window = selected,
    crude_window = crude
  ), details), class = "acti_sleep_guider")
}

# Five-second rolling median of one axis, as in GGIR's g.applymetrics():
# taken on every floor(sf / 10)-th sample (about 10 Hz), with an odd window,
# then repeated back to the original sample rate.  Unlike GGIR, which keeps
# the unsmoothed axis when the repeated series is longer than the input, the
# repeated series is truncated (https://github.com/wadpac/GGIR/issues/1562).
.acti_sleep_rollmedian <- function(x, sample_rate) {
  n <- length(x)
  step <- max(floor(sample_rate / 10), 1)
  new_rate <- if (step > 1) 10 else sample_rate
  k <- round(new_rate * 5)
  if (k %% 2 == 0) k <- k + 1
  xm <- x[seq(1, n, by = step)]
  if (length(xm) >= k) xm <- stats::runmed(xm, k, endrule = "constant")
  xm <- rep(xm, each = step)
  if (length(xm) >= n) xm[seq_len(n)] else c(xm, rep(xm[length(xm)], n - length(xm)))
}

# Standardize raw data and apply the rolling median to each axis.  The median
# is taken over sample indices, so it spans the wrong amount of time when
# samples are missing; warn when consecutive samples are further apart than
# 1.5 sample periods.
.acti_sleep_smooth_axes <- function(data) {
  sample_rate <- actibase::get_sample_rate(data)
  data <- actibase::acti_standardize_data(
    data, subset_xyz = FALSE, check_xyz = TRUE
  )
  dt <- diff(as.numeric(data$time))
  n_gaps <- sum(dt > 1.5 / sample_rate, na.rm = TRUE)
  if (n_gaps > 0) {
    warning(sprintf(paste0(
      "`data` has %d gap(s) longer than 1.5 samples at %g Hz; the rolling ",
      "median spans them as if the samples were contiguous. Fill or resample ",
      "the data first (e.g. actibase::acti_resample()), or use ",
      "`smooth = \"none\"`."), n_gaps, sample_rate), call. = FALSE)
  }
  for (axis in c("X", "Y", "Z")) {
    data[[axis]] <- .acti_sleep_rollmedian(data[[axis]], sample_rate)
  }
  data
}

.acti_sleep_raw_angles <- function(data, epoch, longitudinal_axis = "Z",
                                   smooth = c("rollmedian", "none")) {
  epoch <- actibase::acti_standardize_epoch(epoch, output = "character")
  smooth <- match.arg(smooth)
  data <- if (smooth == "rollmedian") {
    .acti_sleep_smooth_axes(data)
  } else {
    actibase::acti_standardize_data(data, subset_xyz = FALSE, check_xyz = TRUE)
  }
  longitudinal_axis <- match.arg(longitudinal_axis, c("X", "Y", "Z"))

  data |>
    dplyr::mutate(
      .time = .data$time,
      .angle = .acti_sleep_angle(.data$X, .data$Y, .data$Z, longitudinal_axis),
      .invalid = if ("invalid" %in% names(data)) as.logical(.data$invalid) else FALSE,
      .epoch = lubridate::floor_date(.data$.time, unit = epoch)
    ) |>
    dplyr::group_by(.data$.epoch) |>
    dplyr::summarise(
      time = dplyr::first(.data$.epoch),
      angle = mean(.data$.angle, na.rm = TRUE),
      invalid = any(.data$.invalid),
      .groups = "drop"
    ) |>
    dplyr::select(-".epoch")
}

.acti_sleep_epoch_data <- function(data, required = character()) {
  data <- actibase::acti_standardize_data(
    data, subset_xyz = FALSE, check_xyz = FALSE
  )
  assertthat::assert_that("time" %in% names(data),
    msg = "`data` must contain a timestamp column that actibase can standardize to `time`.")
  assertthat::assert_that(all(required %in% names(data)),
    msg = sprintf("`data` must contain: %s.", paste(required, collapse = ", ")))
  data
}

.acti_sleep_activity_data <- function(data) {
  data <- .acti_sleep_epoch_data(data)
  activity_col <- intersect(c("activity", "counts", "ENMO", "enmo", "axis1"), names(data))
  assertthat::assert_that(length(activity_col) > 0L,
    msg = "`data` must contain `activity`, `counts`, `ENMO`, `enmo`, or `axis1`.")
  data |>
    dplyr::transmute(time = .data$time, activity = .data[[activity_col[1L]]],
                     invalid = if ("invalid" %in% names(data)) .data$invalid else FALSE)
}

#' Identify a sleep window with HDCZA
#'
#' Implements the HDCZA sleep-period-time guider for wrist accelerometry.  It
#' finds prolonged periods of little change in the supplied z-axis angle, joins
#' interruptions shorter than an hour, and returns the longest resulting block.
#' As in GGIR, the default threshold is derived from the recording: 15 times
#' the 10th percentile of the five-minute rolling median absolute angle change,
#' limited to between 0.13 and 0.5 degrees. Setting `threshold` gives a fixed
#' threshold in degrees instead (e.g. `threshold = 0.2`, the previous default).
#' GGIR's `HDCZA_threshold = c(p, m)` corresponds to
#' `threshold_percentile = p, threshold_multiplier = m`.
#'
#' @param data A data frame of raw accelerometer observations.
#' @param epoch Epoch used to average raw angles, in seconds or a string
#'   such as `"5 seconds"`; see [actibase::acti_standardize_epoch()]. Must be
#'   at most 200 seconds so that each five-minute window holds at least two
#'   angles.
#' @param threshold Fixed maximum five-minute rolling median absolute angle
#'   change, in degrees. The default, `NULL`, derives the threshold from the
#'   recording using `threshold_percentile` and `threshold_multiplier`.
#' @param threshold_percentile Percentile, between 1 and 100, of the rolling
#'   median absolute angle change used for the data-driven threshold. Ignored
#'   when `threshold` is set.
#' @param threshold_multiplier Positive multiplier applied to that percentile
#'   for the data-driven threshold. Ignored when `threshold` is set.
#' @param ignore_invalid Whether invalid observations are treated as movement;
#'   use `NA` to treat them as no movement.
#' @param min_block_minutes Minimum low-movement block duration.
#' @param max_gap_minutes Maximum interruption bridged between blocks.
#' @param smooth Smoothing of the raw axes before the angle is computed:
#'   `"rollmedian"` (the default) takes a five-second rolling median of each
#'   axis first, as described by van Hees et al. (2015, 2018) and implemented
#'   in GGIR, so angles agree with GGIR's `anglez`; `"none"` computes the
#'   angle from each raw sample, as in actisomni 0.3.0 and earlier.  The
#'   median is taken over samples, not time, so `"rollmedian"` warns when the
#'   timestamps have gaps; fill or resample such data first.
#' @return An `acti_sleep_guider` object. `window` is the selected SPT guider;
#'   `crude_window` retains all candidate blocks before choosing the longest.
#' @examples
#' \donttest{
#' # The bundled actiread recording contains raw X, Y, and Z acceleration.
#' raw <- actiread::acti_read_gt3x(actiread::acti_example_gt3x(), verbose = FALSE)
#' hdcza <- acti_sleep_hdcza(raw, epoch = "5 seconds")
#' }
#' @export
acti_sleep_hdcza <- function(data, epoch = "5 seconds", threshold = NULL,
                             threshold_percentile = 10,
                             threshold_multiplier = 15,
                             ignore_invalid = FALSE, min_block_minutes = 30,
                             max_gap_minutes = 60,
                             smooth = c("rollmedian", "none")) {
  if (!is.null(threshold) &&
      (!missing(threshold_percentile) || !missing(threshold_multiplier))) {
    warning("`threshold` is set, so `threshold_percentile` and ",
            "`threshold_multiplier` are ignored.", call. = FALSE)
  }
  epoch_data <- .acti_sleep_raw_angles(data, epoch, smooth = smooth)
  out <- .acti_sleep_hdcza_angle(
    epoch_data$angle, time = epoch_data$time, threshold = threshold,
    threshold_percentile = threshold_percentile,
    threshold_multiplier = threshold_multiplier,
    invalid = epoch_data$invalid, ignore_invalid = ignore_invalid,
    min_block_minutes = min_block_minutes, max_gap_minutes = max_gap_minutes
  )
  out$epoch_data <- epoch_data
  out
}

.acti_sleep_hdcza_angle <- function(angle, time, threshold = NULL,
                                    threshold_percentile = 10,
                                    threshold_multiplier = 15,
                                    invalid = NULL, ignore_invalid = FALSE,
                                    min_block_minutes = 30,
                                    max_gap_minutes = 60) {
  angle <- .acti_sleep_check_vector(angle, "angle")
  n <- length(angle)
  epoch_seconds <- .acti_sleep_epoch_seconds(time)
  assertthat::assert_that(
    is.null(threshold) ||
      (assertthat::is.number(threshold) && is.finite(threshold) &&
         threshold >= 0),
    msg = "`threshold` must be `NULL` or one non-negative number of degrees."
  )
  assertthat::assert_that(
    assertthat::is.number(threshold_percentile),
    is.finite(threshold_percentile),
    threshold_percentile >= 1, threshold_percentile <= 100,
    msg = paste0("`threshold_percentile` must be one number between 1 and ",
                 "100 (e.g. 10 for the 10th percentile).")
  )
  assertthat::assert_that(
    assertthat::is.number(threshold_multiplier),
    is.finite(threshold_multiplier), threshold_multiplier > 0,
    msg = "`threshold_multiplier` must be one positive number."
  )
  if (is.null(invalid)) invalid <- rep(FALSE, n)
  assertthat::assert_that(
    assertthat::are_equal(length(invalid), n),
    msg = "`invalid` must match `angle`."
  )

  width <- max(1L, round(5 * 60 / epoch_seconds))
  assertthat::assert_that(
    width >= 2L,
    msg = paste0("HDCZA needs at least two angles per five-minute window; ",
                 "use an `epoch` of at most 200 seconds (e.g. \"5 seconds\").")
  )
  # As in GGIR: the median absolute angle change within each centred
  # five-minute window of angles
  rolling_change <- .acti_sleep_roll_apply(
    angle, width, function(x) stats::median(abs(diff(x)), na.rm = TRUE)
  )
  if (is.null(threshold)) {
    # GGIR's data-driven HDCZA threshold, bounded to 0.13--0.5 degrees
    threshold <- stats::quantile(rolling_change,
                                 probs = threshold_percentile / 100,
                                 names = FALSE, na.rm = TRUE) *
      threshold_multiplier
    threshold <- min(max(threshold, 0.13), 0.5)
  }
  low_movement <- rolling_change < threshold
  invalid <- as.logical(invalid)
  if (is.na(ignore_invalid)) {
    low_movement[invalid] <- TRUE
  } else if (isTRUE(ignore_invalid)) {
    low_movement[invalid] <- FALSE
  }

  blocks <- .acti_sleep_blocks(
    low_movement,
    min_block_epochs = 60 * min_block_minutes / epoch_seconds,
    max_gap_epochs = 60 * max_gap_minutes / epoch_seconds
  )
  method <- if (is.na(ignore_invalid) && any(invalid & blocks$selected)) {
    "HDCZA+invalid"
  } else {
    "HDCZA"
  }
  .acti_sleep_result(blocks$selected, method, threshold, blocks$crude,
                     list(angle_change = rolling_change,
                          low_movement = low_movement))
}

#' Identify a sleep window from horizontal posture
#'
#' @inheritParams acti_sleep_hdcza
#' @param epoch Epoch used to average raw angles, in seconds or a string
#'   such as `"5 seconds"`; see [actibase::acti_standardize_epoch()].
#' @param horizontal_threshold Absolute-angle limit defining horizontal posture.
#' @param longitudinal_axis Raw axis used as the longitudinal axis: `"X"`,
#'   `"Y"`, or `"Z"`.
#' @examples
#' \donttest{
#' raw <- actiread::acti_read_gt3x(actiread::acti_example_gt3x(), verbose = FALSE)
#' horizontal <- acti_sleep_horangle(raw, epoch = "5 seconds")
#' }
#' @export
#' @return An `acti_sleep_guider` object. `window` marks the longest selected
#'   horizontal-posture block, and `crude_window` marks all candidate blocks.
#'   `horizontal` is the epoch-level posture flag, `threshold` is the angle
#'   limit, and `epoch_data` contains the averaged angle and invalid flag.
acti_sleep_horangle <- function(data, epoch = "5 seconds", longitudinal_axis = "Z",
                                horizontal_threshold = 45, ignore_invalid = FALSE,
                                min_block_minutes = 30, max_gap_minutes = 60,
                                smooth = c("rollmedian", "none")) {
  epoch_data <- .acti_sleep_raw_angles(data, epoch, longitudinal_axis,
                                       smooth = smooth)
  out <- .acti_sleep_horangle_angle(
    epoch_data$angle, time = epoch_data$time,
    horizontal_threshold = horizontal_threshold, invalid = epoch_data$invalid,
    ignore_invalid = ignore_invalid, min_block_minutes = min_block_minutes,
    max_gap_minutes = max_gap_minutes
  )
  out$epoch_data <- epoch_data
  out
}

.acti_sleep_horangle_angle <- function(angle, time, horizontal_threshold = 45,
                                       invalid = NULL, ignore_invalid = FALSE,
                                       min_block_minutes = 30,
                                       max_gap_minutes = 60) {
  angle <- .acti_sleep_check_vector(angle, "angle")
  n <- length(angle)
  epoch_seconds <- .acti_sleep_epoch_seconds(time)
  if (is.null(invalid)) invalid <- rep(FALSE, n)
  assertthat::assert_that(
    assertthat::are_equal(length(invalid), n),
    msg = "`invalid` must match `angle`."
  )
  horizontal <- abs(angle) < horizontal_threshold
  invalid <- as.logical(invalid)
  if (is.na(ignore_invalid)) horizontal[invalid] <- TRUE
  if (isTRUE(ignore_invalid)) horizontal[invalid] <- FALSE
  blocks <- .acti_sleep_blocks(horizontal,
                               60 * min_block_minutes / epoch_seconds,
                               60 * max_gap_minutes / epoch_seconds)
  .acti_sleep_result(blocks$selected, "HorAngle", horizontal_threshold,
                     blocks$crude, list(horizontal = horizontal))
}

#' Identify a sleep window from the least-active five hours
#'
#' @param data A data frame of regular activity epochs.
#' @param l5_hours Duration of the least-active period.
#' @param window_hours Duration of the guider centred on L5.
#' @examplesIf rlang::is_installed("actimetrics")
#' # Repeat the bundled minute-level count data to form a complete example day.
#' data <- actimetrics::acti_count_data
#' data <- data[rep(seq_len(nrow(data)), length.out = 24 * 60), ]
#' data$time <- data$time[1] + (seq_len(nrow(data)) - 1) * 60
#' l5 <- acti_sleep_l5(data)
#' @export
#' @return An `acti_sleep_guider` object. `window` marks the window centred on
#'   the least-active period; `l5_start_index` and `l5_activity_sum` identify
#'   that period's starting epoch and total activity.
acti_sleep_l5 <- function(data, l5_hours = 5, window_hours = 12) {
  epoch_data <- .acti_sleep_activity_data(data)
  time <- epoch_data$time
  activity <- epoch_data$activity
  activity <- .acti_sleep_check_vector(activity, "activity")
  n <- length(activity)
  epoch_seconds <- .acti_sleep_epoch_seconds(time)
  l5_epochs <- round(l5_hours * 3600 / epoch_seconds)
  window_epochs <- round(window_hours * 3600 / epoch_seconds)
  if (l5_epochs < 1L || l5_epochs > n || window_epochs < l5_epochs) {
    stop("The requested L5/window durations are incompatible with the data.",
         call. = FALSE)
  }
  # Circular windows make an L5 period across midnight eligible.
  x <- c(activity, activity[seq_len(l5_epochs - 1L)])
  sums <- vapply(seq_len(n), function(i) sum(x[i:(i + l5_epochs - 1L)],
                                             na.rm = TRUE), numeric(1))
  l5_start <- which.min(sums)
  start <- ((l5_start - floor((window_epochs - l5_epochs) / 2) - 2L) %% n) + 1L
  window <- ((seq_len(n) - start) %% n) < window_epochs
  .acti_sleep_result(window, "L5+/-12", NA_real_, NULL,
                     list(l5_start_index = l5_start,
                          l5_activity_sum = sums[l5_start]))
}

#' Identify a fixed daily sleep window
#'
#' @param data A data frame containing timestamps.
#' @param start_hour,end_hour Start and end clock hours (0--24).
#' @return An `acti_sleep_guider` object.
#' @examplesIf rlang::is_installed("actimetrics")
#' data <- actimetrics::acti_count_data
#' fixed_window <- acti_sleep_setwindow(data, start_hour = 22, end_hour = 8)
#' @export
acti_sleep_setwindow <- function(data, start_hour = 22, end_hour = 8) {
  data <- .acti_sleep_epoch_data(data)
  time <- data$time
  assertthat::assert_that(inherits(time, "POSIXt"),
                          msg = "`time` must be a POSIXct/POSIXlt vector.")
  assertthat::assert_that(
    assertthat::is.number(start_hour), assertthat::is.number(end_hour),
    start_hour >= 0, start_hour <= 24, end_hour >= 0, end_hour <= 24,
    msg = "`start_hour` and `end_hour` must be between 0 and 24."
  )
  clock_hour <- as.numeric(format(time, "%H")) +
    as.numeric(format(time, "%M")) / 60 +
    as.numeric(format(time, "%S")) / 3600
  if (start_hour < end_hour) {
    window <- clock_hour >= start_hour & clock_hour < end_hour
  } else {
    window <- clock_hour >= start_hour | clock_hour < end_hour
  }
  .acti_sleep_result(window, "setwindow", NA_real_, NULL,
                     list(start_hour = start_hour, end_hour = end_hour))
}

#' Identify the longest rest bout from sustained inactivity bouts
#'
#' @param data A data frame of regular epochs.
#' @examplesIf rlang::is_installed("actimetrics")
#' data <- actimetrics::acti_count_data
#' data <- data[rep(seq_len(nrow(data)), length.out = 24 * 60), ]
#' data$time <- data$time[1] + (seq_len(nrow(data)) - 1) * 60
#' # In practice, use a validated SIB classification rather than this example.
#' sib <- data$counts == 0
#' data$sib <- data$counts == 0
#' longest_rest <- acti_sleep_hlrb(data)
#' @export
#' @return An `acti_sleep_guider` object. `window` marks the longest selected
#'   rest bout, `crude_window` marks all bouts before selection, and
#'   `smoothed_sib` is the logical SIB classification after two-hour smoothing.
acti_sleep_hlrb <- function(data) {
  data <- .acti_sleep_epoch_data(data, "sib")
  epoch_data <- data |>
    dplyr::transmute(time = .data$time, sib = .data$sib)
  time <- epoch_data$time
  sib <- epoch_data$sib
  assertthat::assert_that(
    is.numeric(sib) || is.logical(sib), assertthat::not_empty(sib),
    msg = "`sib` must be a non-empty numeric or logical vector."
  )
  sib <- as.logical(sib)
  n <- length(sib)
  epoch_seconds <- .acti_sleep_epoch_seconds(time)
  # The documented HLRB method uses a rounded, two-hour rolling average.
  k <- max(1L, round(2 * 3600 / epoch_seconds))
  smooth <- .acti_sleep_roll_apply(as.numeric(sib), k,
                                   function(x) mean(x, na.rm = TRUE)) >= 0.5
  r <- rle(c(FALSE, smooth, FALSE))
  interior <- .acti_sleep_interior_runs(r)
  short_wake <- interior[!r$values[interior] &
                           r$lengths[interior] < 3600 / epoch_seconds]
  if (length(short_wake)) r$values[short_wake] <- TRUE
  crude <- rep(r$values, r$lengths)[-c(1L, n + 2L)]
  blocks <- .acti_sleep_blocks(crude, 0, 0)
  .acti_sleep_result(blocks$selected, "HLRB", NA_real_, crude,
                     list(smoothed_sib = smooth))
}

#' Identify a low-activity window for no-night-wear protocols
#'
#' @param data A data frame of regular activity epochs.
#' @param min_block_minutes Minimum duration of a low-activity block.
#' @param max_gap_minutes Maximum interruption bridged between blocks.
#' @examplesIf rlang::is_installed("actimetrics")
#' data <- actimetrics::acti_count_data
#' data <- data[rep(seq_len(nrow(data)), length.out = 24 * 60), ]
#' data$time <- data$time[1] + (seq_len(nrow(data)) - 1) * 60
#' # `counts` is an epoch-level activity metric.
#' no_night_wear <- acti_sleep_notworn(data)
#' @export
#' @return An `acti_sleep_guider` object. `window` marks the longest selected
#'   low-activity block, and `crude_window` marks all candidate blocks.
#'   `smoothed_activity` contains five-minute rolling activity values,
#'   `low_activity` flags candidate epochs, and `threshold` is the activity
#'   cutoff used to identify them.
acti_sleep_notworn <- function(data, min_block_minutes = 30,
                               max_gap_minutes = 60) {
  epoch_data <- .acti_sleep_activity_data(data)
  time <- epoch_data$time
  activity <- epoch_data$activity
  invalid <- epoch_data$invalid
  activity <- .acti_sleep_check_vector(activity, "activity")
  n <- length(activity)
  epoch_seconds <- .acti_sleep_epoch_seconds(time)
  assertthat::assert_that(
    assertthat::are_equal(length(invalid), n),
    msg = "`invalid` must match `activity`."
  )
  width <- max(1L, round(5 * 60 / epoch_seconds))
  smooth <- stats::filter(activity, rep(1 / width, width), sides = 2,
                          circular = TRUE)
  smooth <- as.numeric(smooth)
  nonzero <- smooth[smooth != 0 & is.finite(smooth)]
  threshold <- if (length(nonzero)) 0.05 * stats::sd(nonzero) else 0
  if (length(nonzero) && threshold < min(activity, na.rm = TRUE)) {
    threshold <- stats::quantile(smooth, 0.1, na.rm = TRUE, names = FALSE)
  }
  low_activity <- smooth < threshold + 0.001 | as.logical(invalid)
  blocks <- .acti_sleep_blocks(low_activity,
                               60 * min_block_minutes / epoch_seconds,
                               60 * max_gap_minutes / epoch_seconds)
  .acti_sleep_result(blocks$selected, "NotWorn", threshold, blocks$crude,
                     list(smoothed_activity = smooth,
                          low_activity = low_activity))
}

#' Identify a diary-defined sleep window
#'
#' @param data A data frame containing timestamps.
#' @param onset,wakeup POSIXct values defining a diary sleep window.
#' @return An `acti_sleep_guider` object. Missing diary times return an empty
#'   window rather than imputing either boundary.
#' @examplesIf rlang::is_installed("actimetrics")
#' data <- actimetrics::acti_count_data
#' diary_window <- acti_sleep_diary(
#'   data, onset = data$time[5], wakeup = data$time[30]
#' )
#' @export
acti_sleep_diary <- function(data, onset, wakeup) {
  data <- .acti_sleep_epoch_data(data)
  time <- data$time
  assertthat::assert_that(inherits(time, "POSIXt"),
                          msg = "`time` must be POSIXct/POSIXlt.")
  assertthat::assert_that(
    assertthat::is.scalar(onset), assertthat::is.scalar(wakeup),
    msg = "`onset` and `wakeup` must each contain one timestamp."
  )
  if (is.na(onset) || is.na(wakeup)) {
    return(.acti_sleep_result(rep(FALSE, length(time)), "sleeplog"))
  }
  if (wakeup < onset) stop("`wakeup` must not precede `onset`.", call. = FALSE)
  .acti_sleep_result(time >= onset & time <= wakeup, "sleeplog",
                     details = list(onset = onset, wakeup = wakeup))
}

#' Describe data requirements for sleep guiders
#'
#' HDCZA and HorAngle take raw triaxial acceleration and create their own
#' regular epoch-level angle. All other guiders take a regularly spaced,
#' epoch-level data frame and do not require raw acceleration data.
#'
#' @return A tibble describing the required data for each guider.
#' @examples
#' acti_sleep_guider_requirements()
#' @export
acti_sleep_guider_requirements <- function() {
  tibble::tibble(
    method = c("HDCZA", "HorAngle", "L5", "setwindow", "HLRB", "NotWorn", "sleeplog"),
    required_epoch_columns = c(
      "time, X, Y, Z", "time, X, Y, Z", "time, activity", "time",
      "time, sib", "time, activity", "time"
    ),
    raw_acceleration = c(
      TRUE, TRUE, FALSE, FALSE, FALSE, FALSE, FALSE
    ),
    input_description = c(
      "Raw wrist acceleration. The function derives and averages the Z-axis angle.",
      "Raw hip acceleration. The function derives and averages the longitudinal-axis angle.",
      "Any regular epoch-level activity metric, such as counts or ENMO.",
      "Timestamps only; identifies a fixed clock-time window.",
      "A regular epoch-level sustained-inactivity-bout (SIB) classification.",
      "Any regular epoch-level activity metric, such as counts or ENMO.",
      "Timestamps plus `onset` and `wakeup` supplied as arguments."
    )
  )
}

#' Dispatch a sleep-period-time guider from data
#'
#' For `"HDCZA"` and `"HorAngle"`, supply raw triaxial acceleration; the
#' selected function derives a regular epoch-level posture angle. The remaining
#' methods use regular epoch-level activity, SIB, or timestamp data.
#' Use `acti_sleep_guider_requirements()` for a method-by-method summary.
#'
#' @param data A raw or epoch-level data frame, according to `method`.
#' @param method One of `"HDCZA"`, `"HorAngle"`, `"L5"`, `"setwindow"`,
#'   `"HLRB"`, `"NotWorn"`, or `"sleeplog"`.
#' @param ... Method-specific arguments, such as `threshold`, `start_hour`,
#'   `onset`, and `wakeup`.
#' @return An `acti_sleep_guider` object.
#' @examplesIf rlang::is_installed("actimetrics")
#' data <- actimetrics::acti_count_data
#' data <- data[rep(seq_len(nrow(data)), length.out = 24 * 60), ]
#' data$time <- data$time[1] + (seq_len(nrow(data)) - 1) * 60
#' guider <- acti_sleep_guider(data, method = "L5")
#' @export
acti_sleep_guider <- function(data,
                              method = c("HDCZA", "HorAngle", "L5",
                                         "setwindow", "HLRB", "NotWorn",
                                         "sleeplog"),
                              ...) {
  method <- match.arg(method)
  assertthat::assert_that(is.data.frame(data),
    msg = "`data` must be a data frame.")

  switch(method,
    HDCZA = acti_sleep_hdcza(data, ...),
    HorAngle = acti_sleep_horangle(data, ...),
    L5 = acti_sleep_l5(data, ...),
    setwindow = acti_sleep_setwindow(data, ...),
    HLRB = acti_sleep_hlrb(data, ...),
    NotWorn = acti_sleep_notworn(data, ...),
    sleeplog = acti_sleep_diary(data, ...)
  )
}

.acti_sleep_runs <- function(x) {
  run_id <- cumsum(c(TRUE, diff(as.integer(x)) != 0L))
  split(seq_along(x), run_id)
}

#' Convert a sleep guider to epoch-level sleep/wake labels
#'
#' A guider defines the likely main sleep window; it is not a sleep/wake
#' classifier itself. This function applies GGIR's final overlap step to a
#' sustained-inactivity-bout (`sib`) classification. With the default
#' `"SPT"` rule, an entire SIB is sleep when any part overlaps the guider. With
#' `"TimeInBed"`, an SIB must be wholly inside the guider.
#'
#' @param sib Logical or 0/1 sustained-inactivity-bout classification at the
#'   same regular epochs as `guider$window`.
#' @param guider An `acti_sleep_guider` object.
#' @param sleepwindow_type Whether the guider approximates sleep-period time
#'   (`"SPT"`) or time in bed (`"TimeInBed"`).
#' @return A logical vector: `TRUE` for sleep and `FALSE` for wake.
#' @examplesIf rlang::is_installed("actimetrics")
#' data <- actimetrics::acti_count_data
#' data <- data[rep(seq_len(nrow(data)), length.out = 24 * 60), ]
#' data$time <- data$time[1] + (seq_len(nrow(data)) - 1) * 60
#' guider <- acti_sleep_l5(data)
#' sib <- data$counts == 0
#' sleep <- acti_sleep_label(sib, guider)
#' @export
acti_sleep_label <- function(sib, guider,
                             sleepwindow_type = c("SPT", "TimeInBed")) {
  sleepwindow_type <- match.arg(sleepwindow_type)
  assertthat::assert_that(inherits(guider, "acti_sleep_guider"),
    msg = "`guider` must be an `acti_sleep_guider` object.")
  assertthat::assert_that(is.logical(sib) || is.numeric(sib),
    msg = "`sib` must be a logical or numeric vector.")
  sib <- as.logical(sib)
  window <- as.logical(guider$window)
  assertthat::assert_that(assertthat::are_equal(length(sib), length(window)),
    msg = "`sib` and `guider$window` must have the same number of epochs.")

  sleep <- rep(FALSE, length(sib))
  for (indices in .acti_sleep_runs(sib)) {
    if (!sib[indices[1L]]) next
    overlaps <- window[indices]
    qualifies <- if (sleepwindow_type == "SPT") any(overlaps) else all(overlaps)
    if (qualifies) sleep[indices] <- TRUE
  }
  sleep
}

#' Create sleep/wake labels for multiple guiders
#'
#' @param sib Logical or 0/1 sustained-inactivity-bout classification.
#' @param guiders A named list of `acti_sleep_guider` objects. All guider
#'   windows must use the same epoch grid as `sib`.
#' @param sleepwindow_type The SPT or TimeInBed overlap rule.
#' @return A tibble with one logical `sleep_<guider>` column per guider.
#' @examplesIf rlang::is_installed("actimetrics")
#' data <- actimetrics::acti_count_data
#' data <- data[rep(seq_len(nrow(data)), length.out = 24 * 60), ]
#' data$time <- data$time[1] + (seq_len(nrow(data)) - 1) * 60
#' guiders <- list(L5 = acti_sleep_l5(data), fixed = acti_sleep_setwindow(data))
#' labels <- acti_sleep_labels(data$counts == 0, guiders)
#' @export
acti_sleep_labels <- function(sib, guiders,
                              sleepwindow_type = c("SPT", "TimeInBed")) {
  sleepwindow_type <- match.arg(sleepwindow_type)
  assertthat::assert_that(is.list(guiders), assertthat::not_empty(guiders),
    msg = "`guiders` must be a non-empty list of guider objects.")
  names_guiders <- names(guiders)
  if (is.null(names_guiders) || any(!nzchar(names_guiders))) {
    names_guiders <- vapply(guiders, `[[`, character(1), "method")
  }
  labels <- lapply(guiders, function(guider) {
    acti_sleep_label(sib, guider, sleepwindow_type)
  })
  names(labels) <- paste0("sleep_", make.unique(names_guiders))
  tibble::as_tibble(labels)
}

.acti_sleep_staple <- function(labels, tolerance = 1e-6, max_iterations = 200L) {
  labels <- as.matrix(labels)
  storage.mode(labels) <- "numeric"
  assertthat::assert_that(ncol(labels) >= 2L,
    msg = "STAPLE requires labels from at least two guiders.")
  assertthat::assert_that(all(labels %in% c(0, 1)),
    msg = "STAPLE labels must be binary without missing values.")
  prevalence <- mean(labels)
  sensitivity <- rep(0.99, ncol(labels))
  specificity <- rep(0.99, ncol(labels))
  posterior <- rep(prevalence, nrow(labels))

  for (iteration in seq_len(max_iterations)) {
    previous <- posterior
    log_sleep <- log(pmax(prevalence, .Machine$double.eps)) +
      rowSums(sweep(labels, 2L, log(pmax(sensitivity, .Machine$double.eps)), `*`) +
        sweep(1 - labels, 2L, log(pmax(1 - sensitivity, .Machine$double.eps)), `*`))
    log_wake <- log(pmax(1 - prevalence, .Machine$double.eps)) +
      rowSums(sweep(labels, 2L, log(pmax(1 - specificity, .Machine$double.eps)), `*`) +
        sweep(1 - labels, 2L, log(pmax(specificity, .Machine$double.eps)), `*`))
    # Stabilise the posterior calculation on long epoch series.
    offset <- pmax(log_sleep, log_wake)
    posterior <- exp(log_sleep - offset) /
      (exp(log_sleep - offset) + exp(log_wake - offset))
    prevalence <- mean(posterior)
    sensitivity <- colSums(labels * posterior) / pmax(sum(posterior), .Machine$double.eps)
    specificity <- colSums((1 - labels) * (1 - posterior)) /
      pmax(sum(1 - posterior), .Machine$double.eps)
    if (max(abs(posterior - previous)) < tolerance) break
  }
  list(probability = posterior, sensitivity = sensitivity, specificity = specificity,
       prevalence = prevalence, iterations = iteration)
}

#' Fuse multiple sleep/wake labels with STAPLE
#'
#' STAPLE estimates a latent consensus sleep label and each input labeler's
#' sensitivity and specificity using expectation-maximisation.
#'
#' @param labels A data frame, matrix, or tibble of logical/binary sleep-label
#'   columns, such as the output of `acti_sleep_labels()`.
#' @param threshold Posterior sleep-probability threshold for the fused label.
#' @param tolerance,max_iterations STAPLE convergence controls.
#' @return A tibble with `sleep_probability` and binary `sleep` columns. If
#'   `labels` includes `time` or `epoch`, that index is retained. The fitted
#'   STAPLE parameters are attached as the `staple` attribute.
#' @examples
#' labels <- data.frame(
#'   sleep_l5 = c(FALSE, TRUE, TRUE, FALSE),
#'   sleep_fixed = c(FALSE, TRUE, FALSE, FALSE)
#' )
#' acti_sleep_fuse_labels(labels)
#' @export
acti_sleep_fuse_labels <- function(labels, threshold = 0.5, tolerance = 1e-6,
                                   max_iterations = 200L) {
  assertthat::assert_that(is.data.frame(labels) || is.matrix(labels),
    msg = "`labels` must be a data frame or matrix of binary sleep labels.")
  assertthat::assert_that(assertthat::is.number(threshold), threshold >= 0,
                          threshold <= 1,
    msg = "`threshold` must be a number between 0 and 1.")
  index_name <- intersect(c("time", "epoch"), colnames(labels))
  label_columns <- setdiff(colnames(labels), index_name)
  assertthat::assert_that(length(label_columns) >= 2L,
    msg = "`labels` must contain at least two binary sleep-label columns.")
  fit <- .acti_sleep_staple(labels[, label_columns, drop = FALSE], tolerance,
                            max_iterations)
  output <- tibble::tibble(
    sleep_probability = fit$probability,
    sleep = fit$probability >= threshold
  )
  if (length(index_name)) {
    output <- dplyr::bind_cols(labels[, index_name, drop = FALSE], output)
  }
  attr(output, "staple") <- fit[c("sensitivity", "specificity", "prevalence", "iterations")]
  output
}

.acti_sleep_vanhees_sib <- function(angle, epoch_seconds, time_threshold_minutes = 5,
                                    angle_threshold = 5) {
  sib <- rep(FALSE, length(angle))
  posture_changes <- which(abs(diff(angle)) > angle_threshold)
  separated_changes <- which(diff(posture_changes) >
    time_threshold_minutes * 60 / epoch_seconds)
  if (length(separated_changes)) {
    for (index in separated_changes) {
      sib[posture_changes[index]:posture_changes[index + 1L]] <- TRUE
    }
  } else if (length(posture_changes) < 10L) {
    sib[] <- TRUE
  }
  sib
}

#' Detect sustained inactivity bouts (SIBs)
#'
#' For raw triaxial accelerometer data, the default `"vanHees2015"` method
#' derives a longitudinal-axis angle at `epoch` resolution and identifies
#' periods with no posture change above `angle_threshold`. For epoch-level data,
#' provide a precomputed `sib` column; alternatively, `"low_activity"` marks
#' epochs whose conventional activity metric is at or below `activity_threshold`.
#'
#' @param data Raw triaxial or regular epoch-level data.
#' @param method SIB method: `"vanHees2015"` or `"low_activity"`.
#' @param epoch Raw-data aggregation epoch, in seconds or a string such as
#'   `"5 seconds"`; see [actibase::acti_standardize_epoch()].
#' @param time_threshold_minutes,angle_threshold van Hees posture-change
#'   parameters.
#' @param activity_threshold Low-activity cutoff for epoch data.
#' @inheritParams acti_sleep_hdcza
#' @return A tibble with `time`, `sib`, and supporting epoch-level variables.
#' @examples
#' \donttest{
#' raw <- actiread::acti_read_gt3x(actiread::acti_example_gt3x(), verbose = FALSE)
#' sib <- acti_sleep_sib(raw)
#' }
#' @export
acti_sleep_sib <- function(data, method = c("vanHees2015", "low_activity"),
                           epoch = "5 seconds", time_threshold_minutes = 5,
                           angle_threshold = 5, activity_threshold = 0,
                           smooth = c("rollmedian", "none")) {
  method <- match.arg(method)
  standard <- actibase::acti_standardize_data(
    data, subset_xyz = FALSE, check_xyz = FALSE
  )
  raw <- all(c("X", "Y", "Z") %in% names(standard))

  if (method == "vanHees2015") {
    assertthat::assert_that(raw,
      msg = "`vanHees2015` requires raw triaxial acceleration (X, Y, and Z).")
    epochs <- .acti_sleep_raw_angles(data, epoch, smooth = smooth)
    epoch_seconds <- .acti_sleep_epoch_seconds(epochs$time)
    epochs$sib <- .acti_sleep_vanhees_sib(
      epochs$angle, epoch_seconds, time_threshold_minutes, angle_threshold
    )
    return(epochs)
  }

  epochs <- .acti_sleep_epoch_data(data)
  if ("sib" %in% names(epochs)) {
    return(epochs |>
      dplyr::transmute(time = .data$time, sib = as.logical(.data$sib)))
  }
  activity <- .acti_sleep_activity_data(epochs)
  activity |>
    dplyr::transmute(time = .data$time, sib = .data$activity <= activity_threshold)
}

#' Run a sleep-label ensemble from raw or epoch data
#'
#' This convenience workflow detects or accepts sustained inactivity bouts,
#' runs compatible sleep guiders, creates one sleep label per guider, then
#' produces a consensus. Raw triaxial data use `HDCZA`, `HorAngle`, and a fixed
#' 22:00--08:00 window by default; `L5` is included only when the data span its
#' requested duration. Epoch data use `NotWorn` and the fixed window, adding
#' `L5` when possible. Set `guiders` to choose a subset explicitly.
#'
#' @param data Raw triaxial or regular epoch-level data. Epoch data should have
#'   a `sib` column or a conventional activity column.
#' @param guiders Guider names. Defaults depend on whether raw acceleration is
#'   available.
#' @param epoch Raw-data aggregation epoch, in seconds or a string such as
#'   `"5 seconds"`; see [actibase::acti_standardize_epoch()].
#' @param sib_method SIB method, passed to `acti_sleep_sib()`.
#' @param fusion Consensus rule: `"staple"` or `"majority"`.
#' @param sleepwindow_type SPT or TimeInBed overlap rule.
#' @inheritParams acti_sleep_hdcza
#' @param ... Passed to the individual guider functions.
#' @return A list of time-indexed data. `epoch_data` includes the van Hees
#'   `sib`; each guider has a `label_data` element with `time` and `window`;
#'   `labels` has `time` plus one logical `sleep_<guider>` column per guider;
#'   `fused` has `time`, probability, and consensus label; and `label_data`
#'   combines all these analysis columns.
#' @examples
#' \donttest{
#' raw <- actiread::acti_read_gt3x(actiread::acti_example_gt3x(), verbose = FALSE)
#' result <- acti_sleep_ensemble(raw)
#' }
#' @export
acti_sleep_ensemble <- function(data, guiders = NULL, epoch = "5 seconds",
                                sib_method = "vanHees2015",
                                fusion = c("staple", "majority"),
                                sleepwindow_type = c("SPT", "TimeInBed"),
                                smooth = c("rollmedian", "none"), ...) {
  fusion <- match.arg(fusion)
  smooth <- match.arg(smooth)
  sleepwindow_type <- match.arg(sleepwindow_type)
  epoch <- actibase::acti_standardize_epoch(epoch, output = "character")
  standard <- actibase::acti_standardize_data(
    data, subset_xyz = FALSE, check_xyz = FALSE
  )
  raw <- all(c("X", "Y", "Z") %in% names(standard))
  if (!raw && identical(sib_method, "vanHees2015")) {
    sib_method <- "low_activity"
  }
  # Smooth once for all angle-based steps; ENMO below uses the raw axes.
  angle_data <- data
  if (raw && smooth == "rollmedian") {
    angle_data <- .acti_sleep_smooth_axes(data)
    smooth <- "none"
  }
  if (is.null(guiders)) {
    default_guiders <- if (raw) c("HDCZA", "HorAngle", "setwindow") else {
      c("NotWorn", "setwindow")
    }
    l5_hours <- list(...)[["l5_hours"]]
    if (is.null(l5_hours)) l5_hours <- 5
    candidate_epochs <- if (raw) {
      .acti_sleep_raw_angles(angle_data, epoch, smooth = smooth)
    } else {
      .acti_sleep_epoch_data(data)
    }
    has_l5 <- nrow(candidate_epochs) >=
      round(l5_hours * 3600 / .acti_sleep_epoch_seconds(candidate_epochs$time))
    guiders <- if (has_l5) c(default_guiders, "L5") else default_guiders
  }
  assertthat::assert_that(all(guiders %in%
    c("HDCZA", "HorAngle", "L5", "NotWorn", "setwindow")),
    msg = "`guiders` contains an unsupported ensemble guider.")

  sib_data <- acti_sleep_sib(
    if (identical(sib_method, "vanHees2015")) angle_data else data,
    method = sib_method, epoch = epoch, smooth = smooth
  )
  epoch_data <- sib_data
  if (!raw) {
    activity_data <- .acti_sleep_activity_data(data) |>
      dplyr::select("time", "activity")
    epoch_data <- dplyr::left_join(epoch_data, activity_data, by = "time")
  }
  if (!"activity" %in% names(epoch_data) && raw) {
    raw_epochs <- actibase::acti_standardize_data(
      data, subset_xyz = FALSE, check_xyz = TRUE
    ) |>
      dplyr::mutate(
        .epoch = lubridate::floor_date(.data$time, epoch),
        .enmo = pmax(sqrt(.data$X^2 + .data$Y^2 + .data$Z^2) - 1, 0)
      ) |>
      dplyr::group_by(.data$.epoch) |>
      dplyr::summarise(time = dplyr::first(.data$.epoch),
                       activity = mean(.data$.enmo, na.rm = TRUE), .groups = "drop")
    epoch_data <- dplyr::left_join(epoch_data, raw_epochs, by = "time")
  }

  guider_objects <- lapply(guiders, function(method) {
    switch(method,
      HDCZA = acti_sleep_hdcza(angle_data, epoch = epoch, smooth = smooth, ...),
      HorAngle = acti_sleep_horangle(angle_data, epoch = epoch,
                                     smooth = smooth, ...),
      L5 = acti_sleep_l5(epoch_data, ...),
      NotWorn = acti_sleep_notworn(epoch_data, ...),
      setwindow = acti_sleep_setwindow(epoch_data, ...)
    )
  })
  names(guider_objects) <- guiders
  guider_objects <- lapply(guider_objects, function(guider) {
    guider$label_data <- tibble::tibble(
      time = epoch_data$time,
      window = guider$window,
      crude_window = guider$crude_window
    )
    guider
  })
  label_indicators <- acti_sleep_labels(
    epoch_data$sib, guider_objects, sleepwindow_type
  )
  labels <- dplyr::bind_cols(
    dplyr::select(epoch_data, "time"), label_indicators
  )
  fused <- if (fusion == "staple") {
    acti_sleep_fuse_labels(labels)
  } else {
    probability <- rowMeans(as.matrix(label_indicators))
    dplyr::bind_cols(
      dplyr::select(epoch_data, "time"),
      tibble::tibble(sleep_probability = probability, sleep = probability >= 0.5)
    )
  }
  label_data <- dplyr::bind_cols(
    dplyr::select(epoch_data, "time", "sib"), label_indicators,
    dplyr::select(fused, -"time")
  )
  list(epoch_data = epoch_data, guiders = guider_objects, labels = labels,
       fused = fused, label_data = label_data, fusion = fusion)
}
