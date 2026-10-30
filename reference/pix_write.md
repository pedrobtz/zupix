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

pix_write_jpeg(
  x,
  file = NULL,
  quality = 90L,
  subsampling = "4:2:0",
  progressive = FALSE,
  icc = NULL,
  exif = NULL
)

pix_write_webp(
  x,
  file = NULL,
  quality = 75,
  lossless = FALSE,
  method = 4L,
  icc = NULL,
  exif = NULL
)
```

## Arguments

- x:

  The image.

- file:

  A path to write, or `NULL` to return the encoded bytes.

- format:

  `NULL` to use `file`'s extension (`.png`, `.jpg`, `.jpeg`, `.webp`,
  `.qoi`), or `"png"`, `"jpeg"`, `"webp"` or `"qoi"`.

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

- quality:

  For JPEG, 1 to 100 on libjpeg's scale (`90` here means what it means
  to `jpeg::writeJPEG(quality = 0.9)`). For WebP, 0 to 100; with
  `lossless = TRUE` it trades speed for size instead.

- subsampling:

  JPEG chroma subsampling: `"4:2:0"`, `"4:2:2"` or `"4:4:4"`.

- progressive:

  `TRUE` writes a progressive JPEG.

- lossless:

  `TRUE` writes lossless WebP: the pixels read back exactly.

- method:

  WebP's speed and size trade-off, 0 (fastest) to 6 (smallest).

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

- `pix_write_jpeg()`: JPEG, 8-bit grey or RGB through libjpeg-turbo,
  with optimised Huffman tables, an optional ICC profile (`APP2`) and
  EXIF block (`APP1`). An alpha channel must be fully opaque, since JPEG
  cannot store transparency; 16-bit samples are rounded to 8 bits.

- `pix_write_webp()`: WebP through libwebp, lossy or lossless, RGB or
  RGBA (grey widens to RGB), with an optional ICC profile and EXIF block
  in zupix's own `VP8X` container. 16-bit samples are rounded to 8 bits.

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
