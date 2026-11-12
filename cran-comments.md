## Submission

This update moves 'actiread' from Imports to Suggests. No package code used
it; it is only needed for examples (guarded with `requireNamespace()`) and
one test (guarded with `skip_if_not_installed()`). This removes the
"replacing previous import" warning that would otherwise occur once
'actibase', which 'actisomni' also imports, exports `tzoffset_to_tz()` in its
next release. It also reduces the number of recursive hard dependencies from
62 to 47.

The update also adds a `smooth = "rollmedian_full"` option to the angle-based
sleep guiders (the default is unchanged) and new `acti_calculate_*()` aliases.

We know 0.4.0 was published recently (2026-10-26). We are submitting this
update now so the next 'actibase' release does not trigger an install
warning in 'actisomni'. We will space out future updates.

## R CMD check results

0 errors | 0 warnings | 0 notes

## Reverse dependencies

There are no reverse dependencies on CRAN.
