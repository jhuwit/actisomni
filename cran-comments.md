## R CMD check results

0 errors | 0 warnings | 1 note

* Days since last update: 5. This update fixes two problems found after the
  0.2.0 release:
  * `acti_asleep()` and `py_acti_asleep()` returned prediction times shifted
    by the input's UTC offset (e.g. one hour for British Summer Time), and
    mis-aligned predictions across daylight-saving transitions.
  * `acti_sleep_hdcza()` now uses GGIR's data-driven default threshold and
    errors clearly, instead of returning missing values, for epochs too
    coarse for its five-minute window.

## Reverse dependencies

There are no reverse dependencies on CRAN.
