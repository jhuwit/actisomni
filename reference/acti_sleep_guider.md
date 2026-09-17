# Dispatch a sleep-period-time guider from data

For `"HDCZA"` and `"HorAngle"`, supply raw triaxial acceleration; the
selected function derives a regular epoch-level posture angle. The
remaining methods use regular epoch-level activity, SIB, or timestamp
data. Use
[`acti_sleep_guider_requirements()`](https://jhuwit.github.io/actisomni/reference/acti_sleep_guider_requirements.md)
for a method-by-method summary.

## Usage

``` r
acti_sleep_guider(
  data,
  method = c("HDCZA", "HorAngle", "L5", "setwindow", "HLRB", "NotWorn", "sleeplog"),
  ...
)
```

## Arguments

- data:

  A raw or epoch-level data frame, according to `method`.

- method:

  One of `"HDCZA"`, `"HorAngle"`, `"L5"`, `"setwindow"`, `"HLRB"`,
  `"NotWorn"`, or `"sleeplog"`.

- ...:

  Method-specific arguments, such as `threshold`, `start_hour`, `onset`,
  and `wakeup`.

## Value

An `acti_sleep_guider` object.

## Examples

``` r
data <- actimetrics::acti_count_data
data <- data[rep(seq_len(nrow(data)), length.out = 24 * 60), ]
data$time <- data$time[1] + (seq_len(nrow(data)) - 1) * 60
guider <- acti_sleep_guider(data, method = "L5")
```
