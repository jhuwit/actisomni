# Fuse multiple sleep/wake labels with STAPLE

STAPLE estimates a latent consensus sleep label and each input labeler's
sensitivity and specificity using expectation-maximisation.

## Usage

``` r
acti_sleep_fuse_labels(
  labels,
  threshold = 0.5,
  tolerance = 1e-06,
  max_iterations = 200L
)
```

## Arguments

- labels:

  A data frame, matrix, or tibble of logical/binary sleep-label columns,
  such as the output of
  [`acti_sleep_labels()`](https://jhuwit.github.io/actisomni/reference/acti_sleep_labels.md).

- threshold:

  Posterior sleep-probability threshold for the fused label.

- tolerance, max_iterations:

  STAPLE convergence controls.

## Value

A tibble with `sleep_probability` and binary `sleep` columns. If
`labels` includes `time` or `epoch`, that index is retained. The fitted
STAPLE parameters are attached as the `staple` attribute.

## Examples

``` r
labels <- data.frame(
  sleep_l5 = c(FALSE, TRUE, TRUE, FALSE),
  sleep_fixed = c(FALSE, TRUE, FALSE, FALSE)
)
acti_sleep_fuse_labels(labels)
#> # A tibble: 4 × 2
#>   sleep_probability sleep
#>               <dbl> <lgl>
#> 1      0.0000000924 FALSE
#> 2      1.000        TRUE 
#> 3      0.375        FALSE
#> 4      0.0000000924 FALSE
```
