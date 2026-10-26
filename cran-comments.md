## R CMD check results

0 errors | 0 warnings | 1 note

* This update fixes problems found after the
  0.2.0 release:
  * `acti_asleep()` and `py_acti_asleep()` returned prediction times shifted
    by the input's UTC offset (e.g. one hour for British Summer Time), and
    mis-aligned predictions across daylight-saving transitions. The fix
    relies on asleep 0.4.0, which is now on CRAN and required.
  * `acti_sleep_hdcza()` now uses GGIR's data-driven default threshold and
    errors clearly, instead of returning missing values, for epochs too
    coarse for its five-minute window.
  * The angle-based sleep guiders now take a five-second rolling median of
    each raw axis before computing the angle, as described by van Hees et al.
    (2015, 2018) and implemented in GGIR. This changes results; the previous
    behaviour is available with `smooth = "none"`.

## Reverse dependencies

There are no reverse dependencies on CRAN.
