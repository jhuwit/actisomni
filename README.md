
<!-- README.md is generated from README.Rmd. Please edit that file -->

<!-- badges: start -->

[![R-CMD-check](https://github.com/jhuwit/actisomni/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/jhuwit/actisomni/actions/workflows/R-CMD-check.yaml)
[![Codecov test
coverage](https://codecov.io/gh/jhuwit/actisomni/branch/main/graph/badge.svg)](https://app.codecov.io/gh/jhuwit/actisomni?branch=main)
<!-- badges: end -->

# actisomni

`actisomni` estimates sleep from wrist-worn accelerometry. It provides
sleep-period-time (SPT) guiders, sustained-inactivity-bout (SIB) labels,
consensus sleep labels, diary helpers, and wrappers for the `asleep` and
`sleeper` machine-learning models.

The guider functions identify a likely main sleep window. Combine one or
more guiders with a SIB label when an epoch-level sleep/wake label is
needed.

## Why not `actisleep`?

The original package name was `actisleep`, but that conflicted with a
previous R package:
<https://cran.r-project.org/web/packages/ActiSleep/index.html>.

## Installation

Install the development version from GitHub:

``` r
# install.packages("remotes")
remotes::install_github("jhuwit/actisomni")
```

## Sleep guiders and labels

For epoch-level activity data, use an activity-based guider such as `L5`
and then apply a SIB label. The result has one logical sleep label per
epoch.

``` r
library(actisomni)

time <- as.POSIXct("2020-01-01 18:00:00", tz = "UTC") + 0:1439 * 60
epochs <- data.frame(
  time = time,
  activity = c(rep(20, 240), rep(0, 420), rep(20, 780)),
  sib = c(rep(FALSE, 240), rep(TRUE, 420), rep(FALSE, 780))
)

guider <- acti_sleep_l5(epochs)
epochs$sleep <- acti_sleep_label(epochs$sib, guider)
head(epochs)
#>                  time activity   sib sleep
#> 1 2020-01-01 18:00:00       20 FALSE FALSE
#> 2 2020-01-01 18:01:00       20 FALSE FALSE
#> 3 2020-01-01 18:02:00       20 FALSE FALSE
#> 4 2020-01-01 18:03:00       20 FALSE FALSE
#> 5 2020-01-01 18:04:00       20 FALSE FALSE
#> 6 2020-01-01 18:05:00       20 FALSE FALSE
```

For raw X/Y/Z acceleration, `acti_sleep_sib()` calculates the van Hees
SIB indicator and `acti_sleep_ensemble()` combines compatible guiders
into a consensus label. The example recording supplied by `actiread` can
be used directly:

``` r
library(actiread)

raw <- actiread::acti_read_gt3x(
  actiread::acti_example_gt3x(),
  verbose = FALSE
)
result <- acti_sleep_ensemble(raw, epoch = "5 seconds")

result$label_data
```

`result$labels` retains one label per guider, while `result$fused`
contains the consensus probability and logical consensus label.

## Diary windows

When diary times are available, create a guider directly from onset and
wake times. Times are inclusive at both endpoints.

``` r
diary_window <- acti_sleep_diary(
  epochs,
  onset = as.POSIXct("2020-01-01 22:00:00", tz = "UTC"),
  wakeup = as.POSIXct("2020-01-02 06:00:00", tz = "UTC")
)
sum(diary_window$window)
#> [1] 481
```

## Tudor–Locke sleep periods and metrics

For labelled, one-minute epochs, `acti_sleep_tudor_locke()` delegates
Tudor–Locke period detection and sleep metrics to `actigraph.sleepr`. It
accepts the usual actisomni column names: `time`, an activity column,
and a logical or sleep/wake `sleep` column.

``` r
sleep_diary <- data.frame(
  night = 1:2,
  onset = as.POSIXct(c("2020-01-03 22:30:00", "2020-01-04 22:45:00"), tz = "UTC"),
  wakeup = as.POSIXct(c("2020-01-04 06:15:00", "2020-01-05 06:30:00"), tz = "UTC")
)
sleep_diary
#>   night               onset              wakeup
#> 1     1 2020-01-03 22:30:00 2020-01-04 06:15:00
#> 2     2 2020-01-04 22:45:00 2020-01-05 06:30:00

tudor_epochs <- acti_sleep_tudor_locke_diary(
  data.frame(
    time = as.POSIXct("2020-01-03 22:00:00", tz = "UTC") + 0:539 * 60,
    activity = 0
  ),
  sleep_diary = sleep_diary
)
tudor_locke <- acti_sleep_tudor_locke(tudor_epochs)
tudor_locke[c("onset", "out_bed_time", "total_sleep_time", "efficiency")]
#> # A tibble: 1 × 4
#>   onset               out_bed_time        total_sleep_time efficiency
#>   <dttm>              <dttm>                         <int>      <dbl>
#> 1 2020-01-03 22:30:00 2020-01-04 06:15:00              465        100
```

Run the diary helper separately for each person. A diary is one row per
sleep interval, with POSIXct `onset` and `wakeup` columns; intervals can
cross midnight and span multiple days.

## Machine-learning model wrappers

`acti_asleep()` and `acti_sleeper()` both require complete, strictly
time-ordered raw triaxial data. They return the same columns: `time`,
`sleep`, `sleep_probability`, `sleep_stage`, `nonwear`, and `method`.

The models and their Python requirements are managed by the upstream
packages. For `sleeper`, download the model files first and provide
their directory as `model_dir`.

``` r
asleep_estimate <- acti_asleep(raw, verbose = FALSE)
sleeper_estimate <- acti_sleeper(raw, model_dir = "path/to/sleeper-models")
```
