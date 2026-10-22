# actisomni 0.4.0

* `acti_sleep_hdcza()`, `acti_sleep_horangle()`, `acti_sleep_sib()`, and
  `acti_sleep_ensemble()` gain a `smooth` argument. The default,
  `"rollmedian"`, takes a five-second rolling median of each raw axis before
  computing the angle, as described by van Hees et al. (2015, 2018) and
  implemented in GGIR's `anglez`. This changes results: earlier versions
  computed the angle from each raw sample, which `smooth = "none"` restores.
  Smoothing warns when the timestamps have gaps, because the median window
  is counted in samples.
* `acti_sleep_ensemble()` smooths the raw axes once and reuses them for every
  angle-based guider, so messages and warnings are no longer repeated.
* Requires asleep (>= 0.4.0).

# actisomni 0.3.0

* `acti_asleep()` and `py_acti_asleep()` now return times in the input's time
  zone. `asleep` reports local clock times without a time zone, which were
  previously labelled UTC, shifting predictions by the UTC offset of the
  input (e.g. one hour for British Summer Time). A new `tz` argument sets the
  time zone, which is needed for file-path input (default `"UTC"`).
* For data-frame input, `acti_asleep()` and `py_acti_asleep()` pass `asleep` a
  clock held at the UTC offset at the start of the recording, so the clock
  never repeats or skips an hour at a daylight-saving transition and the
  returned times are the exact input instants. File input still reads the
  device clock in `tz`, so the two can differ after a transition.
* `acti_sleep_hdcza()` now defaults to GGIR's data-driven threshold: 15 times
  the 10th percentile of the five-minute rolling median absolute angle change,
  limited to 0.13--0.5 degrees. The percentile and multiplier are set with the
  new `threshold_percentile` and `threshold_multiplier` arguments (GGIR's
  `HDCZA_threshold = c(10, 15)`). `threshold` now defaults to `NULL`; set it to
  a number for a fixed threshold, e.g. `threshold = 0.2` for the previous
  default.
* The HDCZA rolling statistic is now the median absolute angle change within
  each five-minute window of angles, as in GGIR, rather than the median of the
  changes over a window one epoch wider.
* `epoch` arguments (guiders, `acti_sleep_sib()`, `acti_sleep_ensemble()`,
  `acti_sleeper()`) accept numeric seconds or strings such as `"30 seconds"`,
  standardized with `actibase::acti_standardize_epoch()`.
* Requires actibase (>= 0.8.0) for `acti_standardize_epoch()`.

# actisomni 0.2.0

* Removed the Tudor--Locke sleep-period adapter and diary-labeling helper;
  these are now provided through `actimetrics`.
* Removed `actigraph.sleepr` from `Imports`; `actisomni` no longer calls it.
* Trying to cleanup uv lock.
* Upgraded R version for pipe.

# actisomni 0.1.0

* Initial creation.
