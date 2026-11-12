# Describe data requirements for sleep guiders

HDCZA and HorAngle take raw triaxial acceleration and create their own
regular epoch-level angle. All other guiders take a regularly spaced,
epoch-level data frame and do not require raw acceleration data.

## Usage

``` r
acti_sleep_guider_requirements()
```

## Value

A `tibble` describing the required data for each guider.

## Examples

``` r
acti_sleep_guider_requirements()
#> # A tibble: 7 × 4
#>   method    required_epoch_columns raw_acceleration input_description           
#>   <chr>     <chr>                  <lgl>            <chr>                       
#> 1 HDCZA     time, X, Y, Z          TRUE             Raw wrist acceleration. The…
#> 2 HorAngle  time, X, Y, Z          TRUE             Raw hip acceleration. The f…
#> 3 L5        time, activity         FALSE            Any regular epoch-level act…
#> 4 setwindow time                   FALSE            Timestamps only; identifies…
#> 5 HLRB      time, sib              FALSE            A regular epoch-level susta…
#> 6 NotWorn   time, activity         FALSE            Any regular epoch-level act…
#> 7 sleeplog  time                   FALSE            Timestamps plus `onset` and…
```
