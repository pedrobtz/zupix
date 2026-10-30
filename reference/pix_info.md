# Read an image's header and metadata

Reports what an image is without decoding its pixels: format, size,
depth, colour type, transparency, interlacing, animation, density, EXIF
orientation, PNG colour chunks, and whether ICC and EXIF data are
present. The colour information is reported, never applied.

## Usage

``` r
pix_info(x, format = "auto", limits = pix_limits())
```

## Arguments

- x:

  File paths (one row each), a raw vector holding one file's bytes, or a
  connection, which is read whole.

- format:

  `"auto"` reads the format from the file's signature, never its
  extension. A named format (`"png"`, `"jpeg"`, `"webp"`, `"qoi"`) that
  disagrees with the signature is an error.

- limits:

  Limits checked before anything is allocated; see
  [`pix_limits()`](https://pedrobtz.github.io/zupix/reference/pix_limits.md).

## Value

A data frame with one row per image and columns:

- `format`: `"png"`, `"jpeg"`, `"webp"` or `"qoi"`.

- `width`, `height`: in pixels, as stored (before any EXIF rotation).

- `bits`: the stored sample depth: 1, 2, 4, 8 or 16 for PNG; the
  precision for JPEG (8, or 12 which zupix does not decode); 8
  otherwise.

- `colour_type`: `"grey"`, `"grey_alpha"`, `"rgb"`, `"rgba"`,
  `"palette"`, `"ycbcr"`, `"cmyk"` or `"ycck"`, as stored. JPEG and
  lossy WebP store YCbCr; CMYK and YCCK JPEG decode to RGB.

- `alpha`: whether the image has transparency, including PNG `tRNS`.

- `interlaced`: Adam7 PNG or progressive JPEG.

- `animated`: APNG or animated WebP;
  [`pix_read()`](https://pedrobtz.github.io/zupix/reference/pix_read.md)
  decodes the first frame.

- `density_x`, `density_y`, `density_unit`: from PNG `pHYs` (unit 1:
  pixels per metre) or the JPEG JFIF header (1: per inch, 2: per
  centimetre); unit 0 gives only the aspect ratio. `NA` when absent.

- `orientation`: the EXIF orientation, 1 to 8, or `NA`. See
  [`pix_orient()`](https://pedrobtz.github.io/zupix/reference/pix_orient.md).

- `gamma`, `srgb`: PNG `gAMA` (the stored value over 100,000) and the
  `sRGB` rendering intent, or `NA`.

- `chrm`: a list column, PNG `cHRM`'s eight chromaticities (white, red,
  green, blue; x then y), or `NULL`.

- `cicp`: a list column, PNG `cICP`'s four integers (colour primaries,
  transfer function, matrix coefficients, full-range flag), or `NULL`.

- `icc`, `exif`: whether an ICC profile or EXIF data is present; see
  [`pix_icc()`](https://pedrobtz.github.io/zupix/reference/pix_icc.md)
  and
  [`pix_exif()`](https://pedrobtz.github.io/zupix/reference/pix_icc.md).

- `qoi_linear`: for QOI, whether the header declares linear channels
  rather than sRGB; `NA` for other formats.

## Examples

``` r
f <- system.file("extdata", "gradient.png", package = "zupix")
pix_info(f)
#>   format width height bits colour_type alpha interlaced animated density_x
#> 1    png    48     32    8         rgb FALSE      FALSE    FALSE        NA
#>   density_y density_unit orientation gamma srgb chrm cicp   icc  exif
#> 1        NA           NA          NA    NA   NA NULL NULL FALSE FALSE
#>   qoi_linear
#> 1         NA
```
