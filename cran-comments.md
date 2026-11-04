## Submission

This update stops importing the whole 'actiread' namespace and instead uses
`import(actiread, except = "tzoffset_to_tz")`. 'actisomni' does not use
`tzoffset_to_tz()`. The change lets 'actibase', which 'actisomni' also
imports, export `tzoffset_to_tz()` in a future release without causing a
"replacing previous import" warning when 'actisomni' is installed.

We know 0.4.0 was published recently (2026-10-26). We are submitting this
update now so the next 'actibase' release does not trigger an install
warning in 'actisomni'. We will space out future updates.

## R CMD check results

0 errors | 0 warnings | 1 note

## Reverse dependencies

There are no reverse dependencies on CRAN.
