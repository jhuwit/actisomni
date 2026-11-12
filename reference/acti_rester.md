# Estimate sleep with the AcceleRest model

Runs
[`rester::estimate_rest()`](https://rdrr.io/pkg/rester/man/estimate_rest.html),
the AcceleRest model of Lorenzen et al. (2026), on raw triaxial
acceleration and converts its sleep-stage predictions to the common
`acti_sleep_estimate` format. AcceleRest predicts deep, light, REM, and
wake stages for 30-second epochs over context windows of about 2.1
hours, so at least that much data is needed.

## Usage

``` r
acti_rester(
  data,
  model = c("lstm_sleepstages", "linear_sleepstages"),
  sample_rate = NULL,
  tz = NULL,
  cache_dir = rester::ar_cache_dir(),
  context_window_shift = 1L,
  max_batch_size = 16L,
  device = NULL,
  ...
)
```

## Arguments

- data:

  A data frame containing timestamps and triaxial acceleration, or a
  readable accelerometry file path (a device file or CSV; `.h5` files
  are not supported because they have no time stamps). File paths are
  passed unchanged to
  [`rester::estimate_rest()`](https://rdrr.io/pkg/rester/man/estimate_rest.html).

- model:

  The sleep-stage head to use: `"lstm_sleepstages"` (default) or
  `"linear_sleepstages"`.

- sample_rate:

  Sample rate (Hz) of the input. If `NULL`, it is found with
  [`actibase::get_sample_rate()`](https://jhuwit.github.io/actibase/reference/get_sample_rate.html)
  (from the `sample_rate` attribute, the header, or the time stamps).

- tz:

  Time zone of the returned times. By default the time zone of
  `data$time`, or the time zone of the times read from a file.

  For data-frame input, the clock passed to `rester` is held at the UTC
  offset in effect at the start of the recording, as `actipy` works on
  clock times without a time zone. The returned times are the exact
  instants of the input, shown in `tz`.

- cache_dir:

  Directory with the downloaded AcceleRest code and weights; see
  [`rester::ar_setup()`](https://rdrr.io/pkg/rester/man/ar_setup.html).

- context_window_shift:

  Number of 30-second epochs to shift consecutive context windows; see
  [`rester::estimate_rest()`](https://rdrr.io/pkg/rester/man/estimate_rest.html).

- max_batch_size:

  Number of context windows per forward pass.

- device:

  `torch` device, e.g. `"cpu"`, `"cuda"`, or `"mps"`. If `NULL`,
  `rester` chooses.

- ...:

  Additional arguments passed to
  [`rester::ar_read()`](https://rdrr.io/pkg/rester/man/ar_read.html),
  such as `fill_zeros`, `detect_nonwear`, or `verbose`.

## Value

An `acti_sleep_estimate` `tibble` with `time`, `sleep`,
`sleep_probability`, `sleep_stage`, `nonwear`, and `method`.
`sleep_probability` is one minus the probability of wake, `sleep_stage`
is the most probable of `"deep"`, `"light"`, `"rem"`, and `"wake"`, and
epochs with no valid data have `NA` for `sleep`, `sleep_probability`,
`sleep_stage`, and `nonwear`. The `actipy` information about the data is
in `attr(x, "info")`.

## Details

The model code and weights must be downloaded first with
[`rester::ar_setup()`](https://rdrr.io/pkg/rester/man/ar_setup.html).

## References

Lorenzen NR, Brink-Kjaer A, Jennum PJ, Mignot E (2026). AcceleRest: A
Physiology-Aware Masked Autoencoder for Wrist Accelerometer-based Sleep
Staging and Apnea Evaluation. *medRxiv*.
[doi:10.64898/2026.01.28.26345056](https://doi.org/10.64898/2026.01.28.26345056)

## Examples

``` r
# \donttest{
  # Runs only after rester::ar_setup(), so Python is not set up otherwise
  if (rester::ar_have_repo() &&
      rester::ar_have_weights("lstm_sleepstages") &&
      rester::ar_python_modules_installed()) {
    data <- rester::ar_example_data(n_hours = 2.5)
    out <- acti_rester(data, context_window_shift = 32L)
    head(out)
  }
# }
```
