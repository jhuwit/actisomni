# Create sleep/wake labels for multiple guiders

Create sleep/wake labels for multiple guiders

## Usage

``` r
acti_sleep_labels(sib, guiders, sleepwindow_type = c("SPT", "TimeInBed"))
```

## Arguments

- sib:

  Logical or 0/1 sustained-inactivity-bout classification.

- guiders:

  A named list of `acti_sleep_guider` objects. All guider windows must
  use the same epoch grid as `sib`.

- sleepwindow_type:

  The `SPT` or `TimeInBed` overlap rule.

## Value

A `tibble` with one logical `sleep_<guider>` column per guider.

## Examples

``` r
data <- actimetrics::acti_count_data
data <- data[rep(seq_len(nrow(data)), length.out = 24 * 60), ]
data$time <- data$time[1] + (seq_len(nrow(data)) - 1) * 60
guiders <- list(L5 = acti_sleep_l5(data), fixed = acti_sleep_setwindow(data))
labels <- acti_sleep_labels(data$counts == 0, guiders)
```
