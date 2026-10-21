# actisomni (development version)

* `acti_asleep()` and `py_acti_asleep()` now return times in the input's time
  zone. `asleep` reports local clock times without a time zone, which were
  previously labelled UTC, shifting predictions by the UTC offset of the
  input (e.g. one hour for British Summer Time). A new `tz` argument sets the
  time zone, which is needed for file-path input (default `"UTC"`). Clock
  times repeated at an autumn daylight-saving transition are resolved by
  prediction order, so both occurrences of e.g. 01:30 map to distinct
  instants.

# actisomni 0.2.0

* Removed the Tudor--Locke sleep-period adapter and diary-labeling helper;
  these are now provided through `actimetrics`.
* Removed `actigraph.sleepr` from `Imports`; `actisomni` no longer calls it.
* Trying to cleanup uv lock.
* Upgraded R version for pipe.

# actisomni 0.1.0

* Initial creation.
