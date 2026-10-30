# Extract an image's ICC profile or EXIF data

`pix_icc()` returns the ICC profile embedded in a PNG (`iCCP`,
inflated), JPEG (`APP2` segments, reassembled in sequence order) or WebP
(`ICCP`). `pix_exif()` returns the EXIF block of a JPEG (`APP1`), PNG
(`eXIf`) or WebP (`EXIF`), from its TIFF header onward. Neither is
interpreted or applied; pass the profile to a colour-management package
to use it.

## Usage

``` r
pix_icc(x, format = "auto", limits = pix_limits())

pix_exif(x, format = "auto", limits = pix_limits())
```

## Arguments

- x:

  A file path, a raw vector holding the file's bytes, or a connection,
  which is read whole (up to `max_bytes` of `limits`).

- format:

  `"auto"` reads the format from the file's signature, never its
  extension. A named format (`"png"`, `"jpeg"`, `"webp"`, `"qoi"`) that
  disagrees with the signature is an error.

- limits:

  Limits checked before anything is allocated; see
  [`pix_limits()`](https://pedrobtz.github.io/zupix/reference/pix_limits.md).

## Value

A raw vector, or `NULL` when the image has none.

## Examples

``` r
f <- system.file("extdata", "gradient.png", package = "zupix")
pix_icc(f)
#> NULL
pix_exif(f)
#> NULL
```
