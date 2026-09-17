# Summarize sleep periods with Tudor–Locke

Coerces actisomni-style epoch data to an `actigraph.sleepr` `tbl_agd`
and delegates period detection and metric calculation to
[`actigraph.sleepr::apply_tudor_locke()`](https://rdrr.io/pkg/actigraph.sleepr/man/apply_tudor_locke.html).
This avoids maintaining a separate implementation of the Tudor–Locke
rules.

## Usage

``` r
acti_sleep_tudor_locke(
  data,
  time_col = "time",
  activity_col = NULL,
  sleep_col = "sleep",
  id_col = NULL,
  n_bedtime_start = 5,
  n_wake_time_end = 10,
  min_sleep_period = 160,
  max_sleep_period = 1440,
  min_nonzero_epochs = 0
)
```

## Arguments

- data:

  Epoch-level data with timestamp, activity-count, and sleep-label
  columns.

- time_col:

  Name of the POSIXct timestamp column.

- activity_col:

  Name of the non-negative activity-count column. When `NULL`, the first
  of `activity`, `counts`, `axis1`, or `count` is used.

- sleep_col:

  Name of a logical sleep column or a character column using `S`/`W` or
  `sleep`/`wake` labels. Use
  [`acti_sleep_tudor_locke_diary()`](https://jhuwit.github.io/actisomni/reference/acti_sleep_tudor_locke_diary.md)
  to create this column from a sleep diary.

- id_col:

  Optional recording identifier column.

- n_bedtime_start:

  Minimum consecutive sleep epochs required to begin a sleep period.

- n_wake_time_end:

  Wake epochs shorter than this are absorbed into sleep.

- min_sleep_period:

  Minimum retained sleep-period duration, in minutes.

- max_sleep_period:

  Maximum retained sleep-period duration, in minutes.

- min_nonzero_epochs:

  Minimum nonzero activity epochs in a retained period.

## Value

A tibble of Tudor–Locke sleep periods and metrics, as returned by
[`actigraph.sleepr::apply_tudor_locke()`](https://rdrr.io/pkg/actigraph.sleepr/man/apply_tudor_locke.html).

## Examples

``` r
time <- as.POSIXct("2020-01-01", tz = "UTC") + 0:299 * 60
epochs <- data.frame(time = time, activity = 0, sleep = TRUE)
acti_sleep_tudor_locke(epochs)
#> # A tibble: 1 × 15
#>   in_bed_time         out_bed_time        onset               latency efficiency
#>   <dttm>              <dttm>              <dttm>                <int>      <dbl>
#> 1 2020-01-01 00:00:00 2020-01-01 05:00:00 2020-01-01 00:00:00       0        100
#> # ℹ 10 more variables: duration <int>, activity_counts <int>,
#> #   nonzero_epochs <int>, total_sleep_time <int>, wake_after_onset <int>,
#> #   nb_awakenings <int>, ave_awakening <dbl>, movement_index <dbl>,
#> #   fragmentation_index <dbl>, sleep_fragmentation_index <dbl>
```
