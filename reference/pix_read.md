# Read an image

Decodes a PNG, JPEG, WebP or QOI image into one of three shapes. The
pixels are the ones the file holds: no colour conversion, gamma or ICC
profile is applied, and EXIF orientation is applied only when asked.
Animated PNG and WebP decode their first frame, with attribute
`animated` set to `TRUE`. CMYK and YCCK JPEG decode to RGB without
colour management.

## Usage

``` r
pix_read(
  x,
  as = c("native", "double", "integer"),
  bits = NULL,
  channels = NULL,
  orient = FALSE,
  format = "auto",
  limits = pix_limits()
)
```

## Arguments

- x:

  A file path, a raw vector holding the file's bytes, or a connection,
  which is read whole (up to `max_bytes` of `limits`).

- as:

  The shape of the result:

  - `"native"`: a `nativeRaster`, 8-bit RGBA, as
    `png::readPNG(native = TRUE)` returns. 16-bit samples are rounded to
    8 bits.

  - `"double"`: a `height x width x channels` array of values in
    `[0, 1]`, or a matrix for one channel, as
    [`png::readPNG()`](https://rdrr.io/pkg/png/man/readPNG.html)
    returns. 16-bit precision is kept.

  - `"integer"`: the same shape holding the sample values, `0..255` or
    `0..65535`, with attribute `bits` (`8L` or `16L`).

- bits:

  `NULL` keeps the file's depth (1-, 2- and 4-bit PNGs become 8); `8L`
  or `16L` forces it. Not used by `as = "native"`.

- channels:

  `NULL` keeps the file's channels: 1 grey, 2 grey and alpha, 3 RGB, 4
  RGBA; a palette becomes 3, or 4 when it has transparency. A larger
  number adds channels (grey to RGB, an opaque alpha); a smaller one is
  an error, because removing colour or alpha is a colour decision. Not
  used by `as = "native"`.

- orient:

  `TRUE` applies the image's EXIF orientation (see
  [`pix_orient()`](https://pedrobtz.github.io/zupix/reference/pix_orient.md));
  `FALSE`, the default, returns the pixels as stored.

- format:

  `"auto"` reads the format from the file's signature, never its
  extension. A named format (`"png"`, `"jpeg"`, `"webp"`, `"qoi"`) that
  disagrees with the signature is an error.

- limits:

  Limits checked before anything is allocated; see
  [`pix_limits()`](https://pedrobtz.github.io/zupix/reference/pix_limits.md).

## Value

The image, in the shape `as` asks for.

## See also

[zupix-conditions](https://pedrobtz.github.io/zupix/reference/zupix-conditions.md)
for the errors raised.

## Examples

``` r
f <- system.file("extdata", "gradient.png", package = "zupix")
img <- pix_read(f)
dim(img)
#> [1] 32 48
str(pix_read(f, as = "integer"))
#>  int [1:32, 1:48, 1:3] 0 0 0 0 0 0 0 0 0 0 ...
#>  - attr(*, "bits")= int 8
range(pix_read(f, as = "double"))
#> [1] 0 1
```
