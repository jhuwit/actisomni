# Estimate sleep with asleep in an isolated Python process

Uses
[`asleep::py_asleep()`](https://jhuwit.github.io/asleep/reference/asleep.html)
to run the same asleep model as
[`acti_asleep()`](https://jhuwit.github.io/actisomni/reference/acti_asleep.md)
in a `callr` subprocess. This keeps Python package requirements separate
from the current R session.

## Usage

``` r
py_acti_asleep(
  data,
  min_wear_hours = 22L,
  time_shift = "0",
  report_light_and_temp = FALSE,
  pytorch_device = c("cpu", "cuda:0"),
  sample_rate = NULL,
  verbose = TRUE,
  force_download = FALSE,
  pyenv_function = function() asleep::py_require_asleep(),
  show = FALSE
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

- pyenv_function:

  Function that configures Python in the subprocess.

- show:

  Whether to stream subprocess output.

## Value

An `acti_sleep_estimate` tibble; see
[`acti_asleep()`](https://jhuwit.github.io/actisomni/reference/acti_asleep.md).
