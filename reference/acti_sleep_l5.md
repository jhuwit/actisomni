# Identify a sleep window from the least-active five hours

Identify a sleep window from the least-active five hours

## Usage

``` r
acti_sleep_l5(data, l5_hours = 5, window_hours = 12)
```

## Arguments

- data:

  A data frame of regular activity epochs.

- l5_hours:

  Duration of the least-active period.

- window_hours:

  Duration of the guider centred on L5.

## Value

An `acti_sleep_guider` object. `window` marks the window centred on the
least-active period; `l5_start_index` and `l5_activity_sum` identify
that period's starting epoch and total activity.

## Examples

``` r
# Repeat the bundled minute-level count data to form a complete example day.
data <- actimetrics::acti_count_data
data <- data[rep(seq_len(nrow(data)), length.out = 24 * 60), ]
data$time <- data$time[1] + (seq_len(nrow(data)) - 1) * 60
l5 <- acti_sleep_l5(data)
```
