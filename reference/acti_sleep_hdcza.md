# Identify a sleep window with HDCZA

Implements the HDCZA sleep-period-time guider for wrist accelerometry.
It finds prolonged periods of little change in the supplied z-axis
angle, joins interruptions shorter than an hour, and returns the longest
resulting block. As in GGIR, the default threshold is derived from the
recording: 15 times the 10th percentile of the five-minute rolling
median absolute angle change, limited to between 0.13 and 0.5 degrees.
Setting `threshold` gives a fixed threshold in degrees instead (e.g.
`threshold = 0.2`, the previous default). GGIR's
`HDCZA_threshold = c(p, m)` corresponds to
`threshold_percentile = p, threshold_multiplier = m`.

## Usage

``` r
acti_sleep_hdcza(
  data,
  epoch = "5 seconds",
  threshold = NULL,
  threshold_percentile = 10,
  threshold_multiplier = 15,
  ignore_invalid = FALSE,
  min_block_minutes = 30,
  max_gap_minutes = 60
)
```

## Arguments

- data:

  A data frame of raw accelerometer observations.

- epoch:

  Epoch used to average raw angles, in seconds or a string such as
  `"5 seconds"`; see
  [`actibase::acti_standardize_epoch()`](https://jhuwit.github.io/actibase/reference/acti_standardize_epoch.html).
  Must be at most 200 seconds so that each five-minute window holds at
  least two angles.

- threshold:

  Fixed maximum five-minute rolling median absolute angle change, in
  degrees. The default, `NULL`, derives the threshold from the recording
  using `threshold_percentile` and `threshold_multiplier`.

- threshold_percentile:

  Percentile, between 1 and 100, of the rolling median absolute angle
  change used for the data-driven threshold. Ignored when `threshold` is
  set.

- threshold_multiplier:

  Positive multiplier applied to that percentile for the data-driven
  threshold. Ignored when `threshold` is set.

- ignore_invalid:

  Whether invalid observations are treated as movement; use `NA` to
  treat them as no movement.

- min_block_minutes:

  Minimum low-movement block duration.

- max_gap_minutes:

  Maximum interruption bridged between blocks.

## Value

An `acti_sleep_guider` object. `window` is the selected SPT guider;
`crude_window` retains all candidate blocks before choosing the longest.

## Examples

``` r
# \donttest{
# The bundled actiread recording contains raw X, Y, and Z acceleration.
raw <- actiread::acti_read_gt3x(actiread::acti_example_gt3x(), verbose = FALSE)
hdcza <- acti_sleep_hdcza(raw, epoch = "5 seconds")
# }
```
