# Apply an EXIF orientation

Rotates or flips an image the way its EXIF orientation says it should be
displayed. The operation is lossless: pixels are moved, never resampled.
[`pix_read()`](https://pedrobtz.github.io/zupix/reference/pix_read.md)
returns pixels as stored unless `orient = TRUE`, so the orientation
[`pix_info()`](https://pedrobtz.github.io/zupix/reference/pix_info.md)
reports and the pixels returned always agree.

## Usage

``` r
pix_orient(img, orientation)
```

## Arguments

- img:

  An image as
  [`pix_read()`](https://pedrobtz.github.io/zupix/reference/pix_read.md)
  returns it: a `nativeRaster`, a matrix, or a
  `height x width x channels` array.

- orientation:

  The EXIF orientation, 1 to 8: 1 as stored, 2 mirrored left to right, 3
  rotated 180 degrees, 4 mirrored top to bottom, 5 transposed, 6 rotated
  90 degrees clockwise, 7 transverse, 8 rotated 90 degrees
  anticlockwise. `NA` leaves the image as it is.

## Value

`img`, reoriented, with its class and its `bits` and `animated`
attributes kept.

## Examples

``` r
f <- system.file("extdata", "gradient.png", package = "zupix")
img <- pix_read(f, as = "integer")
dim(img)
#> [1] 32 48  3
dim(pix_orient(img, 6L))
#> [1] 48 32  3
```
