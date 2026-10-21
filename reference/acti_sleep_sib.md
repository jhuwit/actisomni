# Detect sustained inactivity bouts (SIBs)

For raw triaxial accelerometer data, the default `"vanHees2015"` method
derives a longitudinal-axis angle at `epoch` resolution and identifies
periods with no posture change above `angle_threshold`. For epoch-level
data, provide a precomputed `sib` column; alternatively,
`"low_activity"` marks epochs whose conventional activity metric is at
or below `activity_threshold`.

## Usage

``` r
acti_sleep_sib(
  data,
  method = c("vanHees2015", "low_activity"),
  epoch = "5 seconds",
  time_threshold_minutes = 5,
  angle_threshold = 5,
  activity_threshold = 0
)
```

## Arguments

- data:

  Raw triaxial or regular epoch-level data.

- method:

  SIB method: `"vanHees2015"` or `"low_activity"`.

- epoch:

  Raw-data aggregation epoch, in seconds or a string such as
  `"5 seconds"`; see
  [`actibase::acti_standardize_epoch()`](https://jhuwit.github.io/actibase/reference/acti_standardize_epoch.html).

- time_threshold_minutes, angle_threshold:

  van Hees posture-change parameters.

- activity_threshold:

  Low-activity cutoff for epoch data.

## Value

A tibble with `time`, `sib`, and supporting epoch-level variables.

## Examples

``` r
# \donttest{
raw <- actiread::acti_read_gt3x(actiread::acti_example_gt3x(), verbose = FALSE)
sib <- acti_sleep_sib(raw)
# }
```
