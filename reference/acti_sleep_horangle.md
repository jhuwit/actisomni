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
  max_gap_minutes = 60
)
```

## Arguments

- data:

  A data frame of raw accelerometer observations.

- epoch:

  Epoch used to average raw angles, in seconds or a string such as
  `"5 seconds"`; see `actibase::acti_standardize_epoch()`.

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
#> Error: 'acti_standardize_epoch' is not an exported object from 'namespace:actibase'
# }
```
