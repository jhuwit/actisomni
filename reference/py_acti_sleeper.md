# Estimate sleep with sleeper in an isolated Python process

Uses
[`sleeper::py_estimate_sleep()`](https://rdrr.io/pkg/sleeper/man/py_estimate_sleep.html)
to run the same sleeper model as
[`acti_sleeper()`](https://jhuwit.github.io/actisleep/reference/acti_sleeper.md)
in a `callr` subprocess.

## Usage

``` r
py_acti_sleeper(
  data,
  epoch = 30L,
  model_dir,
  pyenv_function = function() sleeper::py_require_sleeper(),
  show = FALSE
)
```

## Arguments

- data:

  A data frame containing timestamps and triaxial acceleration.

- epoch:

  Output epoch in seconds.

- model_dir:

  Directory containing the sleeper model files.

- pyenv_function:

  Function that configures Python in the subprocess.

- show:

  Whether to stream subprocess output.

## Value

An `acti_sleep_estimate` tibble; see
[`acti_sleeper()`](https://jhuwit.github.io/actisleep/reference/acti_sleeper.md).
