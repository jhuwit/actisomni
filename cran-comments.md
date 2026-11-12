## Submission

This update moves 'actiread' from Imports to Suggests. No package code used
it; it is only needed for examples (guarded with `requireNamespace()`) and
one test (guarded with `skip_if_not_installed()`). This removes the
"replacing previous import" warning that would otherwise occur once
'actibase', which 'actisomni' also imports, exports `tzoffset_to_tz()` in its
next release. It also reduces the number of recursive hard dependencies from
62 to 47.

The update also adds:

* `acti_rester()` and `py_acti_rester()`, wrappers for the AcceleRest
  sleep-staging model in the 'rester' package (now on CRAN, in Suggests).
  Examples and tests run only when 'rester' is installed; the examples
  also need the model weights, so they are in `\donttest{}` and skip
  otherwise.
* A `smooth = "rollmedian_full"` option for the angle-based sleep guiders
  (the default is unchanged), and new `acti_calculate_*()` aliases.

We are submitting this
update now so the next 'actibase' release does not trigger an install
warning in 'actisomni'. We will space out future updates.

## R CMD check results

0 errors | 0 warnings | 0 notes

## Reverse dependencies

There are no reverse dependencies on CRAN.
