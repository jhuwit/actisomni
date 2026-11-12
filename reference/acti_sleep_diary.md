# Identify a diary-defined sleep window

Identify a diary-defined sleep window

## Usage

``` r
acti_sleep_diary(data, onset, wakeup)
```

## Arguments

- data:

  A data frame containing timestamps.

- onset, wakeup:

  `POSIXct` values defining a diary sleep window.

## Value

An `acti_sleep_guider` object. Missing diary times return an empty
window rather than imputing either boundary.

## Examples

``` r
data <- actimetrics::acti_count_data
diary_window <- acti_sleep_diary(
  data, onset = data$time[5], wakeup = data$time[30]
)
```
