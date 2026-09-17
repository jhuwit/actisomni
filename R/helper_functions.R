# Tudor--Locke sleep periods --------------------------------------------------

.acti_sleep_tudor_locke_diary_sleep <- function(time, diary, diary_onset_col,
                                                 diary_wakeup_col) {
  assertthat::assert_that(
    is.data.frame(diary),
    all(c(diary_onset_col, diary_wakeup_col) %in% names(diary)),
    msg = paste0("`sleep_diary` must contain its selected onset and wakeup ",
                 "columns.")
  )
  onset <- diary[[diary_onset_col]]
  wakeup <- diary[[diary_wakeup_col]]
  assertthat::assert_that(
    inherits(onset, "POSIXt"), inherits(wakeup, "POSIXt"),
    !anyNA(onset), !anyNA(wakeup), all(wakeup > onset),
    msg = "Diary onset and wakeup columns must be complete POSIXct times with wakeup after onset."
  )
  sleep <- rep(FALSE, length(time))
  for (i in seq_len(nrow(diary))) {
    sleep <- sleep | (time >= onset[i] & time < wakeup[i])
  }
  sleep
}

#' Apply a sleep diary to epoch data for Tudor--Locke
#'
#' Adds a logical sleep column to epoch data from diary onset and wakeup times.
#' The resulting data can be passed directly to [acti_sleep_tudor_locke()].
#'
#' @param data Epoch-level data containing a POSIXct timestamp column.
#' @param sleep_diary A data frame with POSIXct sleep onset and wakeup columns.
#'   Each interval may span midnight; multiple days are supported.
#' @param time_col Name of the POSIXct timestamp column in `data`.
#' @param diary_onset_col Name of the diary onset column.
#' @param diary_wakeup_col Name of the diary wakeup column.
#' @param sleep_col Name of the logical sleep column to add or replace.
#' @return `data` with a logical `sleep_col`, `TRUE` from onset (inclusive) to
#'   wakeup (exclusive).
#' @export
acti_sleep_tudor_locke_diary <- function(data, sleep_diary, time_col = "time",
                                         diary_onset_col = "onset",
                                         diary_wakeup_col = "wakeup",
                                         sleep_col = "sleep") {
  assertthat::assert_that(
    is.data.frame(data), time_col %in% names(data),
    inherits(data[[time_col]], "POSIXt"), !anyNA(data[[time_col]]),
    msg = "`data` must contain a complete POSIXct time column."
  )
  data[[sleep_col]] <- .acti_sleep_tudor_locke_diary_sleep(
    time = data[[time_col]], diary = sleep_diary,
    diary_onset_col = diary_onset_col,
    diary_wakeup_col = diary_wakeup_col
  )
  data
}

.acti_sleep_tudor_locke_data <- function(data, time_col, activity_col,
                                         sleep, id_col = NULL) {
  assertthat::assert_that(
    is.data.frame(data),
    all(c(time_col, activity_col) %in% names(data)),
    is.null(id_col) || id_col %in% names(data),
    msg = paste0("`data` must contain the selected time and activity columns ",
                 "(and `id_col`, when supplied).")
  )
  time <- data[[time_col]]
  activity <- data[[activity_col]]
  assertthat::assert_that(
    inherits(time, "POSIXt"), is.numeric(activity),
    !anyNA(time), all(is.finite(activity) & activity >= 0),
    length(sleep) == nrow(data), !anyNA(sleep),
    msg = paste0("The time column must be POSIXct; activity must contain ",
                 "non-negative finite values; and sleep must not contain missing values.")
  )

  sleep <- if (is.logical(sleep)) {
    ifelse(sleep, "S", "W")
  } else {
    label <- tolower(trimws(as.character(sleep)))
    ifelse(label %in% c("s", "sleep", "asleep"), "S",
           ifelse(label %in% c("w", "wake", "awake"), "W", NA_character_))
  }
  assertthat::assert_that(
    !anyNA(sleep),
    msg = "Sleep labels must be logical or contain only sleep/wake labels."
  )

  out <- tibble::tibble(timestamp = as.POSIXct(time, tz = "UTC"),
                        axis1 = as.numeric(activity), sleep = sleep)
  if (!is.null(id_col)) out[[id_col]] <- data[[id_col]]
  groups <- if (is.null(id_col)) list(out) else split(out, out[[id_col]], drop = TRUE)
  valid_time <- vapply(groups, function(x) {
    nrow(x) >= 2L && all(diff(as.numeric(x$timestamp)) == 60)
  }, logical(1))
  assertthat::assert_that(
    all(valid_time),
    msg = paste0("Each recording must have at least two strictly increasing, ",
                 "complete 60-second epochs for Tudor--Locke.")
  )
  out
}

