# actisomni (development version)

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

# actisomni 0.2.0

* Removed the Tudor--Locke sleep-period adapter and diary-labeling helper;
  these are now provided through `actimetrics`.
* Removed `actigraph.sleepr` from `Imports`; `actisomni` no longer calls it.
* Trying to cleanup uv lock.
* Upgraded R version for pipe.

# actisomni 0.1.0

* Initial creation.
