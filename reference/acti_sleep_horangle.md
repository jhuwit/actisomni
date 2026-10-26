# Identify a sleep window from horizontal posture

Identify a sleep window from horizontal posture

## Usage

``` r
acti_sleep_horangle(
  data,
  epoch = "5 seconds",
  longitudinal_axis = "Z",
  horizontal_threshold = 45,
  ignore_invalid = FALSE,
  min_block_minutes = 30,
  max_gap_minutes = 60,
  smooth = c("rollmedian", "none")
)
```

## Arguments

- data:

  A data frame of raw accelerometer observations.

- epoch:

  Epoch used to average raw angles, in seconds or a string such as
  `"5 seconds"`; see
  [`actibase::acti_standardize_epoch()`](https://jhuwit.github.io/actibase/reference/acti_standardize_epoch.html).

- longitudinal_axis:

  Raw axis used as the longitudinal axis: `"X"`, `"Y"`, or `"Z"`.

- horizontal_threshold:

  Absolute-angle limit defining horizontal posture.

- ignore_invalid:

  Whether invalid observations are treated as movement; use `NA` to
  treat them as no movement.

- min_block_minutes:

  Minimum low-movement block duration.

- max_gap_minutes:

  Maximum interruption bridged between blocks.

- smooth:

  Smoothing of the raw axes before the angle is computed: `"rollmedian"`
  (the default) takes a five-second rolling median of each axis first,
  as described by van Hees et al. (2015, 2018) and implemented in GGIR,
  so angles agree with GGIR's `anglez`; `"none"` computes the angle from
  each raw sample, as in actisomni 0.3.0 and earlier. The median is
  taken over samples, not time, so `"rollmedian"` warns when the
  timestamps have gaps; fill or resample such data first.

## Value

An `acti_sleep_guider` object. `window` marks the longest selected
horizontal-posture block, and `crude_window` marks all candidate blocks.
`horizontal` is the epoch-level posture flag, `threshold` is the angle
limit, and `epoch_data` contains the averaged angle and invalid flag.

## Examples

``` r
# \donttest{
raw <- actiread::acti_read_gt3x(actiread::acti_example_gt3x(), verbose = FALSE)
horizontal <- acti_sleep_horangle(raw, epoch = "5 seconds")
# }
```
