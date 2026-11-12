# Estimate sleep with AcceleRest in an isolated Python process

Uses
[`rester::py_estimate_rest()`](https://rdrr.io/pkg/rester/man/py_estimate_rest.html)
to run the same AcceleRest model as
[`acti_rester()`](https://jhuwit.github.io/actisomni/reference/acti_rester.md)
in a `callr` subprocess. This keeps Python package requirements separate
from the current R session.

## Usage

``` r
py_acti_rester(
  data,
  model = c("lstm_sleepstages", "linear_sleepstages"),
  sample_rate = NULL,
  tz = NULL,
  cache_dir = rester::ar_cache_dir(),
  context_window_shift = 1L,
  max_batch_size = 16L,
  device = NULL,
  pyenv_function = function() rester::py_require_rester(),
  show = FALSE,
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

- pyenv_function:

  Function that configures Python in the subprocess.

- show:

  Whether to stream subprocess output.

- ...:

  Additional arguments passed to
  [`rester::ar_read()`](https://rdrr.io/pkg/rester/man/ar_read.html),
  such as `fill_zeros`, `detect_nonwear`, or `verbose`.

## Value

An `acti_sleep_estimate` `tibble`; see
[`acti_rester()`](https://jhuwit.github.io/actisomni/reference/acti_rester.md).
