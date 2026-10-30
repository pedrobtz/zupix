# Limits on what an image may make zupix allocate

Images are hostile input: a small file can declare a huge image. zupix
reads an image's header, checks it against these limits, and only then
allocates anything, so a breach raises a `zupix_limit_error` (see
[zupix-conditions](https://pedrobtz.github.io/zupix/reference/zupix-conditions.md))
before any pixel memory exists.

## Usage

``` r
pix_limits(
  max_side = getOption("zupix.max_side", 65535L),
  max_pixels = getOption("zupix.max_pixels", 1e+08),
  max_bytes = getOption("zupix.max_bytes", 2^31),
  max_metadata = getOption("zupix.max_metadata", 16 * 2^20)
)
```

## Arguments

- max_side:

  The largest width or height, in pixels. The default, 65,535, is JPEG's
  own maximum.

- max_pixels:

  The largest `width * height`. The default is 10^8.

- max_bytes:

  The most memory one decode may use: the R result, its working copy and
  the decoder's work buffer together. The default is 2 GiB. A 10^8-pixel
  RGBA image needs 3.2 GB as a double array but 400 MB as a
  `nativeRaster`. Inputs read from a file or connection are also capped
  at this size.

- max_metadata:

  The most bytes of metadata (ICC profile, EXIF) one image may carry.
  The default is 16 MiB.

## Value

A `zupix_limits` object, to pass as the `limits` argument of the
readers.

## Details

The defaults can be changed for a session with the options
`zupix.max_side`, `zupix.max_pixels`, `zupix.max_bytes` and
`zupix.max_metadata`.

## Examples

``` r
pix_limits()
#> <zupix_limits>
#>   max_side      65,535
#>   max_pixels    100,000,000
#>   max_bytes     2,147,483,648
#>   max_metadata  16,777,216
pix_limits(max_pixels = 1e6)
#> <zupix_limits>
#>   max_side      65,535
#>   max_pixels    1,000,000
#>   max_bytes     2,147,483,648
#>   max_metadata  16,777,216
```