#' Summarize sleep periods with Tudor--Locke
#'
#' Coerces actisomni-style epoch data to an `actigraph.sleepr` `tbl_agd` and
#' delegates period detection and metric calculation to
#' [actigraph.sleepr::apply_tudor_locke()]. This avoids maintaining a separate
#' implementation of the Tudor--Locke rules.
#'
#' @param data Epoch-level data with timestamp, activity-count, and sleep-label
#'   columns.
#' @param time_col Name of the POSIXct timestamp column.
#' @param activity_col Name of the non-negative activity-count column. When
#'   `NULL`, the first of `activity`, `counts`, `axis1`, or `count` is used.
#' @param sleep_col Name of a logical sleep column or a character column using
#'   `S`/`W` or `sleep`/`wake` labels. Use [acti_sleep_tudor_locke_diary()] to
#'   create this column from a sleep diary.
#' @param id_col Optional recording identifier column.
#' @param n_bedtime_start Minimum consecutive sleep epochs required to begin a
#'   sleep period.
#' @param n_wake_time_end Wake epochs shorter than this are absorbed into sleep.
#' @param min_sleep_period Minimum retained sleep-period duration, in minutes.
#' @param max_sleep_period Maximum retained sleep-period duration, in minutes.
#' @param min_nonzero_epochs Minimum nonzero activity epochs in a retained
#'   period.
#' @return A tibble of Tudor--Locke sleep periods and metrics, as returned by
#'   [actigraph.sleepr::apply_tudor_locke()].
#' @examples
#' time <- as.POSIXct("2020-01-01", tz = "UTC") + 0:299 * 60
#' epochs <- data.frame(time = time, activity = 0, sleep = TRUE)
#' acti_sleep_tudor_locke(epochs)
#' @export
acti_sleep_tudor_locke <- function(data, time_col = "time", activity_col = NULL,
                                   sleep_col = "sleep", id_col = NULL,
                                   n_bedtime_start = 5, n_wake_time_end = 10,
                                   min_sleep_period = 160,
                                   max_sleep_period = 1440,
                                   min_nonzero_epochs = 0) {
  if (is.null(activity_col)) {
    activity_col <- intersect(c("activity", "counts", "axis1", "count"), names(data))[1L]
  }
  assertthat::assert_that(
    !is.na(activity_col),
    all(vapply(
      list(n_bedtime_start, n_wake_time_end, min_sleep_period,
           max_sleep_period, min_nonzero_epochs),
      function(x) is.numeric(x) && length(x) == 1L && is.finite(x) && x >= 0,
      logical(1)
    )),
    min_sleep_period <= max_sleep_period,
    msg = paste0("Supply an activity column, non-negative scalar Tudor--Locke ",
                 "parameters, and `min_sleep_period <= max_sleep_period`.")
  )
  assertthat::assert_that(sleep_col %in% names(data),
    msg = "`data` must contain `sleep_col`; use `acti_sleep_tudor_locke_diary()` for diary data.")
  sleep <- data[[sleep_col]]
  agd_data <- .acti_sleep_tudor_locke_data(
    data, time_col, activity_col, sleep, id_col
  )
  agdb <- actigraph.sleepr::tbl_agd(
    agd_data, settings = data.frame(epochlength = 60L)
  )
  if (!is.null(id_col)) agdb <- dplyr::group_by(agdb, .data[[id_col]])
  actigraph.sleepr::apply_tudor_locke(
    agdb,
    n_bedtime_start = n_bedtime_start,
    n_wake_time_end = n_wake_time_end,
    min_sleep_period = min_sleep_period,
    max_sleep_period = max_sleep_period,
    min_nonzero_epochs = min_nonzero_epochs
  )
}
