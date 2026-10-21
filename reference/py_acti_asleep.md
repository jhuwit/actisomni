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
  show = FALSE,
  tz = NULL
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

- tz:

  Time zone of the recording and the returned times. By default the time
  zone of `data$time`, or `"UTC"` when `data` is a file path; set it to
  the recording's time zone for file input. `asleep` works on local
  clock times without a time zone and splits the recording into
  noon-to-noon days on that clock.

  For data-frame input, the clock passed to `asleep` is held at the UTC
  offset in effect at the start of the recording, as a device clock is,
  so it never repeats or skips an hour at a daylight-saving transition.
  The returned times are the exact instants of the input, shown in `tz`.

  For file input, the device clock times that `asleep` reports are taken
  as clock times in `tz`. File and data-frame input of the same
  recording can therefore differ after a daylight-saving transition: a
  device clock that does not change for daylight saving is an hour off
  from `tz` until the clocks change back. This difference is known. To
  match such a device clock, use a fixed-offset time zone, e.g.
  `tz = "Etc/GMT-1"` for UTC+1.

## Value

An `acti_sleep_estimate` tibble; see
[`acti_asleep()`](https://jhuwit.github.io/actisomni/reference/acti_asleep.md).
