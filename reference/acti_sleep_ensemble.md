# Run a sleep-label ensemble from raw or epoch data

This convenience workflow detects or accepts sustained inactivity bouts,
runs compatible sleep guiders, creates one sleep label per guider, then
produces a consensus. Raw triaxial data use `HDCZA`, `HorAngle`, and a
fixed 22:00–08:00 window by default; `L5` is included only when the data
span its requested duration. Epoch data use `NotWorn` and the fixed
window, adding `L5` when possible. Set `guiders` to choose a subset
explicitly.

## Usage

``` r
acti_sleep_ensemble(
  data,
  guiders = NULL,
  epoch = "5 seconds",
  sib_method = "vanHees2015",
  fusion = c("staple", "majority"),
  sleepwindow_type = c("SPT", "TimeInBed"),
  smooth = c("rollmedian", "none"),
  ...
)
```

## Arguments

- data:

  Raw triaxial or regular epoch-level data. Epoch data should have a
  `sib` column or a conventional activity column.

- guiders:

  Guider names. Defaults depend on whether raw acceleration is
  available.

- epoch:

  Raw-data aggregation epoch, in seconds or a string such as
  `"5 seconds"`; see
  [`actibase::acti_standardize_epoch()`](https://jhuwit.github.io/actibase/reference/acti_standardize_epoch.html).

- sib_method:

  SIB method, passed to
  [`acti_sleep_sib()`](https://jhuwit.github.io/actisomni/reference/acti_sleep_sib.md).

- fusion:

  Consensus rule: `"staple"` or `"majority"`.

- sleepwindow_type:

  SPT or TimeInBed overlap rule.

- smooth:

  Smoothing of the raw axes before the angle is computed: `"rollmedian"`
  (the default) takes a five-second rolling median of each axis first,
  as described by van Hees et al. (2015, 2018) and implemented in GGIR,
  so angles agree with GGIR's `anglez`; `"none"` computes the angle from
  each raw sample, as in actisomni 0.3.0 and earlier. The median is
  taken over samples, not time, so `"rollmedian"` warns when the
  timestamps have gaps; fill or resample such data first.

- ...:

  Passed to the individual guider functions.

## Value

A list of time-indexed data. `epoch_data` includes the van Hees `sib`;
each guider has a `label_data` element with `time` and `window`;
`labels` has `time` plus one logical `sleep_<guider>` column per guider;
`fused` has `time`, probability, and consensus label; and `label_data`
combines all these analysis columns.

## Examples

``` r
# \donttest{
raw <- actiread::acti_read_gt3x(actiread::acti_example_gt3x(), verbose = FALSE)
result <- acti_sleep_ensemble(raw)
# }
```
