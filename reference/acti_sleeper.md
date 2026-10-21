# Estimate sleep with the sleeper model

Runs
[`sleeper::estimate_sleep()`](https://rdrr.io/pkg/sleeper/man/estimate_sleep.html)
on complete, time-ordered raw triaxial acceleration. Input is converted
to the timestamp-in-seconds format required by `sleeper` before the
model is called.

## Usage

``` r
acti_sleeper(data, epoch = 30L, model_dir)
```

## Arguments

- data:

  A data frame containing timestamps and triaxial acceleration.

- epoch:

  Output epoch, in whole seconds or a string such as `"30 seconds"`; see
  `actibase::acti_standardize_epoch()`.

- model_dir:

  Directory containing the sleeper model files.

## Value

An `acti_sleep_estimate` tibble with `time`, `sleep`,
`sleep_probability`, `sleep_stage`, `nonwear`, and `method`. The sleeper
backend does not return probabilities or sleep stages, so those columns
are `NA`.
