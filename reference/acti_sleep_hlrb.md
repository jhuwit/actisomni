# Identify the longest rest bout from sustained inactivity bouts

Identify the longest rest bout from sustained inactivity bouts

## Usage

``` r
acti_sleep_hlrb(data)
```

## Arguments

- data:

  A data frame of regular epochs.

## Value

An `acti_sleep_guider` object. `window` marks the longest selected rest
bout, `crude_window` marks all bouts before selection, and
`smoothed_sib` is the logical SIB classification after two-hour
smoothing.

## Examples

``` r
data <- actimetrics::acti_count_data
data <- data[rep(seq_len(nrow(data)), length.out = 24 * 60), ]
data$time <- data$time[1] + (seq_len(nrow(data)) - 1) * 60
# In practice, use a validated SIB classification rather than this example.
sib <- data$counts == 0
data$sib <- data$counts == 0
longest_rest <- acti_sleep_hlrb(data)
```
