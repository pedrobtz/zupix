# Write an image

`pix_write()` picks the format from `file`'s extension (or `format`) and
passes `...` to that format's writer. The writers take the shapes
[`pix_read()`](https://pedrobtz.github.io/zupix/reference/pix_read.md)
returns:

## Usage

``` r
pix_write(x, file, format = NULL, ...)

pix_write_png(
  x,
  file = NULL,
  bits = NULL,
  compression = 6L,
  icc = NULL,
  exif = NULL,
  srgb = NULL
)

pix_write_qoi(x, file = NULL, colourspace = c("srgb", "linear"))
```

## Arguments

- x:

  The image.

- file:

  A path to write, or `NULL` to return the encoded bytes.

- format:

  `NULL` to use `file`'s extension, or `"png"` or `"qoi"`.

- ...:

  Arguments for the format's writer.

- bits:

  `NULL` keeps the image's depth (8 for doubles and `nativeRaster`s);
  `8L` or `16L` forces it.

- compression:

  The zlib level, 0 (store) to 9 (smallest).

- icc:

  An ICC profile as a raw vector, written as `iCCP`.

- exif:

  An EXIF block (TIFF header onward) as a raw vector, written as `eXIf`.

- srgb:

  `NULL`, or the `sRGB` chunk's rendering intent: 0 perceptual, 1
  relative colorimetric, 2 saturation, 3 absolute colorimetric. PNG does
  not allow both `icc` and `srgb`.

- colourspace:

  The QOI header's colourspace byte: `"srgb"` or `"linear"`. It is a
  label only; pixels are written as given.

## Value

With `file`, `file`, invisibly; with `file = NULL`, a raw vector.

## Details

- a `nativeRaster` (8-bit RGBA);

- a double array or matrix with values in `[0, 1]`, clamped to that
  range and rounded to `bits`;

- an integer array or matrix of sample values. Its `bits` attribute
  gives the depth; without one it is 8-bit if every value is at most
  255.

A matrix is a grey image; a `height x width x channels` array has 1 to 4
channels (grey, grey and alpha, RGB, RGBA). `NA` is an error.

## Functions

- `pix_write_png()`: PNG at 8 or 16 bits, 1 to 4 channels, with an
  optional ICC profile, EXIF block or sRGB rendering intent.

- `pix_write_qoi()`: QOI, 8-bit RGB or RGBA; grey widens to RGB.

## See also

[`pix_read()`](https://pedrobtz.github.io/zupix/reference/pix_read.md),
and
[zupix-conditions](https://pedrobtz.github.io/zupix/reference/zupix-conditions.md)
for the errors raised.

## Examples

``` r
f <- system.file("extdata", "gradient.png", package = "zupix")
img <- pix_read(f, as = "integer")
out <- tempfile(fileext = ".qoi")
pix_write(img, out)
identical(pix_read(out, as = "integer"), img)
#> [1] TRUE
```
