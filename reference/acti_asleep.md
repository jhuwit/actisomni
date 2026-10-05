# Estimate sleep with the asleep model

Runs
[`asleep::asleep()`](https://jhuwit.github.io/asleep/reference/asleep.html)
on complete, time-ordered raw triaxial acceleration and converts its
predictions to the common `acti_sleep_estimate` format.

## Usage

``` r
acti_asleep(
  data,
  min_wear_hours = 22L,
  time_shift = "0",
  report_light_and_temp = FALSE,
  pytorch_device = c("cpu", "cuda:0"),
  sample_rate = NULL,
  verbose = TRUE,
  force_download = FALSE
)

acti_calculate_asleep(
  data,
  min_wear_hours = 22L,
  time_shift = "0",
  report_light_and_temp = FALSE,
  pytorch_device = c("cpu", "cuda:0"),
  sample_rate = NULL,
  verbose = TRUE,
  force_download = FALSE
)
```

## Arguments

- data:

  A data frame containing timestamps and triaxial acceleration, or a
  readable accelerometry file path. File paths are passed unchanged to
  [`asleep::asleep()`](https://jhuwit.github.io/asleep/reference/asleep.html).

- min_wear_hours:

  Minimum daily wear time used by `asleep` summaries.

- time_shift:

  Clock-time correction passed to
  [`asleep::asleep()`](https://jhuwit.github.io/asleep/reference/asleep.html).

- report_light_and_temp:

  Whether to request light and temperature output.

- pytorch_device:

  Device used for prediction.

- sample_rate:

  Optional input sample rate.

- verbose:

  Whether `asleep` prints progress messages.

- force_download:

  Whether to re-download `asleep` model files.

## Value

An `acti_sleep_estimate` tibble with `time`, `sleep`,
`sleep_probability`, `sleep_stage`, `nonwear`, and `method`. The asleep
backend currently does not return probabilities, so `sleep_probability`
is `NA`.
