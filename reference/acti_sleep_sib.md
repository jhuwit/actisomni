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
  activity_threshold = 0,
  smooth = c("rollmedian", "none")
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

- smooth:

  Smoothing of the raw axes before the angle is computed: `"rollmedian"`
  (the default) takes a five-second rolling median of each axis first,
  as described by van Hees et al. (2015, 2018) and implemented in GGIR,
  so angles agree with GGIR's `anglez`; `"none"` computes the angle from
  each raw sample, as in actisomni 0.3.0 and earlier. The median is
  taken over samples, not time, so `"rollmedian"` warns when the
  timestamps have gaps; fill or resample such data first.

## Value

A tibble with `time`, `sib`, and supporting epoch-level variables.

## Examples

``` r
# \donttest{
raw <- actiread::acti_read_gt3x(actiread::acti_example_gt3x(), verbose = FALSE)
sib <- acti_sleep_sib(raw)
# }
```
