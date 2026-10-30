# Build information

Reports the codecs compiled into zupix: each vendored library's version,
the upstream commit it was taken from and the local patches applied to
it, the version of zlib zupix is linked against, and whether Wuffs's
CPU-specific (SIMD) code paths were compiled for this platform.

## Usage

``` r
zupix_info()
```

## Value

A list with elements `version` (zupix's own, a
[package_version](https://rdrr.io/r/base/numeric_version.html)),
`vendored` (a data frame with one row per vendored library and columns
`name`, `version`, `commit`, `patches` and `used_for`), `zlib` (a
string) and `wuffs_simd` (`TRUE` or `FALSE`).

## Examples

``` r
info <- zupix_info()
info$vendored[c("name", "version")]
#>            name                      version
#> 1         wuffs 0.4.0-alpha.12+4048.20261020
#> 2 libjpeg-turbo                        3.2.1
#> 3       libwebp                        1.6.0
#> 4           qoi                      ffb2d2c
info$zlib
#> [1] "1.3"
```
