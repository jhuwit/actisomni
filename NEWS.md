# actisomni (development version)

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

# actisomni 0.2.0

* Removed the Tudor--Locke sleep-period adapter and diary-labeling helper;
  these are now provided through `actimetrics`.
* Removed `actigraph.sleepr` from `Imports`; `actisomni` no longer calls it.
* Trying to cleanup uv lock.
* Upgraded R version for pipe.

# actisomni 0.1.0

* Initial creation.
